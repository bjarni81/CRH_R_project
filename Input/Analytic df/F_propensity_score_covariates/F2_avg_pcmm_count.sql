/*Unique ScrSSN count by sta5a in Q4 FY2018*/
/*=====================================================*/
--==
drop table if exists [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count;
--
with cte as(
select count(distinct ScrSSN_char) as pcmm_scrssn_count, pcmm.sta5a
from [PACT_CC].[econ].PatientPCP as pcmm
inner join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on pcmm.Sta5a = vast.sta5a
where fy = 2018 AND qtr = 4
group by pcmm.sta5a)
select sta5a, pcmm_scrssn_count
into [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count
from cte
--1,009