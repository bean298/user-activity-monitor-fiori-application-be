CLASS zcl_uam_logout_log_result DEFINITION
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
             time     TYPE rsau_buf_data-slgdattim,
             client   TYPE rsau_buf_data-slgmand,
           END OF lty_t_buff_data.

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

    DATA: lv_low      TYPE tvarvc-low,
          lv_max_time TYPE tvarvc-low.

    DATA: lt_buf_data_logout TYPE STANDARD TABLE OF lty_t_buff_data,
          lt_logout          TYPE STANDARD TABLE OF lty_t_buff_data.


    "---------------------------------------------------------------
    " Constants
    "---------------------------------------------------------------
    CONSTANTS: lc_type_param TYPE tvarvc-type VALUE 'P',
               lc_cp_logout  TYPE tvarvc-name VALUE 'ZUAM_LOGOUT_TIME'.

    "---------------------------------------------------------------
    " Methods
    "---------------------------------------------------------------
    METHODS create_checkpoint.
    METHODS read_logout_checkpoint.
    METHODS read_logout.
    METHODS update_logout_time.
    METHODS update_checkpoint.
ENDCLASS.



CLASS ZCL_UAM_LOGOUT_LOG_RESULT IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    me->create_checkpoint( ).
    me->read_logout_checkpoint(  ).
  ENDMETHOD.


  METHOD create_checkpoint.
    SELECT SINGLE *
    FROM tvarvc
    WHERE name = @lc_cp_logout
    AND type = @lc_type_param
    INTO @ls_tvarvc.

    IF sy-subrc <> 0.
      CLEAR ls_tvarvc.

      ls_tvarvc-name = lc_cp_logout.
      ls_tvarvc-type = lc_type_param.
      ls_tvarvc-low  = ''.

      INSERT tvarvc FROM ls_tvarvc.

      IF sy-subrc = 0.
        COMMIT WORK.

        MESSAGE s012(zuam_msg).
      ELSE.
        MESSAGE s023(zuam_msg).

        RETURN.
      ENDIF.

    ELSE.
      MESSAGE s013(zuam_msg).
    ENDIF.
  ENDMETHOD.


  METHOD read_logout_checkpoint.
    DATA: lv_date TYPE dats,
          lv_time TYPE tims.

    SELECT SINGLE low
      FROM tvarvc
      INTO lv_low
      WHERE name = lc_cp_logout
      AND type = lc_type_param.

    "If lv_low is existed
    IF lv_low IS NOT INITIAL.
      MESSAGE s014(zuam_msg) WITH lv_low.
    ELSE.
      "If lv_low does not exist
      GET TIME.
      lv_date = sy-datum.
      lv_time = sy-uzeit.

      lv_low = lv_date && lv_time && '00'.

      lv_max_time = lv_low.

      UPDATE tvarvc
        SET low = lv_low
        WHERE name = lc_cp_logout
        AND type = lc_type_param.

      IF sy-subrc = 0.
        COMMIT WORK.

        MESSAGE s015(zuam_msg) WITH lv_low.
      ELSE.
        MESSAGE e016(zuam_msg).
      ENDIF.
    ENDIF.

    me->read_logout(  ).
  ENDMETHOD.


  METHOD read_logout.
    SELECT slguser   AS username
           slgdattim AS time
           slgmand   AS client
    FROM rsau_buf_data
    INTO TABLE lt_buf_data_logout
    WHERE slgdattim > lv_low
     AND area      = 'AU'
     AND subid     = 'C'
    ORDER BY slgdattim ASCENDING.

    LOOP AT lt_buf_data_logout INTO DATA(ls_buf_data_logout).
      APPEND ls_buf_data_logout TO lt_logout.

      "Set new checkpoint
      IF ls_buf_data_logout-time > lv_max_time.
        lv_max_time = ls_buf_data_logout-time.
      ENDIF.
    ENDLOOP.

    me->update_logout_time( ).
    me->update_checkpoint( ).
  ENDMETHOD.


  METHOD update_logout_time.
    DATA: ls_oldest TYPE zuam_auth_log.

    LOOP AT lt_logout INTO DATA(ls_logout).
      CLEAR ls_oldest.

      SELECT  *
      FROM zuam_auth_log
      WHERE username     = @ls_logout-username
      AND logout_date  IS INITIAL
      AND logout_time  = '000000'
      AND login_result = 'SUCCESS'
      AND client       = @ls_logout-client
      AND ( login_date < @ls_logout-time(8)
         OR (
              login_date = @ls_logout-time(8)
          AND login_time <= @ls_logout-time+8(6)
         )
        )
      ORDER BY login_date DESCENDING,
               login_time DESCENDING
      INTO @ls_oldest
      UP TO 1 ROWS.
      ENDSELECT.

      "---------------------------------------------------------*
      " Validate logout later than login
      "---------------------------------------------------------*
      IF ls_logout-time(8) < ls_oldest-login_date OR ( ls_logout-time(8) = ls_oldest-login_date AND ls_logout-time+8(6) < ls_oldest-login_time ).
        MESSAGE s028(zuam_msg) WITH ls_logout-username.
        CONTINUE.
      ENDIF.

      IF sy-subrc = 0.
        UPDATE zuam_auth_log
        SET logout_date = @ls_logout-time(8),
            logout_time = @ls_logout-time+8(6)
        WHERE session_id = @ls_oldest-session_id.

        IF sy-subrc = 0.
          COMMIT WORK.
          MESSAGE s017(zuam_msg) WITH ls_logout-username ls_logout-time.
        ELSE.
          ROLLBACK WORK.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD update_checkpoint.
    IF lv_max_time IS NOT INITIAL.
      UPDATE tvarvc
        SET low = lv_max_time
        WHERE name = lc_cp_logout
        AND type = lc_type_param.

      IF sy-subrc = 0.
        COMMIT WORK.

        MESSAGE s009(zuam_msg) WITH lv_max_time.
      ENDIF.

    ELSE.
      RETURN.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
