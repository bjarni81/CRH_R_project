
--==++==++==++==++==++==++==++==++
/*StopCode-to-LocationSID lookup table*/
drop table if exists #sc_to_loc;
--
select distinct div.Sta3n, div.Sta6a
	, psc.StopCode as pSC, psc.StopCodeName as pSCName
	, ssc.StopCode as sSC, ssc.StopCodeName as sSCName
	, loc.LocationSID, loc.LocationName
into #sc_to_loc
from [CDWWork].[Dim].Location as loc
left join [CDWWork].[Dim].StopCode as psc
	on loc.PrimaryStopCodeSID = psc.StopCodeSID
left join [CDWWork].[Dim].StopCode as ssc
	on loc.SecondaryStopCodeSID = ssc.StopCodeSID
left join [CDWWork].[Dim].Division as div
	on loc.DivisionSID = div.DivisionSID
where psc.StopCode in(156, 176, 177, 178, 301, 322, 323, 338, 348
						, 502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587
						, 534, 539
						, 160)
	OR ssc.StopCode in(156, 176, 177, 178, 301, 322, 323, 338, 348
						, 502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587
						, 534, 539
						, 160);
--665,079
--==++==++==++==++==++==++==++==++
/*ScrSSN-PatientSID lookup table*/
drop table if exists #patid;
--
select distinct a.ScrSSN, b.PatientSID
into #patid
from [OABI_MyVAAccess].[crh_eval].CRH_UNIONED as a
left join [CDWWork].[SPatient].SPatient as b
	on a.ScrSSN = b.ScrSSN
where b.CDWPossibleTestPatientFlag = 'N'
	and b.VeteranFlag = 'Y';
--1,085,399
--==++==++==++==++==++==++==++==++
/*Outpatient Encounters*/
drop table if exists #outpat;
--
select patid.ScrSSN
	, op.VisitDateTime
	, loc.Sta3n, loc.Sta6a, loc.LocationName
	, loc.pSC, loc.pSCName
	, loc.sSC, loc.sSCName
	, care_type = case
		when (pSC in(156, 176, 177, 178, 301, 322, 323, 338, 348) AND (sSC <> 160 OR sSC IS NULL))
			OR (pSC <> 160 AND sSC in(156, 176, 177, 178, 301, 322, 323, 338, 348)) then 'Primary Care'
		when (pSC in(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587) AND (sSC NOT IN(160, 534)))
			OR (pSC NOT IN(160,534) AND sSC IN(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587)) then 'Mental Health'
		when (pSC IN(534, 539) AND (sSC <> 160))
			OR (pSC <> 160 AND sSC IN(534, 539)) then 'PCMHI'
		when (pSC = 160 OR sSC = 160) then 'Pharmacy'
		else 'Specialty' end
	, crh_locName_flag = case when loc.LocationName LIKE '%V__ CRH%' then 1 else 0 end
into #outpat
from [CDWWork].[Outpat].Workload as op
inner join #sc_to_loc as loc
	on op.LocationSID = loc.LocationSID
inner join #patid as patid
	on op.PatientSID = patid.PatientSID
where op.VisitDateTime > cast('2019-09-30' as datetime2)
	and op.VisitDateTime < cast('2021-10-01' as datetime2);
--7,054,592
select top 100 *
from #outpat
order by ScrSSN, VisitDateTime;
--
select sum(crh_locName_flag)
from #outpat;
--753,293 (~10%)
--==++==++==++==++==++==++==++==++
/*Counting by ScrSSN, sta6a, and care_type*/
drop table if exists #encounter_counts_1;
--
select ScrSSN, sta6a, care_type, count(*) as encounters
into #encounter_counts_1
from #outpat
group by ScrSSN, Sta6a, care_type;
--
--==++==++==++==++==++==++==++==++
/*Row_number to get most frequent sta5a by scrssn and care_type*/
drop table if exists #encounter_counts_2;
--
select *
	, ROW_NUMBER() over(partition by scrssn, care_type order by encounters desc) as rowNum
into #encounter_counts_2
from #encounter_counts_1;
--
--==++==++==++==++==++==++==++==++
/*Output Final Table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].freq_scrssn_sta5a;
--
select ScrSSN, Sta6a as most_freq_sta6a, care_type
into [OABI_MyVAAccess].[crh_eval].freq_scrssn_sta5a
from #encounter_counts_2
where rowNum = 1;
--693,793
select top 100 *
from [OABI_MyVAAccess].[crh_eval].freq_scrssn_sta5a
order by ScrSSN
