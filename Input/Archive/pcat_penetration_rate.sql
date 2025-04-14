/*
Program to assemble 2 components of the PC CRH Penetration Rates:
	- PC CRH Encounters
	- Total PC Encounters
--
	PC Encounters in [PACT_CC].[econ].[Outp_PCMM_SSN_Summary] are defined as:
		PrimaryStopCode in(322, 323, 348, 350, 704)
			AND PrimaryStopCode not in(107, 115, 152, 311, 321, 328, 329, 333, 334, 430, 435, 474, 999) 
			OR SecondaryStopCode in(322, 323, 348, 350, 704)
--
Written by Bjarni Haraldsson
Winter, 2022
*/
--#########################################################################################################
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Count of total PC CRH encounters
--	by FY-Qtr and spoke sta5a
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists #crh_encounters_qtr;
--
select count(*) as crh_encounter_count
	, spoke_sta5a_combined_cdw as sta5a
	, fy, qtr
into #crh_encounters_qtr
from [PACT_CC].[CRH].C_crh_utilization_final
where care_type = 'Primary Care'
group by spoke_sta5a_combined_cdw
	, fy, qtr;
--2,068
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
--351,409
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
--4,639
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Make a left-hand side table for joining onto - Quarter
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists #sta5as;
--
select distinct sta5a
into #sta5as
from #crh_encounters_month;
--459
drop table if exists #fy_qtr;
--
create table #fy_qtr (
	fy int,
	qtr int);
insert into #fy_qtr (fy, qtr)
	values (2022, 1), (2021, 1), (2021, 2), (2021, 3), (2021, 4), (2020, 1), (2020, 2), (2020, 3), (2020, 4)
-- 9
drop table if exists #sta5a_qtr;
--
select sta5a, fy, qtr
into #sta5a_qtr
from #sta5as
cross join #fy_qtr;
--4,131
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Make a left-hand side table for joining onto - Month
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists #crh_months;
--
select distinct crh_month into #crh_months from #crh_visitMonth;
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
--12,393
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Join all tables - Quarterly CRH
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists [OABI_MyVAAccess].[crh_eval].crh_penRate_qtr;
--
select a.sta5a, a.fy, a.qtr
	, b.crh_encounter_count
	, c.pc_encounter_total
	, d.pc_encounter_total as pc_encounter_noVax_total
into [OABI_MyVAAccess].[crh_eval].crh_penRate_qtr
from #sta5a_qtr as a
left join #crh_encounters_qtr as b
	on a.sta5a = b.sta5a
		and a.fy = b.fy
		and a.qtr = b.qtr
left join [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr as c
	on a.sta5a = c.Sta6a
		and a.fy = c.fy
		and a.qtr = c.qtr
left join [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_qtr_noVax as d
	on a.sta5a = d.Sta6a
		and a.fy = d.fy
		and a.qtr = d.qtr;
--4,131
--
select top 100 *
from [OABI_MyVAAccess].[crh_eval].crh_penRate_qtr
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Join all tables - Monthly CRH
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drop table if exists [OABI_MyVAAccess].[crh_eval].crh_penRate_month;
--
select a.sta5a, a.crh_month
	, b.crh_encounter_count
	, c.pc_encounter_total
	, d.pc_encounter_total as pc_encounter_noVax_total
into [OABI_MyVAAccess].[crh_eval].crh_penRate_month
from #sta5a_month as a
left join #crh_encounters_month as b
	on a.sta5a = b.sta5a
		and a.crh_month = b.crh_month
left join [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month as c
	on a.sta5a = c.Sta6a
		and a.crh_month = c.visitMonth
left join [OABI_MyVAAccess].[crh_eval].pc_enc_scrssn_count_month_noVax as d
	on a.sta5a = d.Sta6a
		and a.crh_month = d.visitMonth
--12,393
--
select top 100 *
from [OABI_MyVAAccess].[crh_eval].crh_penRate_month
--
select min(crh_month)
from [OABI_MyVAAccess].[crh_eval].crh_penRate_month