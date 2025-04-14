library(tidyverse)
library(DBI)
library(lubridate)
#
`%ni%` <- negate(`%in%`)
#--
pactcc_con <- dbConnect(odbc::odbc(), Driver = "SQL Server", Server = "vhacdwsql13.vha.med.va.gov", 
                      Database = "PACT_CC", Truested_Connection = "true")
#
scrssn_count <- dbGetQuery(pactcc_con,
                           "select count(distinct ScrSSN_num) as scrssn_count, Sta5a
                            from [PACT_CC].[econ].PatientPCP
                            where FY in(2020,2021)
                            group by sta5a") %>%
  rename_all(tolower)
#
vast <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/Data/VAST_from_A06_11jan21.csv")  %>%
  select(sta5a, parent_station_sta5a, station_name, short_name, s_abbr, urh_vast, city, state, urh_pssg, parent_visn) %>%
  filter(s_abbr %in% c("VAMC", "HCC", "PCCBOC", "MSCBOC") & str_detect(sta5a, "FAKE") == F)
#
crh_sta5a_month <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Output/Data/analytic_df_v3_04oct21.csv") %>%
  inner_join(., vast, by = c("spoke_sta5a" = "sta5a")) %>%
  mutate(qtr = case_when(month(all_months) %in% c(10, 11, 12) ~ 1,
                         month(all_months) %in% c(1, 2, 3) ~ 2,
                         month(all_months) %in% c(4, 5, 6) ~ 3,
                         month(all_months) %in% c(7, 8, 9) ~ 4),
         fy = case_when(month(all_months) > 9 ~ year(all_months) + 1,
                        TRUE ~ year(all_months)))
#
crh_months_per_fy <- crh_sta5a_month %>%
  mutate(mt_0_crh_encounters = if_else(encounters_crh > 0, 1, 0),
         mt_5_crh_encounters = if_else(encounters_crh > 5, 1, 0),
         mt_25_crh_encounters = if_else(encounters_crh > 25, 1, 0)) %>%
  group_by(spoke_sta5a) %>%
  summarise(sum_6mos_mt0_crh_encounters_per_fy = sum(mt_0_crh_encounters, na.rm = T),
            sum_6mos_mt5_crh_encounters_per_fy = sum(mt_5_crh_encounters, na.rm = T),
            sum_6mos_mt25_crh_encounters_per_fy = sum(mt_25_crh_encounters, na.rm = T))
#
at_least_6mos_mt0 <- crh_months_per_fy %>%
  filter(sum_6mos_mt0_crh_encounters_per_fy > 5) %>%
  select(spoke_sta5a) %>%
  pull
#
at_least_6mos_mt5 <- crh_months_per_fy %>%
  filter(sum_6mos_mt5_crh_encounters_per_fy > 5) %>%
  select(spoke_sta5a) %>%
  pull
#
at_least_6mos_mt25 <- crh_months_per_fy %>%
  filter(sum_6mos_mt25_crh_encounters_per_fy > 5) %>%
  select(spoke_sta5a) %>%
  pull
#
crh_sta5as <- crh_sta5a_month %>%
  select(spoke_sta5a) %>% distinct %>% pull
#
operational_definition <- dbGetQuery(pactcc_con,
                        "SELECT DISTINCT S.Spoke_Region
                        	, S.Spoke_VISN
                        	, S.Spoke_Sta5a
                        	, 2020 as fy
                          FROM [PACT_CC].[CRH].CRH_sites_FY20  s
                          union
                          SELECT DISTINCT t.Spoke_Region
                          	, t.Spoke_VISN
                          	, t.Spoke_Sta5a
                          	, 2021 as fy
                          FROM [PACT_CC].[CRH].CRH_sites_FY21_full t") %>%
  rename_all(tolower) %>%
  inner_join(., vast, by = c("spoke_sta5a" = "sta5a")) %>% select(spoke_sta5a) %>%
  distinct %>%
  pull
#--------------------------
# non-users, not in operational definition - 423
non_users_not_approved <- vast %>%
  filter(sta5a %ni% crh_sta5as & sta5a %ni% operational_definition) %>%
  select(sta5a) %>%
  mutate(group = "no CRH, not in operational definition")
#non-users, in operational definition - 77
non_users_yes_approved <- vast %>%
  filter(sta5a %ni% crh_sta5as & sta5a %in% operational_definition) %>%
  distinct() %>%
  select(sta5a) %>%
  mutate(group = "no CRH, in operational definition")
#------
#users, at least 6 months with >24 CRH encounters/month - 224
users_6months_25plus_crh <- vast %>%
  filter(sta5a %in% at_least_6mos_mt25) %>%
  select(sta5a) %>%
  mutate(group = "yes CRH, at least 6 months with > 24 encounters")
#users, less than 6 months with >24 CRH encounters/month - 174
users_not_6months_25plus_crh <- vast %>%
  filter(sta5a %in% crh_sta5as & sta5a %ni% at_least_6mos_mt25) %>%
  select(sta5a) %>%
  mutate(group = "yes CRH, less than 6 months with > 24 encounters")
#------------------------
final_list <- non_users_not_approved %>%
  bind_rows(., non_users_yes_approved) %>%
  bind_rows(., users_6months_25plus_crh) %>%
  bind_rows(., users_not_6months_25plus_crh) %>%
  left_join(., scrssn_count) %>%
  left_join(., vast)
#
write_csv(final_list,
          "H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Output/Data/crh_users_non_users_list.csv")

