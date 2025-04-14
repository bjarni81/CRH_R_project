/*Program to make a LocationSID-to-StopCode lookup table
	Per Adam Batten, via Adam Chow; winter, 2021
*/
drop table if exists [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode;
--
select distinct
	a.DSSLocationSID
	, a.DSSLocationStopCodeSID
	, a.Sta3n
	, az.Sta3nName
	, az.Active
	, az.DistrictNumberFY16
	, az.DistrictNameFY16
	, az.DistrictNumberFY17
	, az.DistrictNameFY17
	, a.LocationSID
	, a.PrimaryStopCode
	, ax.StopCode as pStopCode_
	, ax.StopCodeName as pStopCodeName_
	, ay.StopCode as sStopCode_
	, ay.StopCodeName as sStopCodeName_
	, a.DSSClinicStopCode
	, a.DSSCreditStopCode
	, a.InactiveDate
	, a.NonCountClinicFlag as nonCountClinicFlag1
	, b.Sta3n as sta3n_stop
	, b.NationalChar4
	, b.NationalChar4Description
	, c.LocationName
	, c.PrimaryStopCodeSID
	, c.SecondaryStopCodeSID
	, c.Sta3n as sta3n_loc
	, c.NoncountClinicFlag as nonCountClinicFlag2
	, d.Sta3n as sta3n_div
	, d.Sta6a
	, d.DivisionName
into [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode
from [CDWWork].[Dim].DSSLocation as a
left join [CDWWork].[Dim].DSSLocationStopCode as b
	on a.DSSLocationStopCodeSID = b.DSSLocationStopCodeSID
left join [CDWWork].[Dim].Location as c
	on a.LocationSID = c.LocationSID
left join [CDWWork].[Dim].Division as d
	on c.DivisionSID = d.DivisionSID
left join [CDWWork].[Dim].StopCode as ax
	on c.PrimaryStopCodeSID = ax.StopCodeSID
left join [CDWWork].[Dim].StopCode as ay
	on c.SecondaryStopCodeSID = ay.StopCodeSID
left join [CDWWork].[Dim].Sta3n as az
	on a.Sta3n = az.Sta3n;
--1,447,607
select top 100 * from [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode;
--
select count(*) from [OABI_MyVAAccess].[crh_eval].LocationSID_to_StopCode
where PrimaryStopCode <> pStopCode_
-- 22 / 1,447,607 = 0.0015%