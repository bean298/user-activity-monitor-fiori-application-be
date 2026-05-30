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

      UPDATE usr02
        SET uflag = 64
        WHERE bname = <key>-Username.

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
ENDMETHOD.
ENDCLASS.
