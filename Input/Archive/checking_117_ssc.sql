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
--700586
drop table if exists #denom_stopCodes;
--
select *
into #denom_stopCodes
from #LocationSID_to_StopCode
where careType = 'PC' and covid_vax_flag <> 1;
--97778
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
	, b.PrimaryStopCode
	, b.SecondaryStopCode
into #outpat_encounters
from [CDWWork].[Outpat].Workload as op
inner join #denom_stopCodes as b
	on op.LocationSID = b.LocationSID
where op.VisitDateTime > @StartDate
	AND op.VisitDateTime < @EndDate;
--=================================
--
select count(*) as total
	, sum(case when secondarystopcode = 117 then 1 else 0 end) as _117_sum
from #outpat_encounters
--
select cast(17428704 as float) / cast(57886837 as float)