/*
Mental health denominator for CRH evaluation
	-also pulling provider type
---===---===---===---===---===---===*/
/*Step 1:
	All Outpatient Encounters with a 500-series stop code
---===---===---===---===---===---===*/
declare @startDate datetime2(0), @endDate datetime2(0);
--
set @startDate = CAST('2018-09-30' as datetime2(0));
--
set @endDate = CAST('2022-01-01' as datetime2(0));
--
drop table if exists #outpat_encounters;
--
select spat.ScrSSN, spat.PatientICN, viz.PatientSID
	, viz.Sta3n, div.Sta6a as sta5a, vast.station_name, vast.parent_station_sta5a, vast.parent_visn as visn
	, viz.VisitDateTime, viz.VisitSID, cast(viz.VisitDateTime as date) as visitDate, psc.StopCode as primaryStopCode, psc.StopCodeName as pStopCodeName
	, ssc.StopCode as secondaryStopCode
	, sStopCodeName = case when ssc.StopCode IS NULL then '*Unknown at this time*' else ssc.StopCodeName end
	, provType.ProviderType
	, provTypeCat = case /*per HSRD ListServ: https://vaww.listserv.va.gov/scripts/wa.exe?A2=HSRDATA-L;fcf74357.2111&S= */
						when providertype in ('Allopathic & Osteopathic Physicians','Physicians (M.D. and D.O.)','Physicians (Other Roles)','Physician')
							then 'MD'
						when providertype in ('Psychology','Behavioral Health & Social Service Providers','Behavioral Health and Social Service')
							then 'Psychologist'
						when providertype in ('Physician Assistants & Advanced Practice Nursing Providers')
							then 'PA/APN'
						when providertype in ('Nursing Service','Nursing Service Providers','Nursing Service Related Providers')
							then 'Nurse'
						when providertype in ('Pharmacy Service','Pharmacy Service Providers')
							then 'Pharmacist'
						else 'Other' end
	, viz_fy = case 
		when month(viz.visitDateTime) > 9 then year(viz.visitDateTime) + 1 
		else year(viz.visitDateTime) end
	, viz_qtr = case
		when month(viz.visitDatetime) in(10, 11, 12) then 1
		when month(viz.visitDatetime) in(1, 2, 3) then 2
		when month(viz.visitDatetime) in(4, 5, 6) then 3
		when month(viz.visitDatetime) in(7, 8, 9) then 4
		else 99 end
	, MH_F2F_FLAG = 
		CASE WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND psc.StopCode NOT IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597)  
				AND (SSC.StopCode NOT IN(179, 690, 692, 693, 719) OR SSC.StopCode IS NULL)) THEN 1 ELSE 0 END
	, MH_TELE_FLAG = 
		CASE WHEN (PSC.StopCode IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597) 
			OR SSC.StopCode IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597)) THEN 1 ELSE 0 END
	, MH_VVC_FLAG = 
		CASE WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode = 179) THEN 1 ELSE 0 END
	, MH_CVT_FLAG =
		CASE WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode IN(690, 692, 693)) THEN 1 ELSE 0 END
	, MH_SM_FLAG = 
		CASE WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode = 719) THEN 1 ELSE 0 END
	, ordering_for_rowNum = 
		CASE 
			WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND psc.StopCode NOT IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597)  
				AND (SSC.StopCode NOT IN(179, 690, 692, 693, 719) OR SSC.StopCode IS NULL)) then 1
			when (PSC.StopCode IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597) 
				OR SSC.StopCode IN(527, 528, 530, 536, 542, 545, 546, 579, 584, 597)) then 2
			WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode IN(690, 692, 693)) then 3
			WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode = 179) THEN 4
			WHEN (PSC.StopCode > 499 AND psc.StopCode < 600 AND SSC.StopCode = 719) THEN 5
			else 99 end
into #outpat_encounters
from [CDWWork].[Outpat].Workload as viz
left join [CDWWork].[Dim].StopCode as psc
	on viz.PrimaryStopCodeSID = psc.StopCodeSID
left join [CDWWork].[Dim].StopCode as ssc
	on viz.SecondaryStopCodeSID = ssc.StopCodeSID
left join [CDWWork].[SPatient].SPatient as spat
	on viz.PatientSID = spat.PatientSID
left join [CDWWork].[Dim].Division as div
	on viz.DivisionSID = div.DivisionSID
inner join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 as vast
	on div.Sta6a = vast.sta5a
left join [CDWWork].[Outpat].VProvider as prov
	on viz.VisitSID = prov.VisitSID
left join [CDWWork].[Dim].ProviderType as provType
	on prov.ProviderTypeSID = provType.ProviderTypeSID
where 
	((psc.StopCode > 499 AND psc.StopCode < 600)
	 OR (ssc.StopCode > 499 AND ssc.StopCode < 600))
	--AND viz.WorkloadLogicFlag = 'Y'-- must be workload
	AND viz.VisitDateTime > @startDate--after startDate
	AND viz.VisitDateTime < @endDate--before endDate
	AND spat.CDWPossibleTestPatientFlag = 'N'--no test patients
	AND spat.ScrSSN is NOT NULL-- no missing ScrSSN
	AND spat.BirthDateTime > cast('1905-09-29' as date) -- must be 114 years or younger at the start of the study
		AND spat.BirthDateTime < cast('2004-09-29' as date)-- must be 18 years or older at the start of the study
	AND spat.Gender is not NULL-- no missing gender
	AND (spat.DeathDateTime IS NULL OR spat.DeathDateTime > cast('2019-09-30' as datetime2(0)))--deathDate is either missing or after beginning of study
	AND spat.veteranFlag = 'Y';--must be a veteran
--73,826,188
-- DATA CHECKS
--
select count(distinct ScrSSN) as scrssn_count, viz_fy, viz_qtr
from #outpat_encounters
group by viz_fy, viz_qtr
order by viz_fy, viz_qtr
--====----====----====
/*Step 2:
	-Create "mh_other_flag" for tracking encounters that aren't being categorized
	-Restrict to FY > 2018*/
--
drop table if exists #mh_codes;
--
select *
	, mh_other_flag = case when MH_CVT_FLAG <> 1 AND MH_F2F_FLAG <> 1 AND MH_SM_FLAG <> 1 AND MH_TELE_FLAG <> 1 AND MH_VVC_FLAG <> 1 then 1 else 0 end
into #mh_codes 
from #outpat_encounters
where viz_fy > 2018
--73,822,652
select count(*), primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
from #mh_codes
group by primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
order by count(*) desc
---===---===---===---===---===---===
/*Step 3:
	Output permanent table*/
drop table if exists /*[OABI_MyVAAccess].[crh_eval].*/#mh_psc_ssc_provType_counts;
--
select count(*) as psc_ssc_provType_count
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, provTypeCat
into /*[OABI_MyVAAccess].[crh_eval].*/#mh_psc_ssc_provType_counts
from #mh_codes
group by primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, provTypeCat;
--6,756
select top 100 * 
from #mh_psc_ssc_provType_counts
order by psc_ssc_provType_count desc;
--
select distinct primaryStopCode, pStopCodeName
from #mh_psc_ssc_provType_counts
where pStopCodeName like '%MENTAL HEALTH%' or pStopCodeName like '%MH%'