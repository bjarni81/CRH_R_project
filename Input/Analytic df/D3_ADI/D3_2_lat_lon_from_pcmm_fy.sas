/*
Program to pull sta5a-FY-Qtr-specific lat/lon into a table 
	to then run in R to get census block group
	and then merge with ADI
*/
/*=========================
Step 1:
	ScrSSN, FY, Qtr
*/
libname pcs_pcat SQLSVR datasrc=PCS_PCAT_SQL13 &SQL_OPTIMAL. schema=econ;
/**/
proc sql;
create table pcmm as
select distinct ScrSSN_num
	, sta5a, fy, assgnDaysInQtr, AssignPCPDays
from pcs_pcat.PatientPCP_2020_2024;
quit;
/*53,969,600*/
proc sql;
select count(*) as total, count(distinct scrssn_num) as scrssn_count, 
	fy
from work.pcmm
group by fy;
quit;
/**/
proc sort data=work.pcmm;
by ScrSSN_num fy descending AssgnDaysInQtr descending AssignPCPDays;
/**/
data pcmm_1st;
set work.pcmm;
by ScrSSN_num fy descending AssgnDaysInQtr descending AssignPCPDays;
if first.fy then first_var = 1;
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
left join PAF_PSSG.FY2020_Q4_ph2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2020
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2021_Q4_ph2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2021
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
UNION
select distinct a.*
	, b.lat
	, b.lon
	, b.tract
from work.pcmm_1st as a
left join PAF_PSSG.FY2022_Q4_ph2 as b
	on a.ScrSSN_num = b.SCRSSN
where a.fy = 2022
	and a.first_var = 1
	and b.tract <> ''
	and lat <> . and lon <> .
;
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
	Output permanent table
*/
libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table crh.D3_TEMP_lat_lon_fy as
select *
from work.pcmm_lat_lon;
run;
