libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
create table foo as
select distinct scrssn
from P13CRH.C_crh_utilization_final
where care_type = 'Primary care'
	and visitdate > '31MAR2020'd
	and spoke_sta5a_combined_cdw in(select sta5a from crh.ps_matched);
quit;
/**/
proc sql;
create table birthday as
select a.scrssn
	, b.dob 
	, intck('year',b.dob,'01oct22'd) as age_oct1_2022
from work.foo as a
left join vitalcdw.mini as b
on a.ScrSSN = b.scrssn;
quit;
/**/
proc sql;
create table pssg as
select a.scrssn
	, b.drivetimepc
	, b.gender
	, b.urh
	, substr(b.icn, 1, 10) as icn_b4_v
	, b.icn
	, c.race
	, b.lat, b.lon, b.tract
from work.foo as a
left join paf_pssg.fy2021_q4_ph2 as b
on input(a.scrssn, 9.) = b.scrssn
left join PACT13_D.raceEthnicity as c
on substr(b.icn, 1, 10) = c.PatientICN
;
quit;
/**/
proc freq data=work.pssg;
table gender urh race / missing;
run;
/*148,895*/
proc sql;
create table crh.J_pat_chars as
select a.scrssn
	, b.dob, age_oct1_2022
	, c.drivetimepc
	, c.gender
	, c.urh
	, c.race
	, c.lat, c.lon, c.tract
from work.foo as a
left join work.birthday as b
	on a.scrssn = b.scrssn
left join work.pssg as c
	on a.scrssn = c.scrssn;
quit;