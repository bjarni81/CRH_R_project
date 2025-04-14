library(tidyverse)
library(DBI)
#
#connect to sql13
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#
uniques_fxn = function(fy){
  query_text = str_replace_all(paste0("with CTE as (
    select ScrSSN_char, PatientICN, sta5a, fy, AssignPCPDays
        , rownum = ROW_NUMBER() over(partition by PatientICN, fy order by AssignPCPDays desc)
    from [PCS_PCAT].[econ].PatientPCP_2020_2024
    where fy = ", {{fy}}, "
        AND ScrSSN_Num IS NOT NULL
    )
    select sta5a, pcmm_scrssn_count = count(distinct ScrSSN_char)
    , fy = ", {{fy}}, "
    from cte 
    where rownum = 1
    group by sta5a"),
                               pattern = "\\t|\\n", 
                               replacement = " ")
  #
  DBI::dbGetQuery(oabi_con,
                  query_text)
}
#
unique_scrssn = uniques_fxn(2021) %>%
  bind_rows(., uniques_fxn(2022)) %>%
  bind_rows(., uniques_fxn(2023)) %>%
  bind_rows(., uniques_fxn(2024))
#=========
pccrh_eng_name = DBI::Id(schema = "pccrh_eng",
                         table = "E_uniques")
dbWriteTable(oabi_con,
             pccrh_eng_name,
             unique_scrssn,
             overwrite = TRUE)