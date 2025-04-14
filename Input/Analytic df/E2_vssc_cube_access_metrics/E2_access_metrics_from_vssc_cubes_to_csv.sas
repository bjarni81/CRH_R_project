
/*
Pulling VSSC Access Metrics from Cubes and Outputting to .csv
*/

/*====================================================================*/
/* Average 3rd next available */
	proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.thirdNextAvail as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Average 3rd Next Available in PC Clinics (322,323,350)]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2018],[Date].[Fiscal Date].[Mth])),
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2020],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2021],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2022],[Date].[Fiscal Date].[Mth])) } })) * 
{ { ADDCALCULATEDMEMBERS([Facility District].[Sta6a].LEVELS(1).MEMBERS) } }
}
	PROPERTIES MEMBER_UNIQUE_NAME,MEMBER_CAPTION,LEVEL_NUMBER, CHILDREN_CARDINALITY
ON ROWS

FROM [PACTCompass]


 CELL PROPERTIES VALUE 

	);
	quit;
/* Slight mung */
data work.thirdNextAvail;
	set work.thirdNextAvail;
	sta6a = facility_district;
run;
/* Output as .csv */
ods csv file = 'H:\HSRD_General\Kaboli Access Team\CRH Evaluation\Bjarni\CRH_r_project\Input\Analytic df\Data\third_next_available_sta6a_month.csv';
proc print data = work.thirdNextAvail;
run;
ods csv close;
/*====================================================================*/
/* Established Patient Wait Time */
	proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.estPtWt as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Established PC Patient Average Wait Time in Days (Based on Create Date)]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2018],[Date].[Fiscal Date].[Mth])),
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2020],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2021],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2022],[Date].[Fiscal Date].[Mth])) } })) * 
{ { ADDCALCULATEDMEMBERS([Facility District].[Sta6a].LEVELS(1).MEMBERS) } }
}
	PROPERTIES MEMBER_UNIQUE_NAME,MEMBER_CAPTION,LEVEL_NUMBER, CHILDREN_CARDINALITY
ON ROWS

FROM [PACTCompass]


 CELL PROPERTIES VALUE 

	);
	quit;
/* Slight mung */
data work.estPtWt;
	set work.estPtWt;
	sta6a = facility_district;
run;
/* Output as .csv */
ods csv file = 'H:\HSRD_General\Kaboli Access Team\CRH Evaluation\Bjarni\CRH_r_project\Input\Analytic df\Data\established_patient_waitTime_sta6a_month.csv';
proc print data = work.estPtWt;
run;
ods csv close;
/*====================================================================*/
/* New Patient Wait Time */
	proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.newPtWt as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[New PC Patient Average Wait Time in Days (Based on Create Date)]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2018],[Date].[Fiscal Date].[Mth])),
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2020],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2021],[Date].[Fiscal Date].[Mth])), 
								ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2022],[Date].[Fiscal Date].[Mth])) } })) * 
{ { ADDCALCULATEDMEMBERS([Facility District].[Sta6a].LEVELS(1).MEMBERS) } }
}
	PROPERTIES MEMBER_UNIQUE_NAME,MEMBER_CAPTION,LEVEL_NUMBER, CHILDREN_CARDINALITY
ON ROWS

FROM [PACTCompass]


 CELL PROPERTIES VALUE 

	);
	quit;
/* Slight mung */
data work.newPtWt;
	set work.newPtWt;
	sta6a = facility_district;
run;
/* Output as .csv */
ods csv file = 'H:\HSRD_General\Kaboli Access Team\CRH Evaluation\Bjarni\CRH_r_project\Input\Analytic df\Data\new_patient_waitTime_sta6a_month.csv';
proc print data = work.newPtWt;
run;
ods csv close;

