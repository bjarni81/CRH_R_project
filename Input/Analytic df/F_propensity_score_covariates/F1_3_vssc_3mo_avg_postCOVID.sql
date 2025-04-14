/*Average vssc covariates in 3 months before t0*/
/*=====================================================*/
-- Setting join dates
drop table if exists #sta5as_join_dates;
--
select sta5a
	, cast('2021-01-01' as date) as month_for_joining
into #sta5as_join_dates
from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06
UNION
select sta5a
	, cast('2021-02-01' as date) as month_for_joining
from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06
UNION
select sta5a
	, cast('2021-03-01' as date) as month_for_joining
from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06
order by sta5a;
--3,813
/*=====================================================*/
-- Average by sta5a and output permanent table
drop table if exists [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg_postCOVID;
--
with cte as(
select access.nosos_risk_score, access.obs_exp_panel_ratio, access.team_pcp_ap_fte_total
	, access.sta5a, access.vssc_month
from [OABI_MyVAAccess].[crh_eval].F1_2_vssc_covars as access
inner join #sta5as_join_dates as jd
	on access.Sta5a = jd.sta5a
		AND access.vssc_month = jd.month_for_joining)
select sta5a
	, AVG(nosos_risk_score) as nosos_3mo_avg
	, AVG(obs_exp_panel_ratio) as obs_exp_panel_ratio_3mo_avg
	, AVG(team_pcp_ap_fte_total) as team_pcp_ap_fte_total_3mo_avg
into [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg_postCOVID
from cte
group by sta5a
--1,085
select top 100 * from [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg_postCOVID