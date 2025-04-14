/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Timely Care

Adam J Batten
May 24, 2019
		Adapted by Bjarni Haraldsson, Spring, 2021
Details:
	Pull all timely care requests in the VA for the study period
Revision:
	-August 5th, 2021: added inner join with CRH sta5as in final step
	-October 13th, 2021: removed stopCode WHERE clause
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
declare @StartDate date 
	,@EndDate date;
set @StartDate =  CAST('2018-03-31' as datetime2);/*FY19, FY20, through FY21, with 6 months of lead time for rolling-average*/
set @EndDate = CAST('2022-01-01' as datetime2);
--==
drop table if exists #TimelyCareRequests;
--
select cohort.ScrSSN
	, a.AppointmentSID
	, a.sta3n
	, hcs.sta5a, hcs.Parent_Station_Sta5a
	, a.patientsid
	, a.appointmentdatetime
	, a.AppointmentMadeDate
	/* New patient logic*/
	, ISNULL(DesiredAppointmentDate, AppointmentMadeDate) AS DesiredAppointmentDate
	, a.[CheckOutDateTime]
	, loc.pStopCode_ as pStopCode
	, loc.pStopCodeName_ as pStopCodeName
	, loc.sStopCode_ as sStopCode
	, loc.sStopCodeName_ as sStopCodeName
	, cncl.CancellationReasonType
	/* Walk-in logic */
	, CASE
		WHEN a.SchedulingRequestType = 'W' OR PurposeOfVisit = '4' THEN 'W'
		WHEN AppointmentMadeDate = AppointmentDateTime
			AND AppointmentMadeDate = DesiredAppointmentDate
			AND (CheckInDateTime = AppointmentDateTime
				OR CheckOutDateTime = AppointmentDateTime)
		THEN 'W'
		ELSE 'N'
	END AS SchedulingRequestType
into #TimelyCareRequests
from [CDWWork].[Appt].Appointment as a
left join [CDWWork].[SPatient].SPatient as cohort
	on a.PatientSID = cohort.PatientSID
inner join [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode as loc
	on a.LocationSID = loc.LocationSID
left join [CDWWork].[Dim].CancellationReason as cncl
	on a.CancellationReasonSID = cncl.CancellationReasonSID
join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 AS hcs
	ON (hcs.sta5a = case
		when loc.Sta6a is not null OR loc.sta6a <> '*Missing*'
			then loc.sta6a
		else CAST(a.sta3n as varchar(5))
	end)
where (a.SchedulingRequestType in ('N', 'W') OR PurposeOfVisit = '4')
	AND ISNULL(DesiredAppointmentDate, AppointmentMadeDate) >= CONVERT(DATETIME, @StartDate, 102)
	AND ISNULL(DesiredAppointmentDate, AppointmentMadeDate) < CONVERT(DATETIME, @EndDate, 102)
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
	, a.appointmentdatetime
	, a.AppointmentMadeDate
	/* New patient logic*/
	, ISNULL(DesiredAppointmentDate, AppointmentMadeDate) AS DesiredAppointmentDate
	, a.[CheckOutDateTime]
	, loc.pStopCode_ as pStopCode
	, loc.pStopCodeName_ as pStopCodeName
	, loc.sStopCode_ as sStopCode
	, loc.sStopCodeName_ as sStopCodeName
	, cncl.CancellationReasonType
	/* Walk-in logic */
	, CASE
		WHEN a.SchedulingRequestType = 'W' OR PurposeOfVisit = '4' THEN 'W'
		WHEN AppointmentMadeDate = AppointmentDateTime
			AND AppointmentMadeDate = DesiredAppointmentDate
			AND (CheckInDateTime = AppointmentDateTime
				OR CheckOutDateTime = AppointmentDateTime)
		THEN 'W'
		ELSE 'N'
	END AS SchedulingRequestType
from [CDWWork].[Appt].Appointment as a
left join [CDWWork].[SPatient].SPatient as cohort
	on a.PatientSID = cohort.PatientSID
inner join [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode as loc
	on a.LocationSID = loc.LocationSID
left join [CDWWork].[Dim].CancellationReason as cncl
	on a.CancellationReasonSID = cncl.CancellationReasonSID
join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 AS hcs
	ON (hcs.sta5a = case
		when loc.Sta6a is not null OR loc.sta6a <> '*Missing*'
			then loc.sta6a
		else CAST(a.sta3n as varchar(5))
	end)
where (AppointmentMadeDate = CAST(AppointmentDateTime AS DATE)
		AND (CheckInDateTime = AppointmentDateTime
			OR CheckOutDateTime = AppointmentDateTime)
		AND (DesiredAppointmentDate is NULL
			OR AppointmentMadeDate = DesiredAppointmentDate))
	AND ISNULL(DesiredAppointmentDate, AppointmentMadeDate) >= CONVERT(DATETIME, @StartDate, 102)
	AND ISNULL(DesiredAppointmentDate, AppointmentMadeDate) < CONVERT(DATETIME, @EndDate, 102)
	AND loc.nonCountClinicFlag1 = 'N'
	and ((loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and loc.sStopCode_ is null) or
	(loc.pStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711) and
		loc.sStopCode_ not in (137,444,445,446,447,448,450))
		or loc.sStopCode_ in (322,323,338,341,342,348,350,702,704,705,709,711))
	AND CancellationReasonType = '*Missing*';-- i.e. rows without CancellationReasonType = "BOTH", "CLINIC", OR "PATIENT"
--13,266,558
--=========
-- Output permanent table of 1 row per 1 Unique ScrSSN-DesiredAppointmentDate-Sta5a
--=========
drop table if exists [OABI_MyVAAccess].[crh_eval].A_tc_reqs;
--
select distinct ScrSSN, sta5a, DATEFROMPARTS(year(DesiredAppointmentDate), month(DesiredAppointmentDate), '01') as request_month
	, DesiredAppointmentDate, pStopCode, pStopCodeName, sStopCode, sStopCodeName
into [OABI_MyVAAccess].[crh_eval].A_tc_reqs
from #TimelyCareRequests
--12,961,439
select top 100 * from [OABI_MyVAAccess].[crh_eval].A_tc_reqs
--
ALTER TABLE [OABI_MyVAAccess].[crh_eval].A_tc_reqs REBUILD WITH(DATA_COMPRESSION = ROW);