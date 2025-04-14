library(tidyverse)
library(lubridate)
#
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#-
dates <- tibble(
  vssc_month = seq.Date(ymd("2020-10-01"), ymd("2022-09-01"), "1 month")) %>%
  mutate(fy = if_else(month(vssc_month) > 9, year(vssc_month) + 1, year(vssc_month)),
         qtr = case_when(month(vssc_month) %in% c(10, 11, 12) ~ 1,
                         month(vssc_month) %in% c(1, 2, 3) ~ 2,
                         month(vssc_month) %in% c(4, 5, 6) ~ 3,
                         month(vssc_month) %in% c(7, 8, 9) ~ 4,
                         TRUE ~ 99))
#-
#average age on october 1st 2022
age_sta5a_qtr <- DBI::dbGetQuery(oabi_con,
                                 "select * from [OABI_MyVAAccess].[crh_eval].D1_age_sta5a_qtr")
#sta5a-fy-specific counts of gender, race, and urh, as well as total uniques
race_gender_urh <- DBI::dbGetQuery(oabi_con,
                                   "select * from [OABI_MyVAAccess].[crh_eval].D2_race_gender_urh_count") %>%
  mutate(pct_male = male_count / scrssn_count * 100,
         pct_white = race_white_count / scrssn_count * 100,
         pct_rural = urh_rural_count / scrssn_count * 100)
#sta5a-fy_qtr-specific average ADI and quartile counts, as well as total
adi_sta5a_fy <- DBI::dbGetQuery(oabi_con,
                                "select * from [OABI_MyVAAccess].[crh_eval].D3_adi_sta5a_fy")
#-
sta5as <- readr::read_csv(here::here("Output", "For Steven", "sta5a_inclusion_unique 20240720.csv")) %>%
  select(sta5a)
#--
dates %>%
  select(vssc_month) %>%
  cross_join(., sta5as) %>%
  left_join(., dates) %>%
  left_join(., adi_sta5a_fy %>%
              select(sta5a = Sta5a, fy, adi_natRnk_avg)) %>%
  left_join(., age_sta5a_qtr %>%
              select(sta5a = Sta5a, fy = FY, qtr = QTR, avg_age_oct1_2022)) %>%
  left_join(., race_gender_urh %>%
              mutate(proportion_black = race_black_count / scrssn_count,
                     proportion_white = race_white_count / scrssn_count,
                     proportion_other = race_other_count / scrssn_count,
                     proportion_male = pct_male / 100) %>%
              select(sta5a = Sta5a, fy = FY, proportion_male, proportion_black, proportion_white, proportion_other)) %>%
  arrange(sta5a, vssc_month) %>%
  readr::write_csv(.,
                   here::here("Output", "For Steven", "sta5a_demog_22jul24.csv"))
