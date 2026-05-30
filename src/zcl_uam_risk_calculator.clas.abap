CLASS zcl_uam_risk_calculator DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_risk_cfg,
        act_type    TYPE zuam_act_type,
        value       TYPE zuam_cfg_value,
        risk_score  TYPE zuam_risk_score,
        severity    TYPE zuam_severity,
      END OF ty_risk_cfg,
      tt_risk_cfg TYPE STANDARD TABLE OF ty_risk_cfg WITH DEFAULT KEY.

    DATA mt_risk_cfg TYPE tt_risk_cfg.

    METHODS load_config.

    " Calculate TCode score (exact match → wildcard)
    METHODS get_tcode_score
      IMPORTING iv_tcode         TYPE tcode
                iv_act_type      TYPE zuam_act_type DEFAULT 'TCODE'
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    " Calculate Dump score (CS pattern matching)
    METHODS get_dump_score
      IMPORTING iv_message       TYPE ZE_MSG_TEXT
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    " Calculate Export score based on daily thresholds
    METHODS get_export_score
      IMPORTING iv_username      TYPE xubname
                iv_date          TYPE sydatum
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    " Off-hours multiplier × 1.5
    METHODS apply_offhours_multiplier
      IMPORTING iv_act_time TYPE syuzeit
      CHANGING  cs_result   TYPE zuam_risk_result.

        METHODS get_terminal_score          " <-- NEW
      IMPORTING iv_username      TYPE xubname
                iv_login_date    TYPE sydatum
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    METHODS process_tcode_data.
    METHODS process_dump_data.
    METHODS process_export_data.
    METHODS process_auth_data.

ENDCLASS.


CLASS zcl_uam_risk_calculator IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    me->load_config( ).
    me->process_tcode_data( ).
    me->process_dump_data( ).
    me->process_export_data( ).
    me->process_auth_data( ).
  ENDMETHOD.

  METHOD load_config.
    IF mt_risk_cfg IS NOT INITIAL. RETURN. ENDIF.

    SELECT act_type, value, risk_score, severity
      FROM zuam_risk_cfg
      INTO TABLE @mt_risk_cfg.
  ENDMETHOD.

  METHOD apply_offhours_multiplier.
    IF iv_act_time < '080000' OR iv_act_time > '170000'.
      cs_result-score = cs_result-score * 15 / 10.
    ENDIF.
  ENDMETHOD.

  METHOD get_tcode_score.
    " Exact match
    READ TABLE mt_risk_cfg INTO DATA(ls_exact)
      WITH KEY act_type = iv_act_type
               value    = CONV zuam_cfg_value( iv_tcode ).
    IF sy-subrc = 0.
      rs_result-score    = ls_exact-risk_score.
      rs_result-severity = ls_exact-severity.
      RETURN.
    ENDIF.

    " Wildcard fallback (*)
    READ TABLE mt_risk_cfg INTO DATA(ls_wild)
      WITH KEY act_type = iv_act_type
               value    = '*'.
    IF sy-subrc = 0.
      rs_result-score    = ls_wild-risk_score.
      rs_result-severity = ls_wild-severity.
    ENDIF.
  ENDMETHOD.

  METHOD get_dump_score.

    LOOP AT mt_risk_cfg INTO DATA(ls_cfg)
      WHERE act_type = 'DUMP'.

      IF ls_cfg-value = '*'.
        " Fallback — no pattern matched yet
        rs_result-score    = ls_cfg-risk_score.
        rs_result-severity = ls_cfg-severity.
        EXIT.
      ENDIF.

      IF iv_message CS ls_cfg-value.
        rs_result-score    = ls_cfg-risk_score.
        rs_result-severity = ls_cfg-severity.
        RETURN.   " matched → stop further checks
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD get_export_score.
    " Count number of EXPORT records per user per day
    SELECT COUNT(*)
      FROM zuam_act_log
      WHERE username = @iv_username
        AND act_date  = @iv_date
        AND act_type  = 'EXPORT'
      INTO @DATA(lv_count).

    " Determine threshold (highest first)
    DATA(lv_threshold) = COND zuam_cfg_value(
      WHEN lv_count >= 20 THEN 'THRESHOLD_20'
      WHEN lv_count >= 10 THEN 'THRESHOLD_10'
      WHEN lv_count >= 5  THEN 'THRESHOLD_5'
      ELSE '' ).

    IF lv_threshold IS INITIAL. RETURN. ENDIF.

    READ TABLE mt_risk_cfg INTO DATA(ls_cfg)
      WITH KEY act_type = 'EXPORT'
               value    = lv_threshold.
    IF sy-subrc = 0.
      rs_result-score    = ls_cfg-risk_score.
      rs_result-severity = ls_cfg-severity.
    ENDIF.
  ENDMETHOD.

  METHOD process_tcode_data.
    SELECT act_id, username, act_type, tcode, act_tims
      FROM zuam_act_log
      WHERE act_type  IN ('TCODE', 'TABLE_EDIT')
        AND is_scored = @abap_false
      INTO TABLE @DATA(lt_act).

    LOOP AT lt_act INTO DATA(ls_act).
      DATA(ls_result) = me->get_tcode_score(
        iv_tcode    = ls_act-tcode
        iv_act_type = ls_act-act_type ).

      " TABLE_EDIT is always critical → no off-hours multiplier needed
      IF ls_act-act_type = 'TCODE'.
        me->apply_offhours_multiplier(
          EXPORTING iv_act_time = ls_act-act_tims
          CHANGING  cs_result   = ls_result ).
      ENDIF.

      UPDATE zuam_act_log
        SET risk_score = @ls_result-score,
            severity   = @ls_result-severity,
            is_scored  = @abap_true
        WHERE act_id = @ls_act-act_id.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

  METHOD process_dump_data.
    SELECT act_id, username, message_text, act_tims
      FROM zuam_act_log
      WHERE act_type  = 'DUMP'
        AND is_scored = @abap_false
      INTO TABLE @DATA(lt_dump).

    LOOP AT lt_dump INTO DATA(ls_dump).
      DATA(ls_result) = me->get_dump_score(
        iv_message = ls_dump-message_text ).

      " Apply off-hours multiplier only if score < 100
      IF ls_result-score < 100.
        me->apply_offhours_multiplier(
          EXPORTING iv_act_time = ls_dump-act_tims
          CHANGING  cs_result   = ls_result ).
      ENDIF.

      UPDATE zuam_act_log
        SET risk_score = @ls_result-score,
            severity   = @ls_result-severity,
            is_scored  = @abap_true
        WHERE act_id = @ls_dump-act_id.  " <-- use ls_dump
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

  METHOD get_terminal_score.
    " Count distinct terminals with successful logins on the given date
    SELECT COUNT( DISTINCT terminal_id )
      FROM zuam_auth_log
      WHERE username     = @iv_username
        AND login_date   = @iv_login_date
        AND login_result = 'SUCCESS'            " successful logins only
      INTO @DATA(lv_count).

    DATA(lv_threshold) = COND zuam_cfg_value(
      WHEN lv_count >= 3 THEN 'TERMINAL_3+'
      WHEN lv_count >= 2 THEN 'TERMINAL_2'
      ELSE '' ).

    IF lv_threshold IS INITIAL. RETURN. ENDIF.

    READ TABLE mt_risk_cfg INTO DATA(ls_cfg)
      WITH KEY act_type = 'MULTI_TERMIN'
               value    = lv_threshold.
    IF sy-subrc = 0.
      rs_result-score    = ls_cfg-risk_score.
      rs_result-severity = ls_cfg-severity.
    ENDIF.
  ENDMETHOD.

  METHOD process_auth_data.
    " Get distinct (username, login_date) not yet scored
    SELECT DISTINCT username, login_date
      FROM zuam_auth_log
      WHERE is_scored = @abap_false
      INTO TABLE @DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      DATA(ls_result) = me->get_terminal_score(
        iv_username   = ls_user-username
        iv_login_date = ls_user-login_date ).

      IF ls_result-score > 0.
        " Update all sessions for this user on the given date
        UPDATE zuam_auth_log
          SET risk_score = @ls_result-score,
              severity   = @ls_result-severity,
              is_scored  = @abap_true
          WHERE username   = @ls_user-username
            AND login_date = @ls_user-login_date.
      ELSE.
        " Single terminal only — no risk, but mark as scored
        UPDATE zuam_auth_log
          SET is_scored = @abap_true
          WHERE username   = @ls_user-username
            AND login_date = @ls_user-login_date.
      ENDIF.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

  METHOD process_export_data.
    " Get distinct (username, date) not yet scored
    SELECT DISTINCT username, act_date
      FROM zuam_act_log
      WHERE act_type  = 'EXPORT'
        AND is_scored = @abap_false
      INTO TABLE @DATA(lt_users).

    LOOP AT lt_users INTO DATA(ls_user).
      DATA(ls_result) = me->get_export_score(
        iv_username = ls_user-username
        iv_date     = ls_user-act_date ).

      " Apply score only if threshold is exceeded
      IF ls_result-score > 0.
        UPDATE zuam_act_log
          SET risk_score = @ls_result-score,
              severity   = @ls_result-severity,
              is_scored  = @abap_true
          WHERE username = @ls_user-username
            AND act_date  = @ls_user-act_date
            AND act_type  = 'EXPORT'.
      ELSE.
        " Below threshold → mark as scored but score = 0
        UPDATE zuam_act_log
          SET is_scored = @abap_true
          WHERE username = @ls_user-username
            AND act_date  = @ls_user-act_date
            AND act_type  = 'EXPORT'.
      ENDIF.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
