CLASS lsc_zi_user_detail DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

    METHODS save REDEFINITION.

ENDCLASS.

CLASS lsc_zi_user_detail IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_user_detail DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      lockUser   FOR MODIFY
        IMPORTING keys FOR ACTION user_detail~lockUser,
      unlockUser FOR MODIFY
        IMPORTING keys FOR ACTION user_detail~unlockUser,
      resetRiskScore FOR MODIFY
        IMPORTING keys FOR ACTION user_detail~resetRiskScore.
ENDCLASS.

CLASS lhc_user_detail IMPLEMENTATION.

METHOD lockUser.
  LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    " 1. Check if user exists in USR02
    SELECT SINGLE bname, uflag
      FROM usr02
      WHERE bname = @<key>-Username
      INTO @DATA(ls_usr02).

    IF sy-subrc <> 0.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %fail-cause = if_abap_behv=>cause-not_found )
        TO failed-user_detail.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'User does not exist' ) )
        TO reported-user_detail.
      CONTINUE.
    ENDIF.

    " 2. Prevent self-lock
    IF <key>-Username = sy-uname.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %fail-cause = if_abap_behv=>cause-unspecific )
        TO failed-user_detail.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Cannot lock your own account' ) )
        TO reported-user_detail.
      CONTINUE.
    ENDIF.

    " 3. Already locked (uflag = 64)
    IF ls_usr02-uflag = 64.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %fail-cause = if_abap_behv=>cause-unspecific )
        TO failed-user_detail.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'User is already locked' ) )
        TO reported-user_detail.
      CONTINUE.
    ENDIF.

    " 4. Lock the user
    UPDATE usr02
      SET uflag = 64
      WHERE bname = <key>-Username.

    " 5. Send notification email to locked user
    IF sy-subrc = 0.
      TRY.
          " Get user email from USR21 + ADR6
          DATA lv_user_email TYPE ad_smtpadr.
SELECT SINGLE persnumber, addrnumber
  FROM usr21
  WHERE bname = @<key>-Username
  INTO @DATA(ls_usr21_mail).

IF sy-subrc = 0.
  SELECT SINGLE smtp_addr
    FROM adr6
    WHERE addrnumber = @ls_usr21_mail-addrnumber
      AND persnumber = @ls_usr21_mail-persnumber
    INTO @lv_user_email.
ENDIF.

          CHECK lv_user_email IS NOT INITIAL.

          " Build HTML body
          DATA(lv_date) = |{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.
          DATA(lv_time) = |{ sy-uzeit+0(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }|.

          DATA(lv_html) =
            | <html><body style="font-family:Arial;background:#f6f6f6;padding:20px;">              | &&
            | <div style="background:white;padding:20px;border-radius:6px;                         | &&
            |      width:600px;border:1px solid #ddd;">                                            | &&
            | <h2 style="color:#c0392b;">&#128274; Your SAP account has been locked</h2>           | &&
            | <p>Dear <b>{ <key>-Username }</b>,</p>                                               | &&
            | <p>Your SAP account has been locked by an administrator.</p>                         | &&
            | <table style="border-collapse:collapse;width:100%;margin-top:10px;">                 | &&
            | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">System</td>      | &&
            |     <td style="padding:8px;border:1px solid #ddd;">{ sy-sysid }</td></tr>            | &&
            | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Date / Time</td> | &&
            |     <td style="padding:8px;border:1px solid #ddd;">{ lv_date } { lv_time }</td></tr> | &&
            | </table>                                                                              | &&
            | <p>Please contact your system administrator for assistance.</p>                      | &&
            | <p style="font-size:12px;color:#888;">This is an automated message from SAP.</p>     | &&
            | </div></body></html>                                                                  |.

          DATA lt_html TYPE soli_tab.
          CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
            EXPORTING text      = lv_html
            TABLES    ftext_tab = lt_html.

          DATA(lo_doc) = cl_document_bcs=>create_document(
                           i_type    = 'HTM'
                           i_text    = lt_html
                           i_subject = 'Your SAP Account Has Been Locked' ).

          DATA(lo_bcs) = cl_bcs=>create_persistent( ).
          lo_bcs->set_document( lo_doc ).
          lo_bcs->add_recipient(
            cl_cam_address_bcs=>create_internet_address( lv_user_email ) ).
          lo_bcs->set_send_immediately( abap_true ).
          lo_bcs->send( ).

        CATCH cx_send_req_bcs cx_address_bcs cx_document_bcs cx_bcs.
          " Email failure does not block the lock action
      ENDTRY.
    ENDIF.

  ENDLOOP.
ENDMETHOD.

  METHOD unlockUser.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      " 1. Check if user exists
      SELECT SINGLE bname, uflag
        FROM usr02
        WHERE bname = @<key>-Username
        INTO @DATA(ls_usr02).

      IF sy-subrc <> 0.
        APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                        %fail-cause = if_abap_behv=>cause-not_found )
          TO failed-user_detail.
        APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'User does not exist' ) )
          TO reported-user_detail.
        CONTINUE.
      ENDIF.

      " 2. Already unlocked (uflag = 0)
      IF ls_usr02-uflag = 0.
        APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                        %fail-cause = if_abap_behv=>cause-unspecific )
          TO failed-user_detail.
        APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'User is already unlocked' ) )
          TO reported-user_detail.
        CONTINUE.
      ENDIF.

      UPDATE usr02
        SET uflag = 0
        WHERE bname = <key>-Username.

    ENDLOOP.
  ENDMETHOD.

METHOD resetRiskScore.
  LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

    " 1. Check if user exists
    SELECT SINGLE bname
      FROM usr02
      WHERE bname = @<key>-Username
      INTO @DATA(lv_bname).

    IF sy-subrc <> 0.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %fail-cause = if_abap_behv=>cause-not_found )
        TO failed-user_detail.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'User does not exist' ) )
        TO reported-user_detail.
      CONTINUE.
    ENDIF.

    " 2. Check if there is any risk data to reset
    SELECT COUNT(*)
      FROM zuam_act_log
      WHERE username  = @<key>-Username
        AND is_scored = @abap_true
      INTO @DATA(lv_count).

    IF lv_count = 0.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %fail-cause = if_abap_behv=>cause-unspecific )
        TO failed-user_detail.
      APPEND VALUE #( %cid = <key>-%cid_ref  %key = <key>-%key
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-warning
                               text     = 'No risk data found for this user' ) )
        TO reported-user_detail.
      CONTINUE.
    ENDIF.

    " Reset scores only — preserve activity history
    UPDATE zuam_act_log
      SET risk_score = 0,
          severity   = '',
          is_scored  = @abap_false
      WHERE username = @<key>-Username.

    " Risk alert table can be fully cleared (derived data, not source)
    DELETE FROM zuam_risk_alt
      WHERE username = <key>-Username.

  ENDLOOP.

    DATA(lv_time) = CONV tims( sy-uzeit ).
  DATA(lv_date) = CONV dats( sy-datum ).

  INSERT zuam_history FROM @( VALUE #(
    history_id     = |{ sy-uname }{ sy-datum }{ sy-uzeit }|
    action_type    = 'RESET_RISK'
    username       = keys[ 1 ]-username
    action_date    = lv_date
    action_time    = lv_time
    action_message = |ADMIN RESET RISK SCORE FOR USER { keys[ 1 ]-username }|
    reason         = ''
  ) ).

ENDMETHOD.
ENDCLASS.
