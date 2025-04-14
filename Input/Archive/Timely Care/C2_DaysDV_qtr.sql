--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 4: Rolling 6-Month Average TimelyCare Success %
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--Step 40: create FY and Qtr variables
drop table if exists #C_days_qtr_1;
--
select *
	, fy = case
		when month(desiredappointmentdatetime) > 9 then year(desiredAppointmentDateTime) + 1
		else year(desiredAppointmentDateTime) end
	, qtr = case
		when month(desiredappointmentdatetime) in(10, 11, 12) then 1
		when month(desiredappointmentdatetime) in(1, 2, 3) then 2
		when month(desiredappointmentdatetime) in(4, 5, 6) then 3
		when month(desiredappointmentdatetime) in(7, 8, 9) then 4 end
into #C_days_qtr_1
from [OABI_MyVAAccess].[crh_eval].C_daysDV
--==
drop table if exists #C_days_qtr;
--
select *
	, fy_qtr = CONCAT(fy, '_', qtr)
into #C_days_qtr
from #C_days_qtr_1
--=================
/*Step 4a: Summarise the proportion of timelyCare requests that are fulfilled to the sta5a-month
		-- This is also where we catch those people who made requests on Fridays or Saturdays*/
--=================
--
drop table if exists #qtrly_daysDV;
--
select count(*) as tc_requests_sum
	, sum(timelyCare_success) as tc_success_sum
	, sum(timelyCare_PC_success) as tc_pc_success_sum
	, sum(cast(timelyCare_PC_success as float)) / cast(count(*) as float) as tc_pc_success_prop
	, sum(cast(timelyCare_success as float)) / cast(count(*) as float) as tc_success_prop
	, fy_qtr
	, req_sta5a
into #qtrly_daysDV
from #C_days_qtr
where req_sta5a IS NOT NULL--requiring that req_sta5a not be missing; could do inner-join with VAST
group by req_sta5a, fy_qtr;
--15,155
--=================
/*Step 4b: Output permanent table*/
--=================
drop table if exists [OABI_MyVAAccess].[crh_eval].C1_daysDV_qtr_sta5a;
--
select req_sta5a
	, fy_qtr
	, tc_requests_sum
	, tc_success_sum
	, tc_pc_success_sum
	, tc_success_prop
	, AVG(tc_pc_success_prop) OVER(partition by req_sta5a order by fy_qtr rows 2 preceding) as tc_pc_success_6mo_avg
	, AVG(tc_success_prop) OVER(partition by req_sta5a order by fy_qtr rows 2 preceding) as tc_success_6mo_avg
into [OABI_MyVAAccess].[crh_eval].C1_daysDV_qtr_sta5a
from #qtrly_daysDV;
--15,155
select top 100 * from [OABI_MyVAAccess].[crh_eval].C1_daysDV_qtr_sta5a
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 5: Rolling 6-Month Average TimelyCare Success % - parent station
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--=================
/*Step 5a: Summarise the proportion of timelyCare requests that are fulfilled to the sta5a-month
		-- This is also where we catch those people who made requests on Fridays or Saturdays*/
--=================
drop table if exists #qtr_daysDV_parent;
--
select count(*) as tc_requests_sum
	, sum(timelyCare_success) as tc_success_sum
	, sum(timelyCare_PC_success) as tc_pc_success_sum
	, sum(cast(timelyCare_PC_success as float)) / cast(count(*) as float) as tc_pc_success_prop
	, sum(cast(timelyCare_success as float)) / cast(count(*) as float) as tc_success_prop
	, fy_qtr
	, b.parent_station_sta5a
into #qtr_daysDV_parent
from #C_days_qtr as a
left join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 as b
	on a.req_sta5a = b.sta5a
where req_sta5a IS NOT NULL--requiring that req_sta5a not be missing; could do inner-join with VAST
group by parent_station_sta5a, fy_qtr;
--2,010
select top 100 * from #qtr_daysDV_parent
--=================
/*Step 5b: Calculate rolling 6-month average and output permanent table*/
--=================
drop table if exists [OABI_MyVAAccess].[crh_eval].C2_daysDV_qtr_parent_sta5a;
--
select parent_station_sta5a
	, fy_qtr
	, tc_requests_sum
	, tc_success_sum
	, tc_pc_success_sum
	, tc_success_prop
	, tc_pc_success_prop
	, AVG(tc_success_prop) OVER(partition by parent_station_sta5a order by fy_qtr rows 2 preceding) as tc_success_6mo_avg
	, AVG(tc_pc_success_prop) OVER(partition by parent_station_sta5a order by fy_qtr rows 2 preceding) as tc_pc_success_6mo_avg
into [OABI_MyVAAccess].[crh_eval].C2_daysDV_qtr_parent_sta5a
from #qtr_daysDV_parent;
--5,900
select top 100 * from [OABI_MyVAAccess].[crh_eval].C2_daysDV_qtr_parent_sta5a
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 6: Rolling 6-Month Average TimelyCare Success % - VISN
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--=================
/*Step 6a: Summarise the proportion of timelyCare requests that are fulfilled to the sta5a-month
		-- This is also where we catch those people who made requests on Fridays or Saturdays*/
--=================
drop table if exists #qtr_daysDV_visn;
--
select count(*) as tc_requests_sum
	, sum(timelyCare_success) as tc_success_sum
	, sum(timelyCare_PC_success) as tc_pc_success_sum
	, sum(cast(timelyCare_PC_success as float)) / cast(count(*) as float) as tc_pc_success_prop
	, sum(cast(timelyCare_success as float)) / cast(count(*) as float) as tc_success_prop
	, fy_qtr
	, b.parent_visn
into #qtr_daysDV_visn
from #C_days_qtr as a
left join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 as b
	on a.req_sta5a = b.sta5a
where req_sta5a IS NOT NULL--requiring that req_sta5a not be missing; could do inner-join with VAST
group by parent_visn, fy_qtr;
--270
select top 100 * from #qtr_daysDV_visn
--=================
/*Step 6b: Calculate rolling 6-month average and output permanent table*/
--=================
drop table if exists [OABI_MyVAAccess].[crh_eval].C3_daysDV_qtr_visn;
--
select parent_visn
	, fy_qtr
	, tc_requests_sum
	, tc_success_sum
	, tc_pc_success_sum
	, tc_success_prop
	, tc_pc_success_prop
	, AVG(tc_success_prop) OVER(partition by parent_visn order by fy_qtr rows 2 preceding) as tc_success_6mo_avg
	, AVG(tc_pc_success_prop) OVER(partition by parent_visn order by fy_qtr rows 2 preceding) as tc_pc_success_6mo_avg
into [OABI_MyVAAccess].[crh_eval].C3_daysDV_qtr_visn
from #qtr_daysDV_visn;
--270
select top 100 * from [OABI_MyVAAccess].[crh_eval].C3_daysDV_qtr_visn
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-- Step 7: Rolling 6-Month Average TimelyCare Success % - national
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--=================
/*Step 7a: Summarise the proportion of timelyCare requests that are fulfilled to the sta5a-month
		-- This is also where we catch those people who made requests on Fridays or Saturdays*/
--=================
drop table if exists #qtr_daysDV_nat;
--
select count(*) as tc_requests_sum
	, sum(timelyCare_success) as tc_success_sum
	, sum(timelyCare_PC_success) as tc_pc_success_sum
	, sum(cast(timelyCare_success as float)) / cast(count(*) as float) as tc_success_prop
	, sum(cast(timelyCare_PC_success as float)) / cast(count(*) as float) as tc_pc_success_prop
	, fy_qtr
into #qtr_daysDV_nat
from #C_days_qtr as a
left join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 as b
	on a.req_sta5a = b.sta5a
where req_sta5a IS NOT NULL--requiring that req_sta5a not be missing; could do inner-join with VAST
group by fy_qtr;
--43
select top 100 * from #qtr_daysDV_nat
--=================
/*Step 7b: Calculate rolling 6-month average and output permanent table*/
--=================
drop table if exists [OABI_MyVAAccess].[crh_eval].C4_daysDV_qtr_nat;
--
select
	fy_qtr
	, tc_requests_sum
	, tc_success_sum
	, tc_pc_success_sum
	, tc_success_prop
	, tc_pc_success_prop
	, AVG(tc_success_prop) OVER(order by fy_qtr rows 2 preceding) as tc_success_6mo_avg
	, AVG(tc_pc_success_prop) OVER(order by fy_qtr rows 2 preceding) as tc_pc_success_6mo_avg
into [OABI_MyVAAccess].[crh_eval].C4_daysDV_qtr_nat
from #qtr_daysDV_nat;
--43
select top 100 * from [OABI_MyVAAccess].[crh_eval].C4_daysDV_qtr_nat