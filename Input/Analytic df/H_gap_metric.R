library(tidyverse)
library(here)
library(lubridate)
#--
# .csv files downloaded from VSSC
panel_sizes <- grep(list.files(path=here("Input", "Data", "Gap Metric"),
                               full.names = T), 
                    pattern='visn|nat|parent', 
                    invert=TRUE, 
                    value=TRUE)
#--
panel_size_fxn <- function(table_num){
  read_csv(panel_sizes[table_num]) %>%
    mutate(month_n = match(str_to_title(str_sub(`Month`, end = 3)), month.abb),
           fy = as.numeric(str_sub(`Month`, start = -2)),
           cy2 = if_else(month_n > 9, fy - 1, fy),
           cy = as.numeric(str_c("20", cy2)),
           vssc_month = ymd(str_c(cy, month_n, "01", sep = "-")))
}
#--
expected_ps <- panel_size_fxn(1) %>%
  rename(sta5a = Sta6a, 
         expected_panel_size = `Expected Panel Size`) %>%
  dplyr::select(sta5a, vssc_month, expected_panel_size)
#--
expected_ps_crh <- panel_size_fxn(2) %>%
  rename(sta5a = Sta6a, 
         expected_panel_size_crh = `Expected Panel Size`) %>%
  dplyr::select(sta5a, vssc_month, expected_panel_size_crh)
#--
observed_ps <- panel_size_fxn(3) %>%
  rename(sta5a = Sta6a, 
         observed_panel_size = `Observed Panel Size`) %>%
  dplyr::select(sta5a, vssc_month, observed_panel_size)
#--
observed_ps_crh <- panel_size_fxn(4) %>%
  rename(sta5a = Sta6a, 
         observed_panel_size_crh = `Observed Panel Size`) %>%
  dplyr::select(sta5a, vssc_month, observed_panel_size_crh)
#=========
all_sta5a <- observed_ps %>%
  dplyr::select(sta5a) %>%
  distinct
#
all_months <- tibble(vssc_month = seq.Date(ymd("2017-10-01"), ymd("2023-10-01"), by = "1 month"))
#---------
inf_fxn <- function(x) replace(x, is.infinite(x), NA)
nan_fxn <- function(x) replace(x, is.nan(x), NA)
#
gap_metric <- all_sta5a %>%
  cross_join(., all_months) %>%
  left_join(., observed_ps) %>%
  left_join(., observed_ps_crh) %>%
  left_join(., expected_ps) %>%
  left_join(., expected_ps_crh) %>%
  mutate(obs_ps_zero = replace_na(observed_panel_size, 0),
         exp_ps_zero = replace_na(expected_panel_size, 0),
         obs_ps_crh_zero = replace_na(observed_panel_size_crh, 0),
         exp_ps_crh_zero = replace_na(expected_panel_size_crh, 0),
         observed_ps_tot = obs_ps_zero - obs_ps_crh_zero,
         expected_ps_tot = exp_ps_zero - exp_ps_crh_zero,
         gap_metric = inf_fxn(expected_ps_tot / observed_ps_tot),
         gap_metric = nan_fxn(gap_metric),
         gap_metric2 = inf_fxn(expected_ps_tot / obs_ps_zero),
         gap_metric2 = nan_fxn(gap_metric2))
#================================================
# outputting to OABI_MyVAAccess
oabi_connect <- DBI::dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
table_id <- DBI::Id(schema = "crh_eval", table = "H_gap_metric")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = gap_metric,
                  overwrite = TRUE)
