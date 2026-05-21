//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for Search Help Username
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Search Help Username'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_SEARCHHELP_USERNAME
  as select distinct from ZIR_AUTH_LOG
{
         @Search.defaultSearchElement: true
         @EndUserText.label: 'User Name'
  key    Username
}
