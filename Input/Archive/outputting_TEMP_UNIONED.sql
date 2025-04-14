drop table if exists #foo;
--
select * 
into #foo
from [OABI_MyVAAccess].[crh_eval].CRH_ALL
	where VISITSID IS NOT NULL
UNION ALL
select *
from [OABI_MyVAAccess].[crh_eval].CRH_locationName
	where VISITSID IS NOT NULL
---
--
select count(*) from #foo where VISITSID IS NULL
--==3,174,093
drop table if exists #bar;
--
select *
	, ROW_NUMBER() over(partition by visitsid order by scrssn) as rn_visitsid
into #bar
from #foo
where VISITSID IS NOT NULL;
--
select top 100 *
from #bar
where scrssn in(select distinct scrssn from #bar where rn_visitsid > 1)
order by scrssn, VISITSID, rn_visitsid
--==
drop table if exists [OABI_MyVAAccess].[crh_eval].TEMP_UNIONED;
--
select *
into [OABI_MyVAAccess].[crh_eval].TEMP_UNIONED
from #bar
where rn_visitsid = 1;
--1,889,294
select *
	, ROW_NUMBER() over(partition by scrssn, visitdate order by visitdate) as rn_scrssn_vizDate
into #rn_scrssn_vizDate
from #rn_1;
--
select *
into #foo2
from #rn_scrssn_vizDate
where rn_scrssn_vizDate = 1

