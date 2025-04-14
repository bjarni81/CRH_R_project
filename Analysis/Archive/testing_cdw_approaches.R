library(tidyverse)
library(lubridate)
library(janitor)
library(DBI)
#
options(scipen = 999)
###
`%ni%` <- negate(`%in%`)
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Truested_Connection = "true")
#===========
stopCode_lookup <- dbGetQuery(oabi_con,
                              "select distinct stopCode, stopCodeName,
                                restrictionType
                              from [cdwwork].[dim].stopcode
                              where inactivedate IS NOT NULL and restrictionType IS NOT NULL")
#
stopCodes_690_693 <- dbGetQuery(oabi_con,
                                "select distinct stopCode, stopCodeName, restrictionType
                              from [cdwwork].[dim].stopcode
                                where stopCode in(690,693)")
#===========
vast <- read_csv("./Input/Data/VAST_from_A06_11jan21.csv")
#===========
hubs <- dbGetQuery(oabi_con,
                   "select distinct hub_sta3n as hub_sta5a
                    FROM [PACT_CC].[CRH].[CRH_sites_FY20]
                    UNION 
                    select distinct Hub_Sta3n as hub_sta5a
                    FROM [PACT_CC].[CRH].[CRH_sites_FY21_part]")
#
hubs_v <- hubs %>% pull
#-----------------=========================== CRH ENCOUNTERS
crh_encounters_1 <- dbGetQuery(oabi_con,
                               "select *
                               from [OABI_MyVAAccess].[crh_eval].crh_all") %>%
  rename_all(tolower) %>%
  janitor::clean_names() %>%
  mutate(visitdate = ymd(visitdate),
         crh_month = dmy(str_c("01", month(visitdate), year(visitdate), sep = "-")),
         fy = if_else(month(visitdate) > 9, year(visitdate) + 1, year(visitdate)),
         qtr = case_when(month(visitdate) %in% c(10, 11, 12) ~ 1,
                         month(visitdate) %in% c(1, 2, 3) ~ 2,
                         month(visitdate) %in% c(4, 5, 6) ~ 3,
                         month(visitdate) %in% c(7, 8, 9) ~ 4),
         flag_693 = if_else(secondary_stop_code == 693, 1, 0),
         flag_690 = if_else(secondary_stop_code == 690, 1, 0)) %>%
  left_join(., vast, by = c("spoke_sta5a" = "sta5a")) %>%
  filter(
    flag_693 %ni% 1
    #& flag_690 %ni% 1      
         )
#First ordering and row_number of encounters
crh_encounters_2 <- crh_encounters_1 %>%
  mutate(hub_flag = if_else(spoke_sta5a %in% hubs$hub_sta5a, 2, 1)) %>% #if sta5a is hub then 2, else 1
  arrange(scrssn, visitdate, hub_flag) %>%#arranging by hub_flag makes it so that hubs will be lower in the order
  group_by(scrssn, visitdate) %>%
  mutate(scrssn_vizday_rn = row_number()) %>%
  ungroup()
#---Only those rows where row_number == 2
double_scrssns <- crh_encounters_2 %>% 
  filter(scrssn_vizday_rn == 2) %>%
  select(scrssn, visitdate, sta5a2 = spoke_sta5a, psc2 = primary_stop_code, ssc2 = secondary_stop_code)
# re-join, and assign hub-side stop codes to the spoke
crh_encounters_3 <- crh_encounters_2 %>%
  filter(scrssn_vizday_rn == 1) %>%
  left_join(double_scrssns) %>%
  mutate(sta5a_joined = case_when(is.na(spoke_sta5a) == T & is.na(sta5a2) == F ~ sta5a2,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == T ~ spoke_sta5a,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a == sta5a2 ~ sta5a2,
                                  is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a != sta5a2 ~ sta5a2),
         psc_joined = case_when(primary_stop_code != 674 ~ primary_stop_code,
                                primary_stop_code == 674 ~ location_secondary_sc),
         ssc_joined = if_else(is.na(secondary_stop_code), ssc2, secondary_stop_code)) 
#Categorize encounters by stop code
crh_encounters <- crh_encounters_3 %>%
  mutate(care_type = 
           case_when(
             (psc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348) 
              & (ssc_joined != 160 | is.na(ssc_joined) == T)) 
             | (psc_joined != 160 
                & ssc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care crh",
             (psc_joined %in% c(502, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587) 
              & (ssc_joined %ni% c(160, 534) | is.na(ssc_joined) == T)) 
             | (psc_joined %ni% c(160, 534)
                & ssc_joined %in% c(502, 510, 513, 516, 527, 538, 545, 550, 
                                    562, 576, 579, 586, 587))                  ~ "Mental Health crh",
             (psc_joined %in% c(534, 539) 
              & (ssc_joined != 160 | is.na(ssc_joined) == T)) 
             | (psc_joined != 160 & ssc_joined %in% c(534, 539)) ~ "PCMHI crh",
             psc_joined == 160 | ssc_joined == 160  ~ "Pharmacy crh",
             is.na(psc_joined) == T ~ "Missing crh",
             TRUE                                                                                  ~ "Specialty crh"),
         crh_month = dmy(str_c("01",month(visitdate), year(visitdate), sep = "-")))

#--==--==
cdw_crh_visn23_fy21 <- crh_encounters %>%
  filter(fy == 2021 & parent_visn == 23)
#--==
cdw_crh_visn23_fy21 %>%
  select(scrssn) %>% n_distinct
#34,056
#--
cdw_crh_visn23_fy21 %>%
  group_by(care_type) %>%
  summarise(count = n()) %>%
  adorn_totals()
