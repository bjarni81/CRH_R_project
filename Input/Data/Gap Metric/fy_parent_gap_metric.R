library(tidyverse)
#======
gap_fy_parent_files <- list.files(path = here("Input", "Data", "Gap Metric"),
                                  pattern = "fy_parent",
                                  full.names = TRUE)
#--
expected_ps_crh <- read_csv(gap_fy_parent_files[1]) %>%
  rename(fy = 1,
         fac = 2,
         exp_ps_crh = 3) %>%
  mutate(parent_station_sta5a = if_else(str_sub(fac, 11, 11) == ")",
                                        str_sub(fac, 8, 10),
                                        str_sub(fac, 8, 12))) %>%
  select(fy, parent_station_sta5a, exp_ps_crh)
#--
expected_ps <- read_csv(gap_fy_parent_files[2]) %>%
  rename(fy = 1,
         fac = 2,
         exp_ps = 3) %>%
  mutate(parent_station_sta5a = if_else(str_sub(fac, 11, 11) == ")",
                                        str_sub(fac, 8, 10),
                                        str_sub(fac, 8, 12))) %>%
  select(fy, parent_station_sta5a, exp_ps)
#--
obs_ps_crh <- read_csv(gap_fy_parent_files[3]) %>%
  rename(fy = 1,
         fac = 2,
         obs_ps_crh = 3) %>%
  mutate(parent_station_sta5a = if_else(str_sub(fac, 11, 11) == ")",
                                        str_sub(fac, 8, 10),
                                        str_sub(fac, 8, 12))) %>%
  select(fy, parent_station_sta5a, obs_ps_crh)
#--
obs_ps <- read_csv(gap_fy_parent_files[4]) %>%
  rename(fy = 1,
         fac = 2,
         obs_ps = 3) %>%
  mutate(parent_station_sta5a = if_else(str_sub(fac, 11, 11) == ")",
                                        str_sub(fac, 8, 10),
                                        str_sub(fac, 8, 12))) %>%
  select(fy, parent_station_sta5a, obs_ps)
#==--==--==--==--
parent_station_gap_metric <- expected_ps %>%
  select(parent_station_sta5a) %>%
  distinct() %>%
  cross_join(.,
            tibble(fy = c(2018, 2019, 2020, 2021, 2022, 2023))) %>%
  left_join(., expected_ps) %>%
  left_join(., expected_ps_crh) %>%
  left_join(., obs_ps) %>%
  left_join(., obs_ps_crh) %>%
  mutate(across(where(is.numeric), ~replace_na(.x, 0)),
         exp_ps_tot = exp_ps - exp_ps_crh,
         obs_ps_tot = obs_ps - obs_ps_crh,
         gap_metric = exp_ps_tot / obs_ps_tot) %>%
  select(parent_station_sta5a, fy, gap_metric)
#--==--==--==--==--==
write_csv(parent_station_gap_metric,
          here("Input", "Data", "Gap Metric", "fy_parent_gap_metric.csv"))
