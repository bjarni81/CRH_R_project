library(tidyverse)
library(DBI)
library(here)
library(lubridate)
#--
vssc_covars <- list.files(path = here("Input", "Analytic df", "F_propensity_score_covariates", "Propensity Score Covariates from VSSC"),
                             pattern = "month",
                             full.names = TRUE)
#--
nosos <- read_csv(vssc_covars[1]) %>%
  rename_all(tolower) %>%
  rename(date = `fiscal date`, nosos_risk_score = `nosos risk score`) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         cy = if_else(month_n < 10, as.numeric(str_c("20", str_sub(date, start = -2))),
                      as.numeric(str_c("20", str_sub(date, start = -2))) - 1),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, nosos_risk_score)
#--
obs_exp <- read_csv(vssc_covars[2]) %>%
  rename_all(tolower) %>%
  rename(date = `fiscal date`, obs_exp_panel_ratio = 3) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         cy = if_else(month_n < 10, as.numeric(str_c("20", str_sub(date, start = -2))),
                      as.numeric(str_c("20", str_sub(date, start = -2))) - 1),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, obs_exp_panel_ratio)
#--
team_pcpAP_fte <- read_csv(vssc_covars[3]) %>%
  rename_all(tolower) %>%
  rename(date = `fiscal date`, team_pcp_ap_fte_total = 3) %>%
  mutate(month_n = match(str_to_title(str_sub(date, end = 3)), month.abb),
         cy = if_else(month_n < 10, as.numeric(str_c("20", str_sub(date, start = -2))),
                      as.numeric(str_c("20", str_sub(date, start = -2))) - 1),
         vssc_month = ymd(str_c(cy, month_n, "01", sep = "-"))) %>%
  select(vssc_month, sta5a = sta6a, team_pcp_ap_fte_total)
#=======
all_months <- nosos %>% select(vssc_month) %>% distinct
#
all_sta5a <- nosos %>% select(sta5a) %>%
  bind_rows(., obs_exp %>% select(sta5a)) %>%
  bind_rows(., team_pcpAP_fte %>% select(sta5a)) %>%
  distinct
#+++++++
vssc_ps_covars <- all_sta5a %>%
  full_join(., all_months, by = character()) %>%
  left_join(., nosos) %>%
  left_join(., obs_exp) %>%
  left_join(., team_pcpAP_fte)

#================================================
# outputting to OABI_MyVAAccess
oabi_connect <- dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
table_id <- DBI::Id(schema = "crh_eval", table = "F1_2_vssc_covars")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = vssc_ps_covars,
                  overwrite = TRUE)
