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
	, c.est_pc_pt_wt_avg, c.new_pc_pt_wt_avg, c.third_next_avail_avg, c.tc_success_prop_avg, c.tc_pc_success_prop_avg
	, d.adi_natRnk_avg
	, e.avg_non_va_cons, e.avg_tot_cons, e.cons_rate_avg, e.non_va_cons_rate_per_10k_pcmm
	, f.rural_prop
	, at_least_10_pc_crh_flag = case	
		when crh_flag.crh_10_flag = 1 then 1
		else 0 end
	, vast.parent_visn, vast.s_abbr
from [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg as a
left join [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count as b
	on a.sta5a = b.sta5a
left join [OABI_MyVAAccess].[crh_eval].F3B_access_metrics_FY19_avg as c
	on a.sta5a = c.sta5a
left join [OABI_MyVAAccess].[crh_eval].F4_adi as d
	on a.sta5a = d.sta5a
left join [OABI_MyVAAccess].[crh_eval].F5_avg_pc_cons as e
	on a.sta5a = e.sta6a
left join [OABI_MyVAAccess].[crh_eval].F6_urh_white_female_prop as f
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
         treat = if_else(at_least_10_pc_crh_flag == 1, 0, 1),
         s_abbr2 = case_when(s_abbr %in% c("MSCBOC", "PCCBOC") ~ "CBOC",
                             s_abbr %in% c("HCC", "VAMC") ~ "VAMC/HCC",
                             TRUE ~ s_abbr)) %>%
  mutate(pilot_visn_flag = if_else(parent_visn %in% c("06", "16", "19", "20"), "Pilot VISN", "Not a Pilot VISN")) %>%
  select(pcmm_scrssn_count
         , nosos_3mo_avg
         , obs_exp_panel_ratio_3mo_avg
         , team_pcp_ap_fte_total_3mo_avg
         , adi_natRnk_avg
         , rural_prop
         , non_va_cons_rate_per_10k_pcmm, sta5a, at_least_10_pc_crh_flag, pilot_visn_flag,
         est_pc_pt_wt_avg, new_pc_pt_wt_avg, third_next_avail_avg, s_abbr2,
         parent_visn, s_abbr) %>%
  drop_na()
#
sta5a_demog_no_missing <- sta5a_demog %>%
  filter(pcmm_scrssn_count > 450)
#==================
opt_match_pcmm_wVISN <- matchit(at_least_10_pc_crh_flag ~  
                                  #pilot_visn_flag
                                #+ 
                                  parent_visn
                                + s_abbr2
                                + pcmm_scrssn_count
                                + nosos_3mo_avg
                                + obs_exp_panel_ratio_3mo_avg
                                + team_pcp_ap_fte_total_3mo_avg
                                + adi_natRnk_avg
                                + rural_prop
                                + non_va_cons_rate_per_10k_pcmm
                                + third_next_avail_avg
                                + new_pc_pt_wt_avg
                                + est_pc_pt_wt_avg,
                                data = sta5a_demog_no_missing,
                                method = "optimal",
                                distance = "glm",
                                link = "logit",
                                #replacement = TRUE,
                                exact = ~s_abbr2 + parent_visn)
#--
opt_matches_pcmm_wVISN <- match.data(opt_match_pcmm_wVISN) %>%
  select(sta5a, subclass, at_least_10_pc_crh_flag)
#--
opt_matches_pcmm1_wVISN <- opt_matches_pcmm_wVISN %>%
  select(sta5a, subclass, at_least_10_pc_crh_flag)
#======================
# commenting-out so that I can call base::source() without re-writing the .csv
# write_csv(opt_matches_pcmm1_wVISN,
#           here("Input", "Data", "ps_matched_sta5as_v5.csv"))
