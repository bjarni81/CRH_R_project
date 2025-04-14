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
#---===
crh_flag <- tibble(sta5a = crh_10_sta5as) %>%
  mutate(crh_10_flag = 1,
         crh_flag = 1) %>%
  left_join(., crh_1st_month_w_mt9) %>%
  mutate(period_initiating_crh = case_when(
    first_mo_w_mt9_pc_crh < ymd("2020-03-01") ~ "Before March 2020",
    first_mo_w_mt9_pc_crh >= ymd("2020-03-01") 
      & first_mo_w_mt9_pc_crh <= ymd("2020-09-01") ~ "March to September 2020",
    first_mo_w_mt9_pc_crh >= ymd("2020-10-01") ~ "After September 2020"))
#
table_id <- DBI::Id(schema = "pccrh_eng", table = "G_crh_flag")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = crh_flag,
                  overwrite = TRUE)
