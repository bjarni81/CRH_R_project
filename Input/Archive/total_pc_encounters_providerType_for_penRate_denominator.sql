/*
Pulling all encounters with a 300-series primary OR secondary stop code
	-categorizing by ProviderType: provTypeCat
	-flagging whether they belong to the original subset of encounters: pc_crh_flag
*/
drop table if exists #provType;
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
	, provType.ProviderType
	, provTypeCat = case /*per HSRD ListServ: https://vaww.listserv.va.gov/scripts/wa.exe?A2=HSRDATA-L;fcf74357.2111&S= */
						when providertype in ('Allopathic & Osteopathic Physicians','Physicians (M.D. and D.O.)','Physicians (Other Roles)','Physician')
							then 'MD/DO'
						when providertype in ('Psychology','Behavioral Health & Social Service Providers','Behavioral Health and Social Service')
							then 'Psychologist, Behavioral Health, Social Service'
						when providertype in ('Physician Assistants & Advanced Practice Nursing Providers')
							then 'PA/APN'
						when providertype in ('Nursing Service','Nursing Service Providers','Nursing Service Related Providers')
							then 'Nursing Service & Related'
						when providertype in ('Pharmacy Service','Pharmacy Service Providers')
							then 'Pharmacy Service'
						else 'Other' end
	, pc_type_flag = CASE 
		WHEN (PSC.StopCode IN(338, 103, 326, 178, 182, 147, 224, 324, 528, 530)) THEN 'Telephone'
		WHEN (SSC.StopCode = 179) THEN 'VVC'
		WHEN (SSC.StopCode IN(690, 692, 693)) THEN 'CVT'
		WHEN (SSC.StopCode = 719) THEN 'Secure Message'
		ELSE 'In-Person'
		END
	, vaccine_flag = case
		when ssc.StopCode = 710 then 1 else 0 end
into #provType
from [CDWWork].[Outpat].Workload as a
left join [CDWWork].[Dim].StopCode as psc
	on a.PrimaryStopCodeSID = psc.StopCodeSID
left join [CDWWork].[Dim].StopCode as ssc
	on a.SecondaryStopCodeSID = ssc.StopCodeSID
left join [CDWWork].[SPatient].SPatient as spat
	on a.PatientSID = spat.PatientSID
left join [CDWWork].[Dim].Division as div
	on a.DivisionSID = div.DivisionSID
left join [CDWWork].[Outpat].WorkloadVProvider as wkProv
	on a.VisitSID = wkProv.VisitSID
left join [CDWWork].[Dim].ProviderType as provType
	on wkProv.ProviderTypeSID = provType.ProviderTypeSID
where a.visitdatetime > cast('2018-09-30' as datetime2) 
	AND a.VisitDateTime < cast('2022-01-01' as datetime2)
	AND ((psc.StopCode IN(322, 323, 338, 348, 350, 704) 
			AND (ssc.StopCode NOT IN(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474
																				, /*NOTE could exclude 710 - VACCINE*/ 999)
				OR ssc.StopCode IS NULL))
		OR ssc.StopCode IN(322, 323, 348, 350, 704));
--89,583,377
select count(*), cast(count(*) as float) / cast(62367341 as float) as prop, primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
from #provType
group by primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
order by count(*) desc;
--
select count(*), pc_type_flag
from #provType
group by pc_type_flag;
--
select count(*), primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
from #provType
where pc_type_flag = 'CVT'
group by primaryStopCode, pStopCodeName, secondaryStopCode, sStopCodeName
order by count(*) desc;
--
select sum(vaccine_flag) as vax_sum
	, count(*)
from #provType
/*===============================================*/
-- Outputting ScrSSN and total encounter counts by sta6a-month
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month;
--
select count(distinct ScrSSN) as scrssn_count
	, count(*) as pc_encounter_total
	, visitMonth
	, Sta6a
into [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month
from #provType
group by visitMonth
	, Sta6a;
--42,641
--
/*===============================================*/
-- Outputting ScrSSN and total encounter counts by sta6a-month
-- NO VACCINES
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month_noVax;
--
select count(distinct ScrSSN) as scrssn_count
	, count(*) as pc_encounter_total
	, visitMonth
	, Sta6a
into [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month_noVax
from #provType
where vaccine_flag = 0
group by visitMonth
	, Sta6a;
--42,599
/*===============================================*/
-- Outputting ScrSSN and total encounter counts by sta6a-quarter
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr;
--
select count(distinct ScrSSN) as scrssn_count
	, count(*) as pc_encounter_total
	, fy, qtr
	, Sta6a
into [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr
from #provType
group by fy, qtr
	, Sta6a;
--14,372
/*===============================================*/
-- Outputting ScrSSN and total encounter counts by sta6a-quarter
-- NO VACCINES
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr_noVax;
--
select count(distinct ScrSSN) as scrssn_count
	, count(*) as pc_encounter_total
	, fy, qtr
	, Sta6a
into [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr_noVax
from #provType
where vaccine_flag = 0
group by fy, qtr
	, Sta6a;
--14,347
/*===============================================*/
-- Outputting encounter counts by modality and sta6a-quarter
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_by_type_qtr;
--
select count(*) as pc_type_count, pc_type_flag
	, fy, qtr, Sta6a
into [OABI_MyVAAccess].[crh_eval].pc_enc_by_type_qtr
from #provType
group by pc_type_flag, fy, qtr, Sta6a;
--50,186
select *
from #pc_enc_by_type_qtr
where Sta6a = '636A8' AND fy = 2021 AND qtr = 4
/*===============================================*/
-- Outputting encounter counts by modality and sta6a-month
drop table if exists [OABI_MyVAAccess].[crh_eval].pc_enc_by_type_month;
--
select count(*) as pc_type_count, pc_type_flag
	, sta6a, visitMonth
into [OABI_MyVAAccess].[crh_eval].pc_enc_by_type_month
from #provType
group by pc_type_flag, Sta6a, visitMonth;
--139,569
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Old code for outputting counts by PSC, SSC, and ProviderType*/
--Primary Stop Code X Secondary Stop Code
drop table if exists [OABI_MyVAAccess].[crh_eval].psc_ssc;
--
select count(*) as psc_ssc_count
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
into [OABI_MyVAAccess].[crh_eval].psc_ssc
from #provType
group by primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName;
--464
select *
from [OABI_MyVAAccess].[crh_eval].psc_ssc
order by psc_ssc_count desc
/*===============================================*/
--Provider type X PSC/SSC
drop table if exists [OABI_MyVAAccess].[crh_eval].provType_psc_ssc;
--
select count(*) as provType_psc_ssc_count
	, provTypeCat
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
into [OABI_MyVAAccess].[crh_eval].provType_psc_ssc
from #provType
group by provTypeCat
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName;
--1,887
select *
from [OABI_MyVAAccess].[crh_eval].provType_psc_ssc
order by provType_psc_ssc_count desc
--=============================================================
--sta6a, visitMonth, provType, & PSC/SSC
drop table if exists [OABI_MyVAAccess].[crh_eval].provType_psc_ssc_sta5a_month_count;
--
select count(*) as provType_psc_ssc_count
	, Sta6a, visitMonth
	, provTypeCat
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
into [OABI_MyVAAccess].[crh_eval].provType_psc_ssc_sta5a_month_count
from #provType
group by Sta6a, visitMonth
	, provTypeCat
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName;
--837,310
--
select *
from [OABI_MyVAAccess].[crh_eval].provType_psc_ssc_count
where sta6a = '636A8' and provTypeCat = 'MD/DO'
order by visitMonth, provTypeCat