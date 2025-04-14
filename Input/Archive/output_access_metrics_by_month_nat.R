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
#***&&&***&&&***&&&***
all_months <- tibble(vssc_month = seq.Date(dmy("01-10-2019"), dmy("01-09-2021"), by = "1 month"))
#***&&&***&&&***&&&***
vast <- read_csv(here("Input","Data","VAST_from_A06_11jan21.csv"))
#***&&&***&&&***&&&***
oabi_con <- dbConnect(odbc::odbc(), Driver = "SQL Server", Server = "vhacdwsql13.vha.med.va.gov", 
                      Database = "OABI_MyVAAccess", Truested_Connection = "true")
#=========
timely_care_daysDV <- dbGetQuery(oabi_con, 
                               "SELECT * FROM [crh_eval].C4_daysDV_month_nat", 
                               stringsAsFactors=FALSE) %>%
  mutate(vssc_month = ymd(viz_month)) %>%
  select(-c(viz_qtr, viz_fy, viz_month))
#***&&&***&&&***&&&***
access_path <- list.files(path = here("Input", "Data", "VSSC"),
                          full.names = T,
                          pattern = "nat")
#=====
avg_3rd_next_available <- read_xlsx(path = access_path[1],
                                    skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "avg_3rd_next_available") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, avg_3rd_next_available)
#
pc_staff_ratio <- read_xlsx(path = access_path[2],
                                    skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "pc_staff_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, pc_staff_ratio)
#
established_pt_waitTime <- read_xlsx(path = access_path[3],
                            skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "established_pt_waitTime") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, established_pt_waitTime)
#
new_pt_waitTime <- read_xlsx(path = access_path[4],
                                     skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "new_pt_waitTime") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, new_pt_waitTime)
#
obs_expected_panel_size_ratio <- read_xlsx(path = access_path[5],
                             skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "obs_expected_panel_size_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, obs_expected_panel_size_ratio)
#
same_day_appts_wPC_provider_ratio <- read_xlsx(path = access_path[6],
                                           skip = 3) %>%
  rename(national = `...1`) %>%
  pivot_longer(-national,
               values_to = "same_day_appts_wPC_provider_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-"))) %>%
  select(vssc_month, same_day_appts_wPC_provider_ratio)
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_pc_access_metrics <- all_months %>%
  left_join(., established_pt_waitTime) %>%
  left_join(., new_pt_waitTime) %>%
  left_join(., obs_expected_panel_size_ratio) %>%
  left_join(., pc_staff_ratio) %>%
  left_join(., same_day_appts_wPC_provider_ratio) %>%
  left_join(., timely_care_daysDV)
#----------------
write_csv(all_pc_access_metrics,
          here("Input", "Data", "pc_access_metrics_nat.csv"))
