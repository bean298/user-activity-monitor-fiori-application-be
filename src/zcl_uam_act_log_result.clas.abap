CLASS  zcl_uam_act_log_result DEFINITION
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
    " Constants
    "---------------------------------------------------------------
    CONSTANTS: gc_tvarvc_name TYPE tvarvc-name VALUE 'ZUAM_ACT_TIME',
               gc_tvarvc_type TYPE tvarvc-type VALUE 'P',
               gc_act_tcode   TYPE string      VALUE 'TCODE',
               gc_act_dump    TYPE string      VALUE 'DUMP',
               gc_login_succ  TYPE string      VALUE 'SUCCESS',
               gc_seqno_hdr   TYPE snap-seqno  VALUE '000',
               gc_tc_sm       TYPE string      VALUE 'SESSION_MANAGER',
               gc_tc_s000     TYPE string      VALUE 'S000',
               gc_tc_seuint   TYPE string      VALUE 'SEU_INT'.

    "---------------------------------------------------------------
    " Data
    "---------------------------------------------------------------
    DATA: lv_low      TYPE tvarvc-low,  " Lower limit time from TVARVC
          lv_max_time TYPE tvarvc-low.  " Maximum time of processed logs

    DATA: lt_sal  TYPE TABLE OF rsau_buf_data,
          lt_log  TYPE TABLE OF zuam_act_log,
          ls_log  TYPE zuam_act_log,
          lt_dump TYPE TABLE OF snap,
          ls_dump TYPE snap.

    "---------------------------------------------------------------
    " Methods
    "---------------------------------------------------------------
    METHODS read_checkpoint.
    METHODS init_first_run.
    METHODS process_sal_log.
    METHODS process_snap_dump.
    METHODS save_to_database.
    METHODS save_checkpoint.
ENDCLASS.



CLASS zcl_uam_act_log_result IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    me->read_checkpoint( ).
    me->init_first_run( ).
    me->process_sal_log( ).
    me->process_snap_dump( ).
    me->save_to_database( ).
    me->save_checkpoint( ).
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD read_checkpoint.
    SELECT SINGLE low
      INTO lv_low
      FROM tvarvc
      WHERE name = gc_tvarvc_name
      AND type = gc_tvarvc_type.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD init_first_run.
    DATA: lv_date TYPE dats,
          lv_time TYPE tims.

    IF lv_low IS NOT INITIAL.
      MESSAGE s011(zuam_msg) WITH lv_low.
    ELSE.

      GET TIME.
      lv_date = sy-datum.
      lv_time = sy-uzeit.

      lv_low = lv_date && lv_time && '00'.

      lv_max_time = lv_low.

      DATA ls_tvarvc TYPE tvarvc.
      ls_tvarvc-name = gc_tvarvc_name.
      ls_tvarvc-type = gc_tvarvc_type.
      ls_tvarvc-numb = '0000'.
      ls_tvarvc-low  = lv_low.

      MODIFY tvarvc FROM ls_tvarvc.

      IF sy-subrc = 0.
        COMMIT WORK.

        MESSAGE s006(zuam_msg) WITH lv_low.
      ELSE.
        MESSAGE e007(zuam_msg).
      ENDIF.
      RETURN.
    ENDIF.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD process_sal_log.
    SELECT slgmand, slgdattim, slguser, slgtc, area, subid, sal_data
     FROM rsau_buf_data
     WHERE slgmand = @sy-mandt
       AND slgdattim > @lv_low
       AND ( ( area IN ('CU', 'DU') AND subid <> '2')
          OR ( area = 'BU' AND subid = '4' )
          OR ( area = 'AU' AND subid IN ('A', '3', '4') ) )
       AND slgtc IS NOT INITIAL
     INTO CORRESPONDING FIELDS OF TABLE @lt_sal.

    LOOP AT lt_sal INTO DATA(ls_sal).
      CLEAR ls_log.

      DATA(lv_act_date) = ls_sal-slgdattim(8).
      DATA(lv_act_time) = ls_sal-slgdattim+8(6).

      IF ls_sal-slgdattim > lv_max_time.
        lv_max_time = ls_sal-slgdattim.
      ENDIF.

      " Find active session
      SELECT session_id
      FROM zuam_auth_log
      WHERE username = @ls_sal-slguser
        AND (
              ( login_date <  @lv_act_date )
           OR ( login_date =  @lv_act_date
                AND login_time <= @lv_act_time )
            )
        AND (
              logout_date IS INITIAL
           OR logout_date >  @lv_act_date
           OR ( logout_date = @lv_act_date
                AND logout_time >= @lv_act_time )
            )
        AND login_result = @gc_login_succ
        ORDER BY login_date DESCENDING, login_time DESCENDING
        INTO TABLE @DATA(lt_active_session)
        UP TO 1 ROWS.

      IF sy-subrc = 0.
        ls_log-session_id = lt_active_session[ 1 ]-session_id.
      ELSE.
        CONTINUE.
      ENDIF.

      " Calculate MD5 Hash to generate unique Activity Id (Prevent duplicates)
      DATA(lv_raw_data) = |{ ls_sal-slgdattim }{ ls_sal-slguser }{ ls_sal-slgtc }{ ls_sal-area }{ ls_sal-subid }{ ls_sal-sal_data }|.
      DATA lv_guid TYPE sysuuid_c32.
      CALL FUNCTION 'MD5_CALCULATE_HASH_FOR_CHAR'
        EXPORTING
          data = lv_raw_data
        IMPORTING
          hash = lv_guid.

      IF ls_sal-area = 'AU' AND ( ls_sal-subid = '3' OR ls_sal-subid = '4' ).
        ls_log-tcode          = ls_sal-sal_data.
      ELSE.
        ls_log-tcode          = ls_sal-slgtc.
      ENDIF.

      CONDENSE ls_log-tcode.

      IF ls_log-tcode = gc_tc_sm OR
         ls_log-tcode = gc_tc_s000 OR
         ls_log-tcode = gc_tc_seuint.
        CONTINUE.
      ENDIF.

      " Map Security Audit Log (SAL) data to Activity Log
      ls_log-act_id         = lv_guid.
      ls_log-mandt          = sy-mandt.
      ls_log-username       = ls_sal-slguser.
      ls_log-act_tims       = lv_act_time.
      ls_log-act_date       = lv_act_date.
      ls_log-act_type       = gc_act_tcode.
      ls_log-message_text   = zcl_uam_act_msg_parser=>parse_audit_message( im_area     = ls_sal-area
                                                                im_subid    = ls_sal-subid
                                                                im_sal_data = ls_sal-sal_data
                                                               ).

      IF ls_log-message_text CS '====CM' OR
         ls_log-message_text CS '====CC' OR
         ls_log-message_text CS '====CU'.
        CONTINUE.
      ENDIF.

      APPEND ls_log TO lt_log.
    ENDLOOP.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD process_snap_dump.
    DATA(lv_cp_date) = lv_low(8).
    DATA(lv_cp_time) = lv_low+8(6).

    SELECT mandt, seqno, datum, uzeit, uname, ahost, modno, flist
      INTO CORRESPONDING FIELDS OF TABLE @lt_dump
      FROM snap
      WHERE mandt = @sy-mandt
        AND seqno = @gc_seqno_hdr
        AND ( datum > @lv_cp_date
           OR ( datum = @lv_cp_date
                AND uzeit > @lv_cp_time ) ).

    IF lt_dump IS NOT INITIAL.
      SORT lt_dump BY datum uzeit uname.
      DELETE ADJACENT DUPLICATES FROM lt_dump
             COMPARING datum uzeit uname.
    ENDIF.

    LOOP AT lt_dump INTO ls_dump.
      CLEAR ls_log.

      " Build dump timestamp
      DATA lv_dump_ts TYPE tvarvc-low.
      lv_dump_ts = ls_dump-datum && ls_dump-uzeit && '00'.

      " Update checkpoint max time
      IF lv_dump_ts > lv_max_time.
        lv_max_time = lv_dump_ts.
      ENDIF.

      DATA(lv_dump_date) = ls_dump-datum.
      DATA(lv_dump_time) = ls_dump-uzeit.

      " Find active session at dump time (date + time)
      SELECT session_id
        FROM zuam_auth_log
        WHERE username = @ls_dump-uname
          AND (
                ( login_date <  @lv_dump_date )
             OR ( login_date =  @lv_dump_date
                  AND login_time <= @lv_dump_time )
              )
          AND (
                logout_date IS INITIAL
             OR logout_date >  @lv_dump_date
             OR ( logout_date = @lv_dump_date
                  AND logout_time >= @lv_dump_time )
              )
        AND login_result = @gc_login_succ
        ORDER BY login_date DESCENDING, login_time DESCENDING
        INTO TABLE @DATA(lt_active_session)
        UP TO 1 ROWS.

      IF sy-subrc = 0.
        ls_log-session_id = lt_active_session[ 1 ]-session_id.
      ELSE.
        CONTINUE.
      ENDIF.

      " Calculate MD5 Hash to generate unique Activity Id (Prevent duplicates)
      DATA(lv_raw_dump) = |{ lv_dump_ts }{ ls_dump-uname }{ ls_dump-ahost }{ ls_dump-modno }|.
      DATA lv_guid_dump TYPE sysuuid_c32.

      CALL FUNCTION 'MD5_CALCULATE_HASH_FOR_CHAR'
        EXPORTING
          data = lv_raw_dump
        IMPORTING
          hash = lv_guid_dump.
      DATA: lv_dump_tcode TYPE string.

      " Map Dump details to Activity Log
      ls_log-act_id        = lv_guid_dump.
      ls_log-mandt         = sy-mandt.
      ls_log-username      = ls_dump-uname.
      ls_log-act_tims      = lv_dump_time.
      ls_log-act_date      = lv_dump_date.
      ls_log-act_type      = gc_act_dump.
      ls_log-message_text  = zcl_uam_act_msg_parser=>parse_dump_message( EXPORTING im_flist = CONV string( ls_dump-flist )
                                                              IMPORTING ex_tcode = lv_dump_tcode
                                                             ).
      ls_log-tcode = lv_dump_tcode.

      IF ls_log-act_id IS NOT INITIAL AND ls_log-username IS NOT INITIAL.
        APPEND ls_log TO lt_log.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD save_to_database.
    IF lt_log IS NOT INITIAL.
      DELETE lt_log WHERE act_id IS INITIAL.

      IF lt_log IS NOT INITIAL.
        INSERT zuam_act_log FROM TABLE lt_log ACCEPTING DUPLICATE KEYS.

        IF sy-subrc = 0 OR sy-subrc = 4.
          COMMIT WORK.
        ELSE.
          CLEAR lv_max_time.
          ROLLBACK WORK.
          MESSAGE e029(zuam_msg).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  METHOD save_checkpoint.
    IF lv_max_time IS NOT INITIAL.
      UPDATE tvarvc
        SET low = lv_max_time
        WHERE name = gc_tvarvc_name
        AND type = gc_tvarvc_type.

      COMMIT WORK.

      MESSAGE s009(zuam_msg) WITH lv_max_time.
    ELSE.
      RETURN.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
