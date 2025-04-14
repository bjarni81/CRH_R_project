drop table if exists #locationName_lookup;
--
select distinct a.LocationSID, a.sta3n, a.LocationName
	, b.StopCode as psc, b.StopCodeName as psc_name
	, c.StopCode as ssc, c.StopCodeName as ssc_name
	, d.Sta6a, d.DivisionName
into #locationName_lookup
from [CDWWork].[Dim].Location as a
left join [CDWWork].[Dim].StopCode as b
	on a.PrimaryStopCodeSID = b.StopCodeSID
left join [CDWWork].[Dim].StopCode as c
	on a.SecondaryStopCodeSID = c.StopCodeSID
left join [CDWWork].[Dim].Division as d
	on a.DivisionSID = d.DivisionSID
where a.LocationName like '%V__ CRH%'
	and a.LocationName NOT LIKE 'ZZ%'
	and b.StopCode IS NOT NULL
	and d.Sta6a <> '*Missing*';
--===============================
--FY2020
DECLARE @STARTDT datetime2(0)
SET @STARTDT = cast('03/1/2019' as datetime2(0))

DECLARE @ENDDT datetime2(0)
SET @ENDDT = cast('10/01/2021' as datetime2(0))
/*=============================================*/
/*  BRING IN VISITS AT THE SELECT LOCATIONS MEETING LocationSID CRITERIA ABOVE*/
DROP TABLE IF EXISTS #TEMP_2
SELECT A.LOCATIONSID, 'LocationName' as CHAR4, B.PATIENTSID, CONVERT(DATE, B.VISITDATETIME) AS VIZDAY, B.VISITSID,
                B.PRIMARYSTOPCODESID, B.SECONDARYSTOPCODESID, B.DIVISIONSID, B.INSTITUTIONSID, B.WORKLOADLOGICFLAG, B.Sta3n, b.VisitDateTime
INTO #TEMP_2
FROM #locationName_lookup AS A 
LEFT JOIN CDWWork.Outpat.Visit AS B
	ON A.LocationSID = B.LocationSID 
WHERE B.VISITDATETIME >= @STARTDT AND B.VISITDATETIME < @ENDDT
-- 1,621,296 rows


/*  BRING IN OTHER NEEDED VARIABLES  */
DROP TABLE IF EXISTS #TEMP_3
SELECT B.ScrSSN, B.PatientICN, A.PATIENTSID, a.VisitDateTime, A.VIZDAY, A.CHAR4, A.VISITSID, A.WORKLOADLOGICFLAG, h.visnfy17, A.sta3n, 
			C.STOPCODE AS PRIMARY_STOP_CODE,
                D.STOPCODE AS SECONDARY_STOP_CODE,  E.STA6A, F.STAPC,  F.InstitutionName,
				 A.LOCATIONSID, G.LOCATIONNAME,
				G.PrimaryStopCodeSID as locationprimstopcodesid, G.SecondaryStopCodeSID as locationsecstopcodesid
INTO #TEMP_3
FROM #TEMP_2 AS A 
LEFT JOIN CDWWork.SPatient.SPatient AS B 
	ON A.PATIENTSID = B.PATIENTSID
LEFT JOIN CDWWORK.DIM.StopCode AS C 
	ON A.PrimaryStopCodeSID = C.StopCodeSID
LEFT JOIN CDWWork.DIM.StopCode AS D 
	ON A.SecondaryStopCodeSID = D.StopCodeSID
LEFT JOIN CDWWORK.DIM.Division AS E 
	ON A.DivisionSID = E.DivisionSID
LEFT JOIN CDWWORK.DIM.Institution AS F 
	ON a.INSTITUTIONSID = F.InstitutionSID and F.InstitutionName!='*Missing*'
					and F.InstitutionName is not null
Left join CDWWork.DIM.Sta3n as H 
	on A.sta3n=h.sta3n
LEFT JOIN CDWWORK.DIM.Location AS G 
	ON A.LocationSID = G.LocationSID
-- 1,621,296 rows

DROP TABLE IF EXISTS #TEMP_4
SELECT  A.*, C.STOPCODE AS LOCATION_PRIMARY_SC, C.STOPCODENAME AS LOCATION_PRIMARY_SCNAME, D.STOPCODE AS LOCATION_SECONDARY_SC,
		D.STOPCODENAME AS LOCATION_SECONDARY_SCNAME
INTO #TEMP_4
FROM #TEMP_3 AS A
LEFT JOIN CDWWORK.DIM.StopCode AS C 
	ON A.locationprimstopcodesid = C.StopCodeSID
LEFT JOIN CDWWork.DIM.StopCode AS D 
	ON A.locationsecstopcodesid = D.StopCodeSID
-- 1,810,256 rows

SELECT TOP 1000 * from #TEMP_4
--
/*	LINK TO STA5As from Site Level Dataset	*/
--create distinct list of sta5as from site level dataset (without mh/pc separation)

DROP TABLE IF EXISTS #SITE_LEVEL_DISTINCT
SELECT DISTINCT S.Spoke_Region
	, S.Spoke_VISN
	, S.Spoke_Sta5a
INTO #SITE_LEVEL_DISTINCT
FROM [PACT_CC].[CRH].CRH_sites_FY20  s
union
SELECT DISTINCT t.Spoke_Region
	, t.Spoke_VISN
	, t.Spoke_Sta5a
FROM [PACT_CC].[CRH].CRH_sites_FY21_working t
--589
SELECT * FROM #SITE_LEVEL_DISTINCT ORDER BY Spoke_Sta5a


/*Output Final Table*/

DROP TABLE IF EXISTS [OABI_MyVAAccess].[crh_eval].CRH_locationName
SELECT DISTINCT S.*
	, P.ScrSSN
	, P.PatientICN
	, P.PATIENTSID AS PatientSID
	, P.VIZDAY AS VisitDate
	, p.VisitDateTime
	, P.CHAR4
	, P.VISITSID
	, P.WORKLOADLOGICFLAG --Don't think that we need this any longer given that we are starting from official list
	, P.PRIMARY_STOP_CODE
	, P.SECONDARY_STOP_CODE
	, p.LOCATION_PRIMARY_SC
	, p.LOCATION_SECONDARY_SC--we should use these to categorize encounters with primary stop code = 674
	, P.LOCATION_PRIMARY_SCNAME AS PrimaryStopCodeLocationName
	, P.LOCATION_SECONDARY_SCNAME AS SecondaryStopCodeLocationName
	, p.LocationName
--	, P.STA6A
INTO [OABI_MyVAAccess].[crh_eval].CRH_locationName
FROM #SITE_LEVEL_DISTINCT S
LEFT JOIN #TEMP_4 P
	ON S.Spoke_Sta5a = P.STA6A;
--1,436,240
