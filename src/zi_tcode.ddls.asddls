//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for TCode
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - TCode'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_TCODE
  as select from ZI_ACTIVITY_LOG
{
  key   Tcode,
  key   ActDate,
  key   TCodeName,
  key   Username,

        count( * ) as TCodeCount
}
where
      Tcode     is not null
  and Tcode     <> ''
  and TCodeName is not null
  and TCodeName <> ''

group by
  Tcode,
  ActDate,
  TCodeName,
  Username
