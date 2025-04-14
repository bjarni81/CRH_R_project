# Author: Bjarni Haraldsson
# Date: 12/19/2023
# Description: 
# 1. Take patient LAT/LONG from PSSG table and find patient corresponding census block
# 2. Use census block and merge with Area Deprevation Index (ADI)
# Adapted from Eric Gunnink
################################################################################



# load libraries
library(tidyverse)
library(odbc)
library(RODBC)
library(DBI)

#library(rgdal)
library(sf)
library(sp)

library(tictoc)
################################################

# Step 1: Get Patient Lat/Long

################################################
oabi_connect <- dbConnect(odbc::odbc(), Driver = "SQL Server", 
                          Server = "vhacdwsql13.vha.med.va.gov",
                          Database = "OABI_MyVAAccess", 
                          Trusted_Connection = "true"
)
#patients in PCMM in fy20
patients_fy20 <- dbGetQuery(oabi_connect,
                               "
    select *
    from [crh_eval].D3_TEMP_lat_lon_fy
      where fy = 2020
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
distinct_counties <- patients_fy20 %>% distinct(STATEFP, COUNTYFP) %>% arrange(STATEFP, COUNTYFP)
state_fips <- distinct_counties %>% select(STATEFP) %>% distinct %>% pull
################################################

# Step 2: Load Census Block Group Boundary File

################################################
stack_of_bgs <- list()
#
for(ii in seq_along(state_fips)){
  print(state_fips[ii])
  #
  stack_of_bgs[[ii]] <- tigris::block_groups(state = state_fips[ii],
                                             cb = FALSE,
                                             year = 2018)
}
#
block_shp <- stack_of_bgs %>%
  bind_rows(.) %>%
  as_Spatial()
################################################

# Step 3: Convert lat/lon to shapefile points

################################################
xy <- patients_fy20 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy20 <- SpatialPointsDataFrame(coords = xy, 
                                               data = patients_fy20,
                                               proj4string = CRS(raster::projection(block_shp)))
#################################################

# Step 4: Merge

#################################################
# This function subsets the block shapefile and the pssg lat/long by county
# (only points within a county are compared to block groups in that county)
# Then returns a tibble with two columns SCRSSN/fips (fips is at blockgroup level)
join_pssg_block <- function(STATEFP_var, COUNTYFP_var, fy_var){
  # Subset PSSG by county
  if (fy_var == 20){
    pssg_county_shp <- patients_shp_fy20[
      (
        (patients_shp_fy20$STATEFP == STATEFP_var) & 
          (patients_shp_fy20$COUNTYFP == COUNTYFP_var) )
      , ]  
  }
  else if (fy_var == 21){
    pssg_county_shp <- patients_shp_fy21[
      (
        (patients_shp_fy21$STATEFP == STATEFP_var) & 
          (patients_shp_fy21$COUNTYFP == COUNTYFP_var) )
      , ]  
  }
  else {
    pssg_county_shp <- patients_shp_fy22[
      (
        (patients_shp_fy22$STATEFP == STATEFP_var) & 
          (patients_shp_fy22$COUNTYFP == COUNTYFP_var) )
      , ]  
  }
  # Subset block group by county 
  block_shp <- block_shp[
    (
      (block_shp$STATEFP == STATEFP_var) & 
        (block_shp$COUNTYFP == COUNTYFP_var)  )
    , ]
  # This joins the points and the shapes
  pssg_county_shp %>% 
    over(., block_shp) %>% # This does all the heavy lifting. If point is in polygon we get the polygon ID
    as_tibble() %>% 
    bind_cols(ScrSSN_num = pssg_county_shp$ScrSSN_num) %>% # add back identifying information
    select(ScrSSN_num, fips = GEOID) %>%
    mutate(fy = as.numeric(paste0("20", fy_var)))
}
#
# TEST: join_pssg_block(STATEFP_var = "36", COUNTYFP_var = "001", fy_var = 20)
#--
# For loop iterates over all tracts present in lat/long table and saves 
# geocoded patients as a tibble in a list where each element is a tract
#---===---===
# fy20
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
                                        fy_var = 20) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy20 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy20 %>% select(ScrSSN_num, Sta5a))
#--
fy_21_q1_time <- tictoc::toc()
print(paste0("fy20 took ", round((fy_21_q1_time$toc - fy_21_q1_time$tic) / 60, 1), " minutes"))
############################################

# Step 6: Bonus - Merge ADI 

############################################

# ADI File downloaded from:
# https://www.neighborhoodatlas.medicine.wisc.edu/

adi <- read_csv(here("Input", "Data", "ADI", "us_bg.txt")) %>%
  mutate(st_fips = as.numeric(str_sub(FIPS, end = 2))) %>%
  rename_all(tolower) %>%
  mutate(adi_natrank = as.numeric(adi_natrank),
         adi_staternk = as.numeric(adi_staternk))

#---===---===---===
patients_adi_fy20 <- geocoded_patients_fy20 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy20 <- patients_adi_fy20 %>%
  group_by(Sta5a) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
#=========================================================
rm(patients_fy20)
rm(patients_shp_fy20)
rm(patients_adi_fy20)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy20)
rm(stack_of_bgs)
#====================================================
patients_fy21 <- dbGetQuery(oabi_connect,
                            "
    select *
    from [crh_eval].D3_TEMP_lat_lon_fy
      where fy = 2021
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
distinct_counties <- patients_fy21 %>% distinct(STATEFP, COUNTYFP) %>% arrange(STATEFP, COUNTYFP)
state_fips <- distinct_counties %>% select(STATEFP) %>% distinct %>% pull
################################################
stack_of_bgs <- list()
#
for(ii in seq_along(state_fips)){
  print(state_fips[ii])
  #
  stack_of_bgs[[ii]] <- tigris::block_groups(state = state_fips[ii],
                                             cb = FALSE,
                                             year = 2020)
}
#
block_shp <- stack_of_bgs %>%
  bind_rows(.) %>%
  as_Spatial()
################################################
xy <- patients_fy21 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy21 <- SpatialPointsDataFrame(coords = xy, 
                                            data = patients_fy21,
                                            proj4string = CRS(raster::projection(block_shp)))
#################################################
#---===---===
# fy21
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
                                        fy_var = 21) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy21 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy21 %>% select(ScrSSN_num, Sta5a))
#--
fy_21_q1_time <- tictoc::toc()
print(paste0("fy21 took ", round((fy_21_q1_time$toc - fy_21_q1_time$tic) / 60, 1), " minutes"))
############################################
patients_adi_fy21 <- geocoded_patients_fy21 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy21 <- patients_adi_fy21 %>%
  group_by(Sta5a) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
#=========================================================
rm(patients_fy21)
rm(patients_shp_fy21)
rm(patients_adi_fy21)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy21)
rm(stack_of_bgs)
#====================================================
patients_fy22 <- dbGetQuery(oabi_connect,
                            "
    select *
    from [crh_eval].D3_TEMP_lat_lon_fy
      where fy = 2022
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
distinct_counties <- patients_fy22 %>% distinct(STATEFP, COUNTYFP) %>% arrange(STATEFP, COUNTYFP)
state_fips <- distinct_counties %>% select(STATEFP) %>% distinct %>% pull
################################################
stack_of_bgs <- list()
#
for(ii in seq_along(state_fips)){
  print(state_fips[ii])
  #
  stack_of_bgs[[ii]] <- tigris::block_groups(state = state_fips[ii],
                                             cb = FALSE,
                                             year = 2021)
}
#
block_shp <- stack_of_bgs %>%
  bind_rows(.) %>%
  as_Spatial()
################################################
xy <- patients_fy22 %>%
  select(LON, LAT)
# SpatialPointsDataFrame
patients_shp_fy22 <- SpatialPointsDataFrame(coords = xy, 
                                            data = patients_fy22,
                                            proj4string = CRS(raster::projection(block_shp)))
#################################################
#---===---===
# fy22
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
                                        fy_var = 22) 
  
  COUNTYFP_old = COUNTYFP_loop}
# Stack list of tract tibbles
geocoded_patients_fy22 <- bind_rows(stack_blocks) %>% 
  filter(!is.na(fips)) %>%
  left_join(., patients_fy22 %>% select(ScrSSN_num, Sta5a))
#--
fy_21_q1_time <- tictoc::toc()
print(paste0("fy22 took ", round((fy_21_q1_time$toc - fy_21_q1_time$tic) / 60, 1), " minutes"))
############################################
patients_adi_fy22 <- geocoded_patients_fy22 %>%
  left_join(., adi) %>%
  mutate(in_1_25 = if_else(adi_natrank < 26, 1, 0),
         in_26_50 = if_else(adi_natrank > 25 & adi_natrank < 51, 1, 0),
         in_51_75 = if_else(adi_natrank > 50 & adi_natrank < 76, 1, 0),
         in_76_100 = if_else(adi_natrank > 75, 1, 0))
#
sta5a_summary_fy22 <- patients_adi_fy22 %>%
  group_by(Sta5a) %>%
  summarise(adi_count = n(),
            adi_natRnk_avg = mean(adi_natrank, na.rm = T),
            adi_natRnk_sd = sd(adi_natrank, na.rm = T),
            adi_count_in_1_25 = sum(in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(in_76_100, na.rm = T))
#=========================================================
rm(patients_fy22)
rm(patients_shp_fy22)
rm(patients_adi_fy22)
rm(xy)
rm(stack_blocks)
rm(geocoded_patients_fy22)
rm(stack_of_bgs)
#==================================
all_summary <- sta5a_summary_fy20 %>%
  mutate(fy = 2020) %>%
  bind_rows(., sta5a_summary_fy21 %>% mutate(fy = 2021)) %>%
  bind_rows(., sta5a_summary_fy22 %>% mutate(fy = 2022)) %>%
  bind_rows(., sta5a_summary_fy22 %>% mutate(fy = 2023))
#--------
# Push to OABI_MyVAAccess
#--==--==
#dbSendQuery(oabi_connect, "DROP TABLE IF EXISTS [OABI_MyVAAccess].[crh_eval].adi_sta5a_qtr")
##
table_id <- DBI::Id(schema = "crh_eval", table = "D3_adi_sta5a_fy")
##
DBI::dbWriteTable(conn = oabi_connect,
                  name = table_id,
                  value = all_summary)