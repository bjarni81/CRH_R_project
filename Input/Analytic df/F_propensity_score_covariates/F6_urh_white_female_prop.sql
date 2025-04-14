select top 100 * from [OABI_MyVAAccess].crh_eval.D2_race_gender_urh_count
--
select sta5a
	, rural_prop = cast(urh_rural_count as float) / cast(scrssn_count as float)
	, race_white_prop = cast(race_white_count as float) / cast(scrssn_count as float)
	, female_prop = cast(female_count as float) / cast(scrssn_count as float)
into [OABI_MyVAAccess].[crh_eval].F6_urh_white_female_prop
from [OABI_MyVAAccess].[crh_eval].D2_race_gender_urh_count
where fy = 2018 AND qtr = 4