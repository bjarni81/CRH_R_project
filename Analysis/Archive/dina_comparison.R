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
hubs <- dbGetQuery(oabi_con,
                   "select distinct hub_sta3n as hub_sta5a
                    FROM [PACT_CC].[CRH].[CRH_sites_FY20]
                    UNION 
                    select distinct Hub_Sta3n as hub_sta5a
                    FROM [PACT_CC].[CRH].[CRH_sites_FY21_working]")
#
vast <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/Data/VAST_from_A06_11jan21.csv")
#
vast_parent <- vast %>% select(sta5a, parent_sta5a = parent_station_sta5a)
#
all_months <- tibble(all_months = seq.Date(dmy("01-10-2019"), dmy("01-09-2021"), by = "1 month"))
#-----------------=========================== CRH ENCOUNTERS
crh_encounters_1 <- dbGetQuery(oabi_con,#1,733,656
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
         flag_690 = if_else(secondary_stop_code == 690, 1, 0),
         crh_locationName_flag = if_else(str_detect(locationname, "CRH"), T, F)) %>%
  left_join(., vast, by = c("spoke_sta5a" = "sta5a"))
#
sum(crh_encounters_1$crh_locationName_flag, na.rm = T)
#limiting to visn23, fy21
crh_v23_fy21 <- crh_encounters_1 %>% filter(parent_visn == 23 & fy == 2021)
#vector of unique ScrSSNS in CDW
scrssn_crh_v23_fy21 <- crh_v23_fy21 %>% select(scrssn) %>% distinct %>% pull
#vector of unique Char4 codes in CDW
visn23_char4 <- crh_v23_fy21 %>% select(char4) %>% distinct %>% pull
#===========Importing Dina's data
v23_dina_check <- read_xlsx("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/Data/CRH_PCAT_Check.xlsx") %>%
  rename_all(tolower) %>%
  mutate(visitdate = as_date(visitdatetime))
#counting Char4
v23_dina_check %>%
  group_by(nationalchar4) %>%
  summarise(count = n()) %>% arrange(desc(count))
#vector of unique ScrSSNs in Dina's
dina_patientid <- v23_dina_check %>%
  filter(nationalchar4 %in% visn23_char4) %>%
  select(pat_id = `pat id`) %>%
  distinct %>% pull
#==============
sum(scrssn_crh_v23_fy21 %in% dina_patientid)
#11,441
sum(scrssn_crh_v23_fy21 %in% dina_patientid) / nrow(table(dina_patientid))
#100% of the scrssns in dina's dataset are in the cdw dataset
#---=======
scrssns_not_in_dina <- crh_v23_fy21 %>% 
  select(scrssn) %>% 
  filter(scrssn %ni% dina_patientid) %>% 
  distinct
#7,144 / 18,585 (38.4%) of scrssns in the CDW data are not in Dina's
#==
scrssns_not_in_dina %>%
  inner_join(crh_v23_fy21) %>%
  group_by(spoke_sta5a, short_name) %>%
  summarise(count = n()) %>%
  arrange(desc(count))
#
scrssns_not_in_dina %>%
  inner_join(crh_v23_fy21) %>%
  group_by(char4) %>%
  summarise(count = n()) %>%
  arrange(desc(count))
#
scrssns_not_in_dina %>%
  inner_join(crh_v23_fy21) %>%
  group_by(crh_locationName_flag) %>%
  summarise(count = n()) %>%
  arrange(desc(count))
