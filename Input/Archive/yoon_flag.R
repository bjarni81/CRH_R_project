library(tidyverse)
library(DBI)
##---------- Connection to OABI_MyVAAccess
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")

# CRH Penetration rate
pen_rate_month <- dbGetQuery(oabi_con,
                             "select * from [OABI_MyVAAccess].[crh_eval].crh_penRate_month")
#---------------
#making Yoon flag
all_months <- pen_rate_month %>%
  select(crh_month) %>%
  distinct
#
all_sta5a <- pen_rate_month %>%
  select(sta5a) %>%
  distinct
#----
yoon_5_sta5as <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         yoon_flag = if_else((crh_encounter_count > 5 & next_month_crh_enc > 5) 
                             | (crh_encounter_count > 5 & is.na(next_month_crh_enc))
                             | (crh_encounter_count > 5 & last_month_crh_count > 5), TRUE, FALSE)) %>%
  group_by(sta5a) %>%
  summarise(yoon_5_flag_sum = sum(yoon_flag, na.rm = T)) %>%
  filter(yoon_5_flag_sum > 1) %>%
  select(sta5a) %>%
  distinct %>%
  pull
#----
yoon_10_sta5as <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>%
  group_by(sta5a) %>%
  mutate(next_month_crh_enc = lead(crh_encounter_count),
         last_month_crh_count = lag(crh_encounter_count),
         yoon_flag = if_else((crh_encounter_count > 9 & next_month_crh_enc > 9) 
                             | (crh_encounter_count > 9 & is.na(next_month_crh_enc))
                             | (crh_encounter_count > 9 & last_month_crh_count > 9), TRUE, FALSE)) %>%
  group_by(sta5a) %>%
  summarise(yoon_10_flag_sum = sum(yoon_flag, na.rm = T)) %>%
  filter(yoon_10_flag_sum > 1) %>%
  select(sta5a) %>%
  distinct %>%
  pull
#===
first_n_month_flags <- all_sta5a %>%
  left_join(., all_months, by = character()) %>%
  left_join(., pen_rate_month) %>%
  arrange(sta5a, crh_month) %>% 
  group_by(sta5a) %>%
  mutate(rowNum = row_number(),
         first_6_months_w_6 = case_when(
           rowNum < 7 & crh_encounter_count > 5 ~ 1,
           TRUE ~ 0),
         first_6_months_w_10 = case_when(
           rowNum < 7 & crh_encounter_count > 9 ~ 1,
           TRUE ~ 0)) %>%
  group_by(sta5a) %>%
  summarise(first_6_mos_w_6_flag = if_else(sum(first_6_months_w_6, na.rm = T) >= 6, 1, 0),
            first_6_mos_w_10_flag = if_else(sum(first_6_months_w_10, na.rm = T) >= 6, 1, 0))
#---===
yoon_flag <- all_sta5a %>%
  mutate(yoon_5_flag = if_else(sta5a %in% yoon_5_sta5as, 1, 0),
         yoon_10_flag = if_else(sta5a %in% yoon_10_sta5as, 1, 0),
         crh_flag = 1) %>%
  left_join(., first_n_month_flags)
#
table_id <- DBI::Id(schema = "crh_eval", table = "yoon_flag")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = yoon_flag,
                  overwrite = TRUE)
