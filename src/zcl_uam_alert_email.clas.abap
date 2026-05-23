
CLASS zcl_uam_alert_email DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: mt_auth_log    TYPE STANDARD TABLE OF zuam_auth_log,
          ms_auth_log    TYPE zuam_auth_log,
          mv_user_count  TYPE i,
          mv_admin_email TYPE ad_smtpadr.

    METHODS get_auth.

    METHODS sent_mail.

    METHODS get_user_email
      IMPORTING iv_user         TYPE xubname
      RETURNING VALUE(rv_email) TYPE ad_smtpadr.

    METHODS sent_user_mail.

ENDCLASS.


CLASS zcl_uam_alert_email IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    "--- Define admin email parameter for Application Job Catalog ---"
    et_parameter_def = VALUE #(
      ( selname        = 'P_EMAIL'
        kind           = 'P'
        datatype       = 'C'
        length         = 241
        component_type = 'AD_SMTPADR'
        mandatory_ind  = abap_true
        changeable_ind = abap_true )
    ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    "--- Read admin email from job parameters ---"
    READ TABLE it_parameters
      WITH KEY selname = 'P_EMAIL'
      INTO DATA(ls_param).
    IF sy-subrc = 0.
      mv_admin_email = ls_param-low.
    ENDIF.

    "--- Run main logic ---"
    get_auth( ).

    CHECK mt_auth_log IS NOT INITIAL.

    sent_mail( ).
    sent_user_mail( ).
  ENDMETHOD.


  METHOD get_auth.
    "--- Read locked user records not yet notified ---"
    SELECT session_id,
           username,
           mandt,
           event_id,
           login_message,
           erdat,
           erzet,
           mail_sent
      FROM zuam_auth_log
      WHERE event_id  = 'AUM'
        AND mail_sent = ''
      INTO CORRESPONDING FIELDS OF TABLE @mt_auth_log.

    IF mt_auth_log IS INITIAL.
      MESSAGE s018(zuam_msg).
    ENDIF.
  ENDMETHOD.


  METHOD get_user_email.
    "--- Read user email from SU01 (USR21 + ADR6) ---"
    DATA: ls_usr21 TYPE usr21.

    SELECT SINGLE persnumber, addrnumber
      FROM usr21
      WHERE bname = @iv_user
      INTO CORRESPONDING FIELDS OF @ls_usr21.

    CHECK sy-subrc = 0.

    SELECT SINGLE smtp_addr
      FROM adr6
      WHERE addrnumber = @ls_usr21-addrnumber
        AND persnumber = @ls_usr21-persnumber
      INTO @rv_email.
  ENDMETHOD.


  METHOD sent_mail.
    "--- Send admin summary report ---"
    DATA: lo_bcs       TYPE REF TO cl_bcs,
          lo_document  TYPE REF TO cl_document_bcs,
          lo_recipient TYPE REF TO if_recipient_bcs,
          lt_html      TYPE soli_tab,
          lv_html      TYPE string.

    DATA: lv_time TYPE string,
          lv_date TYPE string.

    DATA: lv_sent TYPE os_boolean.

    TRY.
        "--- Build HTML ---"
        lv_html =
          | <html>                                                                                           | &&
          | <body style="font-family:Arial;background:#f6f6f6;padding:20px;">                                | &&
          | <div style="background:white;padding:20px;border-radius:6px;width:700px;border:1px solid #ddd;"> | &&
          | <h2 style="color:#2c3e50;">&#128680;User Lock Report</h2>                                        | &&
          | <p style="color:#555;">The following users have been locked:</p>                                 | &&
          | <table style="border-collapse:collapse;width:100%;margin-top:10px;">                             | &&
          | <tr style="background:#2c3e50;color:white;">                                                     | &&
          | <th style="padding:8px;border:1px solid #ddd;">User</th>                                         | &&
          | <th style="padding:8px;border:1px solid #ddd;">System</th>                                       | &&
          | <th style="padding:8px;border:1px solid #ddd;">Client</th>                                       | &&
          | <th style="padding:8px;border:1px solid #ddd;">Lock reason</th>                                  | &&
          | <th style="padding:8px;border:1px solid #ddd;width:100px;">Date</th>                             | &&
          | <th style="padding:8px;border:1px solid #ddd;">Time</th>                                         | &&
          | </tr>                                                                                            |.

        LOOP AT mt_auth_log INTO ms_auth_log.
          lv_time = |{ ms_auth_log-erzet+0(2) }:{ ms_auth_log-erzet+2(2) }:{ ms_auth_log-erzet+4(2) }|.
          lv_date = |{ ms_auth_log-erdat+0(4) }-{ ms_auth_log-erdat+4(2) }-{ ms_auth_log-erdat+6(2) }|.

          lv_html = lv_html &&
            | <tr>                                                                                  | &&
            |  <td style="padding:8px;border:1px solid #ddd;">&#128274;{ ms_auth_log-username }</td>| &&
            |  <td style="padding:8px;border:1px solid #ddd;">{ sy-sysid }</td>                    | &&
            |  <td style="padding:8px;border:1px solid #ddd;">{ ms_auth_log-mandt }</td>            | &&
            |  <td style="padding:8px;border:1px solid #ddd;">{ ms_auth_log-login_message }</td>    | &&
            |  <td style="padding:8px;border:1px solid #ddd;width:100px;">{ lv_date }</td>          | &&
            |  <td style="padding:8px;border:1px solid #ddd;">{ lv_time }</td>                      | &&
            | </tr>                                                                                 |.
        ENDLOOP.

        lv_html = lv_html &&
          | </table>                                                                                         | &&
          | <p style="margin-top:15px;font-size:12px;color:#888;">This is an automated message from SAP.</p> | &&
          | </div></body></html>                                                                             |.

        "--- Convert string -> table ---"
        CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
          EXPORTING
            text      = lv_html
          TABLES
            ftext_tab = lt_html.

        "--- Create document ---"
        lo_document = cl_document_bcs=>create_document(
                        i_type    = 'HTM'
                        i_text    = lt_html
                        i_subject = TEXT-001
                      ).

        "--- Create send request ---"
        lo_bcs = cl_bcs=>create_persistent( ).
        lo_bcs->set_document( lo_document ).

        "--- Add admin recipient ---"
        lo_recipient = cl_cam_address_bcs=>create_internet_address( mv_admin_email ).
        lo_bcs->add_recipient( lo_recipient ).

        "--- Send ---"
        lo_bcs->set_send_immediately( abap_true ).
        lv_sent = lo_bcs->send( ).

        "--- Update MAIL_SENT = 'X' ---"
        IF lv_sent = abap_true.
          LOOP AT mt_auth_log INTO ms_auth_log.
            UPDATE zuam_auth_log
              SET mail_sent = 'X'
              WHERE session_id = @ms_auth_log-session_id.
          ENDLOOP.

          COMMIT WORK.

          mv_user_count = lines( mt_auth_log ).
          MESSAGE s019(zuam_msg) WITH mv_user_count.
        ENDIF.

      CATCH cx_send_req_bcs
            cx_address_bcs
            cx_document_bcs
            cx_bcs INTO DATA(lx_error).

        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.


    METHOD sent_user_mail.
    "--- Send individual lock notification to each locked user ---"
    DATA: lo_bcs       TYPE REF TO cl_bcs,
          lo_document  TYPE REF TO cl_document_bcs,
          lo_recipient TYPE REF TO if_recipient_bcs,
          lt_html      TYPE soli_tab,
          lv_html      TYPE string.

    DATA: lv_user_email TYPE ad_smtpadr,
          lv_time       TYPE string,
          lv_date       TYPE string.

    LOOP AT mt_auth_log INTO ms_auth_log.

      CLEAR: lv_html, lt_html, lo_document, lo_bcs, lo_recipient.

      lv_user_email = get_user_email( ms_auth_log-username ).

      CHECK lv_user_email IS NOT INITIAL.

      lv_time = |{ ms_auth_log-erzet+0(2) }:{ ms_auth_log-erzet+2(2) }:{ ms_auth_log-erzet+4(2) }|.
      lv_date = |{ ms_auth_log-erdat+0(4) }-{ ms_auth_log-erdat+4(2) }-{ ms_auth_log-erdat+6(2) }|.

      "--- Build individual notification HTML ---"
      lv_html =
        | <html>                                                                                               | &&
        | <body style="font-family:Arial;background:#f6f6f6;padding:20px;">                                   | &&
        | <div style="background:white;padding:20px;border-radius:6px;width:600px;border:1px solid #ddd;">    | &&
        | <h2 style="color:#c0392b;">&#128274; Your SAP account has been locked</h2>                          | &&
        | <p style="color:#555;">Dear <b>{ ms_auth_log-username }</b>,</p>                                    | &&
        | <p style="color:#555;">Your SAP account has been locked. Details are as follows:</p>                | &&
        | <table style="border-collapse:collapse;width:100%;margin-top:10px;">                                | &&
        | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;width:140px;">System</td>         | &&
        |     <td style="padding:8px;border:1px solid #ddd;">{ sy-sysid }</td></tr>                           | &&
        | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Client</td>                     | &&
        |     <td style="padding:8px;border:1px solid #ddd;">{ ms_auth_log-mandt }</td></tr>                  | &&
        | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Lock reason</td>                | &&
        |     <td style="padding:8px;border:1px solid #ddd;">{ ms_auth_log-login_message }</td></tr>          | &&
        | <tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Date / Time</td>                | &&
        |     <td style="padding:8px;border:1px solid #ddd;">{ lv_date } { lv_time }</td></tr>                | &&
        | </table>                                                                                            | &&
        | <p style="color:#555;margin-top:15px;">Please contact your system administrator for assistance.</p> | &&
        | <p style="font-size:12px;color:#888;margin-top:15px;">This is an automated message from SAP.</p>    | &&
        | </div></body></html>                                                                                |.

      TRY.
          CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
            EXPORTING
              text      = lv_html
            TABLES
              ftext_tab = lt_html.

          lo_document = cl_document_bcs=>create_document(
                          i_type    = 'HTM'
                          i_text    = lt_html
                          i_subject = TEXT-002
                        ).

          lo_bcs = cl_bcs=>create_persistent( ).
          lo_bcs->set_document( lo_document ).

          lo_recipient = cl_cam_address_bcs=>create_internet_address( lv_user_email ).
          lo_bcs->add_recipient( lo_recipient ).

          lo_bcs->set_send_immediately( abap_true ).
          lo_bcs->send( ).

          COMMIT WORK.

        CATCH cx_send_req_bcs
              cx_address_bcs
              cx_document_bcs
              cx_bcs INTO DATA(lx_error).

          MESSAGE lx_error->get_text( ) TYPE 'W'.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

