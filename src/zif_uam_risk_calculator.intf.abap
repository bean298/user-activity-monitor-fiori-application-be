INTERFACE zif_uam_risk_calculator
  PUBLIC .

  METHODS run.

  METHODS calculate_activity_score
    IMPORTING
      iv_tcode    TYPE tcode
      iv_act_time TYPE syuzeit
    RETURNING
      VALUE(rs_result) TYPE zuam_risk_result.  " structure: score + severity

  METHODS calculate_login_score
    IMPORTING
      iv_result   TYPE zuam_login_result       " 'SUCCESS' / 'FAIL'
      iv_act_time TYPE syuzeit
    RETURNING
      VALUE(rs_result) TYPE zuam_risk_result.
ENDINTERFACE.
