/*
Pulling all PC encounters 
	-PCAT definition of PC (minus SSC = 710 "VACCINE")
	-altered to include only ssc = (185, 186, 187, 188) for In-person and Telephone
	-Video visits include VVC and CVT
*/
drop table if exists #pc_encounters;
--
select visitDate = cast(a.VisitDateTime as date)
	, visitMonth = DATEFROMPARTS(year(a.visitDateTime), month(a.visitDateTime), '01')
	, fy = case when month(a.visitDateTime) > 9 then year(a.visitDateTime) + 1 else year(a.visitDateTime) end
	, qtr = case 
				when month(a.visitDateTime) in(10, 11, 12) then 1
				when month(a.visitDateTime) in(1, 2, 3) then 2
				when month(a.visitDateTime) in(4, 5, 6) then 3
				when month(a.visitDateTime) in(7, 8, 9) then 4 end	
	, spat.ScrSSN
	, div.Sta6a
	, psc.StopCode as primaryStopCode, psc.StopCodeName as pStopCodeName
	, ssc.StopCode as secondaryStopCode
	, sStopCodeName = case when ssc.StopCode IS NULL then '*Unknown at this time*' else ssc.StopCodeName end
	, encounter_type = case
		when psc.StopCode = 338 and (ssc.StopCode IN(185, 186, 187, 188) OR ssc.StopCode IS NULL) then 'Telephone'
		when ssc.StopCode = 179 OR (ssc.StopCode > 689 AND ssc.StopCode < 700) then 'Video'
		--when ssc.StopCode = 719 then 'Secure Message'/*excluding secure message encounters, per email on April 21st, 2022*/
		when psc.StopCode <> 338 and (ssc.StopCode IN(185, 186, 187, 188) OR ssc.StopCode IS NULL) then 'In-Person'
		else 'Other' 
		end
	, vaccine_flag = case
		when ssc.StopCode = 710 then 1 else 0 end
	, vast.parent_visn
	, vast.parent_station_sta5a
into #pc_encounters
from [CDWWork].[Outpat].Workload as a
left join [CDWWork].[Dim].StopCode as psc
	on a.PrimaryStopCodeSID = psc.StopCodeSID
left join [CDWWork].[Dim].StopCode as ssc
	on a.SecondaryStopCodeSID = ssc.StopCodeSID
left join [CDWWork].[SPatient].SPatient as spat
	on a.PatientSID = spat.PatientSID
left join [CDWWork].[Dim].Division as div
	on a.DivisionSID = div.DivisionSID
inner join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on div.Sta6a = vast.sta5a
where a.visitdatetime > cast('2018-06-30' as datetime2) 
	AND a.VisitDateTime < cast('2024-10-01' as datetime2)
	AND ((psc.StopCode IN(322, 323, 338, 348, 350, 704) 
			AND (ssc.StopCode NOT IN(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 710, 999)
				OR ssc.StopCode IS NULL))
		OR ssc.StopCode IN(322, 323, 348, 350, 704));
--124,660,654
--=========
/*
All Unique sta6a-month combinations for joining onto
*/
select distinct Sta6a into #sta6a from #pc_encounters
--1,138
select distinct visitMonth into #visitMonth from #pc_encounters;
--74
drop table if exists #sta6a_months;
--
select sta6a, visitMonth
	, fy = case when month(visitMonth) > 9 then year(visitMonth) + 1 else year(visitMonth) end
	, qtr = case 
				when month(visitMonth) in(10, 11, 12) then 1
				when month(visitMonth) in(1, 2, 3) then 2
				when month(visitMonth) in(4, 5, 6) then 3
				when month(visitMonth) in(7, 8, 9) then 4 end
into #sta6a_months
from #sta6a
cross join #visitMonth
--==========
/*
Counting PC encounters and uniques in cerner
*/
drop table if exists #cerner_count;
--
with CTE as (
	select *
		, sta6a = case
			when SUBSTRING(locationFacility, 4, 1) = ' ' then SUBSTRING(LocationFacility, 1, 3)
			when SUBSTRING(LocationFacility, 4, 1) <> ' ' then SUBSTRING(LocationFacility, 1, 5)
			else 'Uh-oh!' end
		, visitMonth = DATEFROMPARTS(year(DerivedVisitDate), month(DerivedVisitDate), '01')
		, fy = case when month(DerivedVisitDate) > 9 then year(DerivedVisitDate) + 1 else year(DerivedVisitDate) end
		, qtr = case 
					when month(DerivedVisitDate) in(10, 11, 12) then 1
					when month(DerivedVisitDate) in(1, 2, 3) then 2
					when month(DerivedVisitDate) in(4, 5, 6) then 3
					when month(DerivedVisitDate) in(7, 8, 9) then 4 end
	from [PACT_CC].[cern].cipher_201_encounter_dist_personSID
	where rn = 1
		and EncounterType <> 'HBPC'
		)
select count(*) as encounter_count_cerner
	, count(distinct personSID) as personSID_count
	, sta6a, visitMonth, fy, qtr
into #cerner_count
from CTE
group by sta6a, visitMonth, fy, qtr
--781
--=============================================
/*
Counting encounters and uniques from cdw
*/
drop table if exists #cdw_count;
--
select count(distinct ScrSSN) as scrssn_count_cdw
	, count(*) as pc_encounter_cdw
	, visitMonth
	, fy, qtr
	, Sta6a
into #cdw_count
from #pc_encounters
where encounter_type <> 'Other'--per discussion of crh_pc_stopCodes_with_new_restrictions.html
group by visitMonth, fy, qtr
	, Sta6a
/*===============================================*/
-- Outputting ScrSSN and total encounter counts by sta6a-month
drop table if exists [OABI_MyVAAccess].[crh_eval].A1_pc_enc_scrssn_count;
--
select a.Sta6a, a.visitMonth, a.fy, a.qtr
	, b.pc_encounter_cdw, b.scrssn_count_cdw
	, c.encounter_count_cerner, c.personSID_count
	, pc_encounter_total = isNULL(b.pc_encounter_cdw, 0) + isNULL(c.encounter_count_cerner, 0)
	, scrssn_count = isNULL(b.scrssn_count_cdw, 0) + isNULL(c.personSID_count, 0)
into [OABI_MyVAAccess].[crh_eval].A1_pc_enc_scrssn_count
from #sta6a_months as a
left join #cdw_count as b
	on a.Sta6a = b.Sta6a
		and a.visitMonth = b.visitMonth
left join #cerner_count as c
	on a.Sta6a = c.sta6a
		and a.visitMonth = c.visitMonth
--86,488
-- Outputting ScrSSN and total encounter counts by visn-month
--drop table if exists [OABI_MyVAAccess].[crh_eval].A2_pc_enc_scrssn_count_visn;
----
--select count(distinct ScrSSN) as scrssn_count
--	, count(*) as pc_encounter_total
--	, visitMonth
--	, fy, qtr
--	, parent_visn
--into [OABI_MyVAAccess].[crh_eval].A2_pc_enc_scrssn_count_visn
--from #pc_encounters
--where encounter_type <> 'Other'--per discussion of crh_pc_stopCodes_with_new_restrictions.html
--group by visitMonth, fy, qtr
--	, parent_visn
--934
--drop table if exists #pc_encounters;
/*-----------------------------------------------*/
-- Outputting a stop Code comparison 
drop table if exists [OABI_MyVAAccess].[crh_eval].temp_sc_comparison;
--
select count(*) as sc_count
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, encounter_type
into [OABI_MyVAAccess].[crh_eval].temp_sc_comparison
from #pc_encounters
group by primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, encounter_type
--467