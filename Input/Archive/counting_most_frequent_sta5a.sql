/*ScrSSN to PatientSID lookup*/
drop table if exists #patientid;
--
select distinct a.ScrSSN, b.patientSID
into #patientID
from [PACT_CC].[CRH].crh_full_utilization_CLEAN_update as a
left join [CDWWork].[SPatient].SPatient as b
	on cast(a.PatientICN as varchar) = b.PatientICN
where b.CDWPossibleTestPatientFlag = 'N'
	and b.VeteranFlag = 'Y';
--846,005
select count(distinct scrssn) from #patientID
--242,784
select count(distinct scrssn) from [PACT_CC].[CRH].crh_full_utilization_CLEAN_update
--243,858
/*Hub lookup*/
select distinct hub_sta3n as hub_sta5a
into #hubs
FROM [PACT_CC].[CRH].[CRH_sites_FY20]
UNION 
select distinct Hub_Sta3n as hub_sta5a
FROM [PACT_CC].[CRH].[CRH_sites_FY21_working];
--30
/*Spoke lookup*/
select spoke_sta5a 
into #spokes
from [PACT_CC].[CRH].CRH_sites_fy20_working
UNION
select spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy21_working
--589
/*Pull all outpatient encounters*/
drop table if exists #all_encounters;
--
with cte as(
select b.ScrSSN, a.VisitDateTime, c.Sta6a
from [CDWWork].[Outpat].Visit as a
inner join #patientID as b
	on a.PatientSID = b.PatientSID
left join [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode as c
	on a.LocationSID = c.LocationSID
where a.VisitDateTime > cast('2019-09-30' as datetime2)
	and a.VisitDateTime < cast('2021-10-01' as datetime2)
	and c.sta6a <> '*Missing*')
select ScrSSN, count(*) as sta6a_count, sta6a
into #all_encounters
from cte
group by ScrSSN, Sta6a;
--908,022
/*Flags for Hubs and Spokes*/
drop table if exists #all_encounters2;
--
select a.*
	, hub_flag = case when b.hub_sta5a IS NOT NULL then 2 else 1 end/*if the sta5a is in #hubs then 2, else 1*/
	, spoke_flag = case when c.spoke_sta5a IS NULL then 2 else 1 end/*if the sta5a is not in #spokes then 2, else 1*/
into #all_encounters2
from #all_encounters as a
left join #hubs as b
	on a.Sta6a = b.hub_sta5a
left join #spokes as c
	on a.Sta6a = c.Spoke_Sta5a;
--908,022
/*Row_Number partitioned by ScrSSN, ordered by hub_flag, spoke_flag, and sta6a_count*/
drop table if exists #rowNum;
--
select *
	, ROW_NUMBER() over(partition by ScrSSN order by hub_flag asc, spoke_flag asc, sta6a_count desc) as rowNum
into #rowNum
from #all_encounters2;
--908,022
/*Output final table where RowNum = 1*/
drop table if exists [OABI_MyVAAccess].[crh_eval].most_freq_sta5a;
--
select ScrSSN, sta6a as sta5a_most_freq
into [OABI_MyVAAccess].[crh_eval].most_freq_sta5a
from #rowNum
where rowNum = 1;
--242,782
/*=============================================================================*/
select count(*)
from [OABI_MyVAAccess].[crh_eval].most_freq_sta5a
where sta5a_most_freq IN(select hub_sta5a from #hubs);
--3,350
select count(*)
from [OABI_MyVAAccess].[crh_eval].most_freq_sta5a
where sta5a_most_freq NOT IN(select spoke_sta5a from #spokes);
--5,253
select count(*)
from [OABI_MyVAAccess].[crh_eval].most_freq_sta5a
where sta5a_most_freq IN(select hub_sta5a from #hubs)
	OR sta5a_most_freq NOT IN(select spoke_sta5a from #spokes);
--8,603