//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for Login Result
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - Login Result'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_LOGIN_RESULT
  as select from ZIR_AUTH_LOG
{
  key Username,
  key LoginResult,
  key LoginDate,

      count( * ) as CountLoginLog
}

group by
  Username,
  LoginResult,
  LoginDate
