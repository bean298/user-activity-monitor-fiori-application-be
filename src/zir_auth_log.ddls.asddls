//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for Authentication Log
//---------------------------------------------------------------------*

@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Authenticattion Log'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define root view entity ZIR_AUTH_LOG
  as select from zuam_auth_log
    composition [0..*] of ZI_ACTIVITY_LOG as _Activity
{
  key session_id    as SessionId,
      event_id      as EventId,
      username      as Username,
      login_date    as LoginDate,
      login_time    as LoginTime,
      login_result  as LoginResult,
      login_message as LoginMessage,
      logout_date   as LogoutDate,
      logout_time   as LogoutTime,
      client        as UserClient,
      terminal_id   as TerminalId,
      system_id     as SystemId,
      mail_sent     as MailSent,
      risk_score    as RiskScore,      
      severity      as Severity,       
      is_scored     as IsScored,
      erzet         as CreateAt,
      erdat         as CreateOn,    
      
      _Activity
}
