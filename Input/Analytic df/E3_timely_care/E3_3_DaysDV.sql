/*
Calculating a sta5a-level rolling 6-month average TimelyCare success proportion
*/
--
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 1: Lookup table of unique patientSID-desiredAppointmentDateTime combinations
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
/*Step 1a: Unique ScrSSN & DesiredAppointmentDate(Time set to 05:00), and setting a flag to identify ED visits*/
--==
drop table if exists #unique_patSID_desiredDate;
--
SELECT distinct a.ScrSSN, a.sta5a as req_sta5a
	, DATEADD(HOUR, 5, CAST(DesiredAppointmentDateTime AS DATETIME)) AS desiredappointmentdatetime--setting time of request to 5am; probably more reasonable than 00:00:01
into #unique_patSID_desiredDate
FROM /*[OABI_MyVAAccess].[crh_eval].*/##E3_tc_reqs  AS a
where DesiredAppointmentDateTime is not null;
--12,618,753
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 2: Unique ScrSSN-DesiredAppointmentDate-visitDate combinations
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
drop table if exists #seen;
--
select distinct ScrSSN
	, desiredappointmentDateTime
	, wSta5a 
	, wStopType
	, DaysDV
	, pStopCode, pStopCodeName
into #seen
from /*[OABI_MyVAAccess].[crh_eval].*/##E3_2_seen;
--14,994,655
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 3: Join TimelyCare requests with first next encounter
		-- This yields 1 row per desiredAppointmentDate-ScrSSN-DaysDV combination (where DaysDV is the smallest possible for that desiredAppointmentDate-ScrSSN combination)
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--=================
/*Step 3a: Join the tables*/
--=================
drop table if exists #daysDV;
--
select distinct req.ScrSSN
	, req.req_sta5a
	, req.desiredAppointmentDateTime
	, seen.wSta5a
	, seen.wStopType
	, seen.daysDV
into #daysDV
from #unique_patSID_desiredDate as req
left join #seen as seen
	on req.ScrSSN = seen.ScrSSN
		AND req.desiredappointmentdatetime = seen.desiredappointmentdatetime;
--17,563,194
--=================
/*Step 3b: de-duplicate on ScrSSN-desiredAppointmentDate, req_sta5a, and DaysDV*/
--=================
drop table if exists #foo;
--
select ScrSSN
	, desiredappointmentdatetime
	, req_sta5a
	, DaysDV
	, ED_flag = case when sum(case when wStopType = 'ED' then 1 else 0 end) > 0 then 1 else 0 end
	, MH_flag = case when sum(case when wStopType = 'MH' then 1 else 0 end) > 0 then 1 else 0 end
	, PC_flag = case when sum(case when wStopType = 'PC' then 1 else 0 end) > 0 then 1 else 0 end
	, UC_flag = case when sum(case when wStopType = 'UC' then 1 else 0 end) > 0 then 1 else 0 end
	, O_flag = case when sum(case when wStopType = 'O' then 1 else 0 end) > 0 then 1 else 0 end
	, VI_flag = case when sum(case when wStopType = 'VI' then 1 else 0 end) > 0 then 1 else 0 end
into #foo
from #daysDV
group by ScrSSN
	, desiredappointmentdatetime
	, req_sta5a
	, DaysDV
--13,600,611
select top 100 * from #foo
where ED_flag = 0 and MH_flag = 0 and PC_flag = 0 and UC_flag = 0 and O_flag = 0 and VI_flag = 0;
--=================
/*Step 3c: Output DaysDV table*/
--=================
drop table if exists #E3_3_DaysDV;
--
select ScrSSN
	, desiredappointmentdatetime
	, req_sta5a
	, timelyCare_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND (ED_flag = 1 OR MH_flag = 1 OR PC_flag = 1 OR UC_flag = 1 OR O_flag = 1 OR VI_flag = 1) then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_PC_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND PC_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_ED_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND ED_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_MH_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND MH_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_UC_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND UC_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_O_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND O_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
	, timelyCare_VI_success = 
		case when sum(case when (DaysDV < 2 AND DaysDV is NOT NULL) 
						AND VI_flag = 1 then 1 else 0 end) > 0 then 1 else 0 end
into #E3_3_DaysDV
from #foo
group by ScrSSN, desiredappointmentdatetime, req_sta5a;
--12,618,753
--=================
-- DATA CHECKS
select top 100 * from #E3_3_DaysDV
--
select count(*), DATENAME(WEEKDAY, desiredAppointmentDateTime)
from #E3_3_DaysDV
where DATENAME(WEEKDAY, desiredAppointmentDateTime) in('Friday', 'Saturday','Sunday')
group by DATENAME(WEEKDAY, desiredAppointmentDateTime)
order by count(*);
--
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 4: Rolling 6-Month Average TimelyCare Success %
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--=================
/*Step 4a: Summarize the proportion of timelyCare requests that are fulfilled to the sta5a-month
		-- This is also where we catch those people who made requests on Fridays or Saturdays*/
--=================
drop table if exists #monthly_daysDV;
--
select count(*) as tc_requests_sum
	, sum(timelyCare_success) as tc_success_sum
	, sum(timelyCare_PC_success) as tc_pc_success_sum
	, sum(cast(timelyCare_PC_success as float)) / cast(count(*) as float) as tc_pc_success_prop
	, sum(cast(timelyCare_success as float)) / cast(count(*) as float) as tc_success_prop
	, DATEFROMPARTS(year(desiredAppointmentDateTime), month(desiredAppointmentDateTime), '01') as viz_month
	, req_sta5a
into #monthly_daysDV
from #E3_3_DaysDV
where req_sta5a IS NOT NULL--requiring that req_sta5a not be missing; could do inner-join with VAST
group by req_sta5a, DATEFROMPARTS(year(desiredAppointmentDateTime), month(desiredAppointmentDateTime), '01')
order by DATEFROMPARTS(year(desiredAppointmentDateTime), month(desiredAppointmentDateTime), '01'), req_sta5a;
--
select top 100 * from #monthly_daysDV
--=================
/*Step 4b: Calculate rolling 6-month average and output permanent table*/
--=================
drop table if exists [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a;
--
select req_sta5a
	, viz_month
	, viz_fy = case 
		when month(viz_month) in (10, 11, 12) then YEAR(viz_month) + 1
		else YEAR(viz_month) end
	, viz_qtr = case 
		when month(viz_month) in (10, 11, 12) then 1
		when month(viz_month) in (1, 2, 3) then 2
		when month(viz_month) in (4, 5, 6) then 3
		when month(viz_month) in (7, 8, 9) then 4
		else NULL end
	, tc_requests_sum
	, tc_success_sum
	, tc_pc_success_sum
	, tc_success_prop
	, AVG(tc_pc_success_prop) OVER(partition by req_sta5a order by viz_month rows 6 preceding) as tc_pc_success_6mo_avg
	, AVG(tc_success_prop) OVER(partition by req_sta5a order by viz_month rows 6 preceding) as tc_success_6mo_avg
into [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a
from #monthly_daysDV;
--57,642
select top 100 * from [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a
--========
drop table if exists [OABI_MyVAAccess].[crh_eval].E3_0_LocationSID_to_StopCode;
--
drop table if exists ##E3_tc_reqs;
--
drop table if exists ##E3_2_seen;
