# Author: Eric Gunnink (PCAT)
# Date: 07/31/2020
# Description: 
# 1. Take patient LAT/LONG from PSSG table and find patient corresponding census block
# 2. Use census block and merge with Area Deprevation Index (ADI)
# Adapted by Bjarni Haraldsson, February, 2021
################################################################################



# load libraries
library(tidyverse)
library(odbc)
library(RODBC)
library(DBI)

library(rgdal)
library(sf)

library(tictoc)
################################################

# Step 1: Get Patient Lat/Long

################################################
oabi_connect <- dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
#patients in PCMM in FY20, Q1
patients_fy20_q1 <- dbGetQuery(oabi_connect,
                        "
    select *
    from [crh_eval].pssg_lat_lon_fy20
      where qtr = 1
        AND LAT IS NOT NULL
        AND LON IS NOT NULL
        AND TRACT IS NOT NULL
"
) %>%
  as_tibble() %>%
  mutate(
    STATEFP = str_sub(TRACT, start = 1, end = 2)
    , COUNTYFP = str_sub(TRACT, start = 3, end = 5)
    , TRACTCE = str_sub(TRACT, start = 6, end = 11)
    , COUNTYFP = if_else(COUNTYFP == "270" & STATEFP == "02", "158", COUNTYFP) #per change in FIPS from 02270 to 02158
    , COUNTYFP = if_else(COUNTYFP == "113" & STATEFP == "46", "102", COUNTYFP)
    , COUNTYFP = if_else(COUNTYFP == "515" & STATEFP == "51", "019", COUNTYFP)
  )
#--==--==--==
# This is a list of all the distinct counties in your data (for iterating over later)
distinct_counties <- patients_fy20_q1 %>% distinct(STATEFP, COUNTYFP) %>% arrange(STATEFP, COUNTYFP)
################################################

# Step 2: Load Census Block Group Boundary File

################################################
# Load shape layer 
# SpatialPolygonsDataFrame
# CRS from: https://epsg.io/2163
#--==--== CY18
block_shp_18 <- readOGR(dsn = file.path("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/cb_2018_us_bg_500k"), 
                        stringsAsFactors = F)
################################################

# Step 3: Convert lat/lon to shapefile points

################################################
xy <- patients_fy20_q1 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy20_q1 <- SpatialPointsDataFrame(coords = xy, 
                                                 data = patients_fy20_q1,
                                                 proj4string = CRS(raster::projection(block_shp_18)))
#################################################

# Step 4: Merge

#################################################
# This function subsets the block shapefile and the pssg lat/long by county
# (only points within a county are compared to block groups in that county)
# Then returns a tibble with two columns SCRSSN/fips (fips is at blockgroup level)
join_pssg_block <- function(STATEFP_var, COUNTYFP_var, fy_var, qtr_var){
    # Subset PSSG by county
  if (fy_var == 20){
    if(qtr_var == 1){
     pssg_county_shp <- patients_shp_fy20_q1[
      (
        (patients_shp_fy20_q1$STATEFP == STATEFP_var) & 
          (patients_shp_fy20_q1$COUNTYFP == COUNTYFP_var) )
      , ]  }
    else if(qtr_var == 2){
      pssg_county_shp <- patients_shp_fy20_q2[
        (
          (patients_shp_fy20_q2$STATEFP == STATEFP_var) & 
            (patients_shp_fy20_q2$COUNTYFP == COUNTYFP_var) )
        , ]  }
    else if(qtr_var == 3){
      pssg_county_shp <- patients_shp_fy20_q3[
        (
          (patients_shp_fy20_q3$STATEFP == STATEFP_var) & 
            (patients_shp_fy20_q3$COUNTYFP == COUNTYFP_var) )
        , ]  }
    else {
      pssg_county_shp <- patients_shp_fy20_q4[
        (
          (patients_shp_fy20_q4$STATEFP == STATEFP_var) & 
            (patients_shp_fy20_q4$COUNTYFP == COUNTYFP_var) )
        , ]  }
  }
  else{
    if(qtr_var == 1){
      pssg_county_shp <- patients_shp_fy21_q1[
        (
          (patients_shp_fy21_q1$STATEFP == STATEFP_var) & 
            (patients_shp_fy21_q1$COUNTYFP == COUNTYFP_var) )
        , ]  }
    else if(qtr_var == 2){
      pssg_county_shp <- patients_shp_fy21_q2[
        (
          (patients_shp_fy21_q2$STATEFP == STATEFP_var) & 
            (patients_shp_fy21_q2$COUNTYFP == COUNTYFP_var) )
        , ]  }
    else if(qtr_var == 3){
      pssg_county_shp <- patients_shp_fy21_q3[
        (
          (patients_shp_fy21_q3$STATEFP == STATEFP_var) & 
            (patients_shp_fy21_q3$COUNTYFP == COUNTYFP_var) )
        , ]  }
    else if(qtr_var == 4){
      pssg_county_shp <- patients_shp_fy21_q4[
        (
          (patients_shp_fy21_q4$STATEFP == STATEFP_var) & 
            (patients_shp_fy21_q4$COUNTYFP == COUNTYFP_var) )
        , ]  }
  }
    # Subset block group by county 
    county_block_shp <- block_shp_18[
      (
        (block_shp_18$STATEFP == STATEFP_var) & 
          (block_shp_18$COUNTYFP == COUNTYFP_var)  )
      , ]
  # This joins the points and the shapes
  pssg_county_shp %>% 
    over(., county_block_shp) %>% # This does all the heavy lifting. If point is in polygon we get the polygon ID
    as_tibble() %>% 
    bind_cols(ScrSSN_num = pssg_county_shp$ScrSSN_num) %>% # add back identifying information
    select(ScrSSN_num, fips = GEOID) %>%
    mutate(fy = as.numeric(paste0("20", fy_var)), qtr = qtr_var)
}
#
# TEST: join_pssg_block(STATEFP_var = "36", COUNTYFP_var = "001", fy_var = 20, qtr_var = 1)
#--
# For loop iterates over all tracts present in lat/long table and saves 
# geocoded patients as a tibble in a list where each element is a tract
#---===---===
# FY20, Q1
stack_blocks <- list() # To fill with geocoded data
COUNTYFP_old = "" # For printing
tictoc::tic()
for(ii in seq_along(distinct_counties$STATEFP)){
  
  STATEFP_loop <- distinct_counties$STATEFP[ii]
  COUNTYFP_loop <- distinct_counties$COUNTYFP[ii]
  
  # Print a status message for every county
  if(COUNTYFP_old != COUNTYFP_loop){
    print(paste0("Loop: ", ii , " (", round(ii / 3219 * 100, 1), "%), ",
                 " Now in STATEFP: ", STATEFP_loop, " COUNTYFP: ", COUNTYFP_loop, " SYS TIME: ", Sys.time()))
  }
  stack_blocks[[ii]] <- join_pssg_block(STATEFP_var = STATEFP_loop, COUNTYFP_var = COUNTYFP_loop,
                                        fy_var = 20, qtr_var = 1) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy20_q1 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy20_q1 %>% select(ScrSSN_num, Sta5a))
#--
fy_20_q1_time <- tictoc::toc()
print(paste0("FY20, Q1 took ", round((fy_20_q1_time$toc - fy_20_q1_time$tic) / 60, 1), " minutes"))
############################################

# Step 6: Bonus - Merge ADI 

############################################

# ADI File downloaded from:
# https://www.neighborhoodatlas.medicine.wisc.edu/

adi <- read_csv("H:/HSRD_General/Kaboli Access Team/CRH Evaluation/Bjarni/CRH_r_project/Input/Data/ADI/us_bg.txt") %>%
  mutate(st_fips = as.numeric(str_sub(FIPS, end = 2))) %>%
  rename_all(tolower) %>%
  mutate(adi_natrank = as.numeric(adi_natrank),
         adi_staternk = as.numeric(adi_staternk))

#---===---===---===
patients_adi_fy20_q1 <- geocoded_patients_fy20_q1 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy20_q1 <- patients_adi_fy20_q1 %>%
  group_by(Sta5a, fy, qtr) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
############################################################################################################
# FY20, Q2
############################################################################################################
rm(patients_fy20_q1)
rm(patients_shp_fy20_q1)
rm(patients_adi_fy20_q1)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy20_q1)
#
#patients in PCMM in FY20, Q2
tictoc::tic()
#
patients_fy20_q2 <- dbGetQuery(oabi_connect,
                               "
    select *
    from [crh_eval].pssg_lat_lon_fy20
      where qtr = 2
        AND LAT IS NOT NULL
        AND LON IS NOT NULL
        AND TRACT IS NOT NULL
"
) %>%
  as_tibble() %>%
  mutate(
    STATEFP = str_sub(TRACT, start = 1, end = 2)
    , COUNTYFP = str_sub(TRACT, start = 3, end = 5)
    , TRACTCE = str_sub(TRACT, start = 6, end = 11)
    , COUNTYFP = if_else(COUNTYFP == "270" & STATEFP == "02", "158", COUNTYFP) #per change in FIPS from 02270 to 02158
    , COUNTYFP = if_else(COUNTYFP == "113" & STATEFP == "46", "102", COUNTYFP)
    , COUNTYFP = if_else(COUNTYFP == "515" & STATEFP == "51", "019", COUNTYFP)
  )

################################################
xy <- patients_fy20_q2 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy20_q2 <- SpatialPointsDataFrame(coords = xy, 
                                               data = patients_fy20_q2,
                                               proj4string = CRS(raster::projection(block_shp_18)))
#---===---===---===---===---===---===---===---===---===---===
# loop over all counties - FY20, Q2
stack_blocks <- list() # To fill with geocoded data
COUNTYFP_old = "" # For printing
for(ii in seq_along(distinct_counties$STATEFP)){
  
  STATEFP_loop <- distinct_counties$STATEFP[ii]
  COUNTYFP_loop <- distinct_counties$COUNTYFP[ii]
  
  # Print a status message for every county
  if(COUNTYFP_old != COUNTYFP_loop){
    print(paste0("Loop: ", ii , " (", round(ii / 3219 * 100, 1), "%), ",
                 " Now in STATEFP: ", STATEFP_loop, " COUNTYFP: ", COUNTYFP_loop, " SYS TIME: ", Sys.time()))
  }
  stack_blocks[[ii]] <- join_pssg_block(STATEFP_var = STATEFP_loop, COUNTYFP_var = COUNTYFP_loop,
                                        fy_var = 20, qtr_var = 2) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy20_q2 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy20_q2 %>% select(ScrSSN_num, Sta5a))
#--
fy_20_q2_time <- tictoc::toc()
print(paste0("FY20, Q2 took ", round((fy_20_q2_time$toc - fy_20_q2_time$tic) / 60, 1), " minutes"))
#---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===
# ADI
patients_adi_fy20_q2 <- geocoded_patients_fy20_q2 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy20_q2 <- patients_adi_fy20_q2 %>%
  group_by(Sta5a, fy, qtr) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
############################################################################################################
# FY20, Q3
############################################################################################################
rm(patients_fy20_q2)
rm(patients_shp_fy20_q2)
rm(patients_adi_fy20_q2)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy20_q2)
#
#patients in PCMM in FY20, q3
tictoc::tic()
#
patients_fy20_q3 <- dbGetQuery(oabi_connect,
                               "
    select *
    from [crh_eval].pssg_lat_lon_fy20
      where qtr = 3
        AND LAT IS NOT NULL
        AND LON IS NOT NULL
        AND TRACT IS NOT NULL
"
) %>%
  as_tibble() %>%
  mutate(
    STATEFP = str_sub(TRACT, start = 1, end = 2)
    , COUNTYFP = str_sub(TRACT, start = 3, end = 5)
    , TRACTCE = str_sub(TRACT, start = 6, end = 11)
    , COUNTYFP = if_else(COUNTYFP == "270" & STATEFP == "02", "158", COUNTYFP) #per change in FIPS from 02270 to 02158
    , COUNTYFP = if_else(COUNTYFP == "113" & STATEFP == "46", "102", COUNTYFP)
    , COUNTYFP = if_else(COUNTYFP == "515" & STATEFP == "51", "019", COUNTYFP)
  )

################################################
xy <- patients_fy20_q3 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy20_q3 <- SpatialPointsDataFrame(coords = xy, 
                                               data = patients_fy20_q3,
                                               proj4string = CRS(raster::projection(block_shp_18)))
#---===---===---===---===---===---===---===---===---===---===
# FY20, q3
stack_blocks <- list() # To fill with geocoded data
COUNTYFP_old = "" # For printing
for(ii in seq_along(distinct_counties$STATEFP)){
  
  STATEFP_loop <- distinct_counties$STATEFP[ii]
  COUNTYFP_loop <- distinct_counties$COUNTYFP[ii]
  
  # Print a status message for every county
  if(COUNTYFP_old != COUNTYFP_loop){
    print(paste0("Loop: ", ii , " (", round(ii / 3219 * 100, 1), "%), ",
                 " Now in STATEFP: ", STATEFP_loop, " COUNTYFP: ", COUNTYFP_loop, " SYS TIME: ", Sys.time()))
  }
  stack_blocks[[ii]] <- join_pssg_block(STATEFP_var = STATEFP_loop, COUNTYFP_var = COUNTYFP_loop,
                                        fy_var = 20, qtr_var = 3) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy20_q3 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy20_q3 %>% select(ScrSSN_num, Sta5a))
#--
fy_20_q3_time <- tictoc::toc()
print(paste0("FY20, q3 took ", round((fy_20_q3_time$toc - fy_20_q3_time$tic) / 60, 1), " minutes"))
#---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===
# ADI
patients_adi_fy20_q3 <- geocoded_patients_fy20_q3 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy20_q3 <- patients_adi_fy20_q3 %>%
  group_by(Sta5a, fy, qtr) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
############################################################################################################
# FY20, Q4
############################################################################################################
rm(patients_fy20_q3)
rm(patients_shp_fy20_q3)
rm(patients_adi_fy20_q3)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy20_q3)
#
#patients in PCMM in FY20, q4
tictoc::tic()
#
patients_fy20_q4 <- dbGetQuery(oabi_connect,
                               "
    select *
    from [crh_eval].pssg_lat_lon_fy20
      where qtr = 4
        AND LAT IS NOT NULL
        AND LON IS NOT NULL
        AND TRACT IS NOT NULL
"
) %>%
  as_tibble() %>%
  mutate(
    STATEFP = str_sub(TRACT, start = 1, end = 2)
    , COUNTYFP = str_sub(TRACT, start = 3, end = 5)
    , TRACTCE = str_sub(TRACT, start = 6, end = 11)
    , COUNTYFP = if_else(COUNTYFP == "270" & STATEFP == "02", "158", COUNTYFP) #per change in FIPS from 02270 to 02158
    , COUNTYFP = if_else(COUNTYFP == "113" & STATEFP == "46", "102", COUNTYFP)
    , COUNTYFP = if_else(COUNTYFP == "515" & STATEFP == "51", "019", COUNTYFP)
  )

################################################
xy <- patients_fy20_q4 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy20_q4 <- SpatialPointsDataFrame(coords = xy, 
                                               data = patients_fy20_q4,
                                               proj4string = CRS(raster::projection(block_shp_18)))
#---===---===---===---===---===---===---===---===---===---===
# FY20, q4
stack_blocks <- list() # To fill with geocoded data
COUNTYFP_old = "" # For printing
for(ii in seq_along(distinct_counties$STATEFP)){
  
  STATEFP_loop <- distinct_counties$STATEFP[ii]
  COUNTYFP_loop <- distinct_counties$COUNTYFP[ii]
  
  # Print a status message for every county
  if(COUNTYFP_old != COUNTYFP_loop){
    print(paste0("Loop: ", ii , " (", round(ii / 3219 * 100, 1), "%), ",
                 " Now in STATEFP: ", STATEFP_loop, " COUNTYFP: ", COUNTYFP_loop, " SYS TIME: ", Sys.time()))
  }
  stack_blocks[[ii]] <- join_pssg_block(STATEFP_var = STATEFP_loop, COUNTYFP_var = COUNTYFP_loop,
                                        fy_var = 20, qtr_var = 4) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy20_q4 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy20_q4 %>% select(ScrSSN_num, Sta5a))
#--
fy_20_q4_time <- tictoc::toc()
print(paste0("FY20, q4 took ", round((fy_20_q4_time$toc - fy_20_q4_time$tic) / 60, 1), " minutes"))
#---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===---===
# ADI
patients_adi_fy20_q4 <- geocoded_patients_fy20_q4 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy20_q4 <- patients_adi_fy20_q4 %>%
  group_by(Sta5a, fy, qtr) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
#--------
# Push to OABI_MyVAAccess
#--==--==
#dbSendQuery(oabi_connect, "DROP TABLE IF EXISTS [OABI_MyVAAccess].[crh_eval].adi_sta5a_qtr")
##
table_id <- DBI::Id(schema = "crh_eval", table = "adi_sta5a_qtr")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = sta5a_summary_fy20_q1,
                  append = TRUE)
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = sta5a_summary_fy20_q2,
                  append = TRUE)
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = sta5a_summary_fy20_q3,
                  append = TRUE)
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = sta5a_summary_fy20_q4,
                  append = TRUE)
#=========
rm(patients_fy20_q4)
rm(patients_shp_fy20_q4)
rm(patients_adi_fy20_q4)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy20_q4)