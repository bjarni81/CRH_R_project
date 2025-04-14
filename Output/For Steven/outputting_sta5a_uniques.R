library(tidyverse)
library(DBI)
#--
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#=====
uniques_sta5a <- dbGetQuery(oabi_con,
                            "
                            with cte as(
	select visitDate = cast(a.VisitDateTime as date)
		, visitMonth = DATEFROMPARTS(year(a.visitDateTime), month(a.visitDateTime), '01')
		, fy = case when month(a.visitDateTime) > 9 then year(a.visitDateTime) + 1 else year(a.visitDateTime) end
		, qtr = case 
					when month(a.visitDateTime) in(10, 11, 12) then 1
					when month(a.visitDateTime) in(1, 2, 3) then 2
					when month(a.visitDateTime) in(4, 5, 6) then 3
					when month(a.visitDateTime) in(7, 8, 9) then 4 end	
		, spat.ScrSSN
		, div.Sta6a
		, psc.StopCode as primaryStopCode, psc.StopCodeName as pStopCodeName
		, ssc.StopCode as secondaryStopCode
		, sStopCodeName = case when ssc.StopCode IS NULL then '*Unknown at this time*' else ssc.StopCodeName end
		, encounter_type = case
			when psc.StopCode = 338 and (ssc.StopCode IN(185, 186, 187, 188) OR ssc.StopCode IS NULL) then 'Telephone'
			when ssc.StopCode = 179 OR (ssc.StopCode > 689 AND ssc.StopCode < 700) then 'Video'
			--when ssc.StopCode = 719 then 'Secure Message'/*excluding secure message encounters, per email on April 21st, 2022*/
			when psc.StopCode <> 338 and (ssc.StopCode IN(185, 186, 187, 188) OR ssc.StopCode IS NULL) then 'In-Person'
			else 'Other' 
			end
		, vaccine_flag = case
			when ssc.StopCode = 710 then 1 else 0 end
		, vast.parent_visn
		, vast.parent_station_sta5a
	from [CDWWork].[Outpat].Workload as a
	left join [CDWWork].[Dim].StopCode as psc
		on a.PrimaryStopCodeSID = psc.StopCodeSID
	left join [CDWWork].[Dim].StopCode as ssc
		on a.SecondaryStopCodeSID = ssc.StopCodeSID
	left join [CDWWork].[SPatient].SPatient as spat
		on a.PatientSID = spat.PatientSID
	left join [CDWWork].[Dim].Division as div
		on a.DivisionSID = div.DivisionSID
	inner join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
		on div.Sta6a = vast.sta5a
	where a.visitdatetime > cast('2020-09-30' as datetime2) 
		AND a.VisitDateTime < cast('2022-10-01' as datetime2)
		AND ((psc.StopCode IN(322, 323, 338, 348, 350, 704) 
				AND (ssc.StopCode NOT IN(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 710, 999)
					OR ssc.StopCode IS NULL))
			OR ssc.StopCode IN(322, 323, 348, 350, 704))
		)
select count(distinct scrssn) as scrssn_count, Sta6a
from cte
group by Sta6a") %>%
  rename(sta5a = Sta6a)
#--
write_csv(uniques_sta5a,
          here("Output", "For Steven", "pc_uniques_sta5a.csv"))
