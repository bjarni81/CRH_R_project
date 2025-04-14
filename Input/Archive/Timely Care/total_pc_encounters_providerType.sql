/*
Pulling all encounters with a 300-series primary OR secondary stop code
	-categorizing by ProviderType: provTypeCat
	-flagging whether they belong to the original subset of encounters: pc_crh_flag
*/
drop table if exists #provType;
--
select visitDate = cast(a.VisitDateTime as date)
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
	, pc_crh_flag = case when (psc.StopCode in (156, 176, 177, 178, 301, 322, 323, 338, 348) 
					AND (ssc.StopCode not in(160, 534, 539) OR ssc.StopCode IS NULL)) 
				OR (psc.StopCode not in(160, 534, 539) 
					AND ssc.StopCode in (156, 176, 177, 178, 301, 322, 323, 338, 348)) then 1 else 0 end
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
where a.visitdatetime > cast('2019-09-30' as datetime2) 
	AND a.VisitDateTime < cast('2022-01-01' as datetime2)
	AND ((psc.StopCode > 299 AND psc.StopCode < 400 AND ssc.StopCode <> 710/*710 = PREVENTIVE IMMUNIZATION*/) 
		OR (ssc.StopCode > 299 AND ssc.StopCode < 400))
--67,353,247
/*Output permanent table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].psc_ssc_provType_counts;
--
select count(*) as psc_ssc_provType_count
	, primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, provTypeCat
into [OABI_MyVAAccess].[crh_eval].psc_ssc_provType_counts
from #provType
group by primaryStopCode, pStopCodeName
	, secondaryStopCode, sStopCodeName
	, provTypeCat
--8,485