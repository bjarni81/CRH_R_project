library(tidyverse)
library(DBI)
library(lubridate)
#
`%ni%` <- negate(`%in%`)
##---------- Connection to OABI_MyVAAccess
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")

# CRH Penetration rate
pen_rate_month <- dbGetQuery(oabi_con,
                             "select * from [OABI_MyVAAccess].[crh_eval].B1_crh_penRate") %>%
  mutate(crh_month = ymd(crh_month))
# vast
vast <- dbGetQuery(oabi_con,
                   "select * from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06")
#---------------
#making flag for sta5as with 2 consecutive months with > 9 PC CRH encounters
all_months <- pen_rate_month %>%
  select(crh_month) %>%
  mutate(crh_month = ymd(crh_month)) %>%
  distinct
#
all_sta5a <- pen_rate_month %>%
  group_by(sta5a) %>%
  summarise(crh_encounter_count = sum(crh_encounter_count, na.rm = T)) %>%
  filter(crh_encounter_count > 0) %>%
  select(sta5a) %>% 
  distinct

#----
crh_10_sta5as <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         crh_flag = if_else((crh_encounter_count > 9 & next_month_crh_enc > 9) 
                            | (crh_encounter_count > 9 & last_month_crh_count > 9), TRUE, FALSE)) %>%
  group_by(sta5a) %>%
  summarise(crh_10_flag_sum = sum(crh_flag, na.rm = T)) %>%
  filter(crh_10_flag_sum > 1) %>%
  select(sta5a) %>%
  distinct %>%
  pull
#------------
# first month with > 9 PC CRH encounters
# adding period in which sta5a had the first month (of the dyad) with > 9 PC CRH encounters
crh_1st_month_w_mt9 <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         crh_flag = if_else((crh_encounter_count > 9 & next_month_crh_enc > 9) 
                            | (crh_encounter_count > 9 & is.na(next_month_crh_enc))
                            | (crh_encounter_count > 9 & last_month_crh_count > 9), TRUE, FALSE)) %>%
  filter(crh_encounter_count > 9 & next_month_crh_enc > 9) %>%
  group_by(sta5a) %>%
  summarise(first_mo_w_mt9_pc_crh = first(crh_month))
#=========
# flag for having >9 PC CRH encounters each of the first 6 months of FY20
first_n_month_flags <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>% 
  group_by(sta5a) %>%
  mutate(rowNum = row_number(),
         first_6_months_w_10 = case_when(
           rowNum < 7 & crh_encounter_count > 9 ~ 1,
           TRUE ~ 0)) %>%
  group_by(sta5a) %>%
  summarise(first_6_mos_w_10_flag = if_else(sum(first_6_months_w_10, na.rm = T) >= 6, 1, 0))
#========
# flag for meeting PC CRH inclusion criteria after March 2020
had_pcCRH_after_march20 <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  filter(crh_month > ymd("2020-03-01")) %>%#this is the difference with crh_10_sta5as from above
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         crh_flag = if_else((crh_encounter_count > 9 & next_month_crh_enc > 9) 
                            | (crh_encounter_count > 9 & last_month_crh_count > 9), TRUE, FALSE)) %>%
  group_by(sta5a) %>%
  summarise(crh_10_flag_sum = sum(crh_flag, na.rm = T)) %>%
  filter(crh_10_flag_sum > 1) %>%
  select(sta5a) %>%
  pull
#========
# flag for meeting PC CRH inclusion criteria after september 2021
had_pcCRH_after_sept21 <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  filter(crh_month > ymd("2021-09-01")) %>%#this is the difference with crh_10_sta5as from above
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         crh_flag = if_else((crh_encounter_count > 9 & next_month_crh_enc > 9) 
                            | (crh_encounter_count > 9 & last_month_crh_count > 9), TRUE, FALSE)) %>%
  group_by(sta5a) %>%
  summarise(crh_10_flag_sum = sum(crh_flag, na.rm = T)) %>%
  filter(crh_10_flag_sum > 1) %>%
  select(sta5a) %>%
  pull
#--==
# flag for having >0 pc crh encounters before March 2020 but not meeting our inclusion criteria
not_enough_crh_before_march_20 <- pen_rate_month %>%
  filter(crh_month < ymd("2020-03-01")) %>%
  group_by(sta5a) %>%
  summarise(crh_encounter_count = sum(crh_encounter_count, na.rm = T)) %>%
  filter(sta5a %ni% crh_10_sta5as
         & crh_encounter_count > 0) %>%
  select(sta5a) %>%
  pull
#--==
# flag for having >0 pc crh encounters before october 2021 but not meeting our inclusion criteria
not_enough_crh_before_oct_21 <- pen_rate_month %>%
  filter(crh_month < ymd("2021-10-01")) %>%
  group_by(sta5a) %>%
  summarise(crh_encounter_count = sum(crh_encounter_count, na.rm = T)) %>%
  filter(sta5a %ni% crh_10_sta5as
         & crh_encounter_count > 0) %>%
  select(sta5a) %>%
  pull
#---===
crh_flag <- all_sta5a %>%
  mutate(crh_10_flag = if_else(sta5a %in% crh_10_sta5as, 1, 0),
         crh_flag = 1,
         not_enough_crh_before_march_20 = if_else(sta5a %in% not_enough_crh_before_march_20, 1, 0),
         not_enough_crh_before_oct_21 = if_else(sta5a %in% not_enough_crh_before_oct_21, 1, 0)) %>%
  left_join(., first_n_month_flags) %>%
  left_join(., crh_1st_month_w_mt9) %>%
  mutate(period_initiating_crh = case_when(
    first_mo_w_mt9_pc_crh < ymd("2019-10-01") ~ "Initiated PC CRH Before 9/2019",
    first_mo_w_mt9_pc_crh > ymd("2019-09-01") 
    & first_mo_w_mt9_pc_crh < ymd("2020-03-01") ~ "Initiated PC CRH Between 10/2019 and 2/2020",
    first_mo_w_mt9_pc_crh > ymd("2020-02-01") 
    & first_mo_w_mt9_pc_crh < ymd("2021-03-01") ~ "Initiated PC CHR Between 3/2020 and 2/2021",
    first_mo_w_mt9_pc_crh > ymd("2021-02-01") ~ "Initiated PC CRH After 2/2021"
  ),
  had_pcCRH_after_march20 = if_else(sta5a %in% had_pcCRH_after_march20, 1, 0),
  had_pccrh_after_sep_21 = if_else(sta5a %in% had_pcCRH_after_sept21, 1, 0))
#
table_id <- DBI::Id(schema = "crh_eval", table = "C1_crh_flag")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = crh_flag,
                  overwrite = TRUE)
