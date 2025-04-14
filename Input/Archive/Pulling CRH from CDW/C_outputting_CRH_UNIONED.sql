/*CRH Encounters:
	- Concatenating CRH_ALL and CRH_locationName
	- De-duplicating by VisitSID
*/
--====================================
/*Step 1: Hub lookup table for making flags*/
select Hub_Sta3n as hub_sta5a
into #hubs
from [PACT_CC].[CRH].CRH_sites_FY20_working
UNION
select Hub_Sta3n as hub_sta5a
from [PACT_CC].[CRH].CRH_sites_FY21_working;
--30
--====================================
/*Step 2: UNION All the 2 tables*/
drop table if exists #unioned;
--
select *
	, hub_flag = case when Spoke_Sta5a in(select hub_sta5a from #hubs) then 2 else 1 end
into #unioned
from [OABI_MyVAAccess].[crh_eval].encounters_B1_char4
	where VISITSID IS NOT NULL
UNION ALL
select *
	, hub_flag = case when Spoke_Sta5a in(select hub_sta5a from #hubs) then 2 else 1 end
from [OABI_MyVAAccess].[crh_eval].encounters_B2_LocationName
	where VISITSID IS NOT NULL;
--1,607,399
--====================================
/*Step 3: Row_Number paritioned by visitSID, ordered by hub_flag*/
drop table if exists #union_rowNum;
--
select *
	, qtr = case
		when month(visitDate) in(10, 11, 12) then 1
		when month(visitDate) in(1, 2, 3) then 2
		when month(visitDate) in(4, 5, 6) then 3
		when month(visitDate) in(7, 8, 9) then 4
		else NULL end
	, fy = case
		when month(visitDate) > 9 then year(visitDate) + 1
		when month(visitDate) < 10 then year(visitDate)
		else NULL end
	, ROW_NUMBER() over(partition by visitsid order by hub_flag) as rn_visitsid
into #union_rowNum
from #unioned;
--1,607,399
--=====================================
/*Output permanent table
	- Join most_freq_sta5a
	- 'WHERE rn_visitsid = 1'
*/
drop table if exists [OABI_MyVAAccess].[crh_eval].encounters_C_unioned;
--
select a.*
	, b.sta5a_most_freq
	, fy_qtr = CONCAT(a.fy, '_', a.qtr)
into [OABI_MyVAAccess].[crh_eval].encounters_C_unioned
from #union_rowNum as a
left join [OABI_MyVAAccess].[crh_eval].encounters_A1_most_freq_sta5a as b
	on a.ScrSSN = b.ScrSSN
where rn_visitsid = 1;
--909,609
--++==++==++==++==
--Scratch
--++==++==++==++==
select top 100 *
from [OABI_MyVAAccess].[crh_eval].encounters_C_unioned
order by ScrSSN, VisitDate;


