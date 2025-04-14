

--==++==++==++==++
/*Hub sta5a lookup table*/
select Hub_Sta3n as hub_sta5a
into #hubs
from [PACT_CC].[CRH].CRH_sites_FY20_working
UNION
select hub_sta3n as hub_sta5a
from [PACT_CC].[CRH].CRH_sites_FY21_working
--==++==++==++==++
/*Count(*) by ScrSSN and spoke_sta5a
	- Make hub_flag for sorting*/
drop table if exists #counts_1;
--
select ScrSSN, Spoke_Sta5a, count(*) as sta5a_crh_count
	, hub_flag = case when spoke_sta5a in(select hub_sta5a from #hubs) then 2 else 1 end
into #counts_1
from [OABI_MyVAAccess].[crh_eval].CRH_UNIONED
group by ScrSSN, Spoke_Sta5a;
--
--==++==++==++==++
/*row_number to get most frequent sta5a where hub_flag <> 2*/
drop table if exists #counts_2;
--
select *
	, ROW_NUMBER() over(partition by ScrSSN order by sta5a_crh_count desc, hub_flag asc) as rowNum
into #counts_2
from #counts_1;
--
--==++==++==++==++
/*Output final table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].freq_crh_scrssn_sta5a;
--
select ScrSSN, Spoke_Sta5a as most_freq_spoke_sta5a
into [OABI_MyVAAccess].[crh_eval].freq_crh_scrssn_sta5a
from #counts_2
where rowNum = 1;
--
select top 100 *
from [OABI_MyVAAccess].[crh_eval].freq_crh_scrssn_sta5a
order by ScrSSN
