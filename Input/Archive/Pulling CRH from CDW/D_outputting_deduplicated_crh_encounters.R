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
library(DBI)
library(here)
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
#--===
hubs <- dbGetQuery(oabi_con,
                     "select hub_sta3n from [PACT_CC].[CRH].CRH_sites_fy20_working
                     UNION
                     select hub_sta3n from [PACT_CC].[CRH].CRH_sites_fy21_working")
#
vast <- read_csv(here("Input", "Data","VAST_from_A06_11jan21.csv"))
#-----------------=========================== CRH ENCOUNTERS version 2.0
crh_encounters_1 <- dbGetQuery(oabi_con,
                               "select *
                               from [OABI_MyVAAccess].[crh_eval].encounters_C_unioned") %>%
  rename_all(tolower) %>%
  janitor::clean_names()
#group by Patient, VisitDate (gives us the list of visits that we want on the patient side but not the correct care type, 
  #need stop codes from the hub encounters for 2 sided visits)
crh_grouped <- crh_encounters_1 %>% 
  group_by(hub_visn, sitetype, scrssn, visitdate) %>% 
  arrange(desc(char4)) %>% 
  slice(1L) %>% 
  ungroup() 
#take the other row of two sided visits in order to get the correct primary and secondary stop codes 
  #(without the pat admin activities) for categorization and then re-join
crh_antijoin <- anti_join(crh_encounters_1, crh_grouped, by = c("scrssn", "visitdate", "char4")) %>% 
  select(scrssn, visitdate, hub_visn, hub_sta3n, location_primary_sc, location_secondary_sc, 
         primarystopcodelocationname, secondarystopcodelocationname)
#-
crh_full <- crh_grouped %>%
  left_join(., crh_antijoin, 
            by = c("hub_visn", "hub_sta3n", "scrssn", "visitdate"), 
            suffix = c(".dmrc", ".other")) %>% 
  select(-c(primary_stop_code, secondary_stop_code, workloadlogicflag, visitsid)) %>% 
  mutate(primary_sc = if_else(location_primary_sc.other != "NULL" & is.na(location_primary_sc.other) == F, 
                              location_primary_sc.other, location_primary_sc.dmrc),
         secondary_sc = if_else(location_secondary_sc.other != "NULL" & is.na(location_secondary_sc.other == F), 
                                location_secondary_sc.other,
                                location_secondary_sc.dmrc)) %>% 
  select(-location_primary_sc.other, -location_secondary_sc.other, 
         -location_primary_sc.dmrc, -location_secondary_sc.dmrc, 
         -primarystopcodelocationname.other, -secondarystopcodelocationname.other, 
         -primarystopcodelocationname.dmrc, -secondarystopcodelocationname.dmrc) %>%
  mutate(care_type = 
           case_when(
             (primary_sc %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348) 
              & (secondary_sc != 160 | is.na(secondary_sc) == T)) 
             | (primary_sc != 160 
                & secondary_sc %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care",
             (primary_sc %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587) 
              & (secondary_sc %ni% c(160, 534) | is.na(secondary_sc) == T)) 
             | (primary_sc %ni% c(160, 534)
                & secondary_sc %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550, 
                                      562, 576, 579, 586, 587))                  ~ "Mental Health",
             (primary_sc %in% c(534, 539) 
              & (secondary_sc != 160 | is.na(secondary_sc) == T)) 
             | (primary_sc != 160 & secondary_sc %in% c(534, 539)) ~ "PCMHI",
             primary_sc == 160 | secondary_sc == 160  ~ "Pharmacy",
             is.na(primary_sc) == T ~ "Missing",
             TRUE                                                                                  ~ "Specialty"),
         crh_month = dmy(str_c("01",month(visitdate), year(visitdate), sep = "-")))
#-- Output Table to SQL13
table_id <- DBI::Id(schema = "crh_eval", table = "encounters_D_deDup")
#
dbSendQuery(oabi_con, "drop table if exists [OABI_MyVAAccess].[crh_eval].encounters_D_deDup")
#foo
dbWriteTable(conn = oabi_con,
             name = table_id,
             value = crh_full)
#-----------------=========================== CRH ENCOUNTERS version 1.0
# crh_encounters_1 <- dbGetQuery(oabi_con,
#                                "select *
#                                from [OABI_MyVAAccess].[crh_eval].CRH_UNIONED") %>%
#   rename_all(tolower) %>%
#   janitor::clean_names() %>%
#   mutate(visitdate = ymd(visitdate),
#          crh_month = dmy(str_c("01", month(visitdate), year(visitdate), sep = "-"))) %>%
#   left_join(., vast, by = c("spoke_sta5a" = "sta5a")) %>%
#   mutate(hub_flag = if_else(spoke_sta5a %in% hubs$hub_sta5a, 2, 1),#if sta5a is hub then 2, else 1
#          location_flag = if_else(char4 == "LocationName", 2, 1),
#          care_type_drop =
#            case_when(
#              (location_primary_sc %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348)
#               & (location_secondary_sc != 160 | is.na(location_secondary_sc) == T))
#              | (location_primary_sc != 160
#                 & location_secondary_sc %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care",
#              (location_primary_sc %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587)
#               & (location_secondary_sc %ni% c(160, 534) | is.na(location_secondary_sc) == T))
#              | (location_primary_sc %ni% c(160, 534)
#                 & location_secondary_sc %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550,
#                                     562, 576, 579, 586, 587))                  ~ "Mental Health",
#              (location_primary_sc %in% c(534, 539)
#               & (location_secondary_sc != 160 | is.na(location_secondary_sc) == T))
#              | (location_primary_sc != 160 & location_secondary_sc %in% c(534, 539)) ~ "PCMHI",
#              location_primary_sc == 160 | location_secondary_sc == 160  ~ "Pharmacy",
#              is.na(location_primary_sc) == T ~ "Missing",
#              TRUE                                                                                  ~ "Specialty")) %>% #
#   arrange(scrssn, visitdate, hub_flag, location_flag) %>%#arranging by hub_flag makes it so that hubs will be lower in the order
#   group_by(scrssn, visitdate, care_type_drop) %>%
#   mutate(scrssn_vizday_rn = row_number()) %>%
#   ungroup() %>%
#   select(-care_type_drop)
# #---Only those rows where row_number == 2
# double_scrssns <- crh_encounters_1 %>%
#   filter(scrssn_vizday_rn == 2) %>%
#   select(scrssn, visitdate, sta5a2 = spoke_sta5a, psc2 = primary_stop_code,
#           ssc2 = secondary_stop_code)
# #======
# crh_encounters_3 <- crh_encounters_1 %>%
#   filter(scrssn_vizday_rn == 1) %>%
#   left_join(double_scrssns) %>%
#   mutate(sta5a_joined = case_when(is.na(spoke_sta5a) == T & is.na(sta5a2) == F ~ sta5a2,
#                                   is.na(spoke_sta5a) == F & is.na(sta5a2) == T ~ spoke_sta5a,
#                                   is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a == sta5a2 ~ sta5a2,
#                                   is.na(spoke_sta5a) == F & is.na(sta5a2) == F & spoke_sta5a != sta5a2 ~ spoke_sta5a),
#          psc_joined = case_when(primary_stop_code != 674 ~ primary_stop_code,
#                                 primary_stop_code == 674 ~ location_secondary_sc),
#          ssc_joined = if_else(is.na(secondary_stop_code), ssc2, secondary_stop_code))
# #-----
# crh_encounters <- crh_encounters_3 %>%
#   mutate(care_type =
#            case_when(
#              (psc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348)
#               & (ssc_joined != 160 | is.na(ssc_joined) == T))
#              | (psc_joined != 160
#                 & ssc_joined %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care",
#              (psc_joined %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587)
#               & (ssc_joined %ni% c(160, 534) | is.na(ssc_joined) == T))
#              | (psc_joined %ni% c(160, 534)
#                 & ssc_joined %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550,
#                                     562, 576, 579, 586, 587))                  ~ "Mental Health",
#              (psc_joined %in% c(534, 539)
#               & (ssc_joined != 160 | is.na(ssc_joined) == T))
#              | (psc_joined != 160 & ssc_joined %in% c(534, 539)) ~ "PCMHI",
#              psc_joined == 160 | ssc_joined == 160  ~ "Pharmacy",
#              is.na(psc_joined) == T ~ "Missing",
#              TRUE                                                                                  ~ "Specialty"),
#          crh_month = dmy(str_c("01",month(visitdate), year(visitdate), sep = "-")))
# #-- Output Table to SQL13
# table_id <- DBI::Id(schema = "crh_eval", table = "crh_encounters_deDup")
# #
# dbSendQuery(oabi_con, "drop table if exists [OABI_MyVAAccess].[crh_eval].crh_encounters_deDup")
# #foo
# dbWriteTable(conn = oabi_con,
#              name = table_id,
#              value = crh_encounters)

