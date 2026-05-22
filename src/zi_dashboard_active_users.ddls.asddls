@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View Dashboard Active Users'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DASHBOARD_ACTIVE_USERS
  as select from    ZIR_AUTH_LOG   as Auth
    left outer join ZI_USER_DETAIL as UserDetail on Auth.Username = UserDetail.Username
{
  key Auth.SessionId,
      Auth.Username,
      UserDetail.FullName,
      UserDetail.EmailAddress,
      Auth.LoginDate,
      Auth.LoginTime,
      Auth.TerminalId,
      Auth.UserClient,
      Auth.SystemId
}
where
      Auth.LoginResult = 'SUCCESS'
  and Auth.LogoutDate  = '00000000'
