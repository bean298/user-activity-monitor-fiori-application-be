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
    
define view entity ZI_USER_DETAIL
  as select from    usr21 as user
    left outer join adrp  as person  on user.persnumber = person.persnumber
    left outer join adrc  as address on user.addrnumber = address.addrnumber
    left outer join usr02 as logon   on user.bname = logon.bname
    left outer join adr6  as email   on user.persnumber = email.persnumber
{
  key user.bname                          as Username,
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
      email.smtp_addr                     as EmailAddress
}
