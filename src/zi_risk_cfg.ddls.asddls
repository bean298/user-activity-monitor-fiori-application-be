@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Risk config'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RISK_CFG
  as select from zuam_risk_cfg
{
  key act_type    as ActType,
  key value       as Value,
      risk_score  as RiskScore,
      severity    as Severity,
      description as Description
}
