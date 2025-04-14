
-- Pull-in non-va pc-cc referrals
	-- create fy and qtr columns
drop table if exists #ScrSSN_fyQtr_nonVA;
--
with CTE as(
	select scrssn, activityDateTime, Sta6a
		, fy = case 
			when month(activityDateTime) > 9 then year(activityDateTime) + 1
			else year(activityDateTime) end
		, qtr = case
			when month(activityDateTime) in(10, 11, 12) then 1
			when month(activityDateTime) in(1, 2, 3) then 2
			when month(activityDateTime) in(4, 5, 6) then 3
			when month(activityDateTime) in(7, 8, 9) then 4
			else NULL end
	from [OABI_MyVAAccess].[crh_eval].G_pc_communityCare_referrals
	where non_va = 1
	)
select ScrSSN, fy, qtr, count(*) as referral_count
into #ScrSSN_fyQtr_nonVA
from CTE
group by scrssn, fy, qtr
--175,998
select count(distinct scrssn) from #ScrSSN_fyQtr_nonVA
--119,898
--==================
-- PC CC referrals joined with PCMM on scrssn, fy, and qtr to get sta5a
	-- also row_number to get 1 per scrssn-fy_qtr
drop table if exists #pc_refs_w_sta5a;
--
with CTE as(
	select a.*, b.sta5a, b.AssgnDaysInQtr, b.AssignPCPDays
		, ROW_NUMBER() over(partition by ScrSSN, a.fy, a.qtr order by AssgnDaysInQtr, AssignPCPDays desc) as rowNum
	from #ScrSSN_fyQtr_nonVA as a
	left join [PACT_CC].[econ].PatientPCP as b
	on a.scrssn = b.ScrSSN_char
		and a.fy = b.fy
		and a.qtr = b.QTR
	)
select *
into #pc_refs_w_sta5a
from CTE
where rowNum = 1;
--175,998
select count(*) from #pc_refs_w_sta5a where Sta5a IS NULL
--81,275
select count(distinct scrssn) from #pc_refs_w_sta5a where Sta5a IS NULL
--56,960
--=================
--Finding sta5as for patients without a match on fy_qtr
	-- also row_number to get one per scrssn-qtr
drop table if exists #finding_sta5a;
--
with CTE as(
	select a.ScrSSN, a.fy as fy_ref, a.qtr as qtr_ref, a.referral_count
		, b.sta5a, b.fy, b.qtr, b.AssgnDaysInQtr, b.AssignPCPDays,
		ROW_NUMBER() over(partition by ScrSSN, b.fy, b.qtr order by b.AssgnDaysInQtr, b.AssignPCPDays desc) as rowNum
	from #pc_refs_w_sta5a as a
	left join [PACT_CC].[econ].PatientPCP as b
	on a.scrssn = b.ScrSSN_char
		 AND b.fy > 2018
	where a.sta5a IS NULL
	)
select *
	, fy_dif = ABS(fy_ref - fy)--absolute value of differences to get closest in time with a row_number later
	, qtr_dif = ABS(qtr_ref - qtr)--absolute value of differences to get closest in time with a row_number later
into #finding_sta5a
from CTE
where rowNum = 1;
--283,626
select count(distinct scrssn) from #finding_sta5a
--56,960
--======
--Row_number to get most recent sta5a
drop table if exists #finding_sta5a2;
--
with CTE as (
	select *
		, ROW_NUMBER() over(partition by scrssn, fy_ref, qtr_ref order by fy_dif, qtr_dif, sta5a) as rowNum2
	from #finding_sta5a
	)
select *
into #finding_sta5a2
from CTE
where rowNum2 = 1;
--64,110
select count(distinct scrssn) from #finding_sta5a2
--56,960
select count(distinct scrssn) from #finding_sta5a2 where Sta5a IS NULL
--23,802
--==
drop table if exists #referrals_by_scrssn_sta5a_qtr;
--
select scrssn, Sta5a, fy, qtr, referral_count
into #referrals_by_scrssn_sta5a_qtr
from #pc_refs_w_sta5a
where sta5a IS NOT NULL
UNION ALL
select scrssn, sta5a, fy = fy_ref, qtr = qtr_ref, referral_count
from #finding_sta5a2
--158,833
---=-----
drop table if exists #final;
--
select a.scrssn, a.fy, a.qtr
	, b.sta5a, b.referral_count
into #final
from #ScrSSN_fyQtr_nonVA as a
left join #referrals_by_scrssn_sta5a_qtr as b
on a.scrssn = b.scrssn
	and a.fy = b.fy
	and a.qtr = b.qtr
--175,998
select top 100 *
from #final
order by scrssn, fy, qtr;
--
select count(*)
from #final
where sta5a IS NULL
--40,871
select count(distinct scrssn)
from #final
where sta5a IS NULL
--24,855
--============================================================
drop table if exists [OABI_MyVAAccess].[crh_eval].G2_referrals_sta5a_qtr;
--
select *
into [OABI_MyVAAccess].[crh_eval].G2_referrals_sta5a_qtr
from #final