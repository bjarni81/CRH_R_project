/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Timely Care Report
Query timely care requests in Primary Care
VA Access to Care
Adam J Batten
May 24, 2019
-- adapted by Bjarni Haraldsson - Spring, 2021

Details:
Map the timely care request to the place of fulfillment


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
drop table if exists #unique_patSID_desiredDate;
--
SELECT distinct b.PatientSID
	, sta5a as sta5a_req
	, DATEADD(HOUR, 5, CAST(DesiredAppointmentDate AS DATETIME)) AS desiredappointmentdatetime--setting time of request to 5am; probably more reasonable than 00:00:01
into #unique_patSID_desiredDate
FROM [OABI_MyVAAccess].[crh_eval].A_tc_reqs  AS a
left join [CDWWork].[SPatient].SPatient as b
	on a.ScrSSN = b.ScrSSN
where DesiredAppointmentDate is not null
	and b.VeteranFlag = 'Y'-- limiting duplicates in SPat
	and b.CDWPossibleTestPatientFlag = 'N';-- limiting duplicates in SPat
--36618,466
---------
CREATE NONCLUSTERED INDEX [funny_idx_name]
ON #unique_patSID_desiredDate([PatientSID],[DesiredAppointmentDateTime])
GO
/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
VA Outpatient (toxic)
	Take the first visit in Outpat.Workload following PID
	Go out 6 days after last appointment date
Due to the size of the Workload tables this process may need to be
split into monthly queries depending on how many timely care
requests there are in TimelyCareReport.TimelyCareRequests or how long the
time period over which you are querying.
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
drop table if exists #getVOviz;
-- replace these with the  first month of your time period
declare @opStartDate date, @opEndDate date;
set @opStartDate =  CAST('2018-03-31' as datetime2);
set @opEndDate = CAST('2019-01-01' as datetime2);
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
inner join [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode as b
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
;--6,200,084
delete from #getVOviz where RN <> 1
--2,447,671
--select top 100 * from #getVOviz order by PatientSID, desiredappointmentdatetime, VisitDateTime;
--
--select * from [ORD_Augustine_202012038D].[Dflt].VAST_from_A06_11jan21 where sta5a like '402%';
/*==============================================================*/
--Step 2b: Same as above, but making it a procedure
/*==============================================================*/
DROP PROCEDURE if exists #sp_getVOviz;
--
GO
CREATE PROCEDURE #sp_getVOviz(@OpStartDate date, @OpEndDate date) AS
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
inner join [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode as b
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
--
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2019-01-02 00:00:00', @OpEndDate='2019-04-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--2 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2019-04-02 00:00:00', @OpEndDate='2019-07-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2019-07-02 00:00:00', @OpEndDate='2019-10-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--=,=--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2019-10-02 00:00:00', @OpEndDate='2020-01-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2020-01-02 00:00:00', @OpEndDate='2020-04-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--3 Months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2020-04-02 00:00:00', @OpEndDate='2020-07-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--540,542
--==--==--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2020-07-02 00:00:00', @OpEndDate='2020-10-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2020-10-02 00:00:00', @OpEndDate='2021-01-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--
--==--==--==--
--3 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2021-01-02 00:00:00', @OpEndDate='2021-04-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--674,066
--==--==--==--
--7 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2021-04-02 00:00:00', @OpEndDate='2021-10-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--1,264,211
--==--==--==--
--7 months
INSERT INTO #getVOviz
	EXECUTE #sp_getVOviz @OpStartDate='2021-10-02 00:00:00', @OpEndDate='2022-01-01 00:00:00';
--
delete from #getVOviz where RN <> 1;
--679,190
--==--==--==--
select count(*) from #getVOviz;
--17,143,208
select top 100 * from #getVOviz
--====
ALTER TABLE #getVOviz REBUILD WITH(DATA_COMPRESSION = ROW);
--
drop table if exists [OABI_MyVAAccess].[crh_eval].B1_getVOviz;
--
select *
into [OABI_MyVAAccess].[crh_eval].B1_getVOviz
from #getVOviz;
--17,143,208
ALTER TABLE [OABI_MyVAAccess].[crh_eval].B1_getVOviz REBUILD WITH(DATA_COMPRESSION = ROW);
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- VA Inpat
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
drop table if exists [OABI_MyVAAccess].[crh_eval].B2_getVInpat;
--
declare @ipStartDate date, @ipEndDate date;
set @ipStartDate =  CAST('2018-03-31' as datetime2);
set @ipEndDate = CAST('2022-01-01' as datetime2);
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
select distinct * into [OABI_MyVAAccess].[crh_eval].B2_getVInpat from FOO where RN = 1;
--161,722
ALTER TABLE [OABI_MyVAAccess].[crh_eval].B2_getVInpat REBUILD WITH(DATA_COMPRESSION = ROW);
--
select top 10 * from [OABI_MyVAAccess].[crh_eval].B2_getVInpat;

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
from [OABI_MyVAAccess].[crh_eval].B1_getVOviz
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
from [OABI_MyVAAccess].[crh_eval].B2_getVInpat
;--17,304,930
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
;--17,304,930
--
select top 100 * from #foo
where ScrSSN in(select ScrSSN from #foo where rn > 1)
order by ScrSSN, desiredappointmentdatetime, VisitDate, RN
--==============
--drop table if exists [OABI_MyVAAccess].[crh_eval].B1_getVOviz;
--
--drop table if exists [OABI_MyVAAccess].[crh_eval].B2_getVInpat;
--
drop table if exists [OABI_MyVAAccess].[crh_eval].B_seen;
--
select distinct * 
into [OABI_MyVAAccess].[crh_eval].B_seen 
from #foo where RN = 1
	AND DaysDV > -1
	AND DaysDV < 3;
--15,575,682
--
ALTER TABLE [OABI_MyVAAccess].[crh_eval].B_seen REBUILD WITH(DATA_COMPRESSION = ROW);
