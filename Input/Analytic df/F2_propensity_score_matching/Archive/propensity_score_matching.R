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
set.seed(1234)
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
# gap_join_dates <- dbGetQuery(oabi_con,
#                              "with cte as(
# select sta5a, dateadd(MONTH, -1, first_mo_w_mt9_pc_crh) as month_for_joining
# from [OABI_MyVAAccess].[crh_eval].C1_crh_flag
# where crh_10_flag = 1)
# select cte.sta5a
# 	, cte.month_for_joining
# from cte as cte
# UNION
# select sta5a
# 	, cast('2019-09-01' as date) as month_for_joining
# from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06
# where sta5a NOT IN (select sta5a from [OABI_MyVAAccess].[crh_eval].C1_crh_flag where crh_10_flag = 1)") %>%
#   mutate(month_for_joining = ymd(month_for_joining),
#          month_minus_2 = month_for_joining - months(2))
# #=====
# gap_metric <- read_csv("//vhacdwdwhapp15.vha.med.va.gov/PACT_CC/CRH/Documentation/Gap Metric/GapData_Jan2022.csv") %>%
#   rename_all(tolower) %>%
#   mutate(moyear = ymd(moyear))
# #-----
# gap_avg <- gap_join_dates %>%
#   left_join(., gap_metric, by = c("sta5a" = "sta6a")) %>%
#   filter(moyear >= month_minus_2 & moyear <= month_for_joining) %>%
#   group_by(sta5a) %>%
#   summarise(gap_3mo_avg = mean(gap, na.rm = T))
#===
sta5a_demog <- dbGetQuery(oabi_con,
                          "select vast.sta5a
	, at_least_10_pc_crh_flag = case	
		when crh_flag.crh_10_flag = 1 then 1
		else 0 end
	, vast.parent_visn
	, urh = case 
		when vast.urh_vast = 'U' then 'U'
		when vast.urh_vast <> 'U' then 'R'
		end
	, vast.census_division
	, vast.s_abbr
	, vssc.nosos_3mo_avg
	, vssc.obs_exp_panel_ratio_3mo_avg
	, vssc.team_pcp_ap_fte_total_3mo_avg
	, pcmm.pcmm_scrssn_count
	, access.est_pc_pt_wt_3mo_avg
	, access.new_pc_pt_wt_3mo_avg
	, access.third_next_avail_3mo_avg
	, adi.adi_natRnk_avg
	, prop_adi_GT_75 = cast(adi2.adi_count_in_76_100 as float) / cast(adi2.adi_count as float)
	, age.avg_age_oct1_2020
	, prop_GT_69 = (cast(_70_79_count as float) + cast(_80_plus_count as float)) / cast(total as float)
	, prop_male = cast(demog.male_count as float) / cast(demog.scrssn_count as float)
	, prop_white = cast(demog.race_white_count as float) / cast(demog.scrssn_count as float)
	, prop_rural = cast(demog.urh_rural_count as float) / cast(demog.scrssn_count as float)
from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
left join [OABI_MyVAAccess].[crh_eval].C1_crh_flag as crh_flag
	on vast.sta5a = crh_flag.sta5a
left join [OABI_MyVAAccess].[crh_eval].F1_3_vssc_3mo_avg as vssc
	on vast.sta5a = vssc.sta5a
left join [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count_avg as pcmm
	on vast.sta5a = pcmm.sta5a
left join [OABI_MyVAAccess].[crh_eval].F3_access_metrics_3mo_avg as access
	on vast.sta5a = access.sta5a
left join [OABI_MyVAAccess].[crh_eval].F4_adi_avg as adi
	on vast.sta5a = adi.sta5a
left join [OABI_MyVAAccess].[crh_eval].D3_adi_sta5a_qtr as adi2
	on vast.sta5a = adi2.sta5a
left join [OABI_MyVAAccess].[crh_eval].D1_age_sta5a_qtr as age
	on vast.sta5a = age.Sta5a
left join [OABI_MyVAAccess].[crh_eval].D2_race_gender_urh_count as demog
	on vast.sta5a = demog.Sta5a
where age.FY = 2020 AND age.QTR = 1
	AND demog.fy = 2020 AND demog.qtr = 1
	AND adi2.fy = 2020 AND adi2.qtr = 1") %>%
  mutate(parent_visn = factor(parent_visn),
         adi_cat = case_when(adi_natRnk_avg < 25 ~ "0-24",
                             adi_natRnk_avg >= 25 & adi_natRnk_avg < 50 ~ "25-49",
                             adi_natRnk_avg >= 50 & adi_natRnk_avg < 75 ~ "50-74",
                             adi_natRnk_avg >= 75 ~ "75-100"),
         treat = if_else(at_least_10_pc_crh_flag == 1, 0, 1),
         s_abbr2 = case_when(s_abbr %in% c("MSCBOC", "PCCBOC") ~ "CBOC",
                             s_abbr %in% c("HCC", "VAMC") ~ "VAMC/HCC",
                             TRUE ~ s_abbr)) %>%
  filter(pcmm_scrssn_count > 450)
#
sta5a_demog_no_missing <- sta5a_demog %>%
  drop_na() %>%
  mutate(pilot_visn_flag = if_else(parent_visn %in% c("06", "16", "19", "20"), "Pilot VISN", "Not a Pilot VISN"))
#==================
opt_match_pcmm <- matchit(at_least_10_pc_crh_flag ~  
                            pilot_visn_flag
                          + pcmm_scrssn_count
                          + nosos_3mo_avg
                          + obs_exp_panel_ratio_3mo_avg
                          + team_pcp_ap_fte_total_3mo_avg
                          + adi_natRnk_avg
                          + prop_rural,
                          data = sta5a_demog_no_missing,
                          method = "optimal",
                          distance = "glm",
                          link = "logit",
                          exact = ~pilot_visn_flag)
#--
opt_matches_pcmm <- match.data(opt_match_pcmm) %>%
  select(sta5a, at_least_10_pc_crh_flag, subclass)
#======================
write_csv(opt_matches_pcmm,
          here("Input", "Data", "ps_matched_sta5as.csv"))
