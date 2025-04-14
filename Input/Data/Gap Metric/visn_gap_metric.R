library(tidyverse)
#======
gap_visn_files <- list.files(path = here("Input", "Data", "Gap Metric"),
                            pattern = "_visn",
                            full.names = TRUE)
#--
expected_ps_crh <- read_csv(gap_visn_files[1]) %>%
  rename(fdate = 1,
         visn = 2,
         exp_ps_crh = 3) %>%
  mutate(month_char = str_to_title(str_sub(fdate, end = 3)),
         month_num = match(month_char, month.abb),
         fy2 = as.numeric(str_sub(fdate, start = -2)),
         cy2 = if_else(month_num > 9, fy2 - 1, fy2),
         cy4 = str_c("20", cy2),
         vssc_month = ymd(str_c(cy4, month_num, "1", sep = "-")),
         visn = str_remove(visn, "V")) %>%
  select(vssc_month, visn, exp_ps_crh)
#--
expected_ps <- read_csv(gap_visn_files[2]) %>%
  rename(fdate = 1,
         visn = 2,
         exp_ps = 3) %>%
  mutate(month_char = str_to_title(str_sub(fdate, end = 3)),
         month_num = match(month_char, month.abb),
         fy2 = as.numeric(str_sub(fdate, start = -2)),
         cy2 = if_else(month_num > 9, fy2 - 1, fy2),
         cy4 = str_c("20", cy2),
         vssc_month = ymd(str_c(cy4, month_num, "1", sep = "-")),
         visn = str_remove(visn, "V")) %>%
  select(vssc_month, visn, exp_ps)
#--
obs_ps_crh <- read_csv(gap_visn_files[3]) %>%
  rename(fdate = 1,
         visn = 2,
         obs_ps_crh = 3) %>%
  mutate(month_char = str_to_title(str_sub(fdate, end = 3)),
         month_num = match(month_char, month.abb),
         fy2 = as.numeric(str_sub(fdate, start = -2)),
         cy2 = if_else(month_num > 9, fy2 - 1, fy2),
         cy4 = str_c("20", cy2),
         vssc_month = ymd(str_c(cy4, month_num, "1", sep = "-")),
         visn = str_remove(visn, "V")) %>%
  select(vssc_month, visn, obs_ps_crh)
#--
obs_ps <- read_csv(gap_visn_files[4]) %>%
  rename(fdate = 1,
         visn = 2,
         obs_ps = 3) %>%
  mutate(month_char = str_to_title(str_sub(fdate, end = 3)),
         month_num = match(month_char, month.abb),
         fy2 = as.numeric(str_sub(fdate, start = -2)),
         cy2 = if_else(month_num > 9, fy2 - 1, fy2),
         cy4 = str_c("20", cy2),
         vssc_month = ymd(str_c(cy4, month_num, "1", sep = "-")),
         visn = str_remove(visn, "V")) %>%
  select(vssc_month, visn, obs_ps)
#==--==--==--==--
visn_gap_metric <- expected_ps %>%
  left_join(., expected_ps_crh) %>%
  left_join(., obs_ps) %>%
  left_join(., obs_ps_crh) %>%
  mutate(across(where(is.numeric), ~replace_na(.x, 0)),
         exp_ps_tot = exp_ps - exp_ps_crh,
         obs_ps_tot = obs_ps - obs_ps_crh,
         gap_metric = exp_ps_tot / obs_ps_tot) %>%
  select(vssc_month, visn, gap_metric)
#--==--==--==--==--==
write_csv(visn_gap_metric,
          here("Input", "Data", "Gap Metric", "visn_gap_metric.csv"))
