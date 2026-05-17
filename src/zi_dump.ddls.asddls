//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for Dump Log
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - Dump'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DUMP
  as select from ZI_ACTIVITY_LOG
{
  key Username,
  key ActDate,
      count( * ) as DumpCount
}
where
  ActType = 'DUMP'

group by
  Username,
  ActDate
