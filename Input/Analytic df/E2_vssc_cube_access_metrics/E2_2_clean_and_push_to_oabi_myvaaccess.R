library(tidyverse)
library(DBI)
library(here)
library(lubridate)
#--
access_metrics <- list.files(path = here("Input", "Analytic df", "E2_vssc_cube_access_metrics"),
                             pattern = "sta6a_month",
                             full.names = TRUE)
#--
established_pt_wt <- read_csv(access_metrics[1]) %>%
  rename_all(tolower) %>%
  rename(date = 1) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, est_pc_pt_wt = 3)
#--
new_pt_wt <- read_csv(access_metrics[2]) %>%
  rename_all(tolower) %>%
  rename(date = 1) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, new_pc_pt_wt = 3)
#--
tna <- read_csv(access_metrics[3]) %>%
  rename_all(tolower) %>%
  rename(date = 1) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, third_next_avail = 3)
#--
tna2 <- read_csv(here("Input", "Data", "VSSC", "Appointments - Completed Summary",
                         "3rd_next_avail_new_source.csv")) %>%
  rename_all(tolower) %>%
  rename(date = 2,
         div_name = 1,
         tna_new_source = 3) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")),
         sta5a = if_else(str_sub(div_name, start = 11, end = 11) == ")",
                         str_sub(div_name, start = 8, end = 10),
                         str_sub(div_name, start = 8, end = 12)),
         tna_new_source = as.character(round(tna_new_source, 2))) %>%
  select(vssc_month, sta5a, tna_new_source)
#--
est_pid <- read_csv(here("Input", "Data", "VSSC", "Appointments - Completed Summary",
                         "appt_cube_est_pt_wt_from_indicated.csv")) %>%
  rename_all(tolower) %>%
  rename(date = 1,
         div_name = 2) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")),
         sta5a = if_else(str_sub(div_name, start = 11, end = 11) == ")",
                         str_sub(div_name, start = 8, end = 10),
                         str_sub(div_name, start = 8, end = 12))) %>%
  select(vssc_month, sta5a, est_pc_pt_wt_pid = 3)
#--
new_create <- read_csv(here("Input", "Data", "VSSC", "Appointments - Completed Summary",
                         "appt_cube_new_pt_wt_create_date.csv")) %>%
  rename_all(tolower) %>%
  rename(date = 1,
         div_name = 2) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")),
         sta5a = if_else(str_sub(div_name, start = 11, end = 11) == ")",
                         str_sub(div_name, start = 8, end = 10),
                         str_sub(div_name, start = 8, end = 12))) %>%
  select(vssc_month, sta5a, new_pc_pt_wt_create = 3)
#--
new_0_20_days_create <- read_csv(here("Input", "Data", "VSSC", "Appointments - Completed Summary",
                                      "appt_cube_new_pt_pct_appts_0_20_days_create.csv")) %>%
  rename_all(tolower) %>%
  rename(date = 1,
         div_name = 2) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")),
         sta5a = if_else(str_sub(div_name, start = 11, end = 11) == ")",
                         str_sub(div_name, start = 8, end = 10),
                         str_sub(div_name, start = 8, end = 12))) %>%
  select(vssc_month, sta5a, new_0_20_days_create = 3)
#--
panel_fullness <- read_csv(here("Input", "Data",
                                "panel_fullness_sta5a_month.csv")) %>%
  rename_all(tolower) %>%
  rename(date = 1,
         div_name = 2) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         fy = as.numeric(str_sub(date, start = -2)),
         cy2 = if_else(month_n > 9, fy - 1, fy),
         cy = as.numeric(str_c("20", cy2)),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")),
         sta5a = div_name) %>%
  select(vssc_month, sta5a, panel_fullness = 3)
#=======
all_months <- tibble(
  vssc_month = seq.Date(ymd("2017-10-01"), ymd("2023-09-01"), "1 month"))
#
all_sta5a <- established_pt_wt %>% select(sta5a) %>%
  bind_rows(., new_pt_wt %>% select(sta5a)) %>%
  bind_rows(., tna %>% select(sta5a)) %>%
  distinct
#+++++++
vssc_pc_access_metrics <- all_sta5a %>%
  cross_join(., all_months) %>%
  left_join(., established_pt_wt) %>%
  left_join(., new_pt_wt) %>%
  left_join(., tna) %>%
  left_join(., est_pid) %>%
  left_join(., new_create) %>%
  left_join(., tna2) %>%
  left_join(., new_0_20_days_create) %>%
  left_join(., panel_fullness)
#
summary(vssc_pc_access_metrics)
#================================================
# outputting to OABI_MyVAAccess
oabi_connect <- dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
table_id <- DBI::Id(schema = "crh_eval", table = "E2_VSSC_access_metrics")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = vssc_pc_access_metrics,
                  overwrite = TRUE)
