library(tidyverse)
library(lubridate)
library(odbc)
#library(RODBC)
library(DBI)
library(haven)
library(here)
#
`%ni%` <- negate(`%in%`)
##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#--------
# Importing and cleaning FY 19
#--------
shep_fy19 <- read_sas("//vhacdwdwhapp15.vha.med.va.gov/PACT_CC/PACT_DATA/SHEP/PCMH/dua2020_007_pcmh_fy19.sas7bdat") %>%
  zap_formats() %>%
  zap_label() %>%
  mutate(shep_viz_month = ymd(str_c(year(VIZDAY), month(VIZDAY), "01", sep = "-")),
         q_6_always = case_when(
           CareReceived_P1 == 4 ~ 1,
           CareReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_9_always = case_when(
           CheckupReceived_P1 == 4 ~ 1,
           CheckupReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_14_always = case_when(
           QuestionOfficehoursAnswer_P1 == 4 ~ 1,
           QuestionOfficehoursAnswer_P1 %in% c(1, 2, 3) ~ 0)) %>% 
  rename_all(tolower) %>%
  select(sta5a, shep_viz_month, q_6_always, q_9_always, q_14_always, weight)
#--------
# Importing and cleaning FY 20
#--------
shep_fy20 <- read_sas("//vhacdwdwhapp15.vha.med.va.gov/PACT_CC/PACT_DATA/SHEP/PCMH/dua2020_007_pcmh_fy20.sas7bdat") %>%
  zap_formats() %>%
  zap_label() %>%
  mutate(shep_viz_month = ymd(str_c(year(VIZDAY), month(VIZDAY), "01", sep = "-")),
         q_6_always = case_when(
           CareReceived_P1 == 4 ~ 1,
           CareReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_9_always = case_when(
           CheckupReceived_P1 == 4 ~ 1,
           CheckupReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_14_always = case_when(
           QuestionOfficehoursAnswer_P1 == 4 ~ 1,
           QuestionOfficehoursAnswer_P1 %in% c(1, 2, 3) ~ 0)) %>% 
  rename_all(tolower) %>%
  select(sta5a, shep_viz_month, q_6_always, q_9_always, q_14_always, weight)
#--------
# Importing and cleaning FY 21
#--------
shep_fy21 <- read_sas("//vhacdwdwhapp15.vha.med.va.gov/PACT_CC/PACT_DATA/SHEP/PCMH/dua2020_007_pcmh_fy21.sas7bdat") %>%
  zap_formats() %>%
  zap_label() %>%
  mutate(shep_viz_month = ymd(str_c(year(VIZDAY), month(VIZDAY), "01", sep = "-")),
         q_6_always = case_when(
           CareReceived_P1 == 4 ~ 1,
           CareReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_9_always = case_when(
           CheckupReceived_P1 == 4 ~ 1,
           CheckupReceived_P1 %in% c(1, 2, 3) ~ 0),
         q_14_always = case_when(
           QuestionOfficehoursAnswer_P1 == 4 ~ 1,
           QuestionOfficehoursAnswer_P1 %in% c(1, 2, 3) ~ 0)) %>% 
  rename_all(tolower) %>%
  select(sta5a, shep_viz_month, q_6_always, q_9_always, q_14_always, weight)
#----====----====----====
shep_all <- shep_fy21 %>%
  bind_rows(., shep_fy20) %>% 
  bind_rows(., shep_fy19) %>%
  filter(is.na(weight) == F)
#------=======-------======-------=======-------=======
shep_summary_sta5a_1 <- shep_all %>%
  group_by(shep_viz_month, sta5a) %>%
  summarise(q_6_always_wgt = if_else(is.nan(weighted.mean(q_6_always, weight, na.rm = T)),
                                     NA_real_,
                                     weighted.mean(q_6_always, weight, na.rm = T)),
            q_9_always_wgt = if_else(is.nan(weighted.mean(q_9_always, weight, na.rm = T)),
                                     NA_real_,
                                     weighted.mean(q_9_always, weight, na.rm = T)),
            q_14_always_wgt = if_else(is.nan(weighted.mean(q_14_always, weight, na.rm = T)),
                                      NA_real_,
                                      weighted.mean(q_14_always, weight, na.rm = T))) %>%
  mutate(has_all_3_access_qs = if_else(is.na(q_6_always_wgt) == F
                                       & is.na(q_9_always_wgt) == F
                                       & is.na(q_14_always_wgt) == F,
                                       TRUE, FALSE))
#
rowWise_mean <- shep_summary_sta5a_1 %>%
  select(-has_all_3_access_qs) %>%
  pivot_longer(-c(sta5a, shep_viz_month)) %>%
  group_by(sta5a, shep_viz_month) %>%
  summarise(shep_access_metric = mean(value, na.rm = T))
#--
shep_summary_sta5a <- shep_summary_sta5a_1 %>%
  left_join(., rowWise_mean) %>% 
  mutate(shep_access_metric = if_else(is.na(shep_access_metric) |
                                        is.nan(shep_access_metric) |
                                        is.infinite(shep_access_metric), NA_real_, shep_access_metric))
#================================================
#outputting a .csv
write_csv(shep_summary_sta5a,
          here("Input", "Analytic df", "Data", "shep_access_summary_sta5a_month.csv"))
#================================================
# outputting to OABI_MyVAAccess
oabi_connect <- dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
table_id <- DBI::Id(schema = "crh_eval", table = "E1_SHEP_sta5a_month")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = shep_summary_sta5a,
                  overwrite = TRUE)
