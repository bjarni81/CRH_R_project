/*
Program to combine all components of the analytic dataset
*/

/*
Step 1:
	Unique sta5a-month combinations
*/
drop table if exists #sta6a_month_uniques;
--
with CTE as(
	select distinct Sta6a, visitMonth
		, qtr = case	
			when month(visitMonth) IN(10, 11, 12) then 1
			when month(visitMonth) IN(1, 2, 3) then 2
			when month(visitMonth) IN(4, 5, 6) then 3
			when month(visitMonth) IN(7, 8, 9) then 4 end
		, fy = case
			when month(visitMonth) > 9 then year(visitMonth) + 1
			else year(visitMonth) end
	from [OABI_MyVAAccess].[crh_eval].A1_pc_enc_scrssn_count
	)
select *, fy_qtr = CONCAT(fy, '_', qtr)
into #sta6a_month_uniques
from CTE
--where visitMonth < cast('2021-10-01' as date)
--53,505
select max(visitMonth) from #sta6a_month_uniques
/*
Step 2:
	Summarise primary care community care referrals to sta5a-month
*/
--drop table if exists #pcccr_sta5a_month;
----
--with CTE as(
--	select *, cast(DATEFROMPARTS(year(activityDateTime), month(activityDateTime), '01') as date) as pcccRef_month
--	from [OABI_MyVAAccess].[crh_eval].G_communityCare_referrals
--	where stopCode_group = 'Primary Care'
--	)
--select count(*) as pc_cc_referral_count, pcccRef_month, sta6a
--into #pcccr_sta5a_month
--from CTE
--group by pcccRef_month, Sta6a;
--49,013

/*
Step 3:
	Uniques in PCMM by FY-Qtr
*/
drop table if exists #pcmm_uniques;
--
select count(distinct scrssn_char) as pcmm_count
	, Sta5a, fy, qtr
into #pcmm_uniques
from [PACT_CC].[econ].PatientPCP
where fy > 2016
group by sta5a, fy, qtr
--15,982
	/*Step 3b:
		Average uniques over period*/
	drop table if exists #pcmm_avg;
	--
	select AVG(pcmm_count) pcmm_count_avg, sta5a
	into #pcmm_avg
	from #pcmm_uniques
	group by sta5a;
--1,119
/*
Step 4:
	Start joining-on
*/
drop table if exists [OABI_MyVAAccess].[crh_eval].Z_analytic_df;
--
select a.Sta6a, a.visitMonth, a.fy, a.qtr
	--penetration rate
	, penRate.crh_encounter_count, penRate.pc_encounter_total, penRate.pc_crh_per_1k_total_pc
	--CRH flags
	, crhFlag.crh_flag, crhFlag.crh_10_flag, crhFlag.first_6_mos_w_10_flag, crhFlag.first_mo_w_mt9_pc_crh
	--VAST
	, vast.parent_visn, vast.parent_station_sta5a, vast.s_abbr, vast.urh_vast, vast.census_division
	--age
	, age.avg_age_oct1_2022, age._18_39_count, age._40_49_count, age._50_59_count, age._60_69_count, age._70_79_count, age._80_plus_count
	--gender, race, and URH
	, race.female_count
		, race.male_count, race.race_black_count, race.race_missing, race.race_other_count, race.race_white_count
		, race.urh_urban_count, race.urh_rural_count, race.urh_missing_count
		, race.scrssn_count
	--adi
	, adi.adi_natRnk_avg, adi.adi_natRnk_sd
		, adi.adi_count, adi.adi_count_in_1_25, adi.adi_count_in_26_50, adi.adi_count_in_51_75, adi.adi_count_in_76_100
	--shep
	, shep.q_6_always_wgt, shep.q_9_always_wgt, shep.q_14_always_wgt, shep.has_all_3_access_qs, shep.shep_access_metric
	--vssc
	, vssc.est_pc_pt_wt, vssc.new_pc_pt_wt, vssc.third_next_avail, vssc.panel_fullness
	--Timely Care
	, timelyCare.tc_requests_sum, timelyCare.tc_pc_success_sum
		, tc_pc_success_prop = cast(timelyCare.tc_pc_success_sum as float) / cast(timelyCare.tc_requests_sum as float)
		, timelyCare.tc_pc_success_6mo_avg
		, timelyCare.tc_success_sum, timelyCare.tc_success_prop, timelyCare.tc_success_6mo_avg
	----Primary Care community Care referrals
	--, pcccr.pc_cc_referral_count
	--	, pcccr_per_10k_uniques = (cast(pcccr.pc_cc_referral_count as float) / cast(pcmm.pcmm_count as float)) * 10000
	--fy-qtr-specific number of uniques in PCMM
	, pcmm.pcmm_count as pcmm_count_fy_qtr
	--average number of uniques in PCMM
	, pcmm_avg.pcmm_count_avg
	--nosos, obs:exp, and pcp/ap fte
	, vssc2.nosos_risk_score, vssc2.obs_exp_panel_ratio, vssc2.team_pcp_ap_fte_total
	--driveTime and Distance
	, driveTime.avg_driveDist, driveTime.sd_driveDist
	, driveTime.avg_driveTime, driveTime.sd_driveTime
into [OABI_MyVAAccess].[crh_eval].Z_analytic_df
from #sta6a_month_uniques as a
left join [OABI_MyVAAccess].[crh_eval].B1_crh_penRate as penRate
	on a.Sta6a = penRate.sta5a
		and a.visitMonth = penRate.crh_month
left join [OABI_MyVAAccess].[crh_eval].C1_crh_flag as crhFlag
	on a.Sta6a = crhFlag.sta5a
left join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on a.Sta6a = vast.sta5a
left join [OABI_MyVAAccess].[crh_eval].D1_age_sta5a_qtr as age
	on a.Sta6a = age.Sta5a
		and a.fy = age.FY
		and a.qtr = age.QTR
left join [OABI_MyVAAccess].[crh_eval].D2_race_gender_urh_count as race
	on a.Sta6a = race.Sta5a
		and a.fy = race.FY
left join [OABI_MyVAAccess].[crh_eval].D3_adi_sta5a_qtr as adi
	on a.Sta6a = adi.Sta5a
		and a.fy = adi.fy
		and a.qtr = adi.qtr
left join [OABI_MyVAAccess].[crh_eval].E1_SHEP_sta5a_month as shep
	on a.Sta6a = shep.sta5a
		and a.visitMonth = shep.shep_viz_month
left join [OABI_MyVAAccess].[crh_eval].E2_VSSC_access_metrics as vssc
	on a.Sta6a = vssc.sta5a
		and a.visitMonth = vssc.vssc_month
left join [OABI_MyVAAccess].[crh_eval].E3_daysDV_month_sta5a as timelyCare
	on a.Sta6a = timelyCare.req_sta5a
		and a.visitMonth = timelyCare.viz_month
--left join #pcccr_sta5a_month as pcccr
--	on a.Sta6a = pcccr.Sta6a
--		and a.visitMonth = pcccr.pcccRef_month
left join #pcmm_uniques as pcmm
	on a.Sta6a = pcmm.Sta5a
		and a.fy = pcmm.FY
		and a.qtr = pcmm.QTR
left join #pcmm_avg as pcmm_avg
	on a.Sta6a = pcmm_avg.Sta5a
left join [OABI_MyVAAccess].[crh_eval].F1_2_vssc_covars as vssc2
	on a.Sta6a = vssc2.sta5a
		and a.visitMonth = vssc2.vssc_month
left join [OABI_MyVAAccess].[crh_eval].D4_avg_drive_time as driveTime
	on a.Sta6a = driveTime.CLOSESTPCSITE
		and a.fy = driveTime.fy
		;
--53,505
--========================================
select top 100 * 
from [OABI_MyVAAccess].[crh_eval].Z_analytic_df
where visitMonth = cast('2022-09-01' as date)
order by Sta6a, visitMonth