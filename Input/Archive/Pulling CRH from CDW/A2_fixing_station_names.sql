/*Fixing some names so that we can get rid of duplicates*/
UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Lebanon, PA HCS', 'Lebanon, PA')
WHERE 
	Spoke_Location LIKE '%Lebanon%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Fayetteville, AR HCS', 'Fayetteville, AR')
WHERE 
	Spoke_Location LIKE '%Fayetteville%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cleveland, OH Louis Stokes Cleveland', 'Cleveland, OH')
WHERE 
	Spoke_Location LIKE '%Cleveland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Wilkes-Barre, PA HCS', 'Wilkes-Barre, PA')
WHERE 
	Spoke_Location LIKE '%Wilkes-Barre%'
	
UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Roseburg, OR HCS', 'Roseburg, OR')
WHERE 
	Spoke_Location LIKE '%Roseburg%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Fargo, ND HCS', 'Fargo, ND')
WHERE 
	Spoke_Location LIKE '%Fargo%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sioux Falls, SD Royal C. Johnson', 'Sioux Falls, SD')
WHERE 
	Spoke_Location LIKE '%Sioux Falls%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Bozeman, MT Travis W. Atkins', 'Bozeman, MT')
WHERE 
	Spoke_Location LIKE '%Bozeman%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sioux Falls, SD HCS', 'Sioux Falls, SD')
WHERE 
	Spoke_Location LIKE '%Sioux Falls%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cheyenne, WY HCS', 'Cheyenne, WY')
WHERE 
	Spoke_Location LIKE '%Cheyenne%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Honolulu, HI Spark M. Matsunaga', 'Honolulu, HI HCS')
WHERE 
	Spoke_Location LIKE '%Honolulu%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Wilmington, DE HCS', 'Wilmington, DE')
WHERE 
	Spoke_Location LIKE '%Wilmington%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Anchorage, AK HCS', 'Anchorage, AK')
WHERE 
	Spoke_Location LIKE '%Anchorage%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Bath, NY HCS', 'Bath, NY')
WHERE 
	Spoke_Location LIKE '%Bath%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Boise, ID HCS', 'Boise, ID')
WHERE 
	Spoke_Location LIKE '%Boise%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cleveland, OH HCS', 'Cleveland, OH')
WHERE 
	Spoke_Location LIKE '%Cleveland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Detroit, MI John D. Dingell', 'Detroit, MI HCS')
WHERE 
	Spoke_Location LIKE '%Detroit%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Aurora, CO Rocky Mountain Regional', 'Aurora, CO HCS')
WHERE 
	Spoke_Location LIKE '%Aurora%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Iron Mountain, MI Oscar G. Johnson', 'Iron Mountain, MI HCS')
WHERE 
	Spoke_Location LIKE '%Iron Mountain%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Muskogee, OK Jack C. Montgomery', 'Muskogee, OK HCS')
WHERE 
	Spoke_Location LIKE '%Muskogee%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'New Orleans, LA HCS', 'New Orleans, LA')
WHERE 
	Spoke_Location LIKE '%New Orleans%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Phoenix, AZ Carl T. Hayden', 'Phoenix, AZ HCS')
WHERE 
	Spoke_Location LIKE '%Phoenix%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Portland, OR HCS', 'Portland, OR')
WHERE 
	Spoke_Location LIKE '%Portland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Salt Lake City, UT George E. Wahlen', 'Salt Lake City, UT HCS')
WHERE 
	Spoke_Location LIKE '%Salt Lake City%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Seattle, WA', 'Puget Sound, WA HCS')
WHERE 
	Spoke_Location LIKE '%Seattle%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sheridan, WY HCS', 'Sheridan, WY')
WHERE 
	Spoke_Location LIKE '%Sheridan%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Spokane, WA Mann-Grandstaff', 'Spokane, WA HCS')
WHERE 
	Spoke_Location LIKE '%Spokane%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Tomah, WI HCS', 'Tomah, WI')
WHERE 
	Spoke_Location LIKE '%Tomah%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Walla Walla, WA Jonathan M. Wainwright', 'Walla Walla, WA HCS')
WHERE 
	Spoke_Location LIKE '%Walla Walla%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'West Los Angeles, CA', 'Greater Los Angeles, CA HCS')
WHERE 
	Spoke_Location LIKE '%Los Angeles%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'White City, OR HCS', 'White City, OR')
WHERE 
	Spoke_Location LIKE '%White City%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Providence, RI HCS', 'Providence, RI')
WHERE 
	Spoke_Location LIKE '%Providence%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Duffy Road, PA Abie Abraham', 'Butler, PA HCS')
WHERE 
	Spoke_Sta5a = '529'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Northern Indiana HCS', 'Marion, IN')
WHERE 
	Spoke_Sta5a = '610'
	
UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Central Iowa HCS', 'Des Moines, IA')
WHERE 
	Spoke_Sta5a = '636A6'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Washington, DC HCS', 'Washington, DC')
WHERE 
	Spoke_Location LIKE '%Washington, DC%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY20
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Montana HCS', 'Fort Harrison, MT')
WHERE 
	Spoke_Sta5a = '436'
UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Lebanon, PA HCS', 'Lebanon, PA')
WHERE 
	Spoke_Location LIKE '%Lebanon%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Fayetteville, AR HCS', 'Fayetteville, AR')
WHERE 
	Spoke_Location LIKE '%Fayetteville%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cleveland, OH Louis Stokes Cleveland', 'Cleveland, OH')
WHERE 
	Spoke_Location LIKE '%Cleveland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Wilkes-Barre, PA HCS', 'Wilkes-Barre, PA')
WHERE 
	Spoke_Location LIKE '%Wilkes-Barre%'
	
UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Roseburg, OR HCS', 'Roseburg, OR')
WHERE 
	Spoke_Location LIKE '%Roseburg%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Fargo, ND HCS', 'Fargo, ND')
WHERE 
	Spoke_Location LIKE '%Fargo%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sioux Falls, SD Royal C. Johnson', 'Sioux Falls, SD')
WHERE 
	Spoke_Location LIKE '%Sioux Falls%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Bozeman, MT Travis W. Atkins', 'Bozeman, MT')
WHERE 
	Spoke_Location LIKE '%Bozeman%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sioux Falls, SD HCS', 'Sioux Falls, SD')
WHERE 
	Spoke_Location LIKE '%Sioux Falls%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cheyenne, WY HCS', 'Cheyenne, WY')
WHERE 
	Spoke_Location LIKE '%Cheyenne%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Honolulu, HI Spark M. Matsunaga', 'Honolulu, HI HCS')
WHERE 
	Spoke_Location LIKE '%Honolulu%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Wilmington, DE HCS', 'Wilmington, DE')
WHERE 
	Spoke_Location LIKE '%Wilmington%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Anchorage, AK HCS', 'Anchorage, AK')
WHERE 
	Spoke_Location LIKE '%Anchorage%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Bath, NY HCS', 'Bath, NY')
WHERE 
	Spoke_Location LIKE '%Bath%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Boise, ID HCS', 'Boise, ID')
WHERE 
	Spoke_Location LIKE '%Boise%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Cleveland, OH HCS', 'Cleveland, OH')
WHERE 
	Spoke_Location LIKE '%Cleveland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Detroit, MI John D. Dingell', 'Detroit, MI HCS')
WHERE 
	Spoke_Location LIKE '%Detroit%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Aurora, CO Rocky Mountain Regional', 'Aurora, CO HCS')
WHERE 
	Spoke_Location LIKE '%Aurora%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Iron Mountain, MI Oscar G. Johnson', 'Iron Mountain, MI HCS')
WHERE 
	Spoke_Location LIKE '%Iron Mountain%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Muskogee, OK Jack C. Montgomery', 'Muskogee, OK HCS')
WHERE 
	Spoke_Location LIKE '%Muskogee%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'New Orleans, LA HCS', 'New Orleans, LA')
WHERE 
	Spoke_Location LIKE '%New Orleans%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Phoenix, AZ Carl T. Hayden', 'Phoenix, AZ HCS')
WHERE 
	Spoke_Location LIKE '%Phoenix%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Portland, OR HCS', 'Portland, OR')
WHERE 
	Spoke_Location LIKE '%Portland%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Salt Lake City, UT George E. Wahlen', 'Salt Lake City, UT HCS')
WHERE 
	Spoke_Location LIKE '%Salt Lake City%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Seattle, WA', 'Puget Sound, WA HCS')
WHERE 
	Spoke_Location LIKE '%Seattle%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Sheridan, WY HCS', 'Sheridan, WY')
WHERE 
	Spoke_Location LIKE '%Sheridan%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Spokane, WA Mann-Grandstaff', 'Spokane, WA HCS')
WHERE 
	Spoke_Location LIKE '%Spokane%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Tomah, WI HCS', 'Tomah, WI')
WHERE 
	Spoke_Location LIKE '%Tomah%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Walla Walla, WA Jonathan M. Wainwright', 'Walla Walla, WA HCS')
WHERE 
	Spoke_Location LIKE '%Walla Walla%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'West Los Angeles, CA', 'Greater Los Angeles, CA HCS')
WHERE 
	Spoke_Location LIKE '%Los Angeles%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'White City, OR HCS', 'White City, OR')
WHERE 
	Spoke_Location LIKE '%White City%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Providence, RI HCS', 'Providence, RI')
WHERE 
	Spoke_Location LIKE '%Providence%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Duffy Road, PA Abie Abraham', 'Butler, PA HCS')
WHERE 
	Spoke_Sta5a = '529'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Northern Indiana HCS', 'Marion, IN')
WHERE 
	Spoke_Sta5a = '610'
	
UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Central Iowa HCS', 'Des Moines, IA')
WHERE 
	Spoke_Sta5a = '636A6'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Washington, DC HCS', 'Washington, DC')
WHERE 
	Spoke_Location LIKE '%Washington, DC%'

UPDATE [PACT_CC].[CRH].CRH_sites_FY21_full
SET
	Spoke_Location = REPLACE(Spoke_Location, 'Montana HCS', 'Fort Harrison, MT')
WHERE 
	Spoke_Sta5a = '436'