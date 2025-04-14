/*
Average Community Care Referral Rate per 1,000 in PCMM
*/
drop table if exists #cons_avg;
--
with CTE as(
select count(*) as total_cons, sum(non_va) as non_va_cons, sta6a
from [OABI_MyVAAccess].[crh_eval].G_communityCare_referrals
where stopCode_group = 'Primary Care'
	AND MONTH(activityDateTime) IN(7, 8, 9)
	AND year(activityDateTime) = 2020
group by Sta6a)
select a.sta6a, avg_tot_cons = avg(cast(total_cons as float)), avg_non_va_cons = avg(cast(non_va_cons as float)), 
			avg(cast(non_va_cons as float) / cast(total_cons as float)) as cons_rate_avg
into #cons_avg
from CTE as a
group by a.sta6a
--1,015
drop table if exists [OABI_MyVAAccess].[crh_eval].F5_avg_pc_cons_post_COVID;
--
select a.*, b.pcmm_scrssn_count
	, non_va_cons_rate_per_10k_pcmm = (cons_rate_avg /pcmm_scrssn_count) * 10000
into [OABI_MyVAAccess].[crh_eval].F5_avg_pc_cons_post_COVID
from #cons_avg as a
left join [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count as b
	on a.Sta6a = b.sta5a
--981
select top 100 *
from [OABI_MyVAAccess].[crh_eval].F5_avg_pc_cons_post_COVID