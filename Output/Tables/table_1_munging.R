library(tidyverse)
library(DBI)
library(lubridate)
library(here)
#
options(scipen = 999)
#---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
##---------- Connection to PACT_CC
pactcc_con <- dbConnect(odbc::odbc(),
                        Driver = "SQL Server",
                        Server = "vhacdwsql13.vha.med.va.gov",
                        Database = "PACT_CC",
                        Trusted_Connection = "true")
# VAST
vast <- read_csv(here("Input", "Data", "vast_from_a06.csv"))
#
vast_to_include <- vast %>%
  select(sta5a)
# crh flags
crh_flags <- dbGetQuery(oabi_con,
                        "select * from [crh_eval].yoon_10_flag")
# 
#====================================
# AGE, GENDER, RACE, AND SCRSSN COUNT
race_gender_urh_fy21_qtr4 <- dbGetQuery(oabi_con,
                              "select *
                              from [crh_eval].pcmm_pssg_race_gender_count
                              where fy = 2021 AND qtr = 4") %>%
  rename_all(tolower) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include)
#===
race_gender_urh_summary <- race_gender_urh_fy21_qtr4 %>%
  group_by(table_1_columns) %>%
  summarise(total_scrssn = sum(scrssn_count, na.rm = T),
            total_female = sum(female_count, na.rm = T),
            total_white = sum(race_white_count, na.rm = T),
            total_black = sum(race_black_count, na.rm = T),
            total_other = sum(race_other_count, na.rm = T),
            total_urban = sum(urh_urban_count, na.rm = T),
            total_rural = sum(urh_rural_count, na.rm = T)) %>%
  mutate(female_prop = total_female / total_scrssn,
         white_prop = total_white / total_scrssn,
         black_prop = total_black / total_scrssn,
         other_race_prop = total_other / total_scrssn,
         urban_prop = total_urban / total_scrssn,
         rural_prop = total_rural / total_scrssn)
#========================================
# AVERAGE ADI
adi <- dbGetQuery(oabi_con,
                  "select *
                  from [crh_eval].adi_sta5a_qtr
                  where fy = 2021 AND qtr = 4") %>%
  rename_all(tolower) %>%
  filter(is.na(adi_natrnk_sd) == F) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH")),
         gm_value = adi_natrnk_avg * adi_count) %>%
  inner_join(., vast_to_include)
#==
# categorical counts
adi_cats <- adi %>%
  group_by(table_1_columns) %>%
  summarise(adi_total_count = sum(adi_count, na.rm = T),
            adi_count_in_1_25 = sum(adi_count_in_1_25, na.rm = T),
            adi_count_in_26_50 = sum(adi_count_in_26_50, na.rm = T),
            adi_count_in_51_75 = sum(adi_count_in_51_75, na.rm = T),
            adi_count_in_76_100 = sum(adi_count_in_76_100, na.rm = T))
#===
#basis of this function comes from https://www.statstodo.com/CombineMeansSDs.php
adi_summary_fxn <- function(col_name){
  adi_lim <- adi %>%
    filter(table_1_columns == col_name)
  #
  nr = nrow(adi_lim)   # number of rows
  ex <- rep(0,nr)          # array to contain Σx
  exx <- rep(0,nr)         # array to contain Σx2
  tn = 0                   # total n
  tx = 0                   # total Σx 
  txx = 0                  # total Σx2
  for(i in 1:nr)
  {
    ex[i] = adi_lim$adi_count[i] * adi_lim$adi_natrnk_avg[i]
    exx[i] = adi_lim$adi_natrnk_sd[i]^2 * (adi_lim$adi_count[i]-1) + ex[i]^2 / adi_lim$adi_count[i]
    tn = tn + adi_lim$adi_count[i]
    tx = tx + ex[i]
    txx = txx + exx[i]
  }
  if(col_name == "CRH"){
    grand_mean_crh <- tx / tn
    grand_sd_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    adi_crh <<- tibble(
      table_1_columns = "CRH",
      adi_grand_mean = grand_mean_crh,
      adi_grand_sd = grand_sd_crh
    )
  }
  else if(col_name == "No CRH"){
    grand_mean_no_crh <- tx / tn
    grand_sd_no_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    adi_no_crh <<- tibble(
      table_1_columns = "No CRH",
      adi_grand_mean = grand_mean_no_crh,
      adi_grand_sd = grand_sd_no_crh
    )
  }
  else {
    grand_mean_not_enough_crh <- tx / tn
    grand_sd_not_enough_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    adi_not_enough_crh <<- tibble(
      table_1_columns = "Not Enough CRH",
      adi_grand_mean = grand_mean_not_enough_crh,
      adi_grand_sd = grand_sd_not_enough_crh
    )
  }
}
#
adi_summary_fxn("CRH")
adi_summary_fxn("No CRH")
adi_summary_fxn("Not Enough CRH")
#--==--==--
adi_summary <- adi_crh %>%
  bind_rows(., adi_no_crh) %>%
  bind_rows(., adi_not_enough_crh) %>%
  left_join(., adi_cats)
#========================================
# AVERAGE AGE AND CATEGORIES
age <- dbGetQuery(oabi_con,
                  "select * from [crh_eval].age_sta5a_qtr
                  where fy = 2021 AND qtr = 4") %>%
  rename_all(tolower) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include)
#--
age_cats <- age %>%
  group_by(table_1_columns) %>%
  summarise(`_18_39_count` = sum(`_18_39_count`, na.rm = T),
            `_40_49_count` = sum(`_40_49_count`, na.rm = T),
            `_50_59_count` = sum(`_50_59_count`, na.rm = T),
            `_60_69_count` = sum(`_60_69_count`, na.rm = T),
            `_70_79_count` = sum(`_70_79_count`, na.rm = T),
            `_80_plus_count` = sum(`_80_plus_count`, na.rm = T))
#--
age_summary_fxn <- function(col_name){
  age_lim <- age %>%
    filter(table_1_columns == col_name)
  #
  nr = nrow(age_lim)   # number of rows
  ex <- rep(0,nr)          # array to contain Σx
  exx <- rep(0,nr)         # array to contain Σx2
  tn = 0                   # total n
  tx = 0                   # total Σx 
  txx = 0                  # total Σx2
  for(i in 1:nr)
  {
    ex[i] = age_lim$total[i] * age_lim$avg_age_oct1_2020[i]
    exx[i] = age_lim$std_age_oct1_2020[i]^2 * (age_lim$total[i]-1) + ex[i]^2 / age_lim$total[i]
    tn = tn + age_lim$total[i]
    tx = tx + ex[i]
    txx = txx + exx[i]
  }
  if(col_name == "CRH"){
    grand_mean_crh <- tx / tn
    grand_sd_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    age_crh <<- tibble(
      table_1_columns = "CRH",
      age_grand_mean = grand_mean_crh,
      age_grand_sd = grand_sd_crh
    )
  }
  else if(col_name == "No CRH"){
    grand_mean_no_crh <- tx / tn
    grand_sd_no_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    age_no_crh <<- tibble(
      table_1_columns = "No CRH",
      age_grand_mean = grand_mean_no_crh,
      age_grand_sd = grand_sd_no_crh
    )
  }
  else {
    grand_mean_not_enough_crh <- tx / tn
    grand_sd_not_enough_crh <- sqrt(abs(txx - tx^2 / tn) / (tn - 1))
    age_not_enough_crh <<- tibble(
      table_1_columns = "Not Enough CRH",
      age_grand_mean = grand_mean_not_enough_crh,
      age_grand_sd = grand_sd_not_enough_crh
    )
  }
}
#
age_summary_fxn("CRH")
age_summary_fxn("No CRH")
age_summary_fxn("Not Enough CRH")
#
age_summary <- age_crh %>%
  bind_rows(., age_no_crh) %>%
  bind_rows(., age_not_enough_crh) %>%
  left_join(., age_cats)
#========================================================
# PC Encounter count - Quarter
pc_encounters_qtr <- dbGetQuery(oabi_con,
                            "select * from [crh_eval].pc_enc_scrssn_count_qtr") %>%
  rename(sta5a = Sta6a) %>%
  rename_all(tolower) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include)
#
pc_encounters_summary_qtr <- pc_encounters_qtr %>%
  group_by(table_1_columns) %>%
  summarise(mean_pc_enc_per_qtr = mean(pc_encounter_total, na.rm = T),
            sd_pc_enc_per_qtr = sd(pc_encounter_total, na.rm = T))
#====
# PC Encounter count - Month
pc_encounters_month <- dbGetQuery(oabi_con,
                            "select * from [crh_eval].pc_enc_scrssn_count_month") %>%
  rename(sta5a = Sta6a) %>%
  rename_all(tolower) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include)
#
pc_encounters_summary_month <- pc_encounters_month %>%
  group_by(table_1_columns) %>%
  summarise(mean_pc_enc_per_month = mean(pc_encounter_total, na.rm = T),
            sd_pc_enc_per_month = sd(pc_encounter_total, na.rm = T))
#------
pc_encounter_summary <- pc_encounters_summary_month %>%
  left_join(., pc_encounters_summary_qtr)

#========================================================
# NUMBER OF CRH ENCOUNTERS
pc_crh_encounters <- dbGetQuery(pactcc_con,
                                "select * from [CRH].C_crh_utilization_final
                                where care_type = 'Primary Care' AND (fy in(2020, 2021) OR (fy = 2022 AND qtr = 1))") %>%
  rename(sta5a = spoke_sta5a_combined_cdw) %>%
  mutate(visitdate = ymd(visitdate),
         crh_month = ymd(str_c(year(visitdate), month(visitdate), "01", sep = "-"))) %>%
  inner_join(., vast_to_include)
#
# Average and SD
pc_crh_avg_sd <- pc_crh_encounters %>%
  group_by(sta5a) %>%
  summarise(pc_crh_encounters = n()) %>%
  ungroup %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(mean_total_pc_crh_encounters = mean(pc_crh_encounters),
            sd_total_pc_crh_encounters = sd(pc_crh_encounters, na.rm = T),
            pc_crh_encounters_total = sum(pc_crh_encounters))
#
#Average CRH Encounters per month
pc_crh_avg_sd_month <- pc_crh_encounters %>%
  group_by(sta5a, crh_month) %>%
  summarise(pc_crh_encounters = n()) %>%
  ungroup %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(mean_pc_crh_encounters_month = mean(pc_crh_encounters),
            sd_pc_crh_encounters_month = sd(pc_crh_encounters, na.rm = T))
#
#Number of months with at least 1 CRH encounter
pc_crh_gt_0 <- pc_crh_encounters %>%
  group_by(sta5a, crh_month) %>%
  summarise(pc_crh_gt_0 = if_else(n() > 0, 1, 0)) %>%
  group_by(sta5a) %>%
  summarise(mos_w_pc_crh_gt_0 = sum(pc_crh_gt_0)) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(mos_w_pc_crh_gt_0 = sum(mos_w_pc_crh_gt_0))
#
#Number of months w/ > 5 encounters
pc_crh_gt_5 <- pc_crh_encounters %>%
  group_by(sta5a, crh_month) %>%
  summarise(pc_crh_gt_5 = if_else(n() > 5, 1, 0)) %>%
  group_by(sta5a) %>%
  summarise(mos_w_pc_crh_gt_5 = sum(pc_crh_gt_5)) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(mos_w_pc_crh_gt_5 = sum(mos_w_pc_crh_gt_5))
# Number of months (out of 27) with > 0 CRH
months_w_pc_crh <- pc_crh_encounters %>%
  select(sta5a, crh_month) %>%
  distinct %>%
  group_by(sta5a) %>%
  summarise(months_w_crh_encounter = n()) %>%
  mutate(prop_of_27_mos_w_pc_crh = months_w_crh_encounter / 27) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(avg_mos_w_pc_crh_27 = mean(months_w_crh_encounter, na.rm = T),
            sd_mos_w_pc_crh_27 = sd(months_w_crh_encounter, na.rm = T),
            avg_prop_w_pc_crh_27 = mean(prop_of_27_mos_w_pc_crh, na.rm = T),
            sd_prop_w_pc_crh_27 = sd(prop_of_27_mos_w_pc_crh, na.rm = T))
# Number of months (out of 27) with > 5 CRH
months_w_6_pc_crh <- pc_crh_encounters %>%
  group_by(sta5a, crh_month) %>%
  summarise(crh_encounters = n()) %>%
  filter(crh_encounters > 5) %>%
  group_by(sta5a) %>%
  summarise(months_w_6_crh_encounter = n()) %>%
  mutate(prop_of_27_mos_w_6_pc_crh = months_w_6_crh_encounter / 27) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  group_by(table_1_columns) %>%
  summarise(avg_mos_w_6_pc_crh_27 = mean(months_w_6_crh_encounter, na.rm = T),
            sd_mos_w_6_pc_crh_27 = sd(months_w_6_crh_encounter, na.rm = T),
            avg_prop_w_6_pc_crh_27 = mean(prop_of_27_mos_w_6_pc_crh, na.rm = T),
            sd_prop_w_6_pc_crh_27 = sd(prop_of_27_mos_w_6_pc_crh, na.rm = T))
#========================================================
# TOTAL PC ENCOUNTERS BY MODALITY
pc_enc_modality <- dbGetQuery(oabi_con,
                              "select * from  [OABI_MyVAAccess].[crh_eval].pc_enc_by_type_qtr
                              where fy = 2021 AND qtr = 4") %>%
  rename(sta5a = Sta6a) %>%
  select(-fy, -qtr) %>%
  pivot_wider(names_from = pc_type_flag, values_from = pc_type_count) %>%
  replace_na(list(`In-Person` = 0,
                  `Telephone` = 0,
                  `VVC` = 0,
                  `Secure Message` = 0,
                  `CVT` = 0)) %>%
  mutate(total = `In-Person` + `Telephone` + `VVC` + `Secure Message` + `CVT`,
         in_person_prop = `In-Person` / total,
         telephone_prop = `Telephone` / total,
         vvc_prop = `VVC` / total,
         sm_prop = `Secure Message` / total,
         cvt_prop = `CVT` / total) %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include)
#
pc_modality_summary <- pc_enc_modality %>%
  group_by(table_1_columns) %>%
  summarise(total_pc_encounters = sum(total),
            total_in_person = sum(`In-Person`, na.rm = T),
            total_telephone = sum(`Telephone`, na.rm = T),
            total_vvc = sum(`VVC`, na.rm = T),
            total_cvt = sum(`CVT`, na.rm = T),
            total_sm = sum(`Secure Message`, na.rm = T),
            in_person_prop = total_in_person / total_pc_encounters,
            telephone_prop = total_telephone / total_pc_encounters,
            vvc_prop = total_vvc / total_pc_encounters,
            cvt_prop = total_cvt / total_pc_encounters,
            sm_prop = total_sm / total_pc_encounters)
#========================================================
# S_ABBR COUNTS BY TABLE_1_COLUMNS
s_abbr <- race_gender_urh_fy21_qtr4 %>%
  select(sta5a) %>%
  bind_rows(., pc_crh_encounters %>% select(sta5a) %>% distinct) %>%
  distinct %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  select(-c(yoon_10_flag, crh_flag)) %>%
  inner_join(., vast_to_include) %>%
  left_join(., vast %>% select(sta5a, s_abbr)) %>%
  group_by(table_1_columns, s_abbr) %>%
  summarise(s_abbr_count = n()) %>%
  pivot_wider(names_from = s_abbr, values_from = s_abbr_count)
#======================================================
crh_s_abbr <- pc_crh_encounters %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  left_join(., vast %>% select(sta5a, s_abbr)) %>%
  group_by(table_1_columns, s_abbr) %>%
  summarise(crh_enc_s_abbr_count = n()) %>%
  pivot_wider(names_from = s_abbr, values_from = crh_enc_s_abbr_count) %>%
  rename(hcc_s_abbr = "HCC",
         mscboc_s_abbr = "MSCBOC",
         oos_s_abbr = "OOS",
         pccboc_s_abbr = "PCCBOC",
         vamc_s_abbr = "VAMC")
#========================================
#NUMBER OF STA5As
sta5a_summary <- race_gender_urh_fy21_qtr4 %>%
  select(sta5a) %>%
  bind_rows(., pc_crh_encounters %>% select(sta5a) %>% distinct) %>%
  distinct %>%
  left_join(., crh_flags) %>%
  mutate(table_1_columns = factor(case_when(yoon_10_flag == 1 ~ "CRH",
                                            crh_flag == 1 & yoon_10_flag == 0 ~ "Not Enough CRH",
                                            is.na(crh_flag) == T ~ "No CRH",
                                            TRUE ~ "Uh-oh"), 
                                  ordered = TRUE,
                                  levels = c("CRH", "Not Enough CRH", "No CRH"))) %>%
  inner_join(., vast_to_include) %>%
  group_by(table_1_columns) %>%
  summarise(sta5a_count = n())
#==========================================================================================
table_1 <- sta5a_summary %>%
  left_join(., race_gender_urh_summary) %>%
  left_join(., age_summary) %>%
  left_join(., adi_summary) %>%
  left_join(., pc_crh_avg_sd) %>%
  left_join(., pc_crh_avg_sd_month) %>%
  left_join(., pc_crh_gt_0) %>%
  left_join(., pc_crh_gt_5) %>%
  left_join(., pc_encounter_summary) %>%
  left_join(., pc_modality_summary) %>%
  left_join(., s_abbr) %>%
  left_join(., months_w_pc_crh) %>%
  left_join(., months_w_6_pc_crh) %>%
  left_join(., crh_s_abbr) %>%
  pivot_longer(-table_1_columns) %>%
  pivot_wider(names_from = table_1_columns, values_from = value)
#
write_csv(table_1,
          here("Output", "Tables", "Source", "table_1_06apr22.csv"),
          na = "-")
