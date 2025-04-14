/***************************************************************
Project:  CRH MH
Analyst:  Chelle Wheat
		
Purpose:  Updating the MH cohort list using the operational definition
of a CRH spoke site.  Originally, sites identified via VSSC.  As of August
2021, the program evaluation will use this method for site identification
and corresponding utilization.

Date:  17 August 2021
Updated:  09 November 2021

Dependencies:  [PACT_CC].[CRH].[CRH_sites_FY20];  [PACT_CC].[CRH].[CRH_sites_FY21_part]

Update:  some spokes are assigned to multiple hub sites with overlapping time 
periods. After confirming with V23, we will select th HUB that is in the same VISN.  11.09.21
One problematic VISN is V20 where there are three overlapping HUBs in some cases but all in
the same VISN.  In that case, we will select Boise first, then Portland, then Puget Sound depending 
on which are indicated for that spoke site.


***************************************************************/
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 1:  PULL LOCATIONS MEETING CHAR4 CRITERIA  */
DROP TABLE IF EXISTS #TEMP_1;
--
SELECT A.DSSLocationStopCodeSID, A.NationalChar4 as CHAR4, B.LOCATIONSID
INTO #TEMP_1
FROM CDWWork.Dim.DSSLocationStopCode AS A 
LEFT JOIN CDWWork.DIM.DSSLocation AS B 
	ON A.DSSLocationStopCodeSID = B.DSSLocationStopCodeSID 
WHERE A.NationalCHAR4 IN ('DMDC', 'DMEC', 'DMFC', 'DMGC', 'DMJC', 'DMKC', 'DMLC', 'DMQC', 'DMSC', 'DMRC','DMAC')
-- 11,001 rows
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 2: BRING IN VISITS AT THE SELECT LOCATIONS MEETING CHAR4 CRITERIA ABOVE*/
DECLARE @STARTDT datetime2(0)
SET @STARTDT = cast('03/1/2019' as datetime2(0))-- 6 months of lead time

DECLARE @ENDDT datetime2(0)
SET @ENDDT = cast('10/01/2021' as datetime2(0))
--==
DROP TABLE IF EXISTS #TEMP_2;
--
SELECT A.LOCATIONSID, A.CHAR4, B.PATIENTSID, CONVERT(DATE, B.VISITDATETIME) AS VIZDAY, B.VISITSID, 
                B.PRIMARYSTOPCODESID, B.SECONDARYSTOPCODESID, B.DIVISIONSID, B.INSTITUTIONSID, B.WORKLOADLOGICFLAG, B.Sta3n
INTO #TEMP_2
FROM #TEMP_1 AS A 
LEFT JOIN CDWWork.Outpat.Visit AS B
	ON A.LocationSID = B.LocationSID 
WHERE B.VISITDATETIME >= @STARTDT AND B.VISITDATETIME < @ENDDT
--1,798,919  rows
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 3: BRING IN OTHER NEEDED VARIABLES  */
DROP TABLE IF EXISTS #TEMP_3;
--
SELECT B.ScrSSN, B.PatientICN, A.PATIENTSID, A.VIZDAY, A.CHAR4, A.VISITSID, A.WORKLOADLOGICFLAG, h.visnfy17, A.sta3n 
	,C.STOPCODE AS PRIMARY_STOP_CODE
	,D.STOPCODE AS SECONDARY_STOP_CODE,  E.STA6A, F.STAPC,  F.InstitutionName
	,A.LOCATIONSID, G.LOCATIONNAME
	,G.PrimaryStopCodeSID as locationprimstopcodesid, G.SecondaryStopCodeSID as locationsecstopcodesid
	, I.STOPCODE AS LOCATION_PRIMARY_SC, I.STOPCODENAME AS LOCATION_PRIMARY_SCNAME, J.STOPCODE AS LOCATION_SECONDARY_SC
	, J.STOPCODENAME AS LOCATION_SECONDARY_SCNAME
	,SiteType =--indicators for PCMHI, MH, etc. 
    (CASE WHEN 
			((I.STOPCODENAME LIKE '%MENTAL HEALTH%' 
			OR I.STOPCODENAME LIKE '%PSCY%' 
			OR I.STOPCODENAME LIKE '%MH%'
			OR I.STOPCODENAME LIKE '%PTSD%' 
			OR I.STOPCODENAME LIKE '%PHYSCH%' 
			OR I.STOPCODENAME LIKE '%PSY%'
			OR J.STOPCODENAME LIKE '%MENTAL HEALTH%' OR J.STOPCODENAME LIKE '%PSCY%' 
			OR J.STOPCODENAME LIKE '%MH%'
			OR J.STOPCODENAME LIKE '%PTSD%' 
			OR J.STOPCODENAME LIKE '%PHYSCH%' 
			OR J.STOPCODENAME LIKE '%PSY%')
			AND I.STOPCODENAME NOT LIKE '%MHV%SECURE%MESSAGING%' 
			AND J.STOPCODENAME NOT LIKE '%MHV%SECURE%MESSAGING%') 
		THEN 'MH'
		WHEN 
			((I.STOPCODENAME LIKE '%HBPC%' 
			OR I.STOPCODENAME LIKE '%MEDICINE%' 
			OR I.STOPCODENAME LIKE '%PRIMARY CARE%'
			OR I.STOPCODENAME LIKE '%PC%' 
			OR I.STOPCODENAME LIKE '%WOMEN%'
			OR I.STOPCODENAME LIKE '%PHARM%' 
			OR I.STOPCODENAME LIKE '% GERIATR%'
			OR J.STOPCODENAME LIKE '%HBPC%' 
			OR J.STOPCODENAME LIKE '%MEDICINE%' 
			OR J.STOPCODENAME LIKE '%PRIMARY CARE%'
			OR J.STOPCODENAME LIKE '%PC%' 
			OR J.STOPCODENAME LIKE '%WOMEN%'
			OR J.STOPCODENAME LIKE '%PHARM%' 
			OR J.STOPCODENAME LIKE '%GERIATR%')
			AND I.STOPCODENAME NOT LIKE '%SLEEP%' 
			AND J.STOPCODENAME NOT LIKE '%SLEEP%') 
		THEN 'PC' 
		ELSE 'Specialty' END)
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
LEFT JOIN CDWWORK.DIM.StopCode AS I 
	ON G.PrimaryStopCodeSID = I.StopCodeSID
LEFT JOIN CDWWork.DIM.StopCode AS J 
	ON A.SecondaryStopCodeSID = J.StopCodeSID;
-- 1,798,919
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 4: prioritize assignment of Hub VISN to the same VISN as the spoke sta5a when there are duplicates
	also, prioritize the order of sites alphabetically (and due to knowledge of order) in V20 where
	there are often 3 Hubs assigned to the same spoke */
--FY20
WITH cte_flag as (
SELECT
	Hub_Region, Hub_VISN, Hub_Sta3n, Hub_Location,
	SiteType, Spoke_Region, Spoke_VISN, Spoke_Sta5a, Spoke_Location,
	CASE WHEN Spoke_VISN = Hub_VISN THEN 1 ELSE 2 END as SameDiff_Flag
FROM [PACT_CC].[CRH].CRH_sites_FY20
),
cte_PART as (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY Spoke_Sta5a, SiteType ORDER BY SameDiff_Flag, Hub_Location) as rnum
FROM cte_flag
--ORDER BY Spoke_VISN,SiteType
) SELECT * 
INTO #fy20_deduplicated
FROM cte_PART
WHERE rnum=1
--533 rows
--==
--FY21
WITH cte_flag as (
SELECT
	Hub_Region, Hub_VISN, Hub_Sta3n, Hub_Location,
	SiteType, Spoke_Region, Spoke_VISN, Spoke_Sta5a, Spoke_Location,
	CASE WHEN Spoke_VISN = Hub_VISN THEN 1 ELSE 2 END as SameDiff_Flag
FROM [PACT_CC].[CRH].CRH_sites_FY21_full
),
cte_PART as (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY Spoke_Sta5a, SiteType ORDER BY SameDiff_Flag, Hub_Location) as rnum
FROM cte_flag
--ORDER BY Spoke_VISN,SiteType
) SELECT * 
INTO #fy21_deduplicated
FROM cte_PART
WHERE rnum=1
--785 rows
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 5: Join Tables*/
--fy20
DROP TABLE IF EXISTS #fy20_utilization;
--
SELECT DISTINCT S.Hub_Region
	, S.Hub_VISN
	, S.Hub_Sta3n
	, S.Hub_Location
	, S.SiteType
	, S.Spoke_Region
	, S.Spoke_VISN
	, S.Spoke_Sta5a
	, S.Spoke_Location
	, P.ScrSSN
	, P.PatientICN
	, P.PATIENTSID AS PatientSID
	, P.VIZDAY AS VisitDate
	, P.CHAR4
	, P.VISITSID
	, P.WORKLOADLOGICFLAG 
	, P.PRIMARY_STOP_CODE
	, P.SECONDARY_STOP_CODE
	, p.LOCATION_PRIMARY_SC
	, p.LOCATION_SECONDARY_SC--we should use these to categorize encounters with primary stop code = 674
	, P.LOCATION_PRIMARY_SCNAME AS PrimaryStopCodeLocationName
	, P.LOCATION_SECONDARY_SCNAME AS SecondaryStopCodeLocationName
--	, P.STA6A
INTO #fy20_utilization
FROM #fy20_deduplicated S
LEFT JOIN #TEMP_3 P
	ON S.Spoke_Sta5a = P.STA6A
		AND S.SiteType = P.SiteType
WHERE P.VIZDAY < cast('2020-10-01' as date)
--338,157
--==
--fy21
DROP TABLE IF EXISTS #fy21_utilization;
--
SELECT DISTINCT S.Hub_Region
	, S.Hub_VISN
	, S.Hub_Sta3n
	, S.Hub_Location
	, S.SiteType
	, S.Spoke_Region
	, S.Spoke_VISN
	, S.Spoke_Sta5a
	, S.Spoke_Location
	, P.ScrSSN
	, P.PatientICN
	, P.PATIENTSID AS PatientSID
	, P.VIZDAY AS VisitDate
	, P.CHAR4
	, P.VISITSID
	, P.WORKLOADLOGICFLAG 
	, P.PRIMARY_STOP_CODE
	, P.SECONDARY_STOP_CODE
	, p.LOCATION_PRIMARY_SC
	, p.LOCATION_SECONDARY_SC--we should use these to categorize encounters with primary stop code = 674
	, P.LOCATION_PRIMARY_SCNAME AS PrimaryStopCodeLocationName
	, P.LOCATION_SECONDARY_SCNAME AS SecondaryStopCodeLocationName
--	, P.STA6A
INTO #fy21_utilization
FROM #fy21_deduplicated S
LEFT JOIN #TEMP_3 P
	ON S.Spoke_Sta5a = P.STA6A
		AND S.SiteType = P.SiteType
WHERE P.VIZDAY > cast('2020-09-30' as date);
--525,927
--**##**##**##**##**##**##**##**##**##**##**##**##**
/*Step 6: Output final table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].encounters_B1_char4;
--
SELECT *
INTO [OABI_MyVAAccess].[crh_eval].encounters_B1_char4
FROM #fy20_utilization
UNION
SELECT *
FROM #fy21_utilization
--862,663 rows
