library(tidyverse)
library(lubridate)
library(DT)
library(kableExtra)
library(readxl)
library(DBI)
library(here)
#
##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#-----------
dbExecute(oabi_con, "drop table if exists #pcat_sc_encounters")
#
dbExecute(oabi_con,
          "select cast(op.visitDateTime as date) as visitDate
          	, psc.StopCode as pStopCode
      			, pSCName = case 
      				when psc.StopCode = 323 then 'PRIMARY CARE/MEDICINE'
      				else psc.stopcodename end
          	, ssc.StopCode as sStopCode
      			, sSCName = case 
      				when ssc.StopCode = 185 then 'NURSE PRACTITIONER'
      				when ssc.StopCode = 323 then 'PRIMARY CARE/MEDICINE'
      				when ssc.StopCode IS NULL then '*Missing*'
      				else ssc.stopcodename end
          into #pcat_sc_encounters
          from [CDWWork].[Outpat].Workload as op
          left join [CDWWork].[Dim].StopCode as psc
          	on op.PrimaryStopCodeSID = psc.StopCodeSID
          left join [CDWWork].[Dim].StopCode as ssc
          	on op.SecondaryStopCodeSID = ssc.StopCodeSID
          where psc.StopCode in(322, 323, 348, 350, 704)
          	AND psc.StopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999) 
          	OR ssc.StopCode in(322, 323, 348, 350, 704)
          	AND VisitDateTime >= cast('2019-10-01' as datetime2) and VisitDateTime <= cast('2021-09-30' as datetime2);",
          immediate = TRUE)
#==
pcat_sc_count <- dbGetQuery(oabi_con,
                            "select count(*) as pcat_stopCode_count
                            	, pStopCode
                            	, sStopCode, sSCName
                            from #pcat_sc_encounters
                            group by pStopCode
                            	, sStopCode, sSCName")
#-----
write_csv(pcat_sc_count,
          here("Input", "Data", "pcat_pc_sc_counts.csv"))
#
pcat_sc_count <- read_csv(here("Input", "Data", "pcat_pc_sc_counts.csv"))
#--------------------------------
# psc_names <- pcat_sc_count %>%
#   select(pSCName, pStopCode) %>%
#   distinct
#
sc_names <- dbGetQuery(oabi_con,
                       "select distinct stopcode
                        	, stopCodeName = case 
                        		when stopcode = 185 then 'NURSE PRACTITIONER'
                        		when stopcode = 188 then 'FELLOW/RESIDENT'
                        		when stopcode = 301 then 'GENERAL INTERNAL MEDICINE'
                        		when stopcode = 323 then 'PRIMARY CARE/MEDICINE'
                        		when stopcode = 674 then 'ADMIN PAT ACTIVTIES (MASNONCT)'
                        		else StopCodeName end
                        from [CDWWork].[Dim].StopCode
                        where StopCode in(156,176,177,178,301,338,179 ,697,205,206,510,534,185,690,692,693,117    
                        ,125,130,184,186,188,301,673,322, 323, 348, 674)")
#
#---------------
pc_crh_stopCode_count <- dbGetQuery(oabi_con,
                                    "select * from [PACT_CC].[CRH].[crh_full_utilization_final_fy20_21]") %>%
  rename_all(tolower) %>%
  mutate(visitdate = ymd(visitdate),
         crh_month = ymd(str_c(year(visitdate), month(visitdate), "01", sep = "-")),
         fy = if_else(month(crh_month) > 9, year(crh_month) + 1, year(crh_month)),
         qtr = case_when(month(crh_month) %in% c(10, 11, 12) ~ 1,
                         month(crh_month) %in% c(1, 2, 3) ~ 2,
                         month(crh_month) %in% c(4, 5, 6) ~ 3,
                         month(crh_month) %in% c(7, 8, 9) ~ 4),
         fyqtr = str_c(fy, "-", qtr),
         ssc_117_flag = if_else(secondarystopcode == 117, T, F)) %>%
  rename(sta5a = spoke_sta5a_combined_cdw) %>%
  filter(fy %in% c(2020, 2021) 
         & care_type == "Primary Care") %>%
  mutate(secondarystopcode = if_else(is.na(secondarystopcode) == T, "Missing", as.character(secondarystopcode))) %>%
  group_by(primarystopcode, secondarystopcode) %>%
  summarise(crh_sc_count = n())
#-----------------------------------------------------------------------------------------------------------
crh_vs_pcat <- pc_crh_stopCode_count %>%
  left_join(., pcat_sc_count %>% mutate(sStopCode = as.character(sStopCode)), 
            by = c("primarystopcode" = "pStopCode", "secondarystopcode" = "sStopCode")) %>%
  left_join(., sc_names, by = c("primarystopcode" = "stopcode")) %>%
  rename(pSCName = stopCodeName) %>%
  left_join(., sc_names %>% mutate(stopcode = as.character(stopcode)), by = c("secondarystopcode" = "stopcode")) %>%
  mutate(sSCName = if_else(is.na(sSCName), stopCodeName, sSCName)) %>%
  mutate(crh_prop = round(crh_sc_count / 306855 * 100, 1),
         pcat_prop = round(pcat_stopCode_count / 287176114 * 100, 1)) %>%
  select(primarystopcode, pSCName, secondarystopcode, sSCName, crh_sc_count, crh_prop, pcat_stopCode_count, pcat_prop) %>% 
  janitor::adorn_totals() %>%
  mutate(crh_prop = paste0(crh_prop, "%"),
         pcat_prop = if_else(is.na(pcat_prop), "-", as.character(pcat_prop)),
         pcat_prop = paste0(pcat_prop, "%"))
#
crh_vs_pcat %>%
  kbl(col.names = c("Primary SC", "PSC Name", "Secondary SC", "SSC Name", "CRH Count", "CRH %", "PCAT Count", "PCAT %")) %>%
  kable_classic("striped")
