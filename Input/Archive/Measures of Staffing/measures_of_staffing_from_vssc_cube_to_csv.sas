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
	create table WORK.pcp_ap_fte_by_teamType as
	select * from connection to OLEDB
	(
		 MDX::SELECT 

	{[Measures].[Team PCP/AP FTE Total]}
ON COLUMNS  ,
{
	HIERARCHIZE(DISTINCT ({ { ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2019],[Date].[Fiscal Date].[Mth])), ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2020],[Date].[Fiscal Date].[Mth])), ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2021],[Date].[Fiscal Date].[Mth])), ADDCALCULATEDMEMBERS(DESCENDANTS([Date].[Fiscal Date].[FY4].&[2022],[Date].[Fiscal Date].[Mth])) } })) * 
{ { ADDCALCULATEDMEMBERS([Facility District].[Sta6a].LEVELS(1).MEMBERS) } } * 
DISTINCT ({ EXCEPT({ ADDCALCULATEDMEMBERS([Team].[Team Type].LEVELS(1).MEMBERS) }, { [Team].[Team Type].&[Academic], [Team].[Team Type].&[Homeless], [Team].[Team Type].&[Post Deployment], [Team].[Team Type].&[Renal/Dialysis], [Team].[Team Type].&[Serious Mental Illness], [Team].[Team Type].&[Spinal Cord Injury], [Team].[Team Type].&[Infectious Disease] }) })
}
	PROPERTIES MEMBER_UNIQUE_NAME,MEMBER_CAPTION,LEVEL_NUMBER, CHILDREN_CARDINALITY
ON ROWS

FROM [PACTCompass]


 CELL PROPERTIES VALUE 

	);
	quit;
/* Slight mung */
data work.pcp_ap_fte_by_teamType;
	set work.pcp_ap_fte_by_teamType;
	sta6a = facility_district;
run;
/* Output as .csv */
proc export data = work.pcp_ap_fte_by_teamType
	outfile = 'E:\Users\VHAIOWHaralB\Desktop\pcp_ap_fte_by_teamType_sta6a_month.csv'
	dbms = csv;
run;
