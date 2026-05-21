//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for System Information
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - System Information'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_SYSTEM_INFO
  as select distinct from ZIR_AUTH_LOG
{
  key UserClient as userCient
}
where
      UserClient is not null
  and UserClient <> '3xx'
  and UserClient <> '3XX'
