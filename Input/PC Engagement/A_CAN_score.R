library(tidyverse)
library(DBI)
#--
#connect to sql13
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#--
#connect to a01
a01_con = DBI::dbConnect(odbc::odbc(),
                         Driver = "SQL Server",
                         Server = "vhacdwa01.vha.med.va.gov",
                         Database = "CAN_Reporting",
                         Trusted_Connection = "true")
#--
riskDates = dbGetQuery(a01_con,
                       "select distinct riskdate
                       from [CAN_Reporting].[DOEx].[can_weekly_report_V2_5_history]
                       where year(riskdate) > 2019") %>%
  mutate(riskdate = ymd(riskdate)) %>%
  arrange(riskdate) %>%
  filter(riskdate >= ymd("2020-10-01")
         & riskdate < ymd("2024-10-01"))
#-
riskDates %>% pull()
#=====
can_fxn = function(fy){
  start_date = ymd(str_c(fy - 1, "09", "30", sep = "-"))
  end_date = ymd(str_c(fy, "10", "01", sep = "-"))
  #
  cat(crayon::bgMagenta("starting to pull scrssns", Sys.time(), "\n"))
  tictoc::tic(crayon::magenta("pulling scrssns"))
  scrssn = dbGetQuery(oabi_con,
                      str_replace_all(paste("with cte as(
                      	select ScrSSN_num, PatientICN, sta5a, fy, AssignPCPDays
                      		, rownum = ROW_NUMBER() over(partition by PatientICN, fy order by AssignPCPDays desc)
                      	from [PCS_PCAT].[econ].PatientPCP_2020_2024
                      	where fy = ", {{fy}}, "
                      		AND ScrSSN_Num IS NOT NULL
                      )
                      select ScrSSN_num, PatientICN, sta5a, fy
                      from cte
                      where rownum = 1"),
                                      c("\\n|\\t"),
                                      replacement = " "))
  tictoc::toc()
  #-
  dbExecute(a01_con, "drop table if exists ##temp")
  #
  cat(crayon::bgCyan("starting to push scrssns to temp table", Sys.time(), "\n"))
  tictoc::tic(crayon::green("pushing scrssns to temp table"))
  DBI::dbWriteTable(conn = a01_con,
                    name = "##temp",
                    value = scrssn)
  tictoc::toc()
  rm(scrssn)
  #--
  dates = riskDates %>%
    filter(riskdate > start_date
           & riskdate < end_date) %>%
    pull
  #
  phrase = vector()
  for (i in 1:length(dates)){
    phrase = if(i == 1){
      paste0("cast('", dates[i], "' as date)")
    }
    else{
      append(phrase, paste0("cast('", dates[i], "' as date)"))
    }}
  phrase = phrase %>%
    str_c(., collapse = ", ")
  #--
  cat(crayon::bgYellow("starting final query", Sys.time(), "\n"))
  #tictoc::tic(crayon::red("final query"))
  #
  dbGetQuery(a01_con,
             str_replace_all(paste0("with CTE as (               
select a.riskDate
, a.pMort_90d
, a.pHosp_90d
, a.cHosp_90d
, a.cMort_90d
, b.sta5a                  
, cMort_90d_gt95 = case when a.cMort_90d >= 95 then 1 else 0 end
, cMort_90d_gt90 = case when a.cMort_90d >= 90 then 1 else 0 end                 
, cMort_90d_gt80 = case when a.cMort_90d >= 80 then 1 else 0 end                  
, cHosp_90d_gt95 = case when a.cHosp_90d >= 95 then 1 else 0 end                  
, cHosp_90d_gt90 = case when a.cHosp_90d >= 90 then 1 else 0 end                 
, cHosp_90d_gt80 = case when a.cHosp_90d >= 80 then 1 else 0 end                 
, risk_month = DATEFROMPARTS(year(riskdate), month(riskdate), '01')
from [CAN_Reporting].[DOEx].can_weekly_report_V2_5_history as a                
left join ##temp as b                 
on a.PatientICN = b.PatientICN                 
where a.riskDate IN(", phrase,"))
select sta5a, risk_month                
, cMort_90d_mean = AVG(CAST(cMort_90d as FLOAT))           
, cMort_90d_max = MAX(cMort_90d)                   
, cHosp_90d_mean = AVG(CAST(cHosp_90d as FLOAT))                  
, cHosp_90d_max = MAX(cHosp_90d)                  
, cMort_90d_gt95_sum = SUM(cMort_90d_gt95)         
, cMort_90d_gt90_sum = SUM(cMort_90d_gt90)                
, cMort_90d_gt80_sum = SUM(cMort_90d_gt80)                
, cHosp_90d_gt95_sum = SUM(cHosp_90d_gt95)                
, cHosp_90d_gt90_sum = SUM(cHosp_90d_gt90)                
, cHosp_90d_gt80_sum = SUM(cHosp_90d_gt80)  
, tot_count = count(*)                
, missing_pat_count = sum(case when cMort_90d IS NULL THEN 1 ELSE 0 END)               
from CTE               
group by sta5a, risk_month"),
                             c("\\n|\\t"), " ")) %>%
    mutate(fy = {{fy}})
  #tictoc::toc()
}
#
tictoc::tic(crayon::blue("the whole fy21"))
can_fy21 = can_fxn(2021)
tictoc::toc()
#
tictoc::tic(crayon::blue("the whole fy22"))
can_fy22 = can_fxn(2022)
tictoc::toc()
#
tictoc::tic(crayon::blue("the whole fy23"))
can_fy23 = can_fxn(2023)
tictoc::toc()
#
tictoc::tic(crayon::blue("the whole fy24"))
can_fy24 = can_fxn(2024)
tictoc::toc()
#---------
dbExecute(a01_con, "drop table if exists ##temp")
#---------
can_all = can_fy21 %>%
  bind_rows(., can_fy22,
            can_fy23,
            can_fy24)
#=========
pccrh_eng_name = DBI::Id(schema = "pccrh_eng",
                         table = "A_CAN_score")
dbWriteTable(oabi_con,
             pccrh_eng_name,
             can_all,
             overwrite = TRUE)
#=========================
