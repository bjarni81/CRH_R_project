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
#connect to a06
rb03_con = DBI::dbConnect(odbc::odbc(),
                         Driver = "SQL Server",
                         Server = "vhacdwrb03.vha.med.va.gov",
                         Database = "VINCI_PSSG",
                         Trusted_Connection = "true")
#--
#=====
urh_fxn = function(fy){
  fy2 = if(fy == 2024){2023}
    else{{{fy}}}
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
  dbExecute(rb03_con, "drop table if exists ##temp")
  #
  cat(crayon::bgCyan("starting to push scrssns to temp table", Sys.time(), "\n"))
  tictoc::tic(crayon::green("pushing scrssns to temp table"))
  DBI::dbWriteTable(conn = rb03_con,
                    name = "##temp",
                    value = scrssn)
  tictoc::toc()
  rm(scrssn)
  #--
  cat(crayon::bgYellow("starting final query\n"))
  #tictoc::tic(crayon::red("final query"))
  #
  dbGetQuery(rb03_con,
             str_replace_all(paste0("with CTE as(
	select a.urh, b.scrssn_num, b.sta5a, b.fy
	from [VINCI_PSSG].[PSSG].[FY", {{fy2}}, "] as a
	inner join ##temp as b
		on a.ScrSSN = b.ScrSSN_num
		)
select sta5a, fy	
	, urban_sum = sum(case when urh = 'U' then 1 else 0 end)
	, rural_sum = sum(case when urh IN('R', 'H', 'I') then 1 else 0 end)
	, urh_count = count(*)
from cte
group by sta5a, fy"),
                             c("\\n|\\t"), " "))
  #tictoc::toc()
}
#
urh = urh_fxn(2021) %>%
  bind_rows(., urh_fxn(2022)) %>%
  bind_rows(., urh_fxn(2023)) %>%
  bind_rows(., urh_fxn(2024))
#=========
pccrh_eng_name = DBI::Id(schema = "pccrh_eng",
                         table = "F_urh")
dbWriteTable(oabi_con,
             pccrh_eng_name,
             urh,
             overwrite = TRUE)
#
dbDisconnect(rb03_con)