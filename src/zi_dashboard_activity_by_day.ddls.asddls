@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS View - Dashboard Activity By Day'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DASHBOARD_ACTIVITY_BY_DAY
  as select from ZI_ACTIVITY_LOG
{
  key ActDate,

      count( * ) as ActivityCount
}
group by
  ActDate
