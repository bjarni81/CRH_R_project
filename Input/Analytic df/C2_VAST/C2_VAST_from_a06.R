library(tidyverse)
library(RODBC)
library(DBI)
library(here)
#
`%ni%` <- negate(`%in%`)
##---------- Connection to OABI_MyVAAccess
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
##---------- Connection to PACT_CC
pactcc_con <- dbConnect(odbc::odbc(),
                        Driver = "SQL Server",
                        Server = "vhacdwsql13.vha.med.va.gov",
                        Database = "PACT_CC",
                        Trusted_Connection = "true")
#----- PCMM count
# scrssn_count <- dbGetQuery(pactcc_con,
#                            "with cte as(
#                             	select count(distinct ScrSSN_num) as scrssn_count
#                             		, sta5a, fy, qtr
#                             	from [PACT_CC].[econ].PatientPCP
#                             	where fy > 2019
#                             	group by sta5a, fy, qtr)
#                             select max(scrssn_count) as scrssn_count, sta5a
#                             from cte
#                             group by Sta5a") %>%
#   mutate(scrssn_count_cat = factor(case_when(
#     scrssn_count < 450 ~ "< 450",
#     scrssn_count >= 450 & scrssn_count < 2500 ~ "450 - 2,499",
#     scrssn_count >= 2500 & scrssn_count < 10000 ~ "2,500 - 9,999",
#     scrssn_count >= 10000 ~ "10,000+"
#   ), ordered = TRUE,
#   levels = c("< 450", "450 - 2,499", "2,500 - 9,999", "10,000+")))
#
con <-'driver={SQL Server}; 
        server=VHACDWA06.vha.med.va.gov;
        database=CDWWork;
        trusted_connection=true'
#
channel <- odbcDriverConnect(connection = con)
#
vast <- sqlQuery(channel,
                 "select distinct 
                	  stationno as sta5a
                	, par_sta_no as parent_station_sta5a
                	, stationname as station_name
                	, cname as short_name
                	, newvisn as visn
                	, s_abbr
                	, urh
                	, city
                	, st as state
                from [CDWWork].[Dim].[VAST]", 
                 stringsAsFactors=FALSE) %>%
  mutate(visn = str_pad(visn, side = "left", width = 2, pad = "0")) %>%
  rename(urh_vast = urh) %>%
  filter(is.na(s_abbr) == F
         & s_abbr %in% c("HCC", "VAMC", "MSCBOC", "PCCBOC", "OOS")
         & state %ni% c("PR", "AS", "PH", "PR", "VI", "GU", "MP")) %>%
  mutate(census_division = case_when(
    state %in% c("CT", "ME", "MA", "NH", "RI", "VT") ~ "New England",
    state %in% c("NJ", "NY", "PA") ~ "Middle Atlantic",
    state %in% c("IN", "IL", "MI", "OH", "WI") ~ "East North Central",
    state %in% c("IA", "KS", "MN", "MO", "NE", "ND", "SD") ~ "West North Central",
    state %in% c("DE", "DC", "FL", "GA", "MD", "NC", "SC", "VA", "WV") ~ "South Atlantic",
    state %in% c("AL", "KY", "MS", "TN") ~ "East South Central",
    state %in% c("AR", "LA", "OK", "TX") ~ "West South Central",
    state %in% c("AZ", "CO", "ID", "NM", "MT", "UT", "NV", "WY") ~ "Mountain",
    state %in% c("AK", "CA", "HI", "OR", "WA") ~ "Pacific"
  ))
# closing the connection
odbcClose(channel = channel)
#
fix_vast <- vast %>%
  filter(sta5a == parent_station_sta5a) %>%
  mutate(parent_visn = visn) %>%
  select(parent_station_sta5a, parent_visn)
vast <- vast %>%
  left_join(., fix_vast)
#----
write_csv(vast,
          here("Input", "Analytic df", "Data", "vast_from_a06.csv"))
#
table_id <- DBI::Id(schema = "crh_eval", table = "C2_vast_from_a06")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = vast,
                  overwrite = TRUE)

