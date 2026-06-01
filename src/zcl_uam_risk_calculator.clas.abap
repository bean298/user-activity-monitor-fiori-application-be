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

    CONSTANTS:
      " Activity types
      mc_act_dump         TYPE zuam_act_type  VALUE 'DUMP',
      mc_act_export       TYPE zuam_act_type  VALUE 'EXPORT',
      mc_act_multi_term   TYPE zuam_act_type  VALUE 'MULTI_TERMIN',

      " Config value keys
      mc_val_wildcard     TYPE zuam_cfg_value VALUE '*',
      mc_val_terminal_2   TYPE zuam_cfg_value VALUE 'TERMINAL_2',
      mc_val_terminal_3   TYPE zuam_cfg_value VALUE 'TERMINAL_3+',
      mc_val_threshold_5  TYPE zuam_cfg_value VALUE 'THRESHOLD_5',
      mc_val_threshold_10 TYPE zuam_cfg_value VALUE 'THRESHOLD_10',
      mc_val_threshold_20 TYPE zuam_cfg_value VALUE 'THRESHOLD_20',

      " Login result
      mc_login_success    TYPE string         VALUE 'SUCCESS',

      " Export daily thresholds
      mc_export_thresh_5  TYPE i              VALUE 5,
      mc_export_thresh_10 TYPE i              VALUE 10,
      mc_export_thresh_20 TYPE i              VALUE 20,

      " Terminal thresholds
      mc_terminal_min_2   TYPE i              VALUE 2,
      mc_terminal_min_3   TYPE i              VALUE 3.

    DATA mt_risk_cfg TYPE tt_risk_cfg.

    METHODS load_config.

    " Calculate Dump score (CS pattern matching)
    METHODS get_dump_score
      IMPORTING iv_message       TYPE ZE_MSG_TEXT
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    " Calculate Export score based on daily thresholds
    METHODS get_export_score
      IMPORTING iv_username      TYPE xubname
                iv_date          TYPE sydatum
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    METHODS get_terminal_score
      IMPORTING iv_username      TYPE xubname
                iv_login_date    TYPE sydatum
      RETURNING VALUE(rs_result) TYPE zuam_risk_result.

    METHODS process_dump_data.
    METHODS process_export_data.
    METHODS process_auth_data.

ENDCLASS.


CLASS zcl_uam_risk_calculator IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    me->load_config( ).
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

  METHOD get_dump_score.
    LOOP AT mt_risk_cfg INTO DATA(ls_cfg)
      WHERE act_type = mc_act_dump.

      IF ls_cfg-value = mc_val_wildcard.
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
        AND act_type  = @mc_act_export
      INTO @DATA(lv_count).

    " Determine threshold (highest first)
    DATA(lv_threshold) = COND zuam_cfg_value(
      WHEN lv_count >= mc_export_thresh_20 THEN mc_val_threshold_20
      WHEN lv_count >= mc_export_thresh_10 THEN mc_val_threshold_10
      WHEN lv_count >= mc_export_thresh_5  THEN mc_val_threshold_5
      ELSE '' ).

    IF lv_threshold IS INITIAL. RETURN. ENDIF.

    READ TABLE mt_risk_cfg INTO DATA(ls_cfg)
      WITH KEY act_type = mc_act_export
               value    = lv_threshold.
    IF sy-subrc = 0.
      rs_result-score    = ls_cfg-risk_score.
      rs_result-severity = ls_cfg-severity.
    ENDIF.
  ENDMETHOD.

  METHOD process_dump_data.
    SELECT act_id, username, message_text, act_tims
      FROM zuam_act_log
      WHERE act_type  = @mc_act_dump
        AND is_scored = @abap_false
      INTO TABLE @DATA(lt_dump).

    LOOP AT lt_dump INTO DATA(ls_dump).
      DATA(ls_result) = me->get_dump_score(
        iv_message = ls_dump-message_text ).

      UPDATE zuam_act_log
        SET risk_score = @ls_result-score,
            severity   = @ls_result-severity,
            is_scored  = @abap_true
        WHERE act_id = @ls_dump-act_id.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

  METHOD get_terminal_score.
    " Count distinct terminals with successful logins on the given date
    SELECT COUNT( DISTINCT terminal_id )
      FROM zuam_auth_log
      WHERE username     = @iv_username
        AND login_date   = @iv_login_date
        AND login_result = @mc_login_success            " successful logins only
      INTO @DATA(lv_count).

    DATA(lv_threshold) = COND zuam_cfg_value(
      WHEN lv_count >= mc_terminal_min_3 THEN mc_val_terminal_3
      WHEN lv_count >= mc_terminal_min_2 THEN mc_val_terminal_2
      ELSE '' ).

    IF lv_threshold IS INITIAL. RETURN. ENDIF.

    READ TABLE mt_risk_cfg INTO DATA(ls_cfg)
      WITH KEY act_type = mc_act_multi_term
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
      WHERE act_type  = @mc_act_export
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
            AND act_type  = @mc_act_export.
      ELSE.
        " Below threshold → mark as scored but score = 0
        UPDATE zuam_act_log
          SET is_scored = @abap_true
          WHERE username = @ls_user-username
            AND act_date  = @ls_user-act_date
            AND act_type  = @mc_act_export.
      ENDIF.
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
