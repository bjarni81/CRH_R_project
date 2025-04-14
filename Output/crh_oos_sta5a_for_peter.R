library(tidyverse)
library(DBI)
library(lubridate)
library(here)
##---------- Connection to PACT_CC
pactcc_con <- dbConnect(odbc::odbc(),
                        Driver = "SQL Server",
                        Server = "vhacdwsql13.vha.med.va.gov",
                        Database = "PACT_CC",
                        Trusted_Connection = "true")
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
# VAST
vast <- read_csv(here("Input", "Data", "vast_from_a06.csv"))
#
vast_to_include <- vast %>%
  select(sta5a)
# crh flags
crh_flags <- dbGetQuery(oabi_con,
                        "select * from [crh_eval].yoon_flag")
#-------
pc_crh_encounters <- dbGetQuery(pactcc_con,
                                "select * from [CRH].C_crh_utilization_final
                                where care_type = 'Primary Care' AND (fy in(2020, 2021) OR (fy = 2022 AND qtr = 1))") %>%
  rename(sta5a = spoke_sta5a_combined_cdw) %>%
  mutate(visitdate = ymd(visitdate),
         crh_month = ymd(str_c(year(visitdate), month(visitdate), "01", sep = "-"))) %>%
  inner_join(., vast_to_include)
#===
oos_crh <- pc_crh_encounters %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  left_join(., vast %>% select(sta5a, s_abbr, scrssn_count_cat)) %>%
  filter(s_abbr == "OOS" & table_1_columns == "CRH") %>%
  group_by(sta5a) %>%
  summarise(crh_encounters = n()) %>%
  arrange(desc(crh_encounters)) %>%
  left_join(., vast %>% select(sta5a, short_name, state, scrssn_count_cat)) %>%
  mutate(scrssn_count_cat = if_else(is.na(scrssn_count_cat) == T, "No PCMM", scrssn_count_cat))
#
write_csv(oos_crh,
          here("Output", "crh_oos_sta5a.csv"),
          na = "-")
