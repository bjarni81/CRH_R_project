library(tidyverse)
library(lubridate)
library(kableExtra)
library(readxl)
library(DBI)
library(here)
library(scales)
library(janitor)
library(MatchIt)
library(sjPlot)
#
##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#
#
`%ni%` <- negate(`%in%`)
#=================
sta5a_demog <- dbGetQuery(oabi_con,
                          "select a.sta5a, a.nosos_3mo_avg, a.obs_exp_panel_ratio_3mo_avg, a.team_pcp_ap_fte_total_3mo_avg
	, b.pcmm_scrssn_count
	, c.est_pc_pt_wt_avg, c.est_pid_avg, c.new_pc_pt_wt_avg, c.new_create_avg
	, c.third_next_avail_avg, c.tc_success_prop_avg, c.tc_pc_success_prop_avg
	, d.adi_natRnk_avg
	, e.avg_non_va_cons, e.avg_tot_cons, e.cons_rate_avg, e.non_va_cons_rate_per_10k_pcmm
	, f.rural_prop
	, pc_crh_criteria_met_after_march_20 = case	
		when crh_flag.had_pcCRH_after_march20 = 1 then 1
		else 0 end
	, pc_crh_criteria_met_after_sept_21 = case	
		when crh_flag.had_pccrh_after_sep_21 = 1 then 1
		else 0 end
	, vast.parent_visn, vast.s_abbr
	, crh_flag.had_pccrh_after_sep_21, crh_flag.not_enough_crh_before_oct_21
from [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg_postCOVID as a
left join [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count_postCOVID as b
	on a.sta5a = b.sta5a
left join [OABI_MyVAAccess].[crh_eval].F3B_access_metrics_postCOVID as c
	on a.sta5a = c.sta5a
left join [OABI_MyVAAccess].[crh_eval].F4_adi_postCOVID as d
	on a.sta5a = d.sta5a
left join [OABI_MyVAAccess].[crh_eval].F5_avg_pc_cons_post_COVID as e
	on a.sta5a = e.sta6a
left join [OABI_MyVAAccess].[crh_eval].F6_urh_white_female_prop_postCOVID as f
	on a.sta5a = f.sta5a
left join [OABI_MyVAAccess].[crh_eval].C1_crh_flag as crh_flag
	on a.sta5a = crh_flag.sta5a
left join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on a.sta5a = vast.sta5a") %>%
  mutate(avg_tot_cons = replace_na(avg_tot_cons, 0),
         non_va_cons_rate_per_10k_pcmm = replace_na(non_va_cons_rate_per_10k_pcmm, 0),
         parent_visn = factor(parent_visn),
         adi_cat = case_when(adi_natRnk_avg < 25 ~ "0-24",
                             adi_natRnk_avg >= 25 & adi_natRnk_avg < 50 ~ "25-49",
                             adi_natRnk_avg >= 50 & adi_natRnk_avg < 75 ~ "50-74",
                             adi_natRnk_avg >= 75 ~ "75-100"),
         treat = if_else(pc_crh_criteria_met_after_march_20 == 1, 0, 1),
         s_abbr2 = case_when(s_abbr %in% c("MSCBOC", "PCCBOC") ~ "CBOC",
                             s_abbr %in% c("HCC", "VAMC") ~ "VAMC/HCC",
                             TRUE ~ s_abbr)) %>%
  mutate(pilot_visn_flag = if_else(parent_visn %in% c("06", "16", "19", "20"), "Pilot VISN", "Not a Pilot VISN")) %>%
  select(pcmm_scrssn_count
         #, nosos_3mo_avg
         , obs_exp_panel_ratio_3mo_avg
         , team_pcp_ap_fte_total_3mo_avg
         , adi_natRnk_avg
         , rural_prop
         , non_va_cons_rate_per_10k_pcmm
         , sta5a#, pc_crh_criteria_met_after_march_20, 
         , pc_crh_criteria_met_after_sept_21
         #, pilot_visn_flag,
         , third_next_avail_avg
         , s_abbr2
         , parent_visn
         , est_pid_avg
         , new_create_avg,
         , had_pccrh_after_sep_21, not_enough_crh_before_oct_21) %>%
  mutate(had_pccrh_after_sep_21 = if_else(is.na(had_pccrh_after_sep_21), 
                                          0, had_pccrh_after_sep_21),
         not_enough_crh_before_oct_21 = if_else(is.na(not_enough_crh_before_oct_21), 
                                                0, not_enough_crh_before_oct_21)) %>%
  drop_na()
#
sta5a_demog_no_missing <- sta5a_demog %>%
  filter(pcmm_scrssn_count > 450 & not_enough_crh_before_oct_21 == 0)
#==================
opt_match_pcmm_wVISN <- matchit(pc_crh_criteria_met_after_sept_21 ~  
                                  parent_visn
                                + s_abbr2
                                + pcmm_scrssn_count
                                #+ nosos_3mo_avg
                                + obs_exp_panel_ratio_3mo_avg
                                + team_pcp_ap_fte_total_3mo_avg
                                #+ adi_natRnk_avg
                                + rural_prop
                                + non_va_cons_rate_per_10k_pcmm
                                + third_next_avail_avg
                                + new_create_avg
                                + est_pid_avg
                                ,
                                data = sta5a_demog_no_missing,
                                method = "optimal",
                                distance = "glm",
                                link = "logit",
                                #replacement = TRUE,
                                exact = ~s_abbr2 + parent_visn)
#--
opt_matches_pcmm_wVISN <- match.data(opt_match_pcmm_wVISN) %>%
  select(sta5a, subclass, pc_crh_criteria_met_after_sept_21)
#--
opt_matches_pcmm1_wVISN <- opt_matches_pcmm_wVISN %>%
  select(sta5a, subclass, pc_crh_criteria_met_after_sept_21)
#======================
# commenting-out so that I can call base::source() without re-writing the .csv
# write_csv(opt_matches_pcmm1_wVISN,
#           here("Input", "Data", "ps_matched_sta5as_v6_post_COVID.csv"))
