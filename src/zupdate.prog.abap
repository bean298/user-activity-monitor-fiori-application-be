*&---------------------------------------------------------------------*
*& Report ZUPDATE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZUPDATE.

UPDATE zuam_auth_log
   SET SYSTEM_ID = 'S40'
 WHERE SYSTEM_ID = '324'.

IF sy-subrc = 0.
  COMMIT WORK.
  WRITE: / sy-dbcnt, 'records updated from 324 to S40'.
ELSE.
  ROLLBACK WORK.
  WRITE: / 'No records updated'.
ENDIF.
