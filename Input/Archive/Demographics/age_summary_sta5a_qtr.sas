/*
Program to summarise, to sta5a-qtr:
	-Number of patients in age categories
	-Mean and SD of age
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
/*53,969,600*/
/*
Step 2:
	Unique ScrSSNs for pulling birthday
*/
proc sql;
create table dist_scrssn as
select distinct ScrSSN_char 
from work.pcmm;
quit;
/*6,698,955*/
/*
Step 3:
	Join unique scrssn table with spatient table for birthday
*/
proc sql;
create table bdays as
select distinct a.scrssn_char
	, b.birthDateTime
from work.dist_scrssn as a
left join spatient.spatient as b
on a.ScrSSN_char = b.scrssn
where b.veteranFlag = 'Y';
/*6,674,322*/
/*
Step 4:
	Calculate age on October 1st, 2020
*/
data age_calc;
set work.bdays;
age_oct1_2020 = intck('year',datepart(birthdateTime),'01oct20'd);
run;
/*
Step 5:
	Categorize ages 
*/
proc sql;
create table age_cats as 
select *
	,case
		when age_oct1_2020 >= 18 AND age_oct1_2020 < 40 then "18-39"
		when age_oct1_2020 >= 40 AND age_oct1_2020 < 50 then "40-49"
		when age_oct1_2020 >= 50 AND age_oct1_2020 < 60 then "50-59"
		when age_oct1_2020 >= 60 AND age_oct1_2020 < 70 then "60-69"
		when age_oct1_2020 >= 70 AND age_oct1_2020 < 80 then "70-79"
		when age_oct1_2020 >= 80 then "80+"
		else "Uh-oh!" 
end as age_cat
from work.age_calc;
quit;
/*
Step 6:
	Re-join with scrssn-sta5a-qtr
*/
proc sql;
create table ages_whole as
select a.ScrSSN_char
	, a.fy, a.qtr, a.sta5a
	, b.age_oct1_2020
	, b.age_cat
from work.pcmm as a
left join work.age_cats as b
on a.scrssn_char = b.scrssn_char;
quit;
/*
Step 7:
	Summarise to the sta5a-qtr
*/
proc sql;
create table age_summary as
select fy, qtr, sta5a
	, count(*) as total
	, mean(age_oct1_2020) as avg_age_oct1_2020
	, std(age_oct1_2020) as std_age_oct1_2020
	, sum(case when age_oct1_2020 >= 18 AND age_oct1_2020 < 40 then 1 else 0 end)
		as _18_39_count
	, sum(case when age_oct1_2020 >= 40 AND age_oct1_2020 < 50 then 1 else 0 end)
		as _40_49_count
	, sum(case when age_oct1_2020 >= 50 AND age_oct1_2020 < 60 then 1 else 0 end)
		as _50_59_count
	, sum(case when age_oct1_2020 >= 60 AND age_oct1_2020 < 70 then 1 else 0 end)
		as _60_69_count
	, sum(case when age_oct1_2020 >= 70 AND age_oct1_2020 < 80 then 1 else 0 end)
		as _70_79_count
	, sum(case when age_oct1_2020 >= 80 then 1 else 0 end)
		as _80_plus_count
from work.ages_whole
group by fy, qtr, sta5a;
quit;
/*
Step 8:
	Output to [OABI_MyVAAccess].[crh_eval]
*/
libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table crh.age_sta5a_qtr as
select *
from work.age_summary;
run;

