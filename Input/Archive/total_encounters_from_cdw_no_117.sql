/*
Program to count total Encounters by type and sta5a
*/
--=================================
/*Step 1: LocationSID/StopCode Lookup Table*/
drop table if exists #LocationSID_to_StopCode;
--
select distinct
	a.LocationSID
	, a.PrimaryStopCode
	, a.SecondaryStopCode
	, ax.StopCode as pStopCode_
	, ax.StopCodeName as pStopCodeName_
	, ay.StopCode as sStopCode_
	, ay.StopCodeName as sStopCodeName_
	, a.InactiveDate
	, a.NonCountClinicFlag as nonCountClinicFlag1
	, c.LocationName
	, c.PrimaryStopCodeSID
	, c.SecondaryStopCodeSID
	, d.Sta6a
	, d.DivisionName
	, careType = case 
			when (a.PrimaryStopCode in (156, 176, 177, 178, 301, 322, 323, 338, 348) 
					AND (a.SecondaryStopCode not in(117,/*per discussion with Matt Augustine*/ 
														160) OR a.SecondaryStopCode IS NULL)) 
				OR (a.PrimaryStopCode <> 160 
					AND a.SecondaryStopCode in (156, 176, 177, 178, 301, 322, 323, 338, 348)) then 'PC' 
			when (a.PrimaryStopCode in (502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587) 
					AND (a.SecondaryStopCode <> 160 OR a.SecondaryStopCode IS NULL))	
				OR (a.PrimaryStopCode <> 160 
					AND a.SecondaryStopCode in (502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587)) then 'MH'
			when (a.PrimaryStopCode in (534, 539) 
					AND (a.SecondaryStopCode <> 160 OR a.SecondaryStopCode IS NULL)) 
				OR (a.PrimaryStopCode <> 160 AND a.SecondaryStopCode in (534, 539)) then 'PCMHI'
			when a.PrimaryStopCode = 160 OR a.SecondaryStopCode = 160 then 'Pharmacy'
				else NULL end 
	, covid_vax_flag = case when c.LocationName like '%covid vacc%' then 1 else 0 end
into #LocationSID_to_StopCode
from [CDWWork].[Dim].DSSLocation as a
left join [CDWWork].[Dim].DSSLocationStopCode as b
	on a.DSSLocationStopCodeSID = b.DSSLocationStopCodeSID
left join [CDWWork].[Dim].Location as c
	on a.LocationSID = c.LocationSID
left join [CDWWork].[Dim].Division as d
	on c.DivisionSID = d.DivisionSID
left join [CDWWork].[Dim].StopCode as ax
	on c.PrimaryStopCodeSID = ax.StopCodeSID
left join [CDWWork].[Dim].StopCode as ay
	on c.SecondaryStopCodeSID = ay.StopCodeSID
left join [CDWWork].[Dim].Sta3n as az
	on a.Sta3n = az.Sta3n
where a.InactiveDate > cast('2019-09-30' as date) OR a.InactiveDate IS NULL;
--700,586
drop table if exists #denom_stopCodes;
--
select *
into #denom_stopCodes
from #LocationSID_to_StopCode
where careType IS NOT NULL;
--282,575
--=================================
/*Step 2: Outpatient encounters, inner joined on LocationSID from table above*/
declare @StartDate date 
	,@EndDate date;
set @StartDate =  CAST('2019-03-31' as datetime2);/*FY20 + 6months lookback*/
set @EndDate = CAST('2021-10-01' as datetime2);/*FY21*/
--+++++
drop table if exists #outpat_encounters;
--
select op.PatientSID, op.VisitDateTime
	, DATEFROMPARTS(year(op.visitDateTime), month(op.visitDateTime), '01') as vizMonth
	, b.Sta6a
	, b.careType
	, b.covid_vax_flag
into #outpat_encounters
from [CDWWork].[Outpat].Workload as op
inner join #denom_stopCodes as b
	on op.LocationSID = b.LocationSID
where op.VisitDateTime > @StartDate
	AND op.VisitDateTime < @EndDate;
--97,058,832
--=================================
/*Step 3: count encounters by sta6a, month, and type*/
drop table if exists #pc_encounters;
--
select sta6a, vizmonth
	, sum(case when careType = 'PC' AND covid_vax_flag = 0 then 1 else 0 end) as pc_encounters
	, sum(case when careType = 'PC' AND covid_vax_flag = 1 then 1 else 0 end) as pc_CovidVax_encounters
into #pc_encounters
from #outpat_encounters
group by sta6a, vizMonth;
--37,702
drop table if exists #mh_encounters;
--
select sta6a, vizmonth
	, sum(case when careType = 'MH' AND covid_vax_flag = 0 then 1 else 0 end) as mh_encounters
	, sum(case when careType = 'MH' AND covid_vax_flag = 1 then 1 else 0 end) as mh_CovidVax_encounters
into #mh_encounters
from #outpat_encounters
group by sta6a, vizMonth;
--37,702
--==
drop table if exists #pcmhi_encounters;
--
select sta6a, vizmonth
	, sum(case when careType = 'PCMHI' AND covid_vax_flag = 0 then 1 else 0 end) as pcmhi_encounters
	, sum(case when careType = 'PCMHI' AND covid_vax_flag = 1 then 1 else 0 end) as pcmhi_CovidVax_encounters
into #pcmhi_encounters
from #outpat_encounters
group by sta6a, vizMonth;
--37,702
--==
drop table if exists #pharmacy_encounters;
--
select sta6a, vizmonth
	, sum(case when careType = 'Pharmacy' AND covid_vax_flag = 0 then 1 else 0 end) as pharmacy_encounters
	, sum(case when careType = 'Pharmacy' AND covid_vax_flag = 1 then 1 else 0 end) as pharmacy_CovidVax_encounters
into #pharmacy_encounters
from #outpat_encounters
group by sta6a, vizMonth;
--37,702
--=================================
/*Step 4: Sta6a & VizMonth Table for joining onto*/
drop table if exists #vizMonths;
--
select distinct vizmonth
into #vizMonths
from #outpat_encounters
--==
drop table if exists #sta6a;
--
select distinct sta6a
into #sta6a
from #outpat_encounters
where sta6a <> '*Missing*';
--==
drop table if exists #sta6a_months;
--
select a.sta6a, b.vizMonth
into #sta6a_months
from #sta6a as a
cross join #vizMonths as b;
--41,974
--=================================
/*Step 4: Output permanent table with zeroes for missing values*/
drop table if exists [OABI_MyVAAccess].[crh_eval].all_encounters_E_counts;
--
select a.sta6a, a.vizMonth
	, b.pc_encounters, b.pc_CovidVax_encounters
	, c.mh_encounters, c.mh_CovidVax_encounters
	, d.pcmhi_encounters, d.pcmhi_CovidVax_encounters
	, e.pharmacy_encounters, e.pharmacy_CovidVax_encounters
into [OABI_MyVAAccess].[crh_eval].all_encounters_E_counts
from #sta6a_months as a
left join #pc_encounters as b
	on a.Sta6a = b.Sta6a
		and a.vizMonth = b.vizMonth
left join #mh_encounters as c
	on a.Sta6a = c.Sta6a
		and a.vizMonth = c.vizMonth
left join #pcmhi_encounters as d
	on a.Sta6a = d.Sta6a
		and a.vizMonth = d.vizMonth
left join #pharmacy_encounters as e
	on a.Sta6a = e.Sta6a
		and a.vizMonth = e.vizMonth
where a.vizMonth > cast('2019-03-01' as date)
--40,530
select *
from [OABI_MyVAAccess].[crh_eval].all_encounters_E_counts
where sta6a = '636A8'
order by vizMonth