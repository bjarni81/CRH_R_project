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
library(here)
library(DBI)
#
options(scipen = 999)
###
`%ni%` <- negate(`%in%`)
###
all_qtrs <- tibble(fy_qtr = c("2020_1", "2020_2", "2020_3", "2020_4",
                              "2021_1", "2021_2", "2021_3", "2021_4"))
#***&&&***&&&***&&&***
vast <- read_csv(here("Input","Data","VAST_from_A06_11jan21.csv"))
#***&&&***&&&***&&&***
oabi_con <- dbConnect(odbc::odbc(), Driver = "SQL Server", Server = "vhacdwsql13.vha.med.va.gov", 
                      Database = "OABI_MyVAAccess", Truested_Connection = "true")
#====================+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timely_care_daysDV <- dbGetQuery(oabi_con, 
                               "SELECT * FROM [crh_eval].C4_daysDV_qtr_nat", 
                               stringsAsFactors=FALSE)
#***&&&***&&&***&&&***
access_path <- list.files(path = here("Input", "Data", "VSSC"),
                          full.names = T,
                          pattern = "nat_qtr")
#=====
established_pt_waitTime <- read_xlsx(path = access_path[1],
                            skip = 4) %>%
  select(-`AUG-FY21`) %>%
  rename(national = `All`) %>%
  pivot_longer(-national,
               values_to = "established_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_")) %>%
  select(-c(national, name, fy, qtr))
#
new_pt_waitTime <- read_xlsx(path = access_path[2],
                             skip = 3) %>%
  select(-`AUG-FY21`) %>%
  rename(national = `All`) %>%
  pivot_longer(-national,
               values_to = "new_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_")) %>%
  select(-c(national, name, fy, qtr))
#
obs_expected_panel_size_ratio <- read_xlsx(path = access_path[3],
                             skip = 3) %>%
  slice(-1) %>%
  select(-`AUG-FY21`) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "obs_exp_panelSize_ratio") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_"),
         obs_exp_panelSize_ratio = round(as.numeric(obs_exp_panelSize_ratio), 3)) %>%
  select(-c(national, name, fy, qtr))
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_pc_access_metrics_nat <- all_qtrs %>%
  left_join(., established_pt_waitTime) %>%
  left_join(., new_pt_waitTime) %>%
  left_join(., obs_expected_panel_size_ratio) %>%
  left_join(., timely_care_daysDV)
#----------------
write_csv(all_pc_access_metrics_nat,
          here("Input", "Data", "pc_access_metrics_nat_qtr.csv"))
#====================+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timely_care_daysDV_visn <- dbGetQuery(oabi_con, 
                                 "SELECT * FROM [crh_eval].C3_daysDV_qtr_visn", 
                                 stringsAsFactors=FALSE) %>%
  mutate(visn = str_pad(parent_visn, pad = "0", side = "left", width = 2))
#***&&&***&&&***&&&***
access_path <- list.files(path = here("Input", "Data", "VSSC"),
                          full.names = T,
                          pattern = "visn_qtr")
#=====
established_pt_waitTime_visn <- read_xlsx(path = access_path[1],
                                     skip = 3) %>%
  select(-`AUG-FY21`) %>%
  pivot_longer(-VISN,
               values_to = "established_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_"), 
         visn = str_sub(VISN, start = -2)) %>%
  select(-c(VISN, name, fy, qtr))
#
new_pt_waitTime_visn <- read_xlsx(path = access_path[2],
                             skip = 3) %>%
  select(-`AUG-FY21`) %>%
  pivot_longer(-VISN,
               values_to = "new_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_"), 
         visn = str_sub(VISN, start = -2)) %>%
  select(-c(VISN, name, fy, qtr))
#
obs_expected_panel_size_ratio_visn <- read_xlsx(path = access_path[3],
                                           skip = 3) %>%
  slice(-1) %>%
  select(-`AUG-FY21`) %>%
  rename(VISN = `...1`) %>%
  pivot_longer(-VISN,
               values_to = "obs_exp_panelSize_ratio") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_"),
         obs_exp_panelSize_ratio = round(as.numeric(obs_exp_panelSize_ratio), 3), 
         visn = str_sub(VISN, start = -2)) %>%
  select(-c(VISN, name, fy, qtr))
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_pc_access_metrics_visn <- all_qtrs %>%
  left_join(., established_pt_waitTime_visn) %>%
  left_join(., new_pt_waitTime_visn) %>%
  left_join(., obs_expected_panel_size_ratio_visn) %>%
  left_join(., timely_care_daysDV_visn)
#----------------
write_csv(all_pc_access_metrics_visn,
          here("Input", "Data", "pc_access_metrics_visn_qtr.csv"))
#====================+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timely_care_daysDV_sta5a <- dbGetQuery(oabi_con, 
                                      "SELECT * FROM [crh_eval].C1_daysDV_qtr_sta5a", 
                                      stringsAsFactors=FALSE) %>%
  rename(sta6a = req_sta5a)
#***&&&***&&&***&&&***
access_path <- list.files(path = here("Input", "Data", "VSSC"),
                          full.names = T,
                          pattern = "sta5a_qtr")
#=====
established_pt_waitTime_sta5a <- read_xlsx(path = access_path[1],
                                          skip = 3) %>%
  select(-c(`AUG-FY21`, Division)) %>%
  rename_all(tolower) %>%
  pivot_longer(-sta6a,
               values_to = "established_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_")) %>%
  select(-c(name, fy, qtr))
#
new_pt_waitTime_sta5a <- read_xlsx(path = access_path[2],
                                  skip = 3) %>%
  select(-`AUG-FY21`, -Division) %>%
  rename_all(tolower) %>%
  pivot_longer(-sta6a,
               values_to = "new_pt_waitTime") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_")) %>%
  select(-c(name, fy, qtr))
#
obs_expected_panel_size_ratio_sta5a <- read_xlsx(path = access_path[3],
                                                skip = 3) %>%
  slice(-1) %>%
  select(-`AUG-FY21`, -`...2`) %>%
  rename_all(tolower) %>%
  rename(sta6a = `...1`) %>%
  pivot_longer(-sta6a,
               values_to = "obs_exp_panelSize_ratio") %>%
  mutate(fy = as.numeric(str_c("20", str_sub(name, start = 3, end = 4))),
         qtr = str_sub(name, start = -1),
         fy_qtr = str_c(fy, qtr, sep = "_"),
         obs_exp_panelSize_ratio = round(as.numeric(obs_exp_panelSize_ratio), 3)) %>%
  select(-c(name, fy, qtr))
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_sta5a <- timely_care_daysDV_sta5a %>%
  select(sta6a) %>%
  distinct()
#
all_pc_access_metrics_sta5a <- all_qtrs %>%
  full_join(., all_sta5a, by = character()) %>%
  left_join(., established_pt_waitTime_sta5a) %>%
  left_join(., new_pt_waitTime_sta5a) %>%
  left_join(., obs_expected_panel_size_ratio_sta5a) %>%
  left_join(., timely_care_daysDV_sta5a)
#----------------
write_csv(all_pc_access_metrics_sta5a,
          here("Input", "Data", "pc_access_metrics_sta5a_qtr.csv"))
