/*
This program takes the average drive distance to nearest PC site
	grouped by closest PC site
over FY18, 19, and 20
=========================================================*/
libname crh SQLSVR datasrc=OABI_MyVAAccess_SQL13 &SQL_OPTIMAL. schema=crh_eval;
/**/
proc sql;
drop table crh.D4_avg_drive_time;
/**/
create table crh.D4_avg_drive_time as
select count(*) as scrssn_count
	, mean(drivedistancepc) as avg_driveDist
	, std(drivedistancepc) as sd_driveDist
	, mean(drivetimepc) as avg_driveTime
	, std(drivetimepc) as sd_driveTime
	, closestPCSite
	, 2018 as fy
from paf_pssg.fy2018_q4_ph2
where closestPCSite <> ""
group by closestPCSite
UNION
select count(*) as scrssn_count
	, mean(drivedistancepc) as avg_driveDist
	, std(drivedistancepc) as sd_driveDist
	, mean(drivetimepc) as avg_driveTime
	, std(drivetimepc) as sd_driveTime
	, closestPCSite
	, 2019 as fy
from paf_pssg.fy2019_q4_ph2
where closestPCSite <> ""
group by closestPCSite
UNION
select count(*) as scrssn_count
	, mean(drivedistancepc) as avg_driveDist
	, std(drivedistancepc) as sd_driveDist
	, mean(drivetimepc) as avg_driveTime
	, std(drivetimepc) as sd_driveTime
	, closestPCSite
	, 2020 as fy
from paf_pssg.fy2020_q4_ph2
where closestPCSite <> ""
group by closestPCSite
UNION
select count(*) as scrssn_count
	, mean(drivedistancepc) as avg_driveDist
	, std(drivedistancepc) as sd_driveDist
	, mean(drivetimepc) as avg_driveTime
	, std(drivetimepc) as sd_driveTime
	, closestPCSite
	, 2021 as fy
from paf_pssg.fy2021_q4_ph2
where closestPCSite <> ""
group by closestPCSite
UNION
select count(*) as scrssn_count
	, mean(drivedistancepc) as avg_driveDist
	, std(drivedistancepc) as sd_driveDist
	, mean(drivetimepc) as avg_driveTime
	, std(drivetimepc) as sd_driveTime
	, closestPCSite
	, 2022 as fy
from paf_pssg.fy2022_q4_ph2
where closestPCSite <> ""
group by closestPCSite;
quit;