
library(tidyverse)
library(lubridate)
library(gt)
library(kableExtra)
library(readxl)
library(DBI)
library(here)
library(scales)
library(janitor)
library(MatchIt)
library(sjPlot)
#
##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
pactcc_con <- dbConnect(odbc::odbc(),
                        Driver = "SQL Server",
                        Server = "vhacdwsql13.vha.med.va.gov",
                        Database = "PACT_CC",
                        Trusted_Connection = "true")
#
`%ni%` <- negate(`%in%`)
#---------
source(here("input", "Functions", "multiplot_05jan21.R"))
#
vast <- dbGetQuery(oabi_con,
                   "select * from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06")
#
crh_flag <- dbGetQuery(oabi_con,
                       "select * from [crh_eval].C1_crh_flag") %>%
  mutate(first_mo_w_mt9_pc_crh = ymd(first_mo_w_mt9_pc_crh),
         initiated_pc_crh_b4_march_2020 = if_else(first_mo_w_mt9_pc_crh < ymd("2020-03-01"), TRUE, FALSE),
         initiated_pc_crh_b4_feb_2020 = if_else(first_mo_w_mt9_pc_crh < ymd("2020-02-01"), TRUE, FALSE)) %>%
  left_join(., vast %>% select(sta5a, s_abbr))
#
pilot_sites <- dbGetQuery(pactcc_con,
                          "select distinct spoke_sta5a, vimpact_pilot
                          from PACT_CC.CRH.CRH_sites_FY20_working 
                          UNION
                          select distinct spoke_sta5a, vimpact_pilot
                          from PACT_CC.CRH.CRH_sites_FY21_working ") %>%
  filter(vimpact_pilot == 1) %>%
  select(sta5a = spoke_sta5a)
#
ps_matched <- read_csv(here::here("Input", "Data", "ps_matched_sta5as.csv"))
#==
group_1a <- crh_flag %>%
  filter(initiated_pc_crh_b4_feb_2020 == TRUE) %>%
  select(sta5a) %>%
  inner_join(., ps_matched) %>%
  select(subclass) %>%
  inner_join(., ps_matched) %>%
  select(sta5a, crh_flag = at_least_10_pc_crh_flag)
#
write_csv(group_1a,
          here("Output", "For Danielle Rose", "group_1a.csv"))
#==
group_1b <- crh_flag %>%
  filter(initiated_pc_crh_b4_feb_2020 == TRUE
         & sta5a %ni% pilot_sites$sta5a) %>%
  select(sta5a) %>%
  inner_join(., ps_matched) %>%
  select(subclass) %>%
  inner_join(., ps_matched) %>%
  select(sta5a, at_least_10_pc_crh_flag)
#
write_csv(group_1b,
          here("Output", "For Danielle Rose", "group_1b.csv"))
#==
group_2a <- crh_flag %>%
  filter(first_6_mos_w_10_flag == TRUE) %>%
  select(sta5a) %>%
  inner_join(., ps_matched) %>%
  select(subclass) %>%
  inner_join(., ps_matched) %>%
  select(sta5a, at_least_10_pc_crh_flag)
#
write_csv(group_2a,
          here("Output", "For Danielle Rose", "group_2a.csv"))
#==
group_2b <- crh_flag %>%
  filter(first_6_mos_w_10_flag == TRUE
         & sta5a %ni% pilot_sites$sta5a) %>%
  select(sta5a) %>%
  inner_join(., ps_matched) %>%
  select(subclass) %>%
  inner_join(., ps_matched) %>%
  select(sta5a, at_least_10_pc_crh_flag)
#
write_csv(group_2b,
          here("Output", "For Danielle Rose", "group_2b.csv"))
