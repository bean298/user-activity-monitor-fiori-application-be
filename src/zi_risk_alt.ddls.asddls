@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Risk Alert'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RISK_ALT
  as select from zuam_risk_alt
{
  key username   as Username,
      alert_date as AlertDate,
      risk_score as RiskScore,
      mail_sent  as MailSent
}
