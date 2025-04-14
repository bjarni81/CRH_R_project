/*
Program to pull sta5a-FY-Qtr-specific lat/lon into a table 
	to then run in R to get census block group
	and then merge with ADI
*/
/*=========================
Step 1:
	ScrSSN, FY, Qtr
*/
proc sql;
create table pcmm as
select distinct ScrSSN_num
	, sta5a, fy, qtr, assgnDaysInQtr, AssignPCPDays
from PACT13_E.PatientPCP
where fy in(2020, 2021);
quit;
/*48,114,949*/
proc sql;
select count(*) as total, count(distinct scrssn_num) as scrssn_count, 
	fy, qtr
from work.pcmm
group by fy, qtr;
quit;
/**/
proc sort data=work.pcmm;
by ScrSSN_num fy qtr descending AssgnDaysInQtr descending AssignPCPDays;
/**/
data pcmm_1st;
set work.pcmm;
by ScrSSN_num fy qtr descending AssgnDaysInQtr descending AssignPCPDays;
if first.qtr then first_var = 1;
	else first_var = 0;
run;
/*=========================
Step 2:
	Lat & Lon
*/
proc sql;
create table pcmm_lat_lon as
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2020_Q1 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 
	and a.qtr = 1 
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2020_Q2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 2
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2020_Q3 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 3
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2020_Q4 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020 and a.qtr = 4
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2021_Q1 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 1
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2021_Q2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 2
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2021_Q3 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 3
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2021_Q4 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021 and a.qtr = 4
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .;
quit;
/**/
proc sql;
select count(*) as total, count(distinct scrssn_num) as scrssn_count, 
	fy, qtr
from work.pcmm_lat_lon
group by fy, qtr;
quit;
/*=======================
Step 3a: 
	Output permanent table, FY20
*/
libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table crh.pssg_lat_lon_fy20 as
select *
from work.pcmm_lat_lon
where fy = 2020;
run;
/*=======================
Step 3b: 
	Output permanent table, FY21
*/
proc sql;
create table crh.pssg_lat_lon_fy21 as
select *
from work.pcmm_lat_lon
where fy = 2021;
run;
/**/

proc sql;
select count(*)
from work.pcmm_lat_lon
where fy = 2020 and qtr = 1;
quit;