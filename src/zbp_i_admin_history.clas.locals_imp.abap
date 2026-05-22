CLASS lhc_ZI_ADMIN_HISTORY DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_admin_history RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE zi_admin_history.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE zi_admin_history.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE zi_admin_history.

    METHODS read FOR READ
      IMPORTING keys FOR READ zi_admin_history RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK zi_admin_history.

ENDCLASS.

CLASS lhc_ZI_ADMIN_HISTORY IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD create.
    DATA: ls_history TYPE zuam_history,
          lv_hist_id TYPE zuam_history-history_id,
          lv_hash    TYPE sysuuid_c32.

    LOOP AT entities INTO DATA(ls_entity).
      CLEAR: ls_history,
             lv_hist_id,
             lv_hash.

      "---------------------------------------------------------------*
      " Fill history data
      "---------------------------------------------------------------*
      ls_history-mandt          = sy-mandt.
      ls_history-action_type    = ls_entity-ActionType.
      ls_history-username       = ls_entity-Username.
      ls_history-action_message = ls_entity-ActionMessage.
      ls_history-reason         = ls_entity-Reason.

      ls_history-action_date = sy-datum.
      ls_history-action_time = sy-uzeit.

      "---------------------------------------------------------------*
      " Generate history id by hash
      "---------------------------------------------------------------*
      lv_hist_id =
        |{ ls_history-action_date && ls_history-action_time }_{ ls_history-action_type }|.

      CALL FUNCTION 'MD5_CALCULATE_HASH_FOR_CHAR'
        EXPORTING
          data = lv_hist_id
        IMPORTING
          hash = lv_hash.

      ls_history-history_id = lv_hash.

      "---------------------------------------------------------------*
      " Validate mandatory fields
      "---------------------------------------------------------------*
      IF ls_history-history_id  IS INITIAL
      OR ls_history-action_type IS INITIAL
      OR ls_history-username    IS INITIAL
      OR ls_history-action_date IS INITIAL
      OR ls_history-action_time IS INITIAL.
        APPEND VALUE #(
          %cid      = ls_entity-%cid
          HistoryId = ls_history-history_id
        ) TO failed-zi_admin_history.

        CONTINUE.
      ENDIF.

      "---------------------------------------------------------------*
      " Check duplicate
      "---------------------------------------------------------------*
      SELECT SINGLE history_id
        FROM zuam_history
        WHERE history_id = @ls_history-history_id
        INTO @DATA(lv_exist).

      IF sy-subrc = 0.
        APPEND VALUE #(
          %cid      = ls_entity-%cid
          HistoryId = ls_history-history_id
        ) TO failed-zi_admin_history.
        CONTINUE.
      ENDIF.


      "---------------------------------------------------------------*
      " Insert history
      "---------------------------------------------------------------*
      INSERT zuam_history FROM @ls_history.

      IF sy-subrc = 0.
        APPEND VALUE #(
          %cid      = ls_entity-%cid
          HistoryId = ls_history-history_id
        ) TO mapped-zi_admin_history.
      ELSE.
        APPEND VALUE #(
          %cid      = ls_entity-%cid
          HistoryId = ls_history-history_id
        ) TO failed-zi_admin_history.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
  ENDMETHOD.

  METHOD delete.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZI_ADMIN_HISTORY DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_ADMIN_HISTORY IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
