/*
Program to assemble 2 components of the PC CRH Penetration Rates:
	- PC CRH Encounters
	- Total PC Encounters
--
Written by Bjarni Haraldsson
Winter, 2022
*/
--#########################################################################################################
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Count of total PC CRH encounters
--	by visitMonth and spoke sta5a
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists #crh_visitMonth;
--
select *
	, DATEFROMPARTS(year(visitdate), month(visitdate), '01') as crh_month
into #crh_visitMonth
from [PACT_CC].[CRH].C_crh_utilization_final
where care_type = 'Primary Care';
--983,634
drop table if exists #crh_encounters_month;
--
select count(*) as crh_encounter_count
	, spoke_sta5a_combined_cdw as sta5a
	, crh_month
into #crh_encounters_month
from #crh_visitMonth
where care_type = 'Primary Care'
group by spoke_sta5a_combined_cdw
	, crh_month;
--15,562
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Make a left-hand side table for joining onto - Month
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists #sta5as;
--
select distinct sta5a
into #sta5as
from #crh_encounters_month;
--779
drop table if exists #crh_months;
--
select distinct crh_month into #crh_months from #crh_visitMonth;
--71
--==
drop table if exists #sta5a_month;
--
select sta5a, crh_month
	, fy = case when month(crh_month) > 9 then year(crh_month) + 1 else year(crh_month) end
	, qtr = case when month(crh_month) in(10, 11, 12) then 1
				when month(crh_month) in(1, 2, 3) then 2
				when month(crh_month) in(4, 5, 6) then 3
				when month(crh_month) in(7, 8, 9) then 4 end
into #sta5a_month
from #sta5as
cross join #crh_months;
--55,309
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Join all tables - Monthly CRH
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists [OABI_MyVAAccess].[crh_eval].B1_crh_penRate;
--
select a.sta5a, a.crh_month
	, b.crh_encounter_count
	, c.pc_encounter_total
	, pc_crh_per_1k_total_pc = cast(b.crh_encounter_count as float) / cast(b.crh_encounter_count + c.pc_encounter_total as float) * 1000
into [OABI_MyVAAccess].[crh_eval].B1_crh_penRate
from #sta5a_month as a
left join #crh_encounters_month as b
	on a.sta5a = b.sta5a
		and a.crh_month = b.crh_month
left join [OABI_MyVAAccess].[crh_eval].A1_pc_enc_scrssn_count as c
	on a.sta5a = c.Sta6a
		and a.crh_month = c.visitMonth
--58,765
--
select top 100 *
from [OABI_MyVAAccess].[crh_eval].B1_crh_penRate
--
select max(crh_month)
from [OABI_MyVAAccess].[crh_eval].B1_crh_penRate