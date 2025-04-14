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
#
options(scipen = 999)
###
`%ni%` <- negate(`%in%`)
#***&&&***&&&***&&&***
all_months <- tibble(vssc_month = seq.Date(dmy("01-10-2018"), dmy("01-12-2021"), by = "1 month"))
#***&&&***&&&***&&&***
vast <- read_csv(here("Input","Data","VAST_from_A06_11jan21.csv"))
#***&&&***&&&***&&&***
con <-'driver={SQL Server}; 
        server=vhacdwsql13.vha.med.va.gov;
        database=OABI_MyVAAccess;
        trusted_connection=true'
#
channel <- odbcDriverConnect(connection = con)
#=========
timely_care_daysDV <- sqlQuery(channel, 
                               "SELECT * FROM [crh_eval].C1_daysDV_month_sta5a", 
                               stringsAsFactors=FALSE) %>%
  mutate(viz_month = ymd(viz_month))
#***&&&***&&&***&&&***
access_path <- list.files(path = here("Input", "Data", "VSSC"),
                          full.names = T, pattern = "sta5a_month")
#
avg_3rd_next_available <- read_xlsx(path = access_path[1],
                                    skip = 3) %>%
  rename(full_name = Division) %>%
  pivot_longer(-full_name,
               values_to = "avg_3rd_next_available") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, avg_3rd_next_available)
#
pc_staff_ratio <- read_xlsx(path = access_path[2],
                            skip = 3) %>%
  rename(full_name = Division) %>%
  pivot_longer(-full_name,
               values_to = "pc_staff_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, pc_staff_ratio)
#
established_pt_waitTime <- read_xlsx(path = access_path[3],
                                     skip = 3) %>%
  rename(full_name = Division) %>%
  slice(-1) %>%
  pivot_longer(-full_name,
               values_to = "established_pt_waitTime") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, established_pt_waitTime)
#
new_pt_waitTime <- read_xlsx(path = access_path[4],
                             skip = 3) %>%
  rename(full_name = Division) %>%
  pivot_longer(-full_name,
               values_to = "new_pt_waitTime") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, new_pt_waitTime)
#
obs_expected_panel_size_ratio <- read_xlsx(path = access_path[5],
                                           skip = 3) %>%
  rename(full_name = Division) %>%
  slice(-1) %>%
  pivot_longer(-full_name,
               values_to = "obs_expected_panel_size_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, obs_expected_panel_size_ratio)
#
same_day_appts_wPC_provider_ratio <- read_xlsx(path = access_path[6],
                                               skip = 3) %>%
  rename(full_name = Division) %>%
  pivot_longer(-full_name,
               values_to = "same_day_appts_wPC_provider_ratio") %>%
  mutate(month.n = match(str_to_title(str_sub(name, end = 3)), month.abb),
         fy = as.numeric(str_c("20", str_sub(name, start = -2))),
         cy = if_else(month.n > 9, fy - 1, fy),
         vssc_month = dmy(str_c("01", month.n, cy, sep = "-")),
         sta5a = if_else(str_sub(full_name, start = 11, end = 11) == ")",
                         str_sub(full_name, start = 8, end = 10),
                         str_sub(full_name, start = 8, end = 12))) %>%
  select(sta5a, vssc_month, same_day_appts_wPC_provider_ratio)
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_sta5a <- avg_3rd_next_available %>% select(sta5a) %>%
  bind_rows(., established_pt_waitTime %>% select(sta5a)) %>%
  bind_rows(., new_pt_waitTime %>% select(sta5a)) %>%
  bind_rows(., obs_expected_panel_size_ratio %>% select(sta5a)) %>%
  bind_rows(., pc_staff_ratio %>% select(sta5a)) %>%
  bind_rows(., same_day_appts_wPC_provider_ratio %>% select(sta5a)) %>%
  bind_rows(., timely_care_daysDV %>% select(sta5a = req_sta5a)) %>%
  distinct() %>%
  full_join(., all_months, by = character())
#**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^**^^
all_pc_access_metrics <- all_sta5a %>%
  left_join(., established_pt_waitTime) %>%
  left_join(., new_pt_waitTime) %>%
  left_join(., obs_expected_panel_size_ratio) %>%
  left_join(., pc_staff_ratio) %>%
  left_join(., same_day_appts_wPC_provider_ratio) %>%
  left_join(., timely_care_daysDV %>% select(-c(viz_fy, viz_qtr)), by = c("vssc_month" = "viz_month", "sta5a" = "req_sta5a"))
#----------------
write_csv(all_pc_access_metrics,
          here("Input", "Data", "pc_access_metrics.csv"))
