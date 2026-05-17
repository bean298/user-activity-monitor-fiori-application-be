CLASS lhc_UserAuthLog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR UserAuthLog RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE UserAuthLog.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE UserAuthLog.

    METHODS read FOR READ
      IMPORTING keys FOR READ UserAuthLog RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK UserAuthLog.

    METHODS rba_Activity FOR READ
      IMPORTING keys_rba FOR READ UserAuthLog\_Activity FULL result_requested RESULT result LINK association_links.

    METHODS cba_Activity FOR MODIFY
      IMPORTING entities_cba FOR CREATE UserAuthLog\_Activity.

ENDCLASS.

CLASS lhc_UserAuthLog IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD create.
  ENDMETHOD.

  METHOD update.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD rba_Activity.
  ENDMETHOD.

  METHOD cba_Activity.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_UserAcivityLog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS read FOR READ
      IMPORTING keys FOR READ UserAcivityLog RESULT result.

    METHODS rba_User FOR READ
      IMPORTING keys_rba FOR READ UserAcivityLog\_User FULL result_requested RESULT result LINK association_links.

ENDCLASS.

CLASS lhc_UserAcivityLog IMPLEMENTATION.

  METHOD read.
  ENDMETHOD.

  METHOD rba_User.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZIR_AUTH_LOG DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZIR_AUTH_LOG IMPLEMENTATION.

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
