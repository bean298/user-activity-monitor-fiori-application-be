FUNCTION z_fm_lock_user.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_USERNAME) TYPE  BAPIBNAME
*"     REFERENCE(IV_LOCK) TYPE  ABAP_BOOL
*"----------------------------------------------------------------------
  DATA lt_return TYPE TABLE OF bapiret2.

  IF iv_lock = abap_true.
    CALL FUNCTION 'BAPI_USER_LOCK'
      EXPORTING
        bapibname = iv_username
      TABLES
        return    = lt_return.
  ELSE.
    CALL FUNCTION 'BAPI_USER_UNLOCK'
      EXPORTING
        bapibname = iv_username
      TABLES
        return    = lt_return.
  ENDIF.

ENDFUNCTION.
