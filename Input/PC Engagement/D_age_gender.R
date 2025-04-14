library(tidyverse)
library(DBI)
#connect to sql13
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#
age_gender_fxn = function(fy){
  DBI::dbExecute(oabi_con, "drop table if exists ##temp")
  DBI::dbExecute(oabi_con, "drop table if exists ##scrssn")
  query_text = str_replace_all(paste0("
  with cte as(
select ScrSSN_char, PatientICN, sta5a, fy, AssignPCPDays
        , rownum = ROW_NUMBER() over(partition by PatientICN, fy order by AssignPCPDays desc)
    from [PCS_PCAT].[econ].PatientPCP_2020_2024
    where fy = ", {{fy}}, "
        AND ScrSSN_Num IS NOT NULL
)
select * 
into ##scrssn
from cte
where rownum = 1"),
  pattern = "\\t|\\n",
  replacement = " ")
#
query_text2 = str_replace_all(paste0("
select distinct a.ScrSSN_Char, a.Sta5a, b.birthdatetime
	, age_jan1 = DATEDIFF(year, b.birthdateTime, cast('", {{fy}}, "-01-01 00:00:01' as datetime))
	, b.gender
into ##temp
from ##scrssn as a
left join [CDWWork].[SPatient].SPatient as b
	on a.ScrSSN_Char = b.ScrSSN
where b.CDWPossibleTestPatientFlag = 'N'
	and b.VeteranFlag = 'Y';"),
                              pattern = "\\t|\\n",
                              replacement = " ")
query_text3 = str_replace_all(paste0("
select sta5a, AVG(CAST(age_jan1 as float)) as age_jan1_mean, STDEV(age_jan1) as age_jan1_sd
	, male_count = sum(case when gender = 'M' then 1 else 0 end)
	, female_count = sum(case when gender = 'F' then 1 else 0 end)
	, scrssn_count = count(*)
	, fy = ", {{fy}}, "
from ##temp
group by sta5a"),
                              pattern = "\\t|\\n",
                              replacement = " ")
#
DBI::dbExecute(oabi_con,
               query_text)
DBI::dbExecute(oabi_con,
               query_text2)
DBI::dbGetQuery(oabi_con,
                query_text3)
}
#
age_gender = age_gender_fxn(2021) %>%
  bind_rows(., age_gender_fxn(2022)) %>%
  bind_rows(., age_gender_fxn(2023)) %>%
  bind_rows(., age_gender_fxn(2024))
#=========
pccrh_eng_name = DBI::Id(schema = "pccrh_eng",
                         table = "D_age_gender")
dbWriteTable(oabi_con,
             pccrh_eng_name,
             age_gender,
             overwrite = TRUE)