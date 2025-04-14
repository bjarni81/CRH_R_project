drop table if exists #problemSta5as;
--
select 
	b.OrganizationName
	, c.OrganizationAlias
	, a.EncounterSID
	, a.PersonSID
	, a.ActiveIndicator, a.ActiveStatus
	, a.EncounterType
	, a.EncounterTypeClass
	, a.RegistrationDateTime
	, a.ArriveDateTime
	, ArriveDate =
		DATEFROMPARTS(year(a.ArriveDateTime), month(a.ArriveDateTime), day(a.arriveDateTime))
	, ArriveMonth =
		DATEFROMPARTS(year(a.ArriveDateTime), month(a.ArriveDateTime), '01')
	, a.AdmitSource
	, a.DischargeDisposition
	, a.MedicalService
	, a.Location
	, a.LocationBed
	, a.LocationFacility
	, a.LocationNurseUnit
	, ROW_NUMBER() over(partition by personSID
						, DATEFROMPARTS(year(a.ArriveDateTime), month(a.ArriveDateTime), day(a.arriveDateTime)) 
						order by personSID, arriveDatetime) as rownum
into ##problemSta5as
from [CDWWork2].[EncMill].Encounter as a
left join [CDWWork2].[NDimMill].OrganizationName as b
	on a.OrganizationNameSID = b.OrganizationNameSID
inner join [CDWWork2].[NDimMill].OrganizationAlias as c
	on a.OrganizationNameSID = c.OrganizationNameSID
where AliasPool ='VA Station Number'
	and c.OrganizationAlias IN('528GE', '668','687', '687GB', '687GC', '757GA'
		, '757GB', '757GD', '668QD', '757', '757GC' 
		, '653', '653BY', '653GA', '687HA', '692', '692GB', '653GB', '644GE')
	and a.ArriveDateTime > cast('2021-09-30' as datetime)
	and a.ArriveDateTime < cast('2023-01-01' as datetime)
	and EncounterType = 'Outpatient'
	and MedicalService = 'Family Medicine'
	and Location LIKE '%PC'
	and Location NOT LIKE '%Lab'
	and a.ActiveIndicator = 1;
--52,509
--
select *
from ##problemSta5as
where OrganizationAlias = '687GB'
	and ArriveMonth = cast('2022-10-01' as date)
order by ArriveDateTime, PersonSID
--
select count(*), ArriveMonth
from ##problemSta5as
where OrganizationAlias = '687GB' AND ArriveMonth > cast('2022-03-01' as date)
group by ArriveMonth
order by ArriveMonth
--
with CTE as (
	select count(*) as cnt_, ArriveMonth
	from ##problemSta5as
	where OrganizationAlias = '687GC' AND ArriveMonth > cast('2022-03-01' as date) --and rownum = 1
	group by ArriveMonth
	)
select AVG(cnt_) from cte
--
--
select * 
from ##problemSta5as 
where personSID IN(select personSID from ##problemSta5as where rownum > 1)
	and OrganizationAlias = '687GC'
order by PersonSID, ArriveDateTime
--
select *
from [CDWWork2].EncMill.Encounter
where PersonSID = 1800119659
	and ArriveDateTime < cast('2022-05-12 00:00:00' as datetime)
	and ArriveDateTime > cast('2022-05-10 23:59:59' as datetime)