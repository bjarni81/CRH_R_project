-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~																		|
-- | PURPOSE: Calculate Consult Wait Times																 
-- | PROGRAMMER: Kevin Griffith & Aaron Legler		
-- | BACKGROUND: This code calculates consult wait times for both VA and non-VA community care. Please see our Mendeley Data
-- |			repository at https://data.mendeley.com/datasets/rmk89k4rhb to make sure that you have the most up-to-date
-- |			code version and to read our accompanying Data in Brief article. Please reference this Data in Brief in 
-- |			any published manuscripts that use or reference these wait times. 
-- | INSTRUCTIONS: Update desired date ranges for your search (lines 36-37) and stop codes of interest (lines 75).
-- |			Only consults types with average completion times <= 0.2 days are removed (user-adjustable on line 52). 
-- |			Run & enjoy. Note this script references several very large tables, and make take several hours to complete
-- |			when querying wide time ranges.
-- | LAST UPDATED: 4/23/2021																					
-- | INPUT(S):	[con].[Consult]		
-- |			[con].[ConsultActivity]																																				
-- |			[Dim].[Location]	
-- |			[Dim].[StopCode]	
-- |			[Dim].[AssociatedStopCode]
-- |			[Dim].[Division]		
-- |			[Dim].[VistaSite]	
-- |			[Appt].[Appointments]	
-- |			[Outpat].[Visit]	
-- |			[Spatient].[Spatient]		
-- |			[Spatient].[SpatientAddress]												
-- | OUTPUT (FINAL): These may be stratified by VA and non-VA care, and can be calculated at the veteran-level or aggregated to STA3N.
-- |			1) Days to Approved, a measure of the difference between when a consult is created and when it is approved.  For 
-- |			community care, this is when the veteran was authorized to seek care in the community.
-- |			2) Days to Scheduled, a measure of the difference between when a consult is approved and when the appointment is scheduled.
-- |			Note that For community care, this measure represents the date the VA learned the veteran scheduled an appointment.
-- |			3) Days to Completed, a measure of the difference between when an consult is approved and when it was completed.								
-- |																																												
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
--Adapted by Bjarni Haraldsson, August 2022
/*Quick sanity check re: the stop codes for cardiology, oncology/hematology, and urology*/
drop table if exists #sanity_check;
--
select wk.PatientSID, cast(VisitDateTime as date) as vizDate
	, psc.StopCode, psc.StopCodeName
into #sanity_check
from [CDWWork].[Outpat].Workload as wk
inner join [CDWWork].[Dim].StopCode as psc
	on wk.PrimaryStopCodeSID = psc.StopCodeSID
where wk.VisitDateTime > cast('2021-01-06' as datetime)
	AND wk.VisitDateTime < cast('2021-01-08' as datetime)
	AND psc.StopCode IN(303-- cardiology
							, 414--urology clinic
							, 308, 316);--HEMATOLOGY/ONCOLOGY and ONCOLOGY/TUMOR
--
select count(*), StopCode, stopcodename
from #sanity_check
group by stopCode, StopCodeName
/*********************************
DECLARE TEMPORARY VARIABLES
*********************************/

/* DECLARE DATE RANGES TO SEARCH */
DECLARE @CompStartDate datetime2(0) = convert(datetime2(0),'20171001'); -- Start of study period
DECLARE @CompEndDate datetime2(0) = convert(datetime2(0),'20221001'); -- End of study period
DECLARE @SchedEndDate datetime2(0) = dateadd(day,180,@CompEndDate); -- Set maximum wait time of 180 days

/* DECLARE TEMPORARY VARIABLES FOR LATER USE */
declare @rowcount int;
declare @rowmax int;
declare @text varchar(50);
declare @command varchar(500);
declare @stop varchar(3);
declare @stopcodename varchar(50);
declare @waitlimit decimal(5,2) = 0.2; -- Adjust threshold as needed/desired

/****************************************************
CREATE TABLE OF LOCATIONSID FOR STOP CODES OF INTEREST
****************************************************/

-- Set CDWWork as location
use cdwwork

-- Pull stop codes
drop table if exists #stops
select a.locationsid,
	b.stopcode PrimaryStopCode,
	b.stopcodename PrimaryStopCodeName,
	b.stopcodesid PrimaryStopCodeSID,
	c.stopcode SecondaryStopCode,
	c.stopcodename SecondaryStopCodeName,
	c.stopcodesid SecondaryStopCodeSID,
	e.visn,
	a.sta3n,
	e.facility station,
	d.sta6a,
	d.divisionname
into #stops
from Dim.Location a
left join Dim.StopCode b on a.PrimaryStopCodeSID = b.StopCodeSID 
	 and b.stopcode in (322, 323, 350-- Primary care
							, 303-- cardiology
							, 414--urology clinic
							, 308, 316--HEMATOLOGY/ONCOLOGY and ONCOLOGY/TUMOR
							) 
left join Dim.StopCode c on a.SecondaryStopCodeSID = c.StopCodeSID
left join Dim.Division d on a.divisionsid = d.divisionsid
left join Dim.VistaSite e on a.sta3n = e.sta3n
where a.sta3n != '-1' -- Delete records without a station
group by a.locationsid, b.stopcode, b.stopcodename, b.stopcodesid, c.stopcode, c.stopcodename, c.stopcodesid, 
	e.visn, a.sta3n, e.facility, d.sta6a, d.divisionname;

-- Pull associated stop codes
drop table if exists #assocstops;
select a.sta3n,
	a.Sta6a,
	a.primarystopcode,
	a.primarystopcodename,
	b.RequestServiceSID,
	case when a.primarystopcode = 669 then 1 else 0 end non_va
into #assocstops
from #stops a
inner join Dim.AssociatedStopCode b	on B.StopCodeSID = A.PrimaryStopCodeSID 
where b.requestservicesid not in (-1, 0) -- Remove records without a valid RequestServiceSID
group by a.sta3n, a.Sta6a, a.primarystopcode, a.primarystopcodename, b.requestservicesid;

-- Pull all RequestServiceSIDs and associated stop codes into a table
drop table if exists #terms;
select a.sta3n,
	b.StopCode,
	c.stopcodename,
	c.stopcodename stopcodename_mod,
	a.requestservicesid,
	a.servicename,
	a.ServiceName servicename_mod,
	b.StopCode STOPCODE_ALT,
	c.STOPCODENAME STOPCODENAME_ALT,
	cast(b.stopcode as varchar(1000)) stopcode_all,
	ROW_NUMBER() over(partition by a.requestservicesid -- Identify how many non-669 stop codes are associated with each RequestServiceSID
		 order by a.requestservicesid, case when b.stopcode = 669 then 1 else b.stopcode end) reqid_rown,
	row_number() over(order by a.requestservicesid) row_n,
	0 as mapped_via,
	@text mapped_text
into #terms
from dim.RequestService a
inner join dim.AssociatedStopCode b on a.Sta3n = b.Sta3n
	and a.RequestServiceSID = b.RequestServiceSID
inner join dim.StopCode c on b.Sta3n = c.Sta3n
	and b.StopCodeSID = c.StopCodeSID
where b.stopcode not in (656) -- list of totally non-informative stop codes like 'DOD NON-VA CARE'
	and a.RequestServiceSID not in (-1, 0)
and len(b.stopcode) = 3 -- Do not include 2 digit stop codes
group by a.sta3n, b.StopCode, c.StopCodeName, c.stopcodename, a.RequestServiceSID, a.servicename, a.ServiceName,
	b.StopCode, c.StopCodeName, cast(b.StopCode as varchar(100)), b.AssociatedStopCodeIEN;

-- Add any additional stop code mappings based on the requestservicesid
set @rowcount = 1;
print @rowcount;
set @rowmax = (select max(reqid_rown) from #terms);
print @rowmax;
while @rowcount <= @rowmax
begin
	declare @row int = @rowcount;
	set @command = 'update t1
		set t1.stopcode_all = concat(t1.stopcode_all, '' '', t2.stopcode)
		from #terms t1
		inner join #terms t2
		on t1.Sta3n = t2.sta3n
		and t1.RequestServiceSID = t2.RequestServiceSID
		where t1.stopcode != t2.stopcode
		and t1.reqid_rown = 1
		and t2.reqid_rown = ' + cast(@row as varchar(3)) + ';'
	print @command;
	execute(@command);
	set @rowcount = @rowcount + 1;
end;

/*********************************************************************************
1) Map the stop code using RequestServiceSID where there is only 1 other stop code 
*********************************************************************************/

-- Set mapped_via = 1 where requestservicesid = requestservicesid
update t1 
set t1.mapped_via = 1
from #terms t1
inner join #terms t2
on t1.RequestServiceSID = t2.RequestServiceSID
where t1.Sta3n = t2.Sta3n
and t1.stopcode = 669
and t2.StopCode != 669
and t1.mapped_via = 0
and len(t1.stopcode_all) <= 7;

-- Set stopcode_alt = stopcode where requestservicesid = requestservicesid
update t1 
set t1.stopcode_alt = t2.stopcode
from #terms t1
inner join #terms t2
on t1.RequestServiceSID = t2.RequestServiceSID
where t1.Sta3n = t2.Sta3n
and t1.stopcode = 669
and t2.StopCode != 669
and t1.mapped_via = 1;

-- Update the stopcodename
update t1 
set t1.stopcodename_alt = t2.stopcodename
from #terms t1
inner join #terms t2
on t1.stopcode_alt = t2.stopcode
and t1.Sta3n = t2.sta3n
where t1.STOPCODE = 669
and t1.stopcode_alt != 669
and t2.STOPCODE_ALT != 669
and t1.mapped_via = 1;

/********************************************
Clean up service name text for later analysis
********************************************/
		
-- Remove all non-alphanumerics from servicename_mod
update #terms
	set servicename_mod = replace(servicename_mod, substring(servicename_mod, patindex('%[^a-zA-Z ]%', servicename_mod), 1), ' ')
	where patindex('%[^a-zA-Z ]%', servicename_mod) != 0;
	update #terms
	set stopcodename_mod = replace(stopcodename_mod, substring(stopcodename_mod, patindex('%[^a-zA-Z ]%', stopcodename_mod), 1), ' ')
	where patindex('%[^a-zA-Z ]%', stopcodename_mod) != 0;

-- Remove variations of community care & uninformative text from service descriptions
DROP TABLE if exists #cuttext; 
CREATE TABLE #cuttext (
ORDINAL INT,
TEXT VARCHAR(100));
INSERT INTO #cuttext (ORDINAL, TEXT)
VALUES(1, 'COMMUNITY CARE'),
	(2, 'CHOICE'),
	(3, 'CHOICE FIRST'),
	(4, 'NON VA CARE'),
	(5, 'ZZORIGINAL'),
	(6, 'ZZFIRST'),
	(7, 'FIRST'),
	(8, 'GI'),
	(9, 'UEXB'),
	(10, 'ZZ'),
	(11, 'TESTING'),
	(12, 'OUTPT'),
	(13, 'INPT'),
	(14, 'OUTPATIENT'),
	(15, 'INPATIENT'),
	(16, 'MEDICINE'),
	(17, 'THERAPY'),
	(18, ' AND '),
	(19, 'DAY WAIT'),
	(20, 'FEE BASIS'),
	(21, 'CONSULT'),
	(22, 'GENERAL');
set @rowcount = 1;
set @rowmax = (select max(ordinal) from #cuttext);
while @rowcount <= @rowmax
begin
	set @text = (select text from #cuttext where ORDINAL = @rowcount);
	print @text;
	set @command = 'update #terms set servicename_mod = replace(servicename_mod,''' + @text + ''','' '');';
	print @command
	execute(@command);
	set @command = 'update #terms set stopcodename_mod = replace(stopcodename_mod,''' + @text + ''','' '');';
	print @command
	execute(@command);
	set @rowcount = @rowcount + 1;
end;

-- Remove all leading, trailing and duplicate spaces from modified service descriptions and stop code names
update #terms
	set servicename_mod = replace(servicename_mod, '  ', ' ')
	where servicename_mod like '%  %';
update #terms
	set stopcodename_mod = replace(stopcodename_mod, '  ', ' ')
	where stopcodename_mod like '%  %';
update #terms 
	set servicename_mod = RTRIM(ltrim(servicename_mod))

/******************************************
2) Full text matching after standardization
******************************************/

-- Set mapped_via = 2 where matched on servicename_mod = stopcodename_mod
update t1 
set t1.mapped_via = 2
from #terms t1
inner join #terms t2
on t1.servicename_mod = t2.stopcodename_mod
and t1.Sta3n = t2.Sta3n
where t1.stopcode_alt = 669
and t2.StopCode != 669
and t1.mapped_via = 0;

-- Flag based on modified name
update t1 
set t1.stopcode_alt = t2.stopcode
from #terms t1
inner join #terms t2
on t1.servicename_mod = t2.stopcodename_mod
and t1.Sta3n = t2.Sta3n
where t1.stopcode_alt = 669
and t2.StopCode != 669
and t1.mapped_via = 2;

-- update the stopcodename
update t1 
set t1.stopcodename_alt = t2.stopcodename
from #terms t1
inner join #terms t2
on t1.stopcode_alt = t2.StopCode
and t1.Sta3n = t2.Sta3n
where t1.stopcode_alt != 669
and t2.StopCode != 669
and t1.mapped_via = 2;

/**************************************************
3) Match on curated list of keywords and stop codes
**************************************************/

-- Create empty table
drop table if exists #keywords;
create table #keywords (
ordinal int,
text varchar(250),
stopcode varchar(3));

-- Fill in table with stop codes and short versions of their names 
insert into #keywords (ordinal, text, stopcode)
VALUES(1,  '%X RAY%', 105 ),
(2,  '%ELECTROCEPHALOGRAM%', 106 ),
(3,  '%ELECTROCARDIOGRAM%', 107 ),
(4,  '%LABORATORY%', 108 ),
(5,  '%NUCLEAR MEDICINE%', 109 ),
(6,  '%ULTRASOUND%', 115 ),
(7,  '%RESPIRATORY%', 116 ),
(8,  '%HOME TREATMENT%', 118 ),
(9,  '%COMMUNITY NURSING%', 119 ),
(10,  '%HEALTH SCREENING%', 120 ),
(11,  '%RESIDENTIAL CARE%', 121 ),
(12,  '%NUTRITION%', 123 ),
(13,  '%SOCIAL WORK%', 125 ),
(14,  '%EVOKED%', 126 ),
(15,  '%TOPOGRAPH%', 127 ),
(16,  '%PROLONGED VIDEO%', 128 ),
(17,  '%EMERGENCY DEPARTMENT%', 130 ),
(18,  '%URGENT CARE%', 131 ),
(19,  '%SLEEP STUDY%', 143 ),
(20,  '%RADIONUCLIDE%', 144 ),
(21,  '%PHARMACOLOGY%', 145 ),
(22,  '%POSITRON%', 146 ),
(23,  '%TELEPHONE ANCILLARY%', 147 ),
(24,  '%TELEPHONE DIAGNOSTIC%', 148 ),
(25,  '%RADIATION THERAPY%', 149 ),
(26,  '%TOMOGRAPHY%', 150 ),
(27,  '%MRI%', 151 ),
(28,  '%ANGIOGRAM%', 152 ),
(29,  '%INTERVENTIONAL RADIOGRAPHY%', 153 ),
(30,  '%MAGNETOENCEPH%', 154 ),
(31,  '%INFO ASSISTS%', 155 ),
(32,  '%brachytherapy%', 158 ),
(33,  '%ALTERNATIVE THERAPIES%', 159 ),
(34,  '%CLINICAL PHARM%', 160 ),
(35,  '%MEDICAL FOSTER%', 162 ),
(36,  '%CHAPLAIN%', 165 ),
(37,  '%HBPC%', 170 ),
(38,  '%DENTAL%', 180 ),
(39,  '%ADULT DAY%', 190 ),
(40,  '%POLYTRAUMA%', 195 ),
(41,  '%PM RS%', 201 ),
(42,  '%PM RS%', 201 ),
(43,  '%RECREATION%', 202 ),
(44,  '%AUDIOLOGY%', 203 ),
(45,  '%SPEECH PATH%', 204 ),
(46,  '%OCCUPATIONAL THER%', 205 ),
(47,  '%VIST COORD%', 209 ),
(48,  '%SPINAL CORD%', 211 ),
(49,  '%EMG%', 212 ),
(50,  '%KINESIO%', 214 ),
(51,  '%SCI HOME%', 215 ),
(52,  '%TELEPHONE REHAB%', 216 ),
(53,  '%BLIND REHAB%', 217 ),
(54,  '%VISUAL IMPAIR%', 221 ),
(55,  '%OBSERVATION%', 290 ),
(56,  '%GENERAL INTERNAL%', 301 ),
(57,  '%ALLERGY%', 302 ),
(58,  '%CARDI%' , 303 ),
(59,  '%DERMATOL%', 304 ),
(60,  '%ENDO METAB%', 305 ),
(61,  '%DIABETES%', 306 ),
(62,  '%GASTROEN%', 307 ),
(63,  '%ENDOS%', 307 ),
(64,  '%SIMGOIDOSC%', 307 ),
(65,  '%COLONOSCOPY%', 307),
(66,  '%HEMATOL%', 308 ),
(67,  '%HYPERTENSION%', 309 ),
(68,  '%INFECTIOUS%', 310 ),
(69,  '%PACEMAKER%', 311 ),
(70,  '%PULM%', 312 ),
(71,  '%RENAL%', 313 ),
(72,  '%ARTHRITIS%', 314 ),
(73,  '%NEUROLOGY%', 315 ),
(74,  '%ONCOLOGY%', 316 ),
(75,  '%ANTI COAG%', 317 ),
(76,  '%GERIATRIC%', 318 ),
(77,  '%ALZHEIMER%', 320 ),
(78,  '%PRIMARY CARE%', 323 ),
(79,  '%OPERATING ROOM%', 327 ),
(80,  '%MEDICAL SURGICAL DAY%', 328 ),
(81,  '%MEDICAL PROCEDURE UNIT%', 329 ),
(82,  '%CHEMOTHER%', 330 ),
(83,  '%PRE BED%', 331 ),
(84,  '%CARDIAC CATHETER%', 333 ),
(85,  '%STRESS TEST%', 334 ),
(86,  '%PARKINSON%', 335 ),
(87,  '%MEDICAL PRE PROC%', 336 ),
(88,  '%HEPATOLOGY%', 337 ),
(89,  '%EPILEPSY%', 345 ),
(90,  '%SLEEP MED%', 349 ),
(91,  '%HOSPICE%', 351 ),
(92,  '%PALLIATIVE%', 353 ),
(93,  '%ELECTROPHYSIO%', 369 ),
(94,  '%LONG TERM CARE%', 370 ),
(95,  '%CCHT%', 371 ),
(96,  '%WEIGHT MANAGE%', 372 ),
(97,  '%GENERAL SURGERY%', 401 ),
(98,  '%CARDIAC SURGERY%', 402 ),
(99,  '% NOSE%', 403 ),
(100,  '%GYNECOL%', 404 ),
(101,  '%HAND SURG%', 405 ),
(102,  '%NEUROSURG%', 406 ),
(103,  '%OPTHLAM%', 407 ),
(104,  '%OPTOMETRY%', 408 ),
(105,  '%ORTHOPEDIC%', 409 ),
(106,  '%PLASTIC SURG%', 410 ),
(107,  '%PODIATRY%', 411 ),
(108,  '%PROCTOLOGY%', 412 ),
(109,  '%THORACIC%', 413 ),
(110,  '% URO%', 414 ),
(111,  '%VASCULAR%', 415 ),
(112,  '%PRE SURGERY EVAL%', 416 ),
(113,  '%PROSTHETIC%', 417 ),
(114,  '%AMPUTAT%', 418 ),
(115,  '%ANESTHESIA%', 419 ),
(116,  '% PAIN%', 420 ),
(117,  '%CAST CLINIC%', 422 ),
(118,  '%CHIROPRAC%', 436 ),
(119,  '%LOW VISION%', 437 ),
(120,  '%FITTINGS%', 449 ),
(121,  '%TRANSPLANT%', 457 ),
(122,  '%BRONCHOSCOPY%', 481 ),
(123,  '% MH%', 502 ),
(124,  '%MENTAL HEALTH%', 502 ),
(125,  '%DAY TREATMENT%', 505 ),
(126,  '%DAY HOSPITAL%', 506 ),
(127,  '%PSYCH%', 509 ),
(128,  '%SUBSTANCE USE%', 513 ),
(129,  '%PTSD%', 516 ),
(130,  '%OPIOID%', 523 ),
(131,  '%SEXUAL TRAUMA%', 523 ),
(132,  '%HCHV%', 529 ),
(133,  '%HCMI%', 529 ),
(134,  '%DIALYSIS%', 610 ),
(135,  '%MAMMOGRAM%', 703 ),
(136,  '%ALCOHOL SCREEN%', 706 ),
(137,  '%SMOKING%', 707 ),
(138,  '% FLU%', 710 ),
(139,  '%GAMBLING%', 713 ),
(140,  '%DIABETIC RETINAL%', 718 ),
(141, '%MAMMO%', 703),
(142, '%[^ne]Urology%', 414);

-- Reorder the #keywords to match the more informative text first
with c1 as (
	select text
	, ROW_NUMBER() over(order by len(text) desc) ordinal
	from #keywords)
	update t1
	set t1.ordinal = t2.ordinal
	from #keywords t1
	inner join c1 t2
	on t1.text = t2.text;

-- For RequestServiceSIDs with a 669 stop code, check to 
-- see if the description matches one of the above terms. 
-- If so, replace the 669 with the real stop code
update t1
set t1.stopcode_alt = t2.stopcode
, t1.mapped_via = 3
, t1.mapped_text = t2.text
from #terms t1
inner join #keywords t2
on PATINDEX(t2.text, t1.servicename_mod) > 0
where t1.mapped_via = 0
and t1.stopcode = 669
and t1.mapped_text is null;

-- If a replacement was made, update the stop code name
update t1
set t1.stopcodename_alt = t2.stopcodename
from #terms t1
inner join #terms t2
on t1.STOPCODE_ALT = t2.stopcode
where t1.STOPCODE_ALT != 669
and t2.StopCode != 669
and t1.mapped_via = 3;

-- Delete duplicate RequestServiceSIDs (those which are associated with >1 stop codes)
delete from #terms
where reqid_rown > 1
and StopCode != 669;

-- Pull consults during this time period
drop table if exists #consults, #consults2;
select a.sta3n
	, a.consultsid
	, b.requestservicesid
	, c.servicename as torequestservicename /*changed to c from a, and from torequestservicename  */
	, a.patientsid
	, a.requestdatetime
into #consults
from con.Consult a
inner join #terms b
on a.ToRequestServicesid = b.RequestServiceSID
		and a.sta3n = b.sta3n
left join Dim.RequestService c    /*next 3 lines added*/
on a.ToRequestServicesid = c.RequestServiceSID
		and a.sta3n = b.sta3n
WHERE a.RequestDateTime >= @CompStartDate and a.RequestDateTime < @CompEndDate 
	and b.StopCode = 669;

-- Count how often each RequestServiceSID shows up in the consult data
select requestservicesid,
	count(patientsid) n_obs
	into #consults2
	from #consults
	group by RequestServiceSID

-- Merge these counts with the consult mapping and save for later use
drop table if exists #consult_mapping; 
select a.sta3n,
	a.stopcode,
	a.stopcodename,
	a.RequestServiceSID,
	a.ServiceName,
	a.STOPCODE_ALT,
	a.STOPCODENAME_ALT,
	a.stopcode_all,
	a.mapped_via,
	sum(case when b.n_obs is null then 0 else b.n_obs end) n_obs,
	convert(datetime2(0), getdate()) update_date
	into #consult_mapping 
	from #terms a
left join #consults2 b
on a.RequestServiceSID = b.RequestServiceSID
where a.stopcode = 669
group by a.sta3n, a.StopCode, a.stopcodename, a.RequestServiceSID, a.ServiceName, a.STOPCODE_ALT, 
	a.STOPCODENAME_ALT, a.stopcode_all, a.mapped_via
order by a.RequestServiceSID;

-- For 669 stop codes, replace with a real stop code and name if possible	
update t1 
set t1.primarystopcode = t2.stopcode_alt
	, t1.PrimaryStopCodeName = t2.stopcodename_alt
from #assocstops t1
inner join #consult_mapping t2 
	on t1.RequestServiceSID = t2.RequestServiceSID and
		t1.Sta3n = t2.Sta3n	

/***************************
Calculate days to completion
***************************/

-- Select consults to use in calculation
-- Must not be missing activity status, and within desired date range
drop table if exists #completed, #tmp_cons_dtc;
select patientsid,
	consultsid,
	activitydatetime,
	activity,
	sta3n,
	enteredbystaffsid
into #completed
from Con.ConsultActivity
where Activity in ('COMPLETE/UPDATE','DISCONTINUED','CANCELLED')
	and RequestDateTime >= @CompStartDate And RequestDateTime <@CompEndDate 
	and ActivityDateTime >= @CompStartDate and ActivityDateTime < @SchedEndDate; 

-- Limit to associated stop codes
with c1 as (
	select b.PatientSID,
		b.ConsultSID,
		d.primaryStopCode stopcode,
		lower(e.servicename) ToRequestServiceName,
		c.torequestservicesid,
		c.sta3n,
		c.orderingsta3n,
		c.fileentrydatetime,
		b.ActivityDateTime,
		b.Activity,
		b.sta3n sta3n_staff,
		b.enteredbystaffsid staffsid,
		d.Sta6a,
		0 as non_va
	from #completed b
	inner join Con.Consult c
		on b.consultsid = c.consultsid
		and b.sta3n = c.sta3n
	inner join #assocstops d
		on c.ToRequestServiceSID = d.RequestServiceSID
		and c.sta3n = d.sta3n
		and c.RequestDateTime >= @CompStartDate And c.RequestDateTime <@CompEndDate
	left join Dim.RequestService e    /*next 3 lines added*/
		on c.ToRequestServicesid = e.RequestServiceSID
		and c.sta3n = e.sta3n
)

-- Put the rows in data order, so that we can later keep only the first completion activity
select PatientSID,
	ConsultSID,
	orderingsta3n sta3n_ord,
	sta3n sta3n_rec,
	StopCode,
	@stopcodename stopcodename,
	UPPER(replace(ToRequestServiceName,' ','')) torequestservicename,
	reverse(UPPER(replace(ToRequestServiceName,' ',''))) torequestservicename_rev,
	fileentrydatetime,
	ActivityDateTime,
	Activity,
	sta3n,
	staffsid,
	non_va,
	row_number() over(partition by ConsultSID order by ConsultSID, ActivityDatetime) row_n
into #tmp_cons_dtc
from c1
where ActivityDateTime >= fileentrydatetime

-- Flag additional non-VA consults based on 669 stop code or ToRequestServiceName	
update #tmp_cons_dtc set non_va = 1 where stopcode = 669
	OR ToRequestServiceName like 'NON[ |-]VA%'
	OR ToRequestServiceName LIKE 'NONVA%'
	OR ToRequestServiceName like 'CHOICE%' 
	OR ToRequestServiceName like 'CHOICE FIRST%' 
	OR ToRequestServiceName like 'CHOICE-FIRST%' 
	OR ToRequestServiceName like 'COMMUNITYCARE-%'
	OR ToRequestServiceName like 'CHOICEFIRST%' 
	OR ToRequestServiceName like 'ZZCHOICE-FIRST%'
	OR ToRequestServiceName like 'VETERANSCHOICE%' 
	OR ToRequestServiceName_rev like REVERSE('NON[ |-]VA') + '%'
	OR ToRequestServiceName_rev LIKE REVERSE('NONVA') + '%'
--4,405,848
-- Cleanup temp tables as we go along
drop table if exists #completed, #terms, #consults, #consults2;

/*******************************************************
Use outpatient table to try to identify stop codes and 
some more CC visits
*******************************************************/
drop table if exists #tmp_cons_dtc2;

-- Bring in appointmentSID
with c1 as (
select a.*,
	b.visitsid,
	b.locationsid
	from #tmp_cons_dtc a
	left join appt.appointment b
	on a.consultsid = b.consultsid 
	and a.sta3n = b.sta3n
	where b.AppointmentDateTime >= @CompStartDate and b.AppointmentDateTime < @SchedEndDate 
		-- and a.torequestservicename not like '%prosth%' -- If you want to delete any prosthetics
		and a.torequestservicename is not NULL -- Delete missing
		and a.row_n = 1 -- Keep only the First Completion Activity
),
c2 as (
-- Match to outpatient table
select a.*, 
	b.primarystopcodesid,
	b.secondarystopcodesid
	from c1 a
	left join outpat.visit b
	on a.visitsid = b.visitsid
	and a.sta3n = b.sta3n
	where b.VisitDateTime >= @CompStartDate and b.VisitDateTime < @SchedEndDate 
),
c3 as (
select a.*,
	b.stopcode as primarystopcode,
	b.stopcodesid,
	c.stopcode as secondarystopcode
	from c2 a
	left join dim.stopcode b
		on a.PrimaryStopCodeSID = b.StopCodeSID
		and a.sta3n = b.sta3n
	left join dim.stopcode c
		on a.SecondaryStopCodeSID = c.StopCodeSID
		and a.sta3n = b.sta3n
),

/*****************************************
Match consults to appointment stop codes
*****************************************/

-- Match to appointments table
c4 as (
select a.PatientSID
	, a.ConsultSID
	, a.sta3n_ord
	, a.sta3n_rec
	, a.StopCode
	, a.stopcodename
	, a.torequestservicename
	, a.fileentrydatetime
	, a.ActivityDateTime
	, a.Activity
	, a.sta3n
	, a.staffsid
	, a.non_va
	, a.row_n
	, a.visitsid
	, a.locationsid
	, c.stopcode primarystopcode,
	c.stopcodename primarystopcodename,
	d.stopcode secondarystopcode,
	d.stopcodename secondarystopcodename
from c3 a
left join dim.Location b
	on a.sta3n = b.sta3n
	and a.LocationSID = b.LocationSID
left join dim.StopCode c
	on b.sta3n = c.sta3n
	and b.PrimaryStopCodeSID = c.StopCodeSID
left join dim.StopCode d
	on b.Sta3n = d.Sta3n
	and b.SecondaryStopCodeSID = d.StopCodeSID 
--	where a.stopcode in (select PrimaryStopCode from #stops) -- The decomposition of the 669 stop code may add in some unwanted stop codes, this step limits the results to the stop codes you care about
), 

/****************************
Remove zero-day request types
****************************/

-- Consults with near-zero average wait times are removed 
c5 as (
	select torequestservicename
		, avg(cast(datediff(day, fileentrydatetime, ActivityDateTime) as decimal(10, 2))) averagewait
	from c4
	group by torequestservicename)

select a.*
into #tmp_cons_dtc2
from c4 a
inner join c5 b 
on a.torequestservicename = b.torequestservicename
where b.averagewait > @waitlimit; 
--1,100,595
/****************************
Calculate days to approved
****************************/
-- Merge in scheduled date
select a.*,
	b.activitydatetime as approveddatetime,
	cast(datediff(day,a.fileentrydatetime,b.activitydatetime) as decimal(10,2)) as dta
	into #tmp_cons_dtc3
	from #tmp_cons_dtc2 a
	inner join con.ConsultActivity b
	on a.consultsid = b.consultsid
		and a.sta3n = b.sta3n
	where b.ACTIVITY = 'RECEIVED'
		and b.RequestDateTime >= @CompStartDate And b.RequestDateTime <@CompEndDate 
		and b.ActivityDateTime >= @CompStartDate and b.ActivityDateTime < @SchedEndDate

-- Sometimes there are more than one approval due to issues with the consult; place these in descending order
select *,
	row_number() over(partition by ConsultSID order by ConsultSID, dta desc) row_n2
	into #tmp_cons_dtc4
	from #tmp_cons_dtc3
	where dta >= 0 -- Remove erroneous negative DTA, which happens rarely

-- Select the most recent approval 
select *
	into #tmp_cons_dtc5
	from #tmp_cons_dtc4
	where row_n2 = 1
--912,618
-- Cleanup temp tables as we go along
--drop table if exists #tmp_cons_dtc2, #tmp_cons_dtc3, #tmp_cons_dtc4


/****************************
Calculate days to scheduled
****************************/
drop table if exists #tmp_cons_dtc6;
--
-- Merge in appointment date
-- Calculate days until scheduled (est) and completed
select a.*,
	b.AppointmentMadeDate,
	b.appointmentdatetime,
	-- If stopcode for consult is 669, see if stop code from
	-- apppointments table is more informative
	case 
		when (stopcode = 669 and primarystopcode != 669 and primarystopcode is not null) then primarystopcode
		when (stopcode = 669 and primarystopcode = 669 and secondarystopcode != 669 and secondarystopcode is not null) then secondarystopcode
	end as stopcode_rev
	into #tmp_cons_dtc6
	from #tmp_cons_dtc5 a
	inner join appt.appointment b
	on a.consultsid = b.consultsid
		and a.sta3n = b.sta3n
	where b.AppointmentDateTime >= @CompStartDate and b.AppointmentDateTime < @SchedEndDate;
--914,962
select top 100 * from #tmp_cons_dtc6;
/*******************
FINISHING TOUCHES
********************/

-- Set the scrssn
drop table if exists #tmp_cons_dtc7;
select a.* 
	, b.scrssn
	, stopCode_group = case
		when a.stopcode = 303 then 'Cardiology'
		when a.stopcode = 414 then 'Urology clinic'
		when a.stopcode IN(308, 316) then 'Hematology/Oncology'
		when a.stopcode IN(322, 323, 350) then 'Primary care'
		else 'Uh-oh!' end
	, qtr = case 
		when month(ActivityDateTime) in(10, 11, 12) then 1
		when month(ActivityDateTime) in(1, 2, 3) then 2
		when month(ActivityDateTime) in(4, 5, 6) then 3
		when month(ActivityDateTime) in(7, 8, 9) then 4 end
	, fy = case
		when month(ActivityDateTime) > 9 then year(activityDateTime) + 1
		else year(activityDateTime) end
into #tmp_cons_dtc7
from #tmp_cons_dtc6 a
inner join Spatient.Spatient b
on a.PatientSID = b.PatientSID
and a.Sta3n = b.Sta3n
--5,343,598
-- Set city, state, zip
--select a.*, 
--	b.county,
--	b.state,
--	b.zip
--	into #tmp_cons_dtc8
--	from #tmp_cons_dtc7 a
--	inner join SPatient.SPatientAddress b
--	on a.PatientSID = b.PatientSID
--	and a.Sta3n = b.Sta3n
--	where AddressType = 'Patient' and County is not null;

-- Calculate days to approved and completed
drop table if exists #tmp_cons_dtc9;
select a.*,
	datediff(day,approveddatetime,AppointmentMadeDate) as dts,
	datediff(day,approveddatetime,AppointmentDateTime) as dtc
	, d.Sta6a
	into #tmp_cons_dtc9
	from #tmp_cons_dtc7 as a
left join [CDWWork].[Con].Consult as b
	on a.PatientSID = b.PatientSID
		and a.ConsultSID = b.ConsultSID
left join [CDWWork].[Dim].Location as c
	on b.PatientLocationSID = c.LocationSID
left join [CDWWork].[Dim].Division as d
	on c.DivisionSID = d.DivisionSID
--5,343,598
-- Cleanup temp tables as we go along
--drop table if exists #tmp_cons_dtc6, #tmp_cons_dtc7, #tmp_cons_dtc8;
--
select top 100 * from #tmp_cons_dtc9;
select count(distinct sta6a) from #tmp_cons_dtc9 where non_va = 1;
--861
select count(distinct sta6a) from #tmp_cons_dtc9 where dtc < 0 OR dts < 0;
--
select min(activityDateTime) from #tmp_cons_dtc9
select max(activityDateTime) from #tmp_cons_dtc9
--
select sum(non_va) from #tmp_cons_dtc9;
--187,353
select count(*) from #tmp_cons_dtc9 where stopCode_group = 'Uh-oh!';
/*===============
Forward-filling URH
*/
drop table if exists #urh;
--
select a.scrssn, CONCAT(a.fy, '_', a.qtr) as fy_qtr, fy, qtr, URH
into #urh
from [OABI_MyVAAccess].[crh_eval].G_TEMP_pssg_urh_state as a
--4,696,809
--
drop table if exists #fwdFilled_urh;
--
select *
	, MIN(case when valuesAhead = 1 then URH END) over(partition by scrssn) as last_URH
	into #fwdFilled_urh
	from (select *
		, valuesAhead = count(case when URH IS NOT NULL then URH end) over(partition by scrssn order by fy, qtr rows between unbounded preceding and current row)
		
		, urh_carriedFwd = LAST_VALUE(URH) OVER(PARTITION BY SCRSSN ORDER BY FY, QTR rows between unbounded preceding and current row)
		from #urh) as a
order by scrssn, fy, qtr
--4,696,809
drop table if exists #gender;
--
select distinct scrssn, gender 
into #gender
from [OABI_MyVAAccess].[crh_eval].G_TEMP_pssg_urh_state
where gender IS NOT NULL;
--2,092,130
--==============
/*Outputting Final permanent table*/
drop table if exists [OABI_MyVAAccess].[crh_eval].G_communityCare_referrals;
--
select distinct a.*, b.GENDER, c.URH, c.urh_carriedFwd
	, DATEFROMPARTS(year(ActivityDateTime), month(ActivityDateTime), '01') as actyMonth
into [OABI_MyVAAccess].[crh_eval].G_communityCare_referrals
from #tmp_cons_dtc9 as a
left join #gender as b
	on a.ScrSSN = b.scrssn
left join #fwdFilled_urh as c
	on a.ScrSSN = c.scrssn
		and a.fy = c.fy 
		and a.qtr = c.qtr
where dts >= 0 
	AND dtc >= 0
	AND stopCode_group <> 'Uh-oh!'
	--AND sta6a <> '*Missing*' 
	--AND Activity <> 'CANCELLED'
	--AND Activity <> 'DISCONTINUED'
	;
--5,283,122
/***********------------------------------------------------------------------------------------------------------------------
VIEW RESULTS 
***********/

---- vet level
--select year(activitydatetime) as year,
--	sta3n,
--	stopcode,
--	dta,
--	dts,
--	dtc,
--	dta + dtc as dtot,
--	non_va,
--	substring(zip, 1, 3) as zip,
--	activity as disp
--into #vetresults
--from #tmp_cons_dtc9
--	where dts >= 0 AND dtc >= 0   -- Remove negative DTS or DTC

---- zipcode level
--select year(activitydatetime) as year,
--	month(activitydatetime) as month,
--	stopcode,
--	substring(zip, 1, 3) as zip,
--	count(*) as count,
--	avg(dta) as dta,
--	avg(dts) as dts,
--	avg(dtc) as dtc,
--	avg(dta + dtc) as dtot,
--	non_va
--into #zipresults
--from #tmp_cons_dtc9
--	where dts >= 0 AND dtc >= 0  -- Remove negative DTS or DTC
--	group by substring(zip, 1, 3), stopcode, non_va, month(activitydatetime), year(activitydatetime)

---- county level
--select year(activitydatetime) as year,
--	month(activitydatetime) as month,
--	stopcode,
--	county,
--	state,
--	count(*) as count,
--	avg(dta) as dta,
--	avg(dts) as dts,
--	avg(dtc) as dtc,
--	avg(dta + dtc) as dtot,
--	non_va
--into #ctyresults
--from #tmp_cons_dtc9
--	where dts >= 0 AND dtc >= 0  -- Remove negative DTS or DTC
--	group by state, county, stopcode, non_va, month(activitydatetime), year(activitydatetime)

---- Sta3n-level results 
--select year(a.activitydatetime) year,
--	month(a.activitydatetime) month,
--	a.sta3n,
--	a.stopcode,
--	count(a.consultsid) count,
--	avg(a.dta) dta,
--	avg(a.dts) dts,
--	avg(a.dtc) dtc,
--	avg(a.dta) + avg(a.dtc) dtot,
--	a.non_va,
--	b.StreetAddress1 as address1,
--	b.StreetAddress2 as address2,
--	b.City as city,
--	c.stateabbrev as state,
--	b.zip
--into #facresults
--from #tmp_cons_dtc9 a
--left join dim.institution b
--	on a.sta3n = b.sta3n
--left join dim.state c
--	on b.statesid = c.statesid
--	where b.streetaddress1 is not null and len(b.institutioncode)=3 and b.InstitutionCode=b.Sta3n
--	and dts >= 0 AND dtc >= 0 -- Remove negative DTS or DTC
--	group by a.sta3n, a.stopcode, year(a.activitydatetime), month(a.activitydatetime), a.non_va, b.StreetAddress1,
--	b.StreetAddress2, b.City, c.stateabbrev, b.zip

---- Export
--select * from #facresults
--select * from #ctyresults
--select * from #zipresults
--select * from #vetresults
