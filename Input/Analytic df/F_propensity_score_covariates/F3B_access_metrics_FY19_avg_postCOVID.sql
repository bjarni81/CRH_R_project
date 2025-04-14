/*
Average of outcomes for PS matching: FY19
*/
select top 100 * from [OABI_MyVAAccess].[crh_eval].E2_VSSC_access_metrics
select top 100 * from [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a
--
drop table if exists #vssc_avg;
--
select sta5a
	, AVG(est_pc_pt_wt) as est_pc_pt_wt_avg
	, AVG(est_pc_pt_wt_pid) as est_pid_avg
	, AVG(new_pc_pt_wt) as new_pc_pt_wt_avg
	, AVG(new_pc_pt_wt_create) as new_create_avg
	, AVG(third_next_avail) as third_next_avail_avg
into #vssc_avg
from [OABI_MyVAAccess].[crh_eval].E2_VSSC_access_metrics
where vssc_month > cast('2020-09-01' as date)
	and vssc_month < cast('2021-04-01' as date)
group by sta5a;
--1,243
drop table if exists #timely_care_avg;
--
select req_sta5a
	, AVG(tc_success_prop) as tc_success_prop_avg
	, avg(cast(tc_pc_success_sum as float) / cast(tc_requests_sum as float)) as tc_pc_success_prop_avg
into #timely_care_avg
from [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a
where viz_month > cast('2020-12-01' as date)
	and viz_month < cast('2021-04-01' as date)
group by req_sta5a;
--1,063
select sta5a 
into #sta5as
from #vssc_avg
UNION 
select req_sta5a as sta5a
from #timely_care_avg;
--1,244
/*Output permanent table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].F3B_access_metrics_postCOVID;
--
select a.sta5a
	, b.est_pc_pt_wt_avg, b.est_pid_avg, b.new_create_avg, b.new_pc_pt_wt_avg, b.third_next_avail_avg
	, c.tc_success_prop_avg, c.tc_pc_success_prop_avg
into [OABI_MyVAAccess].[crh_eval].F3B_access_metrics_postCOVID
from #sta5as as a
left join #vssc_avg as b
	on a.sta5a = b.sta5a
left join #timely_care_avg as c
	on a.sta5a = c.req_sta5a;
--1,244
select top 100 *
from [OABI_MyVAAccess].[crh_eval].F3B_access_metrics_postCOVID