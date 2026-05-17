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
  as select from ZIR_AUTH_LOG
{
  key UserClient as userCient,
  key SystemId
}
where
      UserClient is not null
  and UserClient <> ''
  and SystemId   is not null
  and SystemId   <> ''

group by
  UserClient,
  SystemId
