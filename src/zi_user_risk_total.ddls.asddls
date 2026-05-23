@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'User Total Risk Score - 30 Days'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_USER_RISK_TOTAL
  as select from zuam_act_log
{
  key username                                                         as Username,
      sum( risk_score )                                                as TotalRiskScore,
      max( risk_score )                                                as MaxRiskScore,
      count(*)                                                         as TotalEvents
}
where
  dats_days_between( act_date, $session.system_date ) <= 30
  and risk_score > 0

group by
  username
