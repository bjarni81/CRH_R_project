library(tidyverse)
library(DBI)
#-----------
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#-----------
vast <- dbGetQuery(oabi_con,
                   "select * from [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06")
#--===
penRate <- dbGetQuery(oabi_con,
                      "select pr.*
                    	, crh_flag = case 
                    		when c1.crh_10_flag = 1 then 1
                    		else 0 end
                      from [OABI_MyVAAccess].[crh_eval].B1_crh_penRate as pr
                      left join [OABI_MyVAAccess].[crh_eval].C1_crh_flag as c1
	                    on pr.sta5a = c1.sta5a") %>%
  inner_join(., vast) %>%
  mutate(crh_month = ymd(crh_month),
         fy = if_else(month(crh_month) > 9, year(crh_month) + 1, year(crh_month)),
         qtr = case_when(
           month(crh_month) %in% c(10, 11, 12) ~ 1,
           month(crh_month) %in% c(1, 2, 3) ~ 2,
           month(crh_month) %in% c(4, 5, 6) ~ 3,
           month(crh_month) %in% c(7, 8, 9) ~ 4),
         fy_qtr = str_c(fy, qtr, sep = "-")) %>%
  filter(crh_flag == 1) %>%
  group_by(sta5a, fy_qtr) %>%
  summarise(crh_encounter_count = sum(crh_encounter_count, na.rm = TRUE), 
            pc_encounter_total = sum(pc_encounter_total, na.rm = TRUE)) %>%
  mutate(pc_crh_per_1k_total_pc = case_when(
    crh_encounter_count > 0 & pc_encounter_total > 0 ~ 
      crh_encounter_count / (crh_encounter_count + pc_encounter_total) * 1000,
    TRUE ~ NA_real_)) %>%
  select(-c(crh_encounter_count, pc_encounter_total)) %>%
  pivot_wider(names_from = fy_qtr, values_from = pc_crh_per_1k_total_pc)
#=====
write_csv(penRate,
          here("Output", "pc_crh_penRate_sta5a_qtr_19may22", "pc_crh_penRate_sta5a_qtr.csv"))
