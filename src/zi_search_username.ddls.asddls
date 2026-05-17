@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Search Help Username'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_SEARCH_USERNAME
  as select distinct from ZIR_AUTH_LOG
{
         @Search.defaultSearchElement: true
         @EndUserText.label: 'User Name'
  key    Username
}
