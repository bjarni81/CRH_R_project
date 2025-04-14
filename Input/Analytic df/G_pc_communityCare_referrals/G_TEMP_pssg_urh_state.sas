libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table work.patids_fy_qtr as
select distinct scrssn, input(scrssn, 9.) as scrssn_char, fy, qtr
from crh.G_communityCare_referrals;
run;
/*4,631,889*/
/**/
proc sql;
create table patids_fy_qtr_pssg as
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2018_Q4_PH2 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2018
/*2019*/
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2019_Q4_PH2 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2019
/*2020*/
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2020_Q4_PH2 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2020
/*2021*/
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2021_Q1 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2021
	AND a.qtr = 1
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2021_Q2 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2021
	AND a.qtr = 2
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2021_Q3 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2021
	AND a.qtr = 3
UNION
select a.*
	, b.gender
	, b.urh
	, b.st, b.state_1, b.state_fips
from work.patids_fy_qtr as a
left join PAF_PSSG.FY2021_Q4 as b
	on a.scrssn_char = b.SCRSSN
where a.fy = 2021
	AND a.qtr = 4;
/*5,941,052*/
proc sql;
create table patids_fy_qtr_pssg2 as 
select a.*
	, b.gender
	, b.urh
from work.patids_fy_qtr as a
left join work.patids_fy_qtr_pssg as b
on a.scrssn = b.scrssn
	and a.fy = b.fy
	and a.qtr = b.qtr;
quit;
/*=================*/
proc sql;
create table crh.G_TEMP_pssg_urh_state as
select *
from work.patids_fy_qtr_pssg2;
quit;