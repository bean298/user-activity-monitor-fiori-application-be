CLASS zcl_uam_risk_calculator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_risk_cfg,
        act_type   TYPE zuam_act_type,
        value      TYPE zuam_cfg_value,
        risk_score TYPE zuam_risk_score,
        severity   TYPE zuam_severity,
      END OF ty_risk_cfg,
      tt_risk_cfg TYPE SORTED TABLE OF ty_risk_cfg
                  WITH NON-UNIQUE KEY act_type value.

    DATA mt_risk_cfg TYPE tt_risk_cfg.

    METHODS load_config.

    METHODS get_score_from_cfg
      IMPORTING
        iv_act_type      TYPE zuam_act_type
        iv_value         TYPE zuam_cfg_value
      RETURNING
        VALUE(rs_result) TYPE zuam_risk_result.

    METHODS apply_offhours_multiplier
      IMPORTING
        iv_act_time TYPE syuzeit
      CHANGING
        cs_result   TYPE zuam_risk_result.

    METHODS process_activity_data.

    METHODS process_auth_data.

ENDCLASS.


CLASS zcl_uam_risk_calculator IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    me->load_config( ).
    me->process_activity_data( ).
    me->process_auth_data( ).
  ENDMETHOD.

  METHOD load_config.
    IF mt_risk_cfg IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT act_type, value, risk_score, severity
      FROM zuam_risk_cfg
      INTO TABLE @mt_risk_cfg.
  ENDMETHOD.


  METHOD get_score_from_cfg.
    " Exact match
    READ TABLE mt_risk_cfg INTO DATA(ls_exact)
      WITH KEY act_type = iv_act_type
               value    = iv_value.
    IF sy-subrc = 0.
      rs_result-score    = ls_exact-risk_score.
      rs_result-severity = ls_exact-severity.
      RETURN.
    ENDIF.

    " Wildcard fallback
    READ TABLE mt_risk_cfg INTO DATA(ls_wild)
      WITH KEY act_type = iv_act_type
               value    = '*'.
    IF sy-subrc = 0.
      rs_result-score    = ls_wild-risk_score.
      rs_result-severity = ls_wild-severity.
    ENDIF.
  ENDMETHOD.


  METHOD apply_offhours_multiplier.
    IF iv_act_time < '080000' OR iv_act_time > '170000'.
      cs_result-score = cs_result-score * 15 / 10.
    ENDIF.
  ENDMETHOD.


  METHOD process_activity_data.
    SELECT act_id, username, tcode, act_tims
      FROM ZUAM_ACT_LOG
      WHERE is_scored = @abap_false
      INTO TABLE @DATA(lt_activity).

    LOOP AT lt_activity INTO DATA(ls_act).
      DATA(ls_result) = me->get_score_from_cfg(
        iv_act_type = 'TCODE'
        iv_value    = CONV #( ls_act-tcode ) ).

      me->apply_offhours_multiplier(
        EXPORTING iv_act_time = ls_act-act_tims
        CHANGING  cs_result   = ls_result ).

      UPDATE ZUAM_ACT_LOG
        SET risk_score = @ls_result-score,
            severity   = @ls_result-severity,
            is_scored  = @abap_true
        WHERE act_id = @ls_act-act_id.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.


  METHOD process_auth_data.
    SELECT session_id, username, login_result, login_time
      FROM ZUAM_AUTH_LOG
      WHERE login_result = 'FAIL'
        AND is_scored    = @abap_false
      INTO TABLE @DATA(lt_auth).

    LOOP AT lt_auth INTO DATA(ls_auth).
      DATA(ls_result) = me->get_score_from_cfg(
        iv_act_type = 'LOGIN_FAIL'
        iv_value    = '*' ).

      me->apply_offhours_multiplier(
        EXPORTING iv_act_time = ls_auth-login_time
        CHANGING  cs_result   = ls_result ).

      UPDATE ZUAM_AUTH_LOG
        SET risk_score = @ls_result-score,
            severity   = @ls_result-severity,
            is_scored  = @abap_true
        WHERE session_id = @ls_auth-session_id.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
