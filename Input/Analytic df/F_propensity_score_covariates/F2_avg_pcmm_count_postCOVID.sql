/*Unique ScrSSN count by sta5a in Q4 FY2018*/
/*=====================================================*/
--==
drop table if exists [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count_postCOVID;
--
with cte as(
select count(distinct ScrSSN_char) as pcmm_scrssn_count, pcmm.sta5a
from [PACT_CC].[econ].PatientPCP as pcmm
inner join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on pcmm.Sta5a = vast.sta5a
where fy = 2021
group by pcmm.sta5a)
select sta5a, AVG(pcmm_scrssn_count) as pcmm_scrssn_count
into [OABI_MyVAAccess].[crh_eval].F2_pcmm_scrssn_count_postCOVID
from cte
group by sta5a
--1,062