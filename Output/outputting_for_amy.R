library(tidyverse)
library(DBI)
##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
##---------- Connection to A06
a06_con <- dbConnect(odbc::odbc(),
                     Driver = "SQL Server",
                     Server = "VHACDWA06.vha.med.va.gov",
                     Database = "CDWWork",
                     Trusted_Connection = "true")
#========== VAST
vast <- dbGetQuery(a06_con,
                   "select distinct 
                	  stationno as sta5a
                	, par_sta_no as parent_station_sta5a
                	, cname as short_name
                	, newvisn as visn
                	, city
                	, st as state
                	, stationname as station_name
                	, urh
                	, s_abbr
                from [CDWWork].[Dim].[VAST]", 
                   stringsAsFactors=FALSE) %>%
  mutate(visn = str_pad(visn, side = "left", width = 2, pad = "0"),
         s_class = case_when(
           s_abbr == "PCCBOC" ~ "Primary Care CBOC",
           s_abbr == "VTCR" ~ "Vet Center",
           s_abbr == "OOS" ~ "Other Outpatient Services",
           s_abbr == "MSCBOC" ~ "Multi-Specialty CBOC",
           s_abbr == "VAMC" ~ "VA Medical Center",
           s_abbr == "MVCTR" ~ "Mobile Veteran Clinic",
           s_abbr == "HCS" ~ "Health Care System",
           s_abbr == "DRRTP" ~ "DRRTP",
           s_abbr == "MCS" ~ "MCS",
           s_abbr == "CLC" ~ "CLC",
           s_abbr == "HCC" ~ "Health Care Center"
         )) %>%
  rename(urh_vast = urh)
#============= spoke sta5as
spokes <- dbGetQuery(oabi_con,
                     "select spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy20_working
                     UNION
                     select spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy21_working") %>%
  pull
#============= hub sta5as
hubs <- dbGetQuery(oabi_con,
                     "select hub_sta3n from [PACT_CC].[CRH].CRH_sites_fy20_working
                     UNION
                     select hub_sta3n from [PACT_CC].[CRH].CRH_sites_fy21_working") %>%
  pull
#============= total # of unique ScrSSNs by sta5a
tot_pcmm_sta5a <- dbGetQuery(oabi_con,
                             "select count(distinct ScrSSN_char) as ScrSSN_count
                              	, sta5a
                              from [PACT_CC].[econ].PatientPCP
                              where fy in(2020, 2021)
                              group by sta5a;")
#------------- average number of unique ScrSSNs by sta5a
avg_pcmm_sta5a <- dbGetQuery(oabi_con,
                             "with cte as(
                              select count(distinct ScrSSN_char) as ScrSSN_count
                              	, sta5a, FY, QTR
                              from [PACT_CC].[econ].PatientPCP
                              where fy in(2020, 2021)
                              group by sta5a, FY, QTR)
                              select AVG(ScrSSN_count) as scrssn_count_avg, sta5a
                              from cte
                              group by sta5a;")
#==== joining
pcmm_ScrSSN_by_sta5a <- tot_pcmm_sta5a %>%
  left_join(., avg_pcmm_sta5a) %>%
  select(sta5a, scrssn_count = ScrSSN_count, scrssn_count_avg) %>%
  mutate(crh_spoke_flag = if_else(sta5a %in% spokes, TRUE, FALSE),
         crh_hub_flag = if_else(sta5a %in% hubs, TRUE, FALSE))
#output
pcmm_table <- Id(schema = "crh_eval", table = "pcmm_ScrSSN_by_sta5a")
#
dbWriteTable(oabi_con,
             pcmm_table,
             pcmm_ScrSSN_by_sta5a,
             overwrite = TRUE)
#+=+=+=+=+=+=+=+=+=+=+=+=+=+
#-----------  CRH Encounters - PC only
pc_crh_encounters <- dbGetQuery(oabi_con,
                                "select * from [PACT_CC].[CRH].crh_full_utilization_final_fy20_21") %>%
  rename_all(tolower) %>%
  filter(fy %in% c(2020, 2021) & care_type == "Primary Care") %>%
  select(scrssn, patienticn, visitdate, fy, qtr, fyqtr, sta5a = spoke_sta5a_combined_cdw, spoke_sta5a_crh,
         visn = spoke_visn_crh, care_type) %>%
  left_join(., vast %>% select(sta5a, short_name, parent_station_sta5a, s_abbr, city, state))
# output
crh_table <- Id(schema = "crh_eval", table = "pc_crh_encounters")
#
dbWriteTable(oabi_con,
             crh_table,
             pc_crh_encounters,
             overwrite = TRUE)
