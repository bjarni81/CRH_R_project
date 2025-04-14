library(tidyverse)
library(DBI)
#connect to sql13
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#
adi_fxn = function(fy){
  fy2 = if(fy < 2022){2021}#as of writing this the most recent pssg year is 2022
  else {2022}
  #
  query_text = str_replace_all(paste0("with CTE as (
    select ScrSSN_char, PatientICN, sta5a, fy, AssignPCPDays
        , rownum = ROW_NUMBER() over(partition by PatientICN, fy order by AssignPCPDays desc)
    from [PCS_PCAT].[econ].PatientPCP_2020_2024
    where fy = ", {{fy}}, "
        AND ScrSSN_Num IS NOT NULL
    )
    select cte.sta5a, AVG(TRY_CONVERT(numeric, adi21.adi_natrank)) as adi_natrank_mean
	, adi_notMissing_cnt = sum(case when adi21.adi_natrank IS NOT NULL then 1 else 0 end)
	, adi_missing_cnt = sum(case when adi21.adi_natrank IS NULL then 1 else 0 end)
	, fy = ", {{fy}}, "
    from cte as cte
    left join [PCS_PCAT].[Geo].PatientBlockGroup", {{fy2}}, "Q4 as cb
    	on cte.scrssn_char = cb.ScrSSN_char
    left join [PCS_PCAT].[Geo].adi2021 as adi21
    	on SUBSTRING(cb.fips, 1, 12) = adi21.fips
    where cte.rownum = 1
    group by cte.sta5a"),
                               pattern = "\\t|\\n", 
                               replacement = " ")
  #
  DBI::dbGetQuery(oabi_con,
                  query_text)
}
adi = adi_fxn(2021) %>%
  bind_rows(., adi_fxn(2022),
            adi_fxn(2023),
            adi_fxn(2024))
#=========
pccrh_eng_name = DBI::Id(schema = "pccrh_eng",
                         table = "C_adi")
dbWriteTable(oabi_con,
             pccrh_eng_name,
             adi,
             overwrite = TRUE)
