/*
Program to summarise, to sta5a-qtr:
	-Total number of patients in PCMM
	-Number who are male
	-Number who are white
	-Number who are "Urban"
*/
/*=========================
Step 1:
	Unique ScrSSN-sta5a-fy-qtr combinations
*/
proc sql;
create table pcmm as
select distinct ScrSSN_char, ScrSSN_num
	, sta5a, fy, qtr
from PACT13_E.PatientPCP
where fy > 2019;
quit;
/*48,114,949*/
/*=========================
Step 2:
	Gender, URH, & ICN
*/
proc sql;
create table pcmm_pssg as
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2020_Q1 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy=2020 and a.qtr = 1
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2020_Q2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 2
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2020_Q3 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 3
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2020_Q4 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 4
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2021_Q1 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 1
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2021_Q2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 2
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2021_Q3 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 3
UNION
select a.*
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as pat_icn
from work.pcmm as a
left join PAF_PSSG.FY2021_Q4 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 4;
quit;
proc freq data=work.pcmm_pssg;
table gender urh fy qtr/ missing;
run;
/*=========================
Step 3:
	Race
*/
proc sql;
create table pcmm_pssg_race as
select a.*
	, b.Race
from work.pcmm_pssg as a
left join PACT13_D.raceEthnicity as b
on a.pat_icn = b.PatientICN;
quit;
/*=======================
Step 4: 
	Count by sta5a-qtr
*/
proc sql;
create table foo as
select sta5a, fy, qtr
	, count(*) as scrssn_count
	, sum(case when gender = 'M' then 1 else 0 end) as male_count
	, sum(case when gender = 'F' then 1 else 0 end) as female_count
	, sum(case when race = 'WHITE' then 1 else 0 end) as race_white_count
	, sum(case when race = 'BLACK' then 1 else 0 end) as race_black_count
	, sum(case when race not in ('WHITE', 'BLACK') then 1 else 0 end) as race_other_count
	, sum(case when race = '' then 1 else 0 end) as race_missing
	, sum(case when urh = 'U' then 1 else 0 end) as urh_urban_count
	, sum(case when urh in('R', 'I', 'H') then 1 else 0 end) as urh_rural_count
	, sum(case when urh ='' then 1 else 0 end) as urh_missing_count
from work.pcmm_pssg_race
group by sta5a, fy, qtr;
quit;
/*=======================
Step 5: 
	Output permanent table
*/
libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table crh.pcmm_pssg_race_gender_count as
select *
from work.foo;
run;
