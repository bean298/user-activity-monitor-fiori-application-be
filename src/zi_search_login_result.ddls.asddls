@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Search Help Login Result'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_SEARCH_LOGIN_RESULT
  as select distinct from ZIR_AUTH_LOG
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Login Result'
  key LoginResult
}
