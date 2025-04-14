library(tidyverse)
library(lubridate)
library(DBI)
#-------
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#------------------------------
timely_care <- dbGetQuery(oabi_con,
                          "select *
                          from [OABI_MyVAAccess].[crh_eval].[E3_daysDV_month_sta5a]") %>%
  mutate(viz_month = ymd(viz_month)) %>%
  rename(sta5a = req_sta5a,
         vssc_month = viz_month)
#pulling vssc access metrics
access_metrics <- dbGetQuery(oabi_con,
                             "select * from [crh_eval].E2_VSSC_access_metrics") %>%
  mutate(vssc_month = ymd(vssc_month))
#making a time column
dates <- timely_care %>%
  filter(viz_fy == 2019) %>%
  select(vssc_month) %>%
  distinct %>%
  arrange(vssc_month) %>%
  rowid_to_column(., var = "time")
#=================
#making the analytic dataset
analytic_df <- access_metrics %>%
  left_join(., timely_care) %>%
  inner_join(., dates) %>%
  drop_na()
#------------
sta5a_list <- analytic_df %>% select(sta5a) %>% distinct() %>% pull
#function for outputting the slope of each sta5as outcome over FY19
sta5a_slope_fxn <- function(sta5a_f, outcome_f){ 
  lm_df <- analytic_df %>% 
    filter(sta5a == sta5a_f) %>%
    select(outcome_name = outcome_f, time) %>%
    lm(outcome_name ~ time,
       data = .)
  #
  outcome_f_name <- paste0(outcome_f, "_slope_fy19")
  #
  slope_df <- tibble(
    sta5a = sta5a_f,
    outcome_name = lm_df$coefficients[[2]]
  )
}
#New Patient Wait Time----------
slope_bucket <- list()
#
for(ii in 1:length(sta5a_list)){
  sta5af_loop <- sta5a_list[ii]
  
  slope_bucket[[ii]] <- sta5a_slope_fxn(sta5af_loop, "new_pc_pt_wt")
}
#
ps_matched_new_pt_wt_slopes_fy19 <- bind_rows(slope_bucket) %>%
  rename(new_pc_pt_wt_slope_fy19 = outcome_name)
#Established Patient Wait Time-------
slope_bucket <- list()
#
for(ii in 1:length(sta5a_list)){
  sta5af_loop <- sta5a_list[ii]
  
  slope_bucket[[ii]] <- sta5a_slope_fxn(sta5af_loop, "est_pc_pt_wt")
}
#
ps_matched_est_pt_wt_slopes_fy19 <- bind_rows(slope_bucket) %>%
  rename(est_pc_pt_wt_slope_fy19 = outcome_name)
#TNA-------
slope_bucket <- list()
#
for(ii in 1:length(sta5a_list)){
  sta5af_loop <- sta5a_list[ii]
  
  slope_bucket[[ii]] <- sta5a_slope_fxn(sta5af_loop, "third_next_avail")
}
#
ps_matched_tna_slopes_fy19 <- bind_rows(slope_bucket) %>%
  rename(third_next_avail_slope_fy19 = outcome_name)
#==========================
slopes_fy19 <- ps_matched_new_pt_wt_slopes_fy19 %>%
  left_join(., ps_matched_est_pt_wt_slopes_fy19) %>%
  left_join(., ps_matched_tna_slopes_fy19)
#======================
table_id <- DBI::Id(schema = "crh_eval", table = "F3C_access_metrics_FY19_slope")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = slopes_fy19,
                  overwrite = TRUE)
