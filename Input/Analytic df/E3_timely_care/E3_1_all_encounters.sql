/* 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Timely Care
*/
declare @StartDate date 
	,@EndDate date;
set @StartDate =  CAST('2020-03-31' as datetime2);
set @EndDate = CAST('2024-10-01' as datetime2);
--==
drop table if exists #TimelyCareRequests;
--
select cohort.ScrSSN
	, a.AppointmentSID
	, a.sta3n
	, hcs.sta5a, hcs.Parent_Station_Sta5a
	, a.patientsid
	, a.appointmentDateTime
	, a.AppointmentMadeDateTime
	/* New patient logic*/
	, ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) AS DesiredAppointmentDateTime
	, a.[CheckOutDateTime]
	, loc.pStopCode_ as pStopCode
	, loc.pStopCodeName_ as pStopCodeName
	, loc.sStopCode_ as sStopCode
	, loc.sStopCodeName_ as sStopCodeName
	, cncl.CancellationReasonType
	/* Walk-in logic */
	, CASE
		WHEN a.SchedulingRequestType = 'W' OR PurposeOfVisit = '4' THEN 'W'
		WHEN AppointmentMadeDateTime = AppointmentDateTime
			AND AppointmentMadeDateTime = DesiredAppointmentDateTime
			AND (CheckInDateTime = AppointmentDateTime
				OR CheckOutDateTime = AppointmentDateTime)
		THEN 'W'
		ELSE 'N'
	END AS SchedulingRequestType
into #TimelyCareRequests
from [CDWWork].[Appt].Appointment as a
left join [CDWWork].[SPatient].SPatient as cohort
	on a.PatientSID = cohort.PatientSID
inner join ##E3_0_LocationSID_to_StopCode as loc
	on a.LocationSID = loc.LocationSID
left join [CDWWork].[Dim].CancellationReason as cncl
	on a.CancellationReasonSID = cncl.CancellationReasonSID
join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 AS hcs
	ON (hcs.sta5a = case
		when loc.Sta6a is not null OR loc.sta6a <> '*Missing*'
			then loc.sta6a
		else CAST(a.sta3n as varchar(5))
	end)
where (a.SchedulingRequestType in ('N', 'W') OR PurposeOfVisit = '4')
	AND ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) >= CONVERT(DateTime, @StartDate, 102)
	AND ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) < CONVERT(DateTime, @EndDate, 102)
	AND loc.nonCountClinicFlag1 = 'N'
	and ((loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and loc.sStopCode_ is null) or
	(loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and
		loc.sStopCode_ not in (137,444,445,446,447,448,450))
		or loc.sStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711))
UNION
select cohort.ScrSSN
	, a.AppointmentSID
	, a.sta3n
	, hcs.sta5a, hcs.Parent_Station_Sta5a
	, a.patientsid
	, a.appointmentDateTime
	, a.AppointmentMadeDateTime
	/* New patient logic*/
	, ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) AS DesiredAppointmentDateTime
	, a.[CheckOutDateTime]
	, loc.pStopCode_ as pStopCode
	, loc.pStopCodeName_ as pStopCodeName
	, loc.sStopCode_ as sStopCode
	, loc.sStopCodeName_ as sStopCodeName
	, cncl.CancellationReasonType
	/* Walk-in logic */
	, CASE
		WHEN a.SchedulingRequestType = 'W' OR PurposeOfVisit = '4' THEN 'W'
		WHEN AppointmentMadeDateTime = AppointmentDateTime
			AND AppointmentMadeDateTime = DesiredAppointmentDateTime
			AND (CheckInDateTime = AppointmentDateTime
				OR CheckOutDateTime = AppointmentDateTime)
		THEN 'W'
		ELSE 'N'
	END AS SchedulingRequestType
from [CDWWork].[Appt].Appointment as a
left join [CDWWork].[SPatient].SPatient as cohort
	on a.PatientSID = cohort.PatientSID
inner join ##E3_0_LocationSID_to_StopCode as loc
	on a.LocationSID = loc.LocationSID
left join [CDWWork].[Dim].CancellationReason as cncl
	on a.CancellationReasonSID = cncl.CancellationReasonSID
join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 AS hcs
	ON (hcs.sta5a = case
		when loc.Sta6a is not null OR loc.sta6a <> '*Missing*'
			then loc.sta6a
		else CAST(a.sta3n as varchar(5))
	end)
where (AppointmentMadeDateTime = CAST(AppointmentDateTime AS DateTime)
		AND (CheckInDateTime = AppointmentDateTime
			OR CheckOutDateTime = AppointmentDateTime)
		AND (DesiredAppointmentDateTime is NULL
			OR AppointmentMadeDateTime = DesiredAppointmentDateTime))
	AND ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) >= CONVERT(DateTime, @StartDate, 102)
	AND ISNULL(DesiredAppointmentDateTime, AppointmentMadeDateTime) < CONVERT(DateTime, @EndDate, 102)
	AND loc.nonCountClinicFlag1 = 'N'
	and ((loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and loc.sStopCode_ is null) or
	(loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and
		loc.sStopCode_ not in (137,444,445,446,447,448,450))
		or loc.sStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711))
	AND CancellationReasonType = '*Missing*';-- i.e. rows without CancellationReasonType = "BOTH", "CLINIC", OR "PATIENT"
--13,524,978
--=========
-- Output global temp table with 1 row per 1 Unique ScrSSN-DesiredAppointmentDate-Sta5a
--=========
drop table if exists /*[OABI_MyVAAccess].[crh_eval].*/##E3_tc_reqs;
--
select distinct ScrSSN, sta5a, DATEFROMPARTS(year(DesiredAppointmentDateTime), month(DesiredAppointmentDateTime), '01') as request_month
	, DesiredAppointmentDateTime, pStopCode, pStopCodeName, sStopCode, sStopCodeName
into /*[OABI_MyVAAccess].[crh_eval].*/##E3_tc_reqs
from #TimelyCareRequests
--13,193,539