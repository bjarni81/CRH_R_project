library(tidyverse)
library(lubridate)
library(DT)
library(kableExtra)
library(readxl)
library(DBI)
library(here)
#=====
pactcc_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "PACT_CC",
                      Trusted_Connection = "true")
#
f2f_by_fy <- dbGetQuery(pactcc_con,
                        "select count(*) as f2f_count,
                        	fy
                        from [PACT_CC].[CRH].[crh_full_utilization_final_fy20_21]
                        where locationname like '%F2F%'
                        	AND fy in(2020, 2021)
                        group by fy")
#--
f2f_by_visn <- dbGetQuery(pactcc_con,
                          "select count(*) as f2f_count,
                        	hub_visn
                        from [PACT_CC].[CRH].[crh_full_utilization_final_fy20_21]
                        where locationname like '%F2F%'
                        	AND fy in(2020, 2021)
                        group by hub_visn")
#--
f2f_by_visn_fy <- dbGetQuery(pactcc_con,
                          "select count(*) as f2f_count,
                        	hub_visn, fy
                        from [PACT_CC].[CRH].[crh_full_utilization_final_fy20_21]
                        where locationname like '%F2F%'
                        	AND fy in(2020, 2021)
                        group by hub_visn, fy") %>%
  pivot_wider(names_from  = fy,
              values_from = f2f_count)
  
