CLASS lhc_user_detail DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      lockUser   FOR MODIFY
                 IMPORTING keys FOR ACTION user_detail~lockUser,
      unlockUser FOR MODIFY
                 IMPORTING keys FOR ACTION user_detail~unlockUser.
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


ENDCLASS.
