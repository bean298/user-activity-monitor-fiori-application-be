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
      UPDATE usr02
        SET uflag = 64
        WHERE bname = <key>-Username.
    ENDLOOP.
  ENDMETHOD.

  METHOD unlockUser.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      UPDATE usr02
        SET uflag = 0
        WHERE bname = <key>-Username.
    ENDLOOP.
  ENDMETHOD.

    METHOD resetRiskScore.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DELETE FROM zuam_act_log
        WHERE username = <key>-Username.

      DELETE FROM zuam_risk_alt
        WHERE username = <key>-Username.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
