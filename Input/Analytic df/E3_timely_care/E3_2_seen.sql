/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Timely Care: encounters that were seen within 2 days 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
drop table if exists #unique_patSID_desiredDate;
--
SELECT distinct b.PatientSID
	, sta5a as sta5a_req
	, DATEADD(HOUR, 5, CAST(DesiredAppointmentDateTime AS DATETIME)) AS desiredappointmentdatetime--setting time of request to 5am; probably more reasonable than 00:00:01
into #unique_patSID_desiredDate
FROM ##E3_tc_reqs  AS a
left join [CDWWork].[SPatient].SPatient as b
	on a.ScrSSN = b.ScrSSN
where DesiredAppointmentDateTime is not null
	and b.VeteranFlag = 'Y'-- limiting duplicates in SPat
	and b.CDWPossibleTestPatientFlag = 'N';-- limiting duplicates in SPat
--40,531,467
---------
CREATE NONCLUSTERED INDEX [funny_idx_name]
ON #unique_patSID_desiredDate([PatientSID],[DesiredAppointmentDateTime])
GO
/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Outpatient
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
drop table if exists #getVOviz;
-- replace these with the  first month of your time period
declare @opStartDate date, @opEndDate date;
set @opStartDate =  CAST('2020-03-31 00:00:00' as datetime2);
set @opEndDate = CAST('2020-08-31 23:59:59' as datetime2);
--==
select appt.PatientSID
	, appt.desiredappointmentdatetime
	, appt.sta5a_req
	, w.VisitSID, w.VisitDateTime, w.Sta3n AS WSta3n
	, b.Sta6a AS Wsta5a
	, DATEDIFF(DAY, desiredappointmentdatetime, w.VisitDateTime) AS DaysDV
	, ROW_NUMBER() over(partition by appt.PatientSID, DesiredAppointmentDateTime, CASE
		WHEN ((e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and f.stopcode is null) or
			(e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and
				f.stopcode not in (137,444,445,446,447,448,450))
				or f.stopcode in (322,323,338,341,342,348,350,702,704,705,709,711))
		THEN 'PC'
		WHEN ((e.StopCode in(502, 509, 510, 513, 534, 540, 562) AND
				(f.StopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999)
				OR f.StopCode is null))
			OR f.StopCode in(502, 509, 510, 513, 540, 562))
		THEN 'MH'
		WHEN e.StopCode = 130 then 'ED'
		when e.StopCode = 131 then 'UC'
		ELSE 'O'
	END order by w.visitDateTime) as RN
	, CASE
		WHEN ((e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and f.stopcode is null) or
			(e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and
				f.stopcode not in (137,444,445,446,447,448,450))
				or f.stopcode in (322,323,338,341,342,348,350,702,704,705,709,711))
		THEN 'PC'
		WHEN ((e.StopCode in(502, 509, 510, 513, 534, 540, 562) AND
				(f.StopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999)
				OR f.StopCode is null))
			OR f.StopCode in(502, 509, 510, 513, 540, 562))
		THEN 'MH'
		WHEN e.StopCode = 130 then 'ED'
		when e.StopCode = 131 then 'UC'
		ELSE 'O'
	END AS WStopType
	, e.stopCode as pStopCode
	, e.StopCodeName
	, wdx.ICD9SID, wdx.ICD10SID
	, dim9.ICD9Code AS PrimaryICD9Code
	, dim10.ICD10Code AS PrimaryICD10Code
into #getVOviz
from #unique_patSID_desiredDate AS appt
join [CDWWork].[Outpat].Workload AS w
	ON (appt.PatientSID = w.PatientSID)
inner join ##E3_0_LocationSID_to_StopCode as b
	on (w.LocationSID = b.LocationSID and w.Sta3n = b.sta3n)
left outer join CDWWork.Dim.StopCode as e
	on (b.PrimaryStopCodeSID = e.StopCodeSID)
left outer join CDWWork.Dim.StopCode as f
	on (b.SecondaryStopCodeSID = f.StopCodeSID)
left join [CDWWork].[Outpat].WorkloadVDiagnosis AS wdx
	ON (w.VisitSID = wdx.VisitSID)
left join CDWWork.Dim.ICD9 AS dim9
	ON (wdx.ICD9SID = dim9.ICD9SID)
left join CDWWork.Dim.ICD10 AS dim10
	ON (wdx.ICD10SID = dim10.ICD10SID)
where w.VisitDateTime >= @opStartDate AND w.VisitDateTime <= @opEndDate
	AND w.VisitDateTime >= desiredappointmentdatetime
	AND w.VisitDateTime <= DATEADD(DAY, 6, appt.desiredappointmentdatetime)
	AND (wdx.PrimarySecondary = 'P' OR wdx.PrimarySecondary is null)
;--
delete from #getVOviz where RN <> 1
--
select count(*) from #getVOviz
--1,398,881
--select top 100 * from #getVOviz order by PatientSID, desiredappointmentdatetime, VisitDateTime;
--
--select * from [ORD_Augustine_202012038D].[Dflt].VAST_from_A06_11jan21 where sta5a like '402%';
/*==============================================================*/
--Step 2b: Same as above, but making it a procedure
/*==============================================================*/
DROP PROCEDURE if exists #sp_getVOviz;
--
GO
CREATE PROCEDURE #sp_getVOviz(@OpStartDate datetime, @OpEndDate datetime) AS
--==
select appt.PatientSID
	, appt.desiredappointmentdatetime
	, appt.sta5a_req
	, w.VisitSID, w.VisitDateTime, w.Sta3n AS WSta3n
	, b.Sta6a AS Wsta5a
	, DATEDIFF(DAY, desiredappointmentdatetime, w.VisitDateTime) AS DaysDV
	, ROW_NUMBER() over(partition by appt.PatientSID, DesiredAppointmentDateTime, CASE
		WHEN ((e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and f.stopcode is null) or
			(e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and
				f.stopcode not in (137,444,445,446,447,448,450))
				or f.stopcode in (322,323,338,341,342,348,350,702,704,705,709,711))
		THEN 'PC'
		WHEN ((e.StopCode in(502, 509, 510, 513, 534, 540, 562) AND
				(f.StopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999)
				OR f.StopCode is null))
			OR f.StopCode in(502, 509, 510, 513, 540, 562))
		THEN 'MH'
		WHEN e.StopCode = 130 then 'ED'
		when e.StopCode = 131 then 'UC'
		ELSE 'O'
	END order by w.visitDateTime) as RN
	, CASE
		WHEN ((e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and f.stopcode is null) or
			(e.StopCode in (322,323,338,341,342,348,350,702,704,705,709,711) and
				f.stopcode not in (137,444,445,446,447,448,450))
				or f.stopcode in (322,323,338,341,342,348,350,702,704,705,709,711))
		THEN 'PC'
		WHEN ((e.StopCode in(502, 509, 510, 513, 534, 540, 562) AND
				(f.StopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999)
				OR f.StopCode is null))
			OR f.StopCode in(502, 509, 510, 513, 540, 562))
		THEN 'MH'
		WHEN e.StopCode = 130 then 'ED'
		when e.StopCode = 131 then 'UC'
		ELSE 'O'
	END AS WStopType
	, e.stopCode as pStopCode
	, e.StopCodeName
	, wdx.ICD9SID, wdx.ICD10SID
	, dim9.ICD9Code AS PrimaryICD9Code
	, dim10.ICD10Code AS PrimaryICD10Code
from #unique_patSID_desiredDate AS appt
join [CDWWork].[Outpat].Workload AS w
	ON (appt.PatientSID = w.PatientSID)
inner join ##E3_0_LocationSID_to_StopCode as b
	on (w.LocationSID = b.LocationSID and w.Sta3n = b.sta3n)
left outer join CDWWork.Dim.StopCode as e
	on (b.PrimaryStopCodeSID = e.StopCodeSID)
left outer join CDWWork.Dim.StopCode as f
	on (b.SecondaryStopCodeSID = f.StopCodeSID)
left join [CDWWork].[Outpat].WorkloadVDiagnosis AS wdx
	ON (w.VisitSID = wdx.VisitSID)
left join CDWWork.Dim.ICD9 AS dim9
	ON (wdx.ICD9SID = dim9.ICD9SID)
left join CDWWork.Dim.ICD10 AS dim10
	ON (wdx.ICD10SID = dim10.ICD10SID)
where w.VisitDateTime >= @opStartDate AND w.VisitDateTime <= @opEndDate
	AND w.VisitDateTime >= desiredappointmentdatetime
	AND w.VisitDateTime <= DATEADD(DAY, 6, appt.desiredappointmentdatetime)
	AND (wdx.PrimarySecondary = 'P' OR wdx.PrimarySecondary is null)
GO
/*==============================================================*/
--Step 2c: Inserting date ranges into the table with the procedure created above
/*==============================================================*/
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2020-09-01 00:00:00', @OpEndDate='2020-12-31 23:59:59';
--
delete from #getVOviz where RN <> 1;
--
--2,779,792
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2021-01-01 00:00:00', @OpEndDate='2021-06-30 23:59:59';
--
delete from #getVOviz where RN <> 1;
--4,763,724
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2021-07-01 00:00:00', @OpEndDate='2021-12-31 23:59:59';
--
delete from #getVOviz where RN <> 1;
--6,891,350
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2022-01-01 00:00:00', @OpEndDate='2022-12-31 23:59:59';
--
delete from #getVOviz where RN <> 1;
--10,512,402
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2023-01-01 00:00:00', @OpEndDate='2023-12-31 23:59:59';
--
delete from #getVOviz where RN <> 1;
--13,973,919
--==--==--==--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2024-01-01 00:00:00', @OpEndDate='2024-09-30 23:59:59';
--
delete from #getVOviz where RN <> 1;
select max(VisitDateTime) as maxVizDt, count(*) as total from #getVOviz
--16,696,310
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- VA Inpat
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
drop table if exists #E3_3_getVInpat;
--
declare @ipStartDate date, @ipEndDate date;
set @ipStartDate =  CAST('2020-03-31' as datetime2);
set @ipEndDate = CAST('2024-10-01' as datetime2);
--
WITH FOO AS (
	select appt.PatientSID 
		, desiredappointmentdatetime
		, w.InpatientSID, w.AdmitDateTime
		, CASE
			WHEN w.AdmitDateTime <= desiredappointmentdatetime AND w.DischargeDateTime >= desiredappointmentdatetime
			THEN 0
			ELSE DATEDIFF(DAY, desiredappointmentdatetime, w.AdmitDateTime)
		END AS DaysDV
		, ROW_NUMBER() OVER (
			PARTITION BY appt.PatientSID, desiredappointmentdatetime
			ORDER BY w.AdmitDateTime, w.InpatientSID
		) AS RN
		, wdx.ICD9SID, wdx.ICD10SID
		, dim9.ICD9Code AS PrimaryICD9Code
		, dim10.ICD10Code AS PrimaryICD10Code
	from #unique_patSID_desiredDate AS appt
	join [CDWWork].[Inpat].Inpatient AS w
		ON (appt.PatientSID = w.PatientSID)
	left join [CDWWork].[Inpat].InpatientDiagnosis AS wdx
		ON (w.InpatientSID = wdx.InpatientSID)
	left join [CDWWork].[Dim].ICD9 AS dim9
		ON (wdx.ICD9SID = dim9.ICD9SID)
	left join [CDWWork].[Dim].ICD10 AS dim10
		ON (wdx.ICD10SID = dim10.ICD10SID)
	where w.InpatientSID > 0 AND w.AdmitDateTime >= @ipStartDate AND w.AdmitDateTime < @ipEndDate
		AND
		(
			(w.AdmitDateTime >= desiredappointmentdatetime
				AND w.AdmitDateTime <= DATEADD(DAY, 6, desiredappointmentdatetime))
			OR (w.AdmitDateTime <= desiredappointmentdatetime
				AND (w.DischargeDateTime >= desiredappointmentdatetime
					OR w.DischargeDateTime is NULL))
		)
		AND (wdx.OrdinalNumber = 1 OR wdx.OrdinalNumber IS NULL)
)
select distinct * into #E3_3_getVInpat from FOO where RN = 1;
--155,933
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Combine
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
drop table if exists #seen;
-- VA Opat
select distinct PatientSID
	, desiredappointmentdatetime
	, CAST(VisitDateTime AS DATE) AS VisitDate
	, VisitDateTime as vizDT
	, pStopCode
	, StopCodeName as pStopCodeName
	, DATEDIFF(HOUR, desiredappointmentdatetime, VisitDateTime) as hoursDV
	, DaysDV
	, WSta3n, Wsta5a, WStopType
	, 'VAO' AS HCS
into #seen
from #getVOviz
UNION
select distinct PatientSID
	, desiredappointmentdatetime
	, CAST(AdmitDateTime AS DATE) AS VisitDate
	, AdmitDateTime as vizDT
	, NULL as pStopCode
	, NULL as pStopCodeName
	, DATEDIFF(HOUR, desiredappointmentdatetime, AdmitDateTime) as hoursDV
	, DaysDV
	, NULL AS WSta3n, 'VI' AS Wsta5a, 'VI' AS WStopType
	, 'VAI' AS HCS
from #E3_3_getVInpat
;--16,852,243
select top 10 * from #seen;
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Row_number to get 1 row per request & fulfillment
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
drop table if exists #foo;
--
select distinct b.ScrSSN
	, desiredappointmentdatetime
	, VisitDate
	, vizDT
	, WSta3n, Wsta5a, WStopType
	, DaysDV
	, hoursDV
	, HCS
	, pStopCode
	, pStopCodeName
	, ROW_NUMBER() OVER (
		PARTITION BY b.ScrSSN, DesiredAppointmentDatetime, wStopType
		ORDER BY hoursDV
	) AS RN
into #foo
from #seen as a
left join [CDWWork].[SPatient].SPatient as b
on a.PatientSID = b.PatientSID
where b.CDWPossibleTestPatientFlag = 'N'
	and b.VeteranFlag = 'Y';
;--16,852,243
--
select top 100 * from #foo
where ScrSSN in(select ScrSSN from #foo where rn > 1)
order by ScrSSN, desiredappointmentdatetime, VisitDate, RN
--==============
--
drop table if exists /*[OABI_MyVAAccess].[crh_eval].*/##E3_2_seen;
--
select distinct * 
into /*[OABI_MyVAAccess].[crh_eval].*/##E3_2_seen 
from #foo where RN = 1
	AND DaysDV > -1
	AND DaysDV < 3;
--14,994,655
--
