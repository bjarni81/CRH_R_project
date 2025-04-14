library(tidyverse)
library(DBI)
#
set.seed(12345)
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Truested_Connection = "true")
#----
crh_subset <- dbGetQuery(oabi_con,
                        "select distinct sp.patientLastName, SUBSTRING(sp.PatientSSN, 6, 4) as last_4
                          	, Spoke_Sta5a, vast.short_name, VisitDate
                          from [OABI_MyVAAccess].[crh_eval].CRH_ALL as a
                          left join [CDWWork].[SPatient].SPatient as sp
                          on a.ScrSSN = sp.ScrSSN
                          left join [OABI_MyVAAccess].[crh_eval].VAST_from_A06_11jan21 as vast
                          	on a.Spoke_Sta5a = vast.sta5a
                          where spoke_sta5a in('463', '653', '531')
                          	AND sp.CDWPossibleTestPatientFlag = 'N' 
                          	AND year(visitDate) = 2021
                          	AND MONTH(visitdate) in(1, 2, 3);")
#
for_ashok <- crh_subset %>%
  group_by(Spoke_Sta5a) %>%
  sample_n(., 15)
#
write_csv(for_ashok,
          "H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Output/Data/for_ashok.csv")
