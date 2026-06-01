CLASS zcl_uam_risk_alert_email DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_critical_user,
             username         TYPE syuname,
             total_risk_score TYPE i,
             lock_status      TYPE char3,
           END OF ty_critical_user.

    CONSTANTS:
      mc_param_email        TYPE string     VALUE 'P_EMAIL',
      mc_param_label        TYPE string     VALUE 'Admin Email',
      mc_doc_type            TYPE so_obj_tp VALUE 'HTM',
      mc_mail_sent          TYPE char1      VALUE 'X',
      mc_critical_threshold TYPE i          VALUE 100,
      mc_subject            TYPE so_obj_des VALUE 'CRITICAL Risk Level Alert - SAP UAM'.

    DATA: mt_critical_users TYPE STANDARD TABLE OF ty_critical_user,
          mv_admin_email    TYPE ad_smtpadr.

    METHODS get_critical_users.
    METHODS sent_admin_risk_mail.

ENDCLASS.


CLASS zcl_uam_risk_alert_email IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname        = mc_param_email
        kind           = 'P'
        datatype       = 'C'
        length         = 241
        component_type = 'AD_SMTPADR'
        mandatory_ind  = abap_true
        changeable_ind = abap_true
        param_text     = mc_param_label )
    ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    READ TABLE it_parameters
      WITH KEY selname = mc_param_email
      INTO DATA(ls_param).
    IF sy-subrc = 0.
      mv_admin_email = ls_param-low.
    ENDIF.

    get_critical_users( ).

    CHECK mt_critical_users IS NOT INITIAL.

    sent_admin_risk_mail( ).
  ENDMETHOD.


  METHOD get_critical_users.
    "--- Compute TotalRiskScore directly from base table (same logic as ZI_USER_RISK_TOTAL)
    "    Use HAVING for aggregate filter, skip users already alerted ---"
    SELECT act~username,
           SUM( act~risk_score ) AS total_risk_score,
           CAST( usr02~uflag AS CHAR( 3 ) ) AS lock_status
      FROM zuam_act_log AS act
      LEFT OUTER JOIN usr02 ON usr02~bname = act~username
      WHERE act~risk_score > 0
        AND dats_days_between( act~act_date, @sy-datum ) <= 30
        AND NOT EXISTS (
          SELECT mandt FROM zuam_risk_alt
           WHERE username  = act~username
             AND mail_sent = @mc_mail_sent
        )
      GROUP BY act~username, usr02~uflag
      HAVING SUM( act~risk_score ) >= @mc_critical_threshold
      ORDER BY SUM( act~risk_score ) DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @mt_critical_users.

    IF mt_critical_users IS INITIAL.
      MESSAGE s018(zuam_msg).
    ENDIF.
  ENDMETHOD.


  METHOD sent_admin_risk_mail.
    DATA: lo_bcs       TYPE REF TO cl_bcs,
          lo_document  TYPE REF TO cl_document_bcs,
          lo_recipient TYPE REF TO if_recipient_bcs,
          lt_html      TYPE soli_tab,
          lv_html      TYPE string,
          lv_count     TYPE i,
          lv_sent      TYPE os_boolean.

    lv_count = lines( mt_critical_users ).

    TRY.
        lv_html =
          | <html>                                                                                                    | &&
          | <body style="font-family:Arial;background:#f6f6f6;padding:20px;">                                        | &&
          | <div style="background:white;padding:20px;border-radius:6px;width:700px;border:1px solid #ddd;">         | &&
          | <h2 style="color:#c0392b;">&#128721; CRITICAL Risk Level Alert</h2>                                      | &&
          | <p style="color:#555;">                                                                                   | &&
          |   System <b>{ sy-sysid }</b> detected <b>{ lv_count }</b> user(s)                                        | &&
          |   whose total risk score has reached <b style="color:#c0392b;">CRITICAL</b> (&ge; 100).                  | &&
          |   Immediate review is recommended.                                                                       | &&
          | </p>                                                                                                     | &&
          | <table style="border-collapse:collapse;width:100%;margin-top:10px;">                                     | &&
          | <tr style="background:#c0392b;color:white;">                                                             | &&
          | <th style="padding:8px;border:1px solid #ddd;">#</th>                                                    | &&
          | <th style="padding:8px;border:1px solid #ddd;">Username</th>                                             | &&
          | <th style="padding:8px;border:1px solid #ddd;">Total Risk Score</th>                                     | &&
          | <th style="padding:8px;border:1px solid #ddd;">Risk Level</th>                                           | &&
          | <th style="padding:8px;border:1px solid #ddd;">Lock Status</th>                                          | &&
          | </tr>                                                                                                     |.

        DATA(lv_idx) = 0.
        LOOP AT mt_critical_users INTO DATA(ls_user).
          lv_idx = lv_idx + 1.
          DATA(lv_bg) = COND string(
            WHEN lv_idx MOD 2 = 0 THEN '#fdf0ef'
            ELSE                       'white'
          ).

          lv_html = lv_html &&
            | <tr style="background:{ lv_bg };">                                                                    | &&
            |  <td style="padding:8px;border:1px solid #ddd;text-align:center;">{ lv_idx }</td>                     | &&
            |  <td style="padding:8px;border:1px solid #ddd;font-weight:bold;">{ ls_user-username }</td>            | &&
            |  <td style="padding:8px;border:1px solid #ddd;text-align:center;                                      | &&
            |      color:#c0392b;font-weight:bold;">{ ls_user-total_risk_score }</td>                               | &&
            |  <td style="padding:8px;border:1px solid #ddd;text-align:center;">                                    | &&
            |    <span style="background:#c0392b;color:white;padding:2px 8px;border-radius:4px;">CRITICAL</span>    | &&
            |  </td>                                                                                                 | &&
            |  <td style="padding:8px;border:1px solid #ddd;text-align:center;">{ ls_user-lock_status }</td>        | &&
            | </tr>                                                                                                  |.
        ENDLOOP.

        lv_html = lv_html &&
          | </table>                                                                                                   | &&
          | <p style="margin-top:15px;font-size:12px;color:#888;">This is an automated message from SAP UAM.</p>      | &&
          | </div></body></html>                                                                                       |.

        CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
          EXPORTING  text      = lv_html
          TABLES     ftext_tab = lt_html.

        lo_document = cl_document_bcs=>create_document(
                        i_type    = mc_doc_type
                        i_text    = lt_html
                        i_subject = mc_subject ).

        lo_bcs = cl_bcs=>create_persistent( ).
        lo_bcs->set_document( lo_document ).

        lo_recipient = cl_cam_address_bcs=>create_internet_address( mv_admin_email ).
        lo_bcs->add_recipient( lo_recipient ).

        lo_bcs->set_send_immediately( abap_true ).
        lv_sent = lo_bcs->send( ).

        "--- Record alert in ZUAM_RISK_ALT ---"
        IF lv_sent = abap_true.
          LOOP AT mt_critical_users INTO ls_user.

            "--- Try update first, insert if not exists ---"
            UPDATE zuam_risk_alt
              SET alert_date = @sy-datum,
                  risk_score = @ls_user-total_risk_score,
                  mail_sent  = @mc_mail_sent
              WHERE username = @ls_user-username.

            IF sy-subrc <> 0.
              INSERT zuam_risk_alt FROM @(
                VALUE zuam_risk_alt(
                  mandt      = sy-mandt
                  username   = ls_user-username
                  alert_date = sy-datum
                  risk_score = ls_user-total_risk_score
                  mail_sent  = mc_mail_sent
                )
              ).
            ENDIF.

          ENDLOOP.

          COMMIT WORK.

          MESSAGE s019(zuam_msg) WITH lv_count.
        ENDIF.

      CATCH cx_send_req_bcs
            cx_address_bcs
            cx_document_bcs
            cx_bcs INTO DATA(lx_error).

        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
