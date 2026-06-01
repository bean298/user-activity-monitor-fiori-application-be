//---------------------------------------------------------------------*
// Modification Log:
// Date        : 2026/04/17
// Author      : Nguyen Anh Tuan
// Description : Create CDS View for User Detail
//---------------------------------------------------------------------*

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CDS View - User Detail'
@Metadata.ignorePropagatedAnnotations: true


define root view entity ZI_USER_DETAIL
  as select from    ZI_SEARCHHELP_USERNAME as auth_log

    left outer join usr21                  as user    on auth_log.Username = user.bname
    left outer join adrp                   as person  on user.persnumber = person.persnumber
    left outer join adrc                   as address on user.addrnumber = address.addrnumber
    left outer join usr02                  as logon   on auth_log.Username = logon.bname
    left outer join adr6                   as email   on user.persnumber = email.persnumber

    left outer join ZI_USER_RISK_TOTAL     as risk    on auth_log.Username = risk.Username

{
  key auth_log.Username                   as Username,
      user.persnumber                     as Persnumber,
      user.addrnumber                     as Addrnumber,
      person.date_from                    as ValidFrom,
      person.date_to                      as ValidTo,
      person.name_text                    as FullName,
      address.name1                       as AddressName,
      address.city1                       as City,
      address.post_code1                  as PostalCode,
      address.street                      as Street,
      cast( logon.uflag as abap.char(3) ) as LockStatus,
      logon.class                         as UserGroup,
      logon.aname                         as Creator,
      logon.erdat                         as CreateOn,
      min( email.smtp_addr )              as EmailAddress,
      min( risk.TotalRiskScore )          as TotalRiskScore,
      min( risk.MaxRiskScore )            as MaxRiskScore


}
group by
  auth_log.Username,
  user.persnumber,
  user.addrnumber,
  person.date_from,
  person.date_to,
  person.name_text,
  address.name1,
  address.city1,
  address.post_code1,
  address.street,
  logon.uflag,
  logon.class,
  logon.aname,
  logon.erdat
