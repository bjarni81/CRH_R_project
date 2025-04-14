/*ADI by sta5a in FY18 Q4*/
/*=====================================================*/
--==
drop table if exists [OABI_MyVAAccess].[crh_eval].F4_adi_avg;
--
select adi.sta5a
	, adi.adi_natRnk_avg
into [OABI_MyVAAccess].[crh_eval].F4_adi
from [OABI_MyVAAccess].[crh_eval].D3_adi_sta5a_qtr as adi
inner join [OABI_MyVAAccess].[crh_eval].C2_vast_from_a06 as vast
	on adi.Sta5a = vast.sta5a
where fy = 2018 and qtr = 4
--1,009
--