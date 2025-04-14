library(tidyverse)
library(readxl)
library(ggplot2)
library(ggthemes)
library(kableExtra)
library(lubridate)
library(scales)
library(grid)
library(DT)
library(RODBC)
library(DBI)
#
options(scipen = 999)
###
`%ni%` <- negate(`%in%`)
#----------
vast <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Data - Shared/VAST_from_A06_11jan21.csv")
#
vast_parent <- vast %>% select(sta5a, parent_sta5a = parent_station_sta5a)
#
all_months <- tibble(all_months = seq.Date(dmy("01-10-2019"), dmy("01-09-2021"), by = "1 month"))
#-----------------=========================== CRH ENCOUNTERS
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Truested_Connection = "true")
#
crh_encounters_1 <- dbGetQuery(oabi_con,
                               "select *
                               from [OABI_MyVAAccess].[crh_eval].crh_all") %>%
  rename_all(tolower) %>%
  janitor::clean_names() %>%
  mutate(visitdate = ymd(visitdate),
         visitdate = dmy(str_c("01", month(visitdate), year(visitdate), sep = "-")),
         fy = if_else(month(visitdate) > 9, year(visitdate) + 1, year(visitdate)),
         qtr = case_when(month(visitdate) %in% c(10, 11, 12) ~ 1,
                         month(visitdate) %in% c(1, 2, 3) ~ 2,
                         month(visitdate) %in% c(4, 5, 6) ~ 3,
                         month(visitdate) %in% c(7, 8, 9) ~ 4),
         flag_693 = if_else(secondary_stop_code == 693, 1, 0)) %>%
  left_join(., vast, by = c("spoke_sta5a" = "sta5a")) %>%
  filter(flag_693 %ni% 1)
#
crh_encounters_2 <- crh_encounters_1 %>%
  arrange(scrssn, visitdate, spoke_sta5a) %>%
  group_by(scrssn, visitdate) %>%
  mutate(scrssn_vizday_rn = row_number()) %>%
  ungroup()
#---
double_scrssns <- crh_encounters_2 %>% 
  filter(scrssn_vizday_rn == 2) %>%
  select(scrssn, visitdate, sta5a2 = spoke_sta5a, psc2 = primary_stop_code, ssc2 = secondary_stop_code)
#
crh_encounters_3 <- crh_encounters_2 %>%
  filter(scrssn_vizday_rn == 1) %>%
  left_join(double_scrssns) %>%
  mutate(sta5a_joined = case_when(is.na(spoke_sta5a) == T & is.na(sta5a2) == F ~ sta5a2,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == T ~ spoke_sta5a,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a == sta5a2 ~ sta5a2,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a != sta5a2 ~ sta5a2),
         psc_joined = case_when(primary_stop_code != 674 ~ primary_stop_code,
                                primary_stop_code == 674 ~ location_secondary_sc),
         ssc_joined = if_else(is.na(secondary_stop_code), ssc2, secondary_stop_code)) 
#
crh_encounters <- crh_encounters_3 %>%
  mutate(care_type = 
           case_when(
             (psc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348) 
              & (ssc_joined != 160 | is.na(ssc_joined) == T)) 
             | (psc_joined != 160 
                & ssc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care crh",
             (psc_joined %in% c(502, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587) 
              & (ssc_joined %ni% c(160, 534) | is.na(ssc_joined) == T)) 
             | (psc_joined %ni% c(160, 534)
                & ssc_joined %in% c(502, 510, 513, 516, 527, 538, 545, 550, 
                                    562, 576, 579, 586, 587))                  ~ "Mental Health crh",
             (psc_joined %in% c(534, 539) 
              & (ssc_joined != 160 | is.na(ssc_joined) == T)) 
             | (psc_joined != 160 & ssc_joined %in% c(534, 539)) ~ "PCMHI crh",
             psc_joined == 160 | ssc_joined == 160  ~ "Pharmacy crh",
             is.na(psc_joined) == T ~ "Missing crh",
             TRUE                                                                                  ~ "Specialty crh"),
         crh_month = dmy(str_c("01",month(visitdate), year(visitdate), sep = "-")))
#===================
crh_enc_sta5a_month <- crh_encounters %>%
  group_by(spoke_sta5a, crh_month) %>%
  summarise(encounters_crh = n())
#
crh_enc_sta5a_month_type <- crh_encounters %>%
  group_by(spoke_sta5a, crh_month, care_type) %>%
  summarise(crh_encounters = n()) %>%
  mutate(care_type = str_replace_all(tolower(care_type), " ", "_")) %>%
  pivot_wider(names_from = care_type, values_from = crh_encounters, values_fill = 0)
#-----------------=========================== COVERAGE
first_crh_cov_month_sta5a <- crh_encounters %>%
  group_by(spoke_sta5a) %>%
  summarise(first_crh_cov_month = min(crh_month))
#=========
daysDV_sta5a <- dbGetQuery(oabi_con, 
                         "SELECT * FROM [crh_eval].C1_daysDV_month_sta5a") %>%
  mutate(viz_month = ymd(viz_month))
#---===
encounters <- dbGetQuery(oabi_con,
                         "select * from [crh_eval].encounter_counts") %>%
  select(-contains("CovidVax")) %>%
  mutate(vizMonth = ymd(vizMonth))

#---===---===---===---===
# Average # of CRH Encounters over period - for cleaning
#---===---===---===---===
avg_tot_encounters <- crh_enc_sta5a_month %>%
  filter(crh_month > dmy("01-09-2019")) %>%
  group_by(spoke_sta5a) %>%
  summarise(mean_tot_crh_encounters = round(mean(encounters_crh, na.rm = T), 1)) 
#
avg_encounters_type <- crh_encounters %>%
  filter(crh_month > dmy("01-09-2019")) %>%
  group_by(spoke_sta5a, crh_month, care_type) %>%
  summarise(crh_encounters = n()) %>%
  mutate(care_type = str_replace_all(tolower(care_type), " ", "_")) %>%
  group_by(spoke_sta5a, care_type) %>%
  summarise(mean_type_crh_encounters = round(mean(crh_encounters, na.rm = T), 1)) %>%
  pivot_wider(names_from = care_type, values_from = mean_type_crh_encounters, values_fill = 0) %>%
  rename_with(.cols = contains("crh"), .fn = ~paste0("mean_", .x))
#---===---===---===---===
# PC Access Metrics
#---===---===---===---===
pc_access_metrics <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Data - Shared/pc_access_metrics.csv")
#---===---===---===---===
# All sta5as to start join
#---===---===---===---===
all_sta5a <- crh_encounters %>%
  select(spoke_sta5a) %>%
  distinct
#---===---===---===---===
# Putting them all together ------
#---===---===---===---===
analytic_df <- all_sta5a %>%
  full_join(., all_months, by = character()) %>%
  left_join(., crh_enc_sta5a_month, by = c("spoke_sta5a" = "spoke_sta5a", "all_months" = "crh_month")) %>%
  left_join(., crh_enc_sta5a_month_type, by = c("spoke_sta5a" = "spoke_sta5a", "all_months" = "crh_month")) %>%
  left_join(., encounters, by = c("spoke_sta5a" = "sta6a", "all_months" = "vizMonth")) %>%
  left_join(., avg_tot_encounters, by = c("spoke_sta5a" = "spoke_sta5a")) %>%
  left_join(., avg_encounters_type, by = c("spoke_sta5a" = "spoke_sta5a")) %>%
  left_join(., pc_access_metrics, by = c("spoke_sta5a" = "sta5a", "all_months" = "vssc_month")) %>%
  left_join(., vast %>% 
              select(sta5a, short_name, parent_visn), by = c("spoke_sta5a" = "sta5a")) %>%
  distinct %>%
  arrange(spoke_sta5a, all_months) %>%
  group_by(spoke_sta5a) %>%
  mutate(crh_time = row_number())
#-----
write_csv(analytic_df,
          "H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/Data/analytic_df_v3_29sep21.csv")

