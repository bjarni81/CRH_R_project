library(tidyverse)
library(lubridate)
library(DBI)
library(here)
#
`%ni%` <- negate(`%in%`)
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Truested_Connection = "true")
#----- Pull CRH Encounters
crh_encounters <- dbGetQuery(oabi_con,
                             "select * from [OABI_MyVAAccess].[crh_eval].crh_encounters_deDup")
#
vast <- read_csv(here("Input", "Data","VAST_from_A06_11jan21.csv"))
#
spokes <- dbGetQuery(oabi_con,
                     "select distinct spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy20_working
                     UNION
                     select distinct spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy21_working")
#--
pc_only <- crh_encounters %>%
  filter(care_type == "Primary Care" & crh_month > ymd('2019-09-01')) %>%
  left_join(., vast %>% select(sta5a, pcmm_visn = parent_visn, pcmm_sta5a_parent = parent_station_sta5a), 
            by = c("sta5a_pcmm" = "sta5a")) %>%
  left_join(., vast %>% select(sta5a, pcmm_visn2 = parent_visn, pcmm_sta5a_parent2 = parent_station_sta5a),
            by = c("sta5a_pcmm_2nd" = "sta5a")) %>%
  mutate(pcmm_visn_match = if_else(parent_visn == pcmm_visn, 1, 0),
         pcmm_visn2_match = if_else(parent_visn == pcmm_visn2, 1, 0),
         final_sta5a = case_when(pcmm_visn_match == 1 ~ sta5a_pcmm,
                                 pcmm_visn_match == 0 & pcmm_visn2_match == 1 ~ sta5a_pcmm_2nd,
                                 TRUE ~ spoke_sta5a))
#
foo <- pc_only %>%
  filter((pcmm_visn_match == 0 | is.na(pcmm_visn_match)) & pcmm_visn2_match == 1)
#---
sum(is.na(pc_only$sta5a_pcmm))
#8,813 are missing sta5a_pcmm (outside of FY21, Q4)
nrow(pc_only)
#372,216 PC encounters (outside of FY21, Q4)
sum(is.na(pc_only$sta5a_pcmm)) / nrow(pc_only) * 100
#2.4% are missing sta5a_pcmm (outside of FY21, Q4)
#--- Checking sta5a_pcmm
sum(pc_only$parent_visn == pc_only$pcmm_visn, na.rm = T)
#354,127 / 372,216 (95.1%) have the same spoke_visn and pcmm_visn
sum(pc_only$parent_station_sta5a == pc_only$pcmm_sta5a_parent, na.rm = T)
#329,441 / 372,216 (88.5%) have the same parent_station_sta5a and pcmm_sta5a_parent
sum(pc_only$spoke_sta5a == pc_only$sta5a_pcmm, na.rm = T)
#271,527 / 372,216 (73%) have the same spoke_sta5a and sta5a_pcmm
#===
#--- Checking sta5a_pcmm_2nd
not_missing_pcmm_2nd <- pc_only %>%
  filter(is.na(sta5a_pcmm_2nd) == F)
#18,688
sum(not_missing_pcmm_2nd$parent_visn == not_missing_pcmm_2nd$pcmm_visn2, na.rm = T)
#354,127 / 18,688 (76%) have the same spoke_visn and pcmm_visn2
sum(not_missing_pcmm_2nd$parent_station_sta5a == not_missing_pcmm_2nd$pcmm_sta5a_parent2, na.rm = T)
#12,079 / 16,688 (72.4%) have the same parent_station_sta5a and pcmm_sta5a_parent2
sum(not_missing_pcmm_2nd$spoke_sta5a == not_missing_pcmm_2nd$sta5a_pcmm2, na.rm = T)
#0 / 16,688 (0%) have the same spoke_sta5a and sta5a_pcmm2
#====================================
v23_plot_df <- pc_only %>%
  filter(parent_visn == 23) %>%
  group_by(final_sta5a, crh_month) %>%
  summarise(count = n()) %>%
  left_join(., vast %>% select(sta5a, short_name), by = c("final_sta5a" = "sta5a")) %>%
  mutate(name_lab = paste0("(", final_sta5a, ") ", short_name))
#
ggplot(data = subset(v23_plot_df, final_sta5a %ni% c("618", "656", "636A6")),
       aes(x = crh_month, y = count, group = name_lab)) +
  geom_line() +
  facet_wrap(~name_lab)
#
ggplot(data = subset(v23_plot_df, final_sta5a %in% c("618", "656", "636A6")),
       aes(x = crh_month, y = count, group = name_lab)) +
  geom_line() +
  facet_wrap(~name_lab)
