/*
Pulling VSSC Cube Propensity Score Covariates and Outputting to .csv
*/

/*====================================================================*/
/* Observed:Expected Panel Size */
proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.obs_exp_panelSize as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Observed/Expected Panel Size Ratio]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
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
data work.obs_exp_panelSize;
	set work.obs_exp_panelSize;
	sta6a = facility_district;
run;
/* Output as .csv */
proc export data = work.obs_exp_panelSize
	outfile = 'E:\Users\VHAIOWHaralB\Desktop\Propensity Score Covariates from VSSC\obs_exp_panelSize_sta6a_month.csv'
	dbms = csv;
run;
/*====================================================================*/
/* Team PCP/AP FTE Total */
proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.team_pcpAP_fte_tot as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Team PCP/AP FTE Total]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
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
data work.team_pcpAP_fte_tot;
	set work.team_pcpAP_fte_tot;
	sta6a = facility_district;
run;
/* Output as .csv */
proc export data = work.team_pcpAP_fte_tot
	outfile = 'E:\Users\VHAIOWHaralB\Desktop\Propensity Score Covariates from VSSC\team_pcpAP_fte_tot_sta6a_month.csv'
	dbms = csv;
run;
/*====================================================================*/
/* Nosos Risk Score */
proc sql;
	connect to OLEDB
	(PROVIDER = 'MSOLAP' 
	 PROPERTIES = ('INITIAL CATALOG' = 'PACTCompass'
	               'DATA SOURCE' = 'VHAAUSBI5.VHA.MED.VA.GOV'
	               'CONNECT TIMEOUT' = 0));
	create table WORK.nosos as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Nosos Risk Score]}
ON COLUMNS  , 
NON EMPTY 
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), 
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
data work.nosos;
	set work.nosos;
	sta6a = facility_district;
run;
/* Output as .csv */
proc export data = work.nosos
	outfile = 'E:\Users\VHAIOWHaralB\Desktop\Propensity Score Covariates from VSSC\nosos_sta6a_month.csv'
	dbms = csv;
run;
