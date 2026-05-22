@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS View - Admin History'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_ADMIN_HISTORY
  as select from zuam_history
{
  key history_id     as HistoryId,
      action_type    as ActionType,
      username       as Username,
      action_date    as ActionDate,
      action_time    as ActionTime,
      action_message as ActionMessage,
      reason         as Reason
}
