select top 100 * from [OABI_MyVAAccess].crh_eval.D2_race_gender_urh_count
--
drop table if exists [OABI_MyVAAccess].[crh_eval].F6_urh_white_female_prop_postCOVID;
--
select sta5a
	, rural_prop = cast(urh_rural_count as float) / cast(scrssn_count as float)
	, race_white_prop = cast(race_white_count as float) / cast(scrssn_count as float)
	, female_prop = cast(female_count as float) / cast(scrssn_count as float)
into [OABI_MyVAAccess].[crh_eval].F6_urh_white_female_prop_postCOVID
from [OABI_MyVAAccess].[crh_eval].D2_race_gender_urh_count
where fy = 2021;
--1,072