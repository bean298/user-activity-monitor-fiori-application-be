CLASS zcl_uam_auth_log_result DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "---------------------------------------------------------------
    " Interface for defining job parameters
    "---------------------------------------------------------------
    INTERFACES if_apj_dt_exec_object .

    "---------------------------------------------------------------
    " Interface for job execution runtime
    "---------------------------------------------------------------
    INTERFACES if_apj_rt_exec_object .

  PROTECTED SECTION.

  PRIVATE SECTION.
    "---------------------------------------------------------------
    " Types
    "---------------------------------------------------------------
    TYPES: BEGIN OF lty_t_buff_data,
             username TYPE rsau_buf_data-slguser,
             area     TYPE rsau_buf_data-area,
             id       TYPE rsau_buf_data-subid,
             client   TYPE rsau_buf_data-slgmand,
             system   TYPE rsau_buf_data-sid,
             time     TYPE rsau_buf_data-slgdattim,
             terminal TYPE rsau_buf_data-slgltrm2,
             variable TYPE rsau_buf_data-sal_data,
             message  TYPE tsl1t-txt,
           END OF lty_t_buff_data.

    TYPES tt_buff_data TYPE STANDARD TABLE OF lty_t_buff_data WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_var,
             name        TYPE tvarvc-name,
             type        TYPE tvarvc-type,
             msg_success TYPE symsgno,
             msg_exist   TYPE symsgno,
           END OF ty_var.

    "---------------------------------------------------------------
    " Data
    "---------------------------------------------------------------
    DATA: ls_tvarvc TYPE tvarvc,
          lt_var    TYPE STANDARD TABLE OF ty_var.

    DATA: lv_low_success      TYPE tvarvc-low,
          lv_low_fail         TYPE tvarvc-low,
          lv_max_time_success TYPE tvarvc-low,
          lv_max_time_fail    TYPE tvarvc-low.

    DATA: lt_buf_data_success TYPE STANDARD TABLE OF lty_t_buff_data,
          lt_buf_data_fail    TYPE STANDARD TABLE OF lty_t_buff_data,
          lt_log_success      TYPE STANDARD TABLE OF lty_t_buff_data,
          lt_log_fail         TYPE STANDARD TABLE OF lty_t_buff_data.

    DATA: lv_type   TYPE zuam_msg_type-message,
          lv_method TYPE zaudit_method-message,
          lv_cause  TYPE zuam_msg_cause-message.

    "---------------------------------------------------------------
    " Constants
    "---------------------------------------------------------------
    CONSTANTS: lc_type_param       TYPE tvarvc-type VALUE 'P',
               lc_cp_login_success TYPE tvarvc-name VALUE 'ZUAM_LOGIN_SUCCESS_TIME',
               lc_cp_login_fail    TYPE tvarvc-name VALUE 'ZUAM_LOGIN_FAIL_TIME',
               lc_log_success_var  TYPE tvarvc-name VALUE 'A&0&P'.

    "---------------------------------------------------------------
    " Methods
    "---------------------------------------------------------------
    METHODS create_checkpoint.
    METHODS read_success_checkpoint.
    METHODS read_login_success.
    METHODS create_login_success_log.
    METHODS update_success_checkpoint.

    METHODS read_fail_checkpoint.
    METHODS read_login_fail.
    METHODS create_login_fail_log.
    METHODS update_fail_checkpoint.

    METHODS filter_by_scope CHANGING ct_log_data TYPE tt_buff_data.
ENDCLASS.

CLASS zcl_uam_auth_log_result IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    lt_var = VALUE #(
      (
        name        = lc_cp_login_fail
        type        = lc_type_param
        msg_success = '000'
        msg_exist   = '001'
      )
      (
        name        = lc_cp_login_success
        type        = lc_type_param
        msg_success = '021'
        msg_exist   = '022'
      )
    ).

    me->create_checkpoint( ).
    me->read_success_checkpoint( ).
    me->read_fail_checkpoint( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD create_checkpoint.
    LOOP AT lt_var INTO DATA(ls_var).
      CLEAR ls_tvarvc.

      SELECT SINGLE *
        FROM tvarvc
        WHERE name = @ls_var-name
          AND type = @ls_var-type
        INTO @ls_tvarvc.

      IF sy-subrc <> 0.

        CLEAR ls_tvarvc.

        ls_tvarvc-name = ls_var-name.
        ls_tvarvc-type = ls_var-type.
        ls_tvarvc-low  = ''.

        INSERT tvarvc FROM ls_tvarvc.

        IF sy-subrc = 0.
          COMMIT WORK.
          MESSAGE ID 'ZUAM_MSG' TYPE 'S' NUMBER ls_var-msg_success.
        ELSE.
          MESSAGE s023(zuam_msg).
          RETURN.
        ENDIF.

      ELSE.
        MESSAGE ID 'ZUAM_MSG' TYPE 'S' NUMBER ls_var-msg_exist.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD read_success_checkpoint.
    DATA:lv_date TYPE dats,
         lv_time TYPE tims.

    SELECT SINGLE low
      INTO @lv_low_success
      FROM tvarvc
      WHERE name = @lc_cp_login_success
        AND type = @lc_type_param.

    IF lv_low_success IS NOT INITIAL.

      MESSAGE s024(zuam_msg) WITH lv_low_success.

    ELSE.

      GET TIME.

      lv_date = sy-datum.
      lv_time = sy-uzeit.

      lv_low_success = lv_date && lv_time && '00'.
      lv_max_time_success = lv_low_success.

      UPDATE tvarvc
        SET low = @lv_low_success
        WHERE name = @lc_cp_login_success
          AND type = @lc_type_param.

      IF sy-subrc = 0.
        COMMIT WORK.
        MESSAGE s025(zuam_msg) WITH lv_low_success.
      ELSE.
        MESSAGE e026(zuam_msg).
      ENDIF.

    ENDIF.

    me->read_login_success( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD read_login_success.
    CLEAR lt_buf_data_success.
    CLEAR lt_log_success.

    SELECT slguser   AS username,
           area,
           subid     AS id,
           slgmand   AS client,
           sid       AS system,
           slgdattim AS time,
           sal_data  AS variable,
           slgltrm2  AS terminal
      FROM rsau_buf_data
      INTO CORRESPONDING FIELDS OF TABLE @lt_buf_data_success
      PACKAGE SIZE 1000
      WHERE slgdattim > @lv_low_success
        AND area = 'AU'
        AND subid = '1'.

      LOOP AT lt_buf_data_success INTO DATA(ls_buf_data_success).
        " Only get SAP GUI Login
        IF ls_buf_data_success-variable = lc_log_success_var.
          APPEND ls_buf_data_success TO lt_log_success.

          " Set new checkpoint
          IF ls_buf_data_success-time > lv_max_time_success.
            lv_max_time_success = ls_buf_data_success-time.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDSELECT.

    me->filter_by_scope( CHANGING ct_log_data = lt_log_success ).
    me->create_login_success_log( ).
    me->update_success_checkpoint( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD create_login_success_log.
    DATA: ls_auth_log_success TYPE zuam_auth_log,
          lv_session_id       TYPE zuam_auth_log-session_id.

    LOOP AT lt_log_success INTO DATA(ls_log_success).
      "-------------------------------------------------------------------*
      " Build unique session ID
      "-------------------------------------------------------------------*
      lv_session_id = |{ ls_log_success-username }_{ ls_log_success-time }_{ ls_log_success-area && ls_log_success-id }|.

      DATA lv_guid TYPE sysuuid_c32.

      CALL FUNCTION 'MD5_CALCULATE_HASH_FOR_CHAR'
        EXPORTING
          data = lv_session_id
        IMPORTING
          hash = lv_guid.

      "-------------------------------------------------------------------*
      " Fill authentication log data
      "-------------------------------------------------------------------*
      CLEAR:
        lv_type,
        lv_method,
        ls_auth_log_success.

      SELECT SINGLE message
        INTO @lv_type
        FROM zuam_msg_type
        WHERE id = @ls_log_success-variable(1).

      SELECT SINGLE message
        INTO @lv_method
        FROM zuam_msg_method
        WHERE id = @ls_log_success-variable+4(1).

      ls_auth_log_success-mandt        = sy-mandt.
      ls_auth_log_success-session_id   = lv_guid.
      ls_auth_log_success-username     = ls_log_success-username.
      ls_auth_log_success-login_date   = ls_log_success-time(8).
      ls_auth_log_success-login_time   = ls_log_success-time+8(6).
      ls_auth_log_success-event_id     = ls_log_success-area && ls_log_success-id.
      ls_auth_log_success-login_result = 'SUCCESS'.
      ls_auth_log_success-mail_sent    = ''.
      ls_auth_log_success-terminal_id  = ls_log_success-terminal.
      ls_auth_log_success-client       = ls_log_success-client.
      ls_auth_log_success-system_id    = ls_log_success-system.
      ls_auth_log_success-erzet        = ls_log_success-time+8(6).
      ls_auth_log_success-erdat        = ls_log_success-time(8).

      "-------------------------------------------------------------------*
      " Read login success message text from TSL1T
      "-------------------------------------------------------------------*
      SELECT SINGLE txt
        FROM tsl1t
        INTO @ls_auth_log_success-login_message
        WHERE area  = @ls_log_success-area
          AND subid = @ls_log_success-id
          AND spras = 'E'.

      REPLACE '&A' IN ls_auth_log_success-login_message WITH lv_type.
      REPLACE '&C' IN ls_auth_log_success-login_message WITH lv_method.

      "---------------------------------------------------------------*
      " Validate mandatory fields
      "---------------------------------------------------------------*
      IF ls_auth_log_success-session_id IS INITIAL
      OR ls_auth_log_success-username IS INITIAL
      OR ls_auth_log_success-login_date IS INITIAL.
        MESSAGE s027(zuam_msg).
        CONTINUE.
      ENDIF.

      "---------------------------------------------------------------*
      " Check duplicate
      "---------------------------------------------------------------*
      SELECT SINGLE session_id
        FROM zuam_auth_log
        WHERE session_id = @ls_auth_log_success-session_id
        INTO @DATA(lv_exist).

      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      INSERT zuam_auth_log FROM @ls_auth_log_success.

      IF sy-subrc = 0.
        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD update_success_checkpoint.
    IF lv_max_time_success IS NOT INITIAL.
      UPDATE tvarvc
        SET low = @lv_max_time_success
        WHERE name = @lc_cp_login_success
          AND type = @lc_type_param.

      IF sy-subrc = 0.
        COMMIT WORK.
        MESSAGE s009(zuam_msg) WITH lv_max_time_success.
      ENDIF.

    ELSE.
      RETURN.
    ENDIF.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD read_fail_checkpoint.

    DATA: lv_date TYPE dats,
          lv_time TYPE tims.

    SELECT SINGLE low
      INTO @lv_low_fail
      FROM tvarvc
      WHERE name = @lc_cp_login_fail
        AND type = @lc_type_param.

    IF lv_low_fail IS NOT INITIAL.
      MESSAGE s008(zuam_msg) WITH lv_low_fail.
    ELSE.

      GET TIME.

      lv_date = sy-datum.
      lv_time = sy-uzeit.

      lv_low_fail = lv_date && lv_time && '00'.
      lv_max_time_fail = lv_low_fail.

      UPDATE tvarvc
        SET low = @lv_low_fail
        WHERE name = @lc_cp_login_fail
          AND type = @lc_type_param.

      IF sy-subrc = 0.
        COMMIT WORK.
        MESSAGE s002(zuam_msg) WITH lv_low_fail.
      ELSE.
        MESSAGE e003(zuam_msg).
      ENDIF.
    ENDIF.

    me->read_login_fail( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD read_login_fail.
    CLEAR lt_buf_data_fail.
    CLEAR lt_log_fail.

    SELECT slguser   AS username,
           area,
           subid     AS id,
           slgmand   AS client,
           slgmand   AS system,
           slgdattim AS time,
           sal_data  AS variable,
           slgltrm2  AS terminal
      FROM rsau_buf_data
      INTO CORRESPONDING FIELDS OF TABLE @lt_buf_data_fail
      PACKAGE SIZE 1000
      WHERE slgdattim > @lv_low_fail
        AND (
             ( area = 'AU' AND subid IN ( '2', 'M' ) )
          OR ( area = 'BU' AND subid = '1' )
        ).

      LOOP AT lt_buf_data_fail INTO DATA(ls_buf_data_fail).

        APPEND ls_buf_data_fail TO lt_log_fail.

        " Set new checkpoint
        IF ls_buf_data_fail-time > lv_max_time_fail.
          lv_max_time_fail = ls_buf_data_fail-time.
        ENDIF.

      ENDLOOP.
    ENDSELECT.

    me->filter_by_scope( CHANGING ct_log_data = lt_log_fail ).
    me->create_login_fail_log( ).
    me->update_fail_checkpoint( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD create_login_fail_log.
    DATA:ls_auth_fail_log TYPE zuam_auth_log,
         lv_session_id    TYPE zuam_auth_log-session_id.

    LOOP AT lt_log_fail INTO DATA(ls_log_fail).
      "-------------------------------------------------------------------*
      " Build unique session ID
      "-------------------------------------------------------------------*
      lv_session_id = |{ ls_log_fail-username }_{ ls_log_fail-time }_{ ls_log_fail-area && ls_log_fail-id }|.

      DATA lv_guid TYPE sysuuid_c32.
      CALL FUNCTION 'MD5_CALCULATE_HASH_FOR_CHAR'
        EXPORTING
          data = lv_session_id
        IMPORTING
          hash = lv_guid.

      "-------------------------------------------------------------------*
      " Fill authentication log data
      "-------------------------------------------------------------------*
      CLEAR ls_auth_fail_log.

      ls_auth_fail_log-mandt        = sy-mandt.
      ls_auth_fail_log-username     = ls_log_fail-username.
      ls_auth_fail_log-session_id   = lv_guid.
      ls_auth_fail_log-login_date   = ls_log_fail-time(8).
      ls_auth_fail_log-login_time   = ls_log_fail-time+8(6).
      ls_auth_fail_log-login_result = 'FAIL'.
      ls_auth_fail_log-mail_sent    = ''.
      ls_auth_fail_log-erzet        = ls_log_fail-time+8(6).
      ls_auth_fail_log-erdat        = ls_log_fail-time(8).
      ls_auth_fail_log-event_id     = ls_log_fail-area && ls_log_fail-id.
      ls_auth_fail_log-terminal_id  = ls_log_fail-terminal.
      ls_auth_fail_log-client       = ls_log_fail-client.
      ls_auth_fail_log-system_id    = ls_log_fail-system.

      "-------------------------------------------------------------------*
      " Read login fail message text from TSL1T
      "-------------------------------------------------------------------*
      SELECT SINGLE txt
        FROM tsl1t
        INTO @ls_auth_fail_log-login_message
        WHERE area  = @ls_log_fail-area
          AND subid = @ls_log_fail-id
          AND spras = 'E'.

      "-------------------------------------------------------------------*
      " Read login fail detail message
      "-------------------------------------------------------------------*
      "Wrong Password - Locked Account
      IF ls_auth_fail_log-event_id = 'BU1' OR ls_auth_fail_log-event_id = 'AUM'.

        DATA: lv_var_client   TYPE string,
              lv_var_username TYPE string.

        SPLIT ls_log_fail-variable AT '&' INTO lv_var_client lv_var_username.

        IF sy-subrc = 0.
          REPLACE '&B' IN ls_auth_fail_log-login_message WITH lv_var_username.
          REPLACE '&A' IN ls_auth_fail_log-login_message WITH lv_var_client.
        ENDIF.

        "Login Fail - Cause - Type - Method
      ELSEIF ls_auth_fail_log-event_id = 'AU2'.

        DATA: lv_var_type   TYPE string,
              lv_var_method TYPE string,
              lv_var_cause  TYPE string.

        CLEAR: lv_type, lv_method, lv_cause.

        SPLIT ls_log_fail-variable AT '&'
          INTO lv_var_type lv_var_cause lv_var_method.

        SELECT SINGLE message
          INTO @lv_type
          FROM zuam_msg_type
          WHERE id = @lv_var_type.

        SELECT SINGLE message
          INTO @lv_method
          FROM zuam_msg_method
          WHERE id = @lv_var_method.

        SELECT SINGLE message
          INTO @lv_cause
          FROM zuam_msg_cause
          WHERE id = @lv_var_cause.

        IF sy-subrc = 0.
          REPLACE '&B' IN ls_auth_fail_log-login_message WITH lv_cause.
          REPLACE '&A' IN ls_auth_fail_log-login_message WITH lv_type.
          REPLACE '&C' IN ls_auth_fail_log-login_message WITH lv_method.
        ENDIF.

      ENDIF.

      "---------------------------------------------------------------*
      " Validate mandatory fields
      "---------------------------------------------------------------*
      IF ls_auth_fail_log-session_id IS INITIAL
      OR ls_auth_fail_log-username IS INITIAL
      OR ls_auth_fail_log-login_date IS INITIAL.
        MESSAGE s027(zuam_msg).
        CONTINUE.
      ENDIF.

      "---------------------------------------------------------------*
      " Check duplicate
      "---------------------------------------------------------------*
      SELECT SINGLE session_id
        FROM zuam_auth_log
        WHERE session_id = @ls_auth_fail_log-session_id
        INTO @DATA(lv_exist).

      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      "---------------------------------------------------------------*
      " Check user status
      "---------------------------------------------------------------*
      SELECT SINGLE uflag
        FROM usr02
        WHERE bname = @ls_log_fail-username
        INTO @DATA(lv_user_status).

      IF lv_user_status IS NOT INITIAL
      AND ls_auth_fail_log-event_id <> 'AUM'
      AND ls_auth_fail_log-event_id <> 'BU1'.
        CONTINUE.
      ENDIF.

      INSERT zuam_auth_log FROM @ls_auth_fail_log.

      IF sy-subrc = 0.
        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD update_fail_checkpoint.
    IF lv_max_time_fail IS NOT INITIAL.
      UPDATE tvarvc
        SET low = @lv_max_time_fail
        WHERE name = @lc_cp_login_fail
          AND type = @lc_type_param.

      COMMIT WORK.

      MESSAGE s009(zuam_msg) WITH lv_max_time_fail.
    ELSE.
      RETURN.
    ENDIF.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD filter_by_scope.
    " Declare SAP Range tables to store dynamic filtering rules for Users and Clients
    DATA: lr_user   TYPE RANGE OF rsau_buf_data-slguser,
          lr_client TYPE RANGE OF rsau_buf_data-slgmand.

    " Fetch dynamic scope configuration rules from the custom Rule Table (ZUAM_SCOPE_CFG)
    SELECT filter_type, sel_sign, sel_opt, low, high
      FROM zuam_scope_cfg
      INTO TABLE @DATA(lt_rules).

    " Populate the SAP Range structures based on the configuration rule type
    LOOP AT lt_rules ASSIGNING FIELD-SYMBOL(<fs_rule>).
      CASE <fs_rule>-filter_type.
        WHEN 'USER'.
          APPEND VALUE #( sign   = <fs_rule>-sel_sign
                          option = <fs_rule>-sel_opt
                          low    = <fs_rule>-low
                          high   = <fs_rule>-high ) TO lr_user.
        WHEN 'CLIENT'.
          APPEND VALUE #( sign   = <fs_rule>-sel_sign
                          option = <fs_rule>-sel_opt
                          low    = <fs_rule>-low
                          high   = <fs_rule>-high ) TO lr_client.
      ENDCASE.
    ENDLOOP.

    " Filter the changing internal table in RAM before database processing
    IF lr_user IS NOT INITIAL OR lr_client IS NOT INITIAL.
      DELETE ct_log_data WHERE NOT ( username IN lr_user AND client IN lr_client ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.


