@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - Dashboard Login Result'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DASHBOARD_LOGIN_RESULT
  as select from ZIR_AUTH_LOG
{
  key LoginDate,
  key LoginResult,

      count( * ) as LoginCount
}
where
     LoginResult = 'SUCCESS'
  or LoginResult = 'FAIL'
group by
  LoginDate,
  LoginResult
