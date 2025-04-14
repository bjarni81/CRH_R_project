library(tidyverse)
library(here)
library(DBI)
#
source(here("Input", "PC Engagement", "B_read_csv_fxn.R"))
#
`%ni%` = purrr::negate(`%in%`)
#---------
tna = read_fxn("3rd", "tna") %>%
  mutate(tna = na_if(tna, NaN))
est = read_fxn("est_pt", "est_pt_wt_pid")
new = read_fxn("new_pt", "new_pt_wt")
nosos = read_fxn("nosos", "nosos")
panel_fullness = read_fxn("fullness", "panel_fullness")
pc_teamlet_staff_ratio = read_fxn("teamlet", "teamlet_staff_ratio")
obs_exp = read_fxn("obs_exp", "obs_exp")
fte_tot = read_fxn("fte_tot", "pcp_fte_tot")
fte_crh = read_fxn("fte_crh", "pcp_fte_crh")
fte_crh_corrected = fte_tot %>%
  left_join(., fte_crh) %>%
  mutate(crh_corr_pcp_fte = pcp_fte_tot - replace_na(pcp_fte_crh, 0))
#---------
oabi_con <- DBI::dbConnect(odbc::odbc(),
                           Driver = "SQL Server",
                           Server = "vhacdwsql13.vha.med.va.gov",
                           Database = "OABI_MyVAAccess",
                           Trusted_Connection = "true")
#==========
timely_care <- DBI::dbGetQuery(oabi_con,
                               "select *
                          from [OABI_MyVAAccess].[crh_eval].[E3_daysDV_month_sta5a]") %>%
  mutate(viz_month = ymd(viz_month)) %>%
  rename(sta5a = req_sta5a,
         vssc_month = viz_month) %>%
  mutate(tc_pc_success_prop = round(tc_pc_success_sum / tc_requests_sum, 3)) %>%
  select(-viz_fy, -viz_qtr)
#----------
gap_metric <- DBI::dbGetQuery(oabi_con,
                              "select * from [PACT_CC].[CRH].[vw_gapMetric]") %>%
  mutate(vssc_month = ymd(str_c(cy, mth_num, "01", sep = "-")),
         gap_metric = expectedPanelSize_total / as.numeric(observedPanelSize_AllTeamTypes),
         gap_capped = if_else(gap_metric > 3, 3, gap_metric),
         gap_cat = factor(case_when(gap_metric < 1.0 ~ "< 1.0",
                                    gap_metric >= 1.0 & gap_metric <= 1.2 ~ "1.0 - 1.2",
                                    gap_metric > 1.2 ~ "> 1.2",
                                    TRUE ~ "Missing"),
                          ordered = TRUE,
                          levels = c("< 1.0", "1.0 - 1.2", "> 1.2", "Missing"))) %>%
  rename(sta5a = sta6a)
#-----------
can_score = DBI::dbGetQuery(oabi_con,
                            "select *
                            from [OABI_MyVAAccess].[pccrh_eng].A_CAN_score") %>%
  rename(vssc_month = risk_month) %>%
  mutate(vssc_month = ymd(vssc_month),
         across((starts_with("c") & contains("sum")), ~.x / tot_count)) %>%
  rename_with(., ~str_replace(.x, "_sum", "_prop"))
#-----------
adi = DBI::dbGetQuery(oabi_con,
                      "select *
                            from [OABI_MyVAAccess].[pccrh_eng].C_adi")
#==============
age_gender = DBI::dbGetQuery(oabi_con,
                             "select *
                            from [OABI_MyVAAccess].[pccrh_eng].D_age_gender") %>%
  mutate(male_prop = male_count / scrssn_count,
         female_prop = female_count / scrssn_count)
#--------------
unique_scrssn = DBI::dbGetQuery(oabi_con,
                                "select *
                                from [OABI_MyVAAccess].[pccrh_eng].E_uniques") %>%
  group_by(sta5a) %>%
  summarise(scrssn_count_mean = mean(scrssn_count, na.rm = T)) %>%
  mutate(scrssn_count_cat = case_when(
    scrssn_count_mean < 450 ~ "< 450",
    scrssn_count_mean >= 450 & scrssn_count_mean < 2400 ~ "450-2,399",
    scrssn_count_mean >= 2400 & scrssn_count_mean < 10000 ~ "2,400-9,999",
    scrssn_count_mean >= 10000 ~ "10,000+"
  ))
#==========
cerner_sites = DBI::dbGetQuery(oabi_con,
                               "select distinct sta6a = case
			when SUBSTRING(locationFacility, 4, 1) = ' ' then SUBSTRING(LocationFacility, 1, 3)
			when SUBSTRING(LocationFacility, 4, 1) <> ' ' then SUBSTRING(LocationFacility, 1, 5)
			else 'Uh-oh!' end 
from [PACT_CC].[cern].cipher_201_encounter_dist_personSID") %>%
  pull

#--
vast = DBI::dbGetQuery(oabi_con,
                  "--
select distinct sta5a = stationno, parent_station = par_sta_no
	, visn = case when newvisn IS NULL then SUBSTRING(district_visn, 3, 2) else newvisn end 
	, city, st, stationname, s_abbr
from [PACT_CC].[Dim].VAST
where extractdate = '8-16-2022'
	AND s_abbr IN('HCC', 'VAMC', 'MSCBOC', 'PCCBOC', 'OOS')
	AND stationname NOT LIKE '%Mobile Clinic%'
		AND stationname NOT LIKE '%Living Center%'
	AND stationno IN(select distinct sta6aid from PACT_CC.Dim.VAST_Historic where snapshotDate = '2022-07-01')") %>%
  filter(sta5a %ni% cerner_sites
         & st %in% c(state.abb, "DC")) %>%
  mutate(visn = str_pad(visn, width = 2, side = "left", pad = "0"))
#==============
urh = dbGetQuery(oabi_con,
                 "select *
                 from [OABI_MyVAAccess].[pccrh_eng].F_urh") %>%
  mutate(urban_prop = urban_sum / urh_count,
         rural_prop = rural_sum / urh_count) %>%
  select(-c(urban_sum, rural_sum, urh_count))
#==============
crh_flag = dbGetQuery(oabi_con,
                      "select *
                      from [OABI_MyVAAccess].[pccrh_eng].G_crh_flag") %>%
  select(sta5a, crh_flag, first_mo_w_mt9_pc_crh, period_initiating_crh)
#==============
pc_crh_pen_rate = dbGetQuery(oabi_con,
                             "select *
                             from [OABI_MyVAAccess].[crh_eval].B1_crh_penRate")
#==============
pc_cc_ref_rate = dbGetQuery(oabi_con,
                            "select *
                            from [OABI_MyVAAccess].[pccrh_eng].H_pc_cc_refs") %>%
  rename(sta5a = sta6a,
         vssc_month = acty_month) %>%
  left_join(., pc_crh_pen_rate %>%
              rename(vssc_month = crh_month)) %>%
  mutate(pc_encounter_total = na_if(pc_encounter_total, 0),
         pc_cc_refs_per_1k_tot_pc = pc_cc_referrals / pc_encounter_total * 1000,
         vssc_month = ymd(vssc_month)) %>%
  select(-crh_encounter_count, -pc_cc_referrals, -pc_encounter_total)
#--------------
age_gender = dbGetQuery(oabi_con,
                        "select *
                        from [OABI_MyVAAccess].[pccrh_eng].D_age_gender") %>%
  mutate(age_jan1_mean = round(age_jan1_mean, digits = 2),
         prop_male = male_count / scrssn_count)
#==============
assembled_df = vast %>%
  select(sta5a) %>%
  cross_join(., tibble(vssc_month = seq.Date(ymd("2020-10-01"), 
                                             ymd("2024-09-01"), 
                                             "month")) %>%
               mutate(fy = if_else(month(vssc_month) > 9, 
                                   year(vssc_month) + 1, 
                                   year(vssc_month)))) %>%
  left_join(., vast %>%
              select(sta5a, visn, parent_station, s_abbr)) %>%
  left_join(., est) %>%
  left_join(., new) %>%
  left_join(., tna) %>%
  left_join(., timely_care %>%
              select(sta5a, vssc_month, tc_pc_success_prop)) %>%
  left_join(., fte_crh_corrected) %>%
  left_join(., gap_metric %>%
              select(sta5a, vssc_month, gap_metric, gap_cat)) %>%
  left_join(., nosos) %>%
  left_join(., can_score %>%
              select(-missing_pat_count, -fy)) %>%
  left_join(., adi %>%
              select(sta5a, fy, adi_natrank_mean)) %>%
  left_join(., obs_exp) %>%
  left_join(., panel_fullness) %>%
  left_join(., pc_teamlet_staff_ratio) %>%
  left_join(., unique_scrssn) %>%
  filter(scrssn_count_cat != "< 450") %>%
  left_join(., crh_flag) %>%
  mutate(period_initiating_crh = replace_na(period_initiating_crh, "No PC CRH"),
         crh_flag = replace_na(crh_flag, 0)) %>%
  left_join(., pc_cc_ref_rate) %>%
  left_join(., age_gender %>%
              select(sta5a, fy, age_jan1_mean, prop_male)) %>%
  left_join(., urh)
#
always_missing_gap = assembled_df %>%
  group_by(sta5a) %>%
  filter(all(is.na(gap_metric))) %>%
  select(sta5a) %>%
  pull
#
always_missing_pf = assembled_df %>%
  group_by(sta5a) %>% 
  filter(all(is.na(panel_fullness))) %>%
  select(sta5a) %>%
  pull
#
always_missing_can = assembled_df %>% 
  group_by(sta5a) %>%
  filter(all(is.na(urban_prop))) %>%
  select(sta5a) %>%
  pull
#
analytic_df = assembled_df %>%
  filter(sta5a %ni% always_missing_can) %>%
  mutate(always_missing_gap = 
           if_else(sta5a %in% always_missing_gap, 1, 0),
         always_missing_pf = 
           if_else(sta5a %in% always_missing_pf, 1, 0))
#--------------
table_id <- DBI::Id(schema = "pccrh_eng", table = "Z_analytic_df")
##
DBI::dbWriteTable(conn = oabi_con,
                  name = table_id,
                  value = analytic_df,
                  overwrite = TRUE)
