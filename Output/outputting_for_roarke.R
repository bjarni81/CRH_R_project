library(tidyverse)
library(DBI)
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Truested_Connection = "true")
#===========
vast <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/Data/VAST_from_A06_11jan21.csv")
#-----------------=========================== CRH ENCOUNTERS
crh_encounters_v23_1 <- dbGetQuery(oabi_con,#110,923
                                   "select *
                               from [OABI_MyVAAccess].[crh_eval].TEMP_UNIONED
                               where spoke_visn = 23") %>%
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
  left_join(., vast, by = c("spoke_sta5a" = "sta5a"))

no_crh_in_locationName <- crh_encounters_v23_1 %>%
  filter(str_detect(locationname, "CRH") == F) %>%
  group_by(locationname, char4) %>%
  summarise(count = n())
#
write_csv(no_crh_in_locationName,
          here("Output", "Data", "no_crh_in_locationName.csv"))
