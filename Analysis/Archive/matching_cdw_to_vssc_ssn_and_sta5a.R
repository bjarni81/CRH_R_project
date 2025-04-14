##---------- Connection to SQL13
oabi_con <- dbConnect(odbc::odbc(),
                      Driver = "SQL Server",
                      Server = "vhacdwsql13.vha.med.va.gov",
                      Database = "OABI_MyVAAccess",
                      Trusted_Connection = "true")
#
`%ni%` <- negate(`%in%`)
#
spokes <- dbGetQuery(oabi_con,
                     "select distinct spoke_sta5a from [PACT_CC].[CRH].CRH_sites_fy20_working")
#
vast <- read_csv(here("Input","Data","VAST_from_A06_11jan21.csv"))
#
vssc_crh_fy20  <- list.files(path = here::here("Input", "Data", "VSSC_CRH"),
           pattern = "*fy20*",
           full.names = T) %>%
  lapply(read_csv, skip = 6, guess_max = 10000) %>%
  bind_rows %>%
  rename(provider_encounter_division = DIVISION_FCDMD,
         did_encounter_pass_audit = Textbox53) %>%
  mutate(VisitDateTime1 = mdy_hms(VisitDateTime1),
         visitDate = as_date(VisitDateTime1, "mdY HMS"),
         viz_month = ymd(str_c(year(visitDate), month(visitDate), "01", sep = "-")),
         viz_fy = case_when(month(visitDate) > 9 ~ year(visitDate) + 1,
                            month(visitDate) < 10 ~ year(visitDate)),
         viz_qtr = case_when(month(visitDate) %in% c(10, 11, 12) ~ 1,
                             month(visitDate) %in% c(1, 2, 3) ~ 2,
                             month(visitDate) %in% c(4, 5, 6) ~ 3,
                             month(visitDate) %in% c(7, 8, 9) ~ 4),
         fy_qtr = str_c(viz_fy, viz_qtr, sep = "_"),
         care_type =
           case_when(
             (Pat_Visit_PrimStopCode %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348)
              & (Pat_Visit_SecStopCode != 160 | is.na(Pat_Visit_SecStopCode) == T))
             | (Pat_Visit_PrimStopCode != 160
                & Pat_Visit_SecStopCode %in% c(156, 176, 177, 178, 301, 322, 323, 338, 348))    ~ "Primary Care",
             (Pat_Visit_PrimStopCode %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550, 562, 576, 579, 586, 587)
              & (Pat_Visit_SecStopCode %ni% c(160, 534) | is.na(Pat_Visit_SecStopCode) == T))
             | (Pat_Visit_PrimStopCode %ni% c(160, 534)
                & Pat_Visit_SecStopCode %in% c(502, 509, 510, 513, 516, 527, 538, 545, 550,
                                               562, 576, 579, 586, 587))                  ~ "Mental Health",
             (Pat_Visit_PrimStopCode %in% c(534, 539)
              & (Pat_Visit_SecStopCode != 160 | is.na(Pat_Visit_SecStopCode) == T))
             | (Pat_Visit_PrimStopCode != 160 & Pat_Visit_SecStopCode %in% c(534, 539)) ~ "PCMHI",
             Pat_Visit_PrimStopCode == 160 | Pat_Visit_SecStopCode == 160  ~ "Pharmacy",
             is.na(Pat_Visit_PrimStopCode) == T ~ "Missing",
             TRUE                                                                                  ~ "Specialty")) %>%
  left_join(., vast, by = c("Pat_Sta6a" = "sta5a")) %>%
  rename_all(tolower)
#---
cdw_crh_fy20 <- dbGetQuery(oabi_con,
                      "select distinct a.*
                      	, b.PatientSSN
                      from [OABI_MyVAAccess].[crh_eval].crh_encounters_deDup as a
                      left join [CDWWork].[SPatient].SPatient as b
                      on a.scrssn = b.ScrSSN
                      where b.CDWPossibleTestPatientFlag = 'N'
                      	and b.VeteranFlag = 'Y' and fy = 2020;") %>%
  rename_all(tolower)
#-----
vssc_ssn <- vssc_crh_fy20 %>%
  select(patientssn) %>%
  distinct() %>% pull
#
cdw_ssn <- cdw_crh_fy20 %>%
  select(patientssn) %>%
  distinct %>% pull
#==
sum(cdw_ssn %in% vssc_ssn)
#59,971
# TESTING ScrSSN by VISN
scrssn_both <- vssc_crh_fy20 %>%
  select(patientssn, parent_visn) %>% distinct %>%
  inner_join(., cdw_crh_fy20 %>% select(patientssn, parent_visn2 = parent_visn) %>% distinct, by = c("patientssn" = "patientssn")) %>%
  mutate(match_flag = if_else(parent_visn == parent_visn2, TRUE, FALSE))
#
scrssn_both %>% group_by(parent_visn) %>% summarise(count = n())
#-
scrssn_cdw_not_vssc <- cdw_crh_fy20 %>%
  select(patientssn, parent_visn) %>% distinct %>%
  anti_join(., vssc_crh_fy20 %>% select(patientssn) %>% distinct, by = c("patientssn" = "patientssn"))
#
scrssn_cdw_not_vssc %>% group_by(parent_visn) %>%
  summarise(count = n())
#-
scrssn_vssc_not_cdw <- vssc_crh_fy20 %>%
  select(patientssn, parent_visn) %>% distinct %>%
  anti_join(., cdw_crh_fy20 %>% select(patientssn) %>% distinct, by = c("patientssn" = "patientssn"))
#
scrssn_vssc_not_cdw %>% group_by(parent_visn) %>% summarise(count = n())
#------
# TESTING Sta5a by VISN
vssc_sta5a <- vssc_crh_fy20 %>%
  select(sta5a = pat_sta6a, parent_visn) %>%
  distinct
#
cdw_sta5a <- cdw_crh_fy20 %>%
  select(sta5a = spoke_sta5a, parent_visn) %>%
  distinct
#
all_sta5a <- vssc_sta5a %>% bind_rows(., cdw_sta5a) %>%
  distinct
#-
sta5a_both <- vssc_sta5a %>%
  inner_join(., cdw_sta5a, by = c("sta5a" = "sta5a"))
#
sta5a_cdw_not_vssc <- cdw_sta5a %>%
  anti_join(., vssc_sta5a)
#
sta5a_vssc_not_cdw <- vssc_sta5a %>%
  anti_join(., cdw_sta5a)
#--==
crh_inner_join <- vssc_visn23_fy21 %>%
  select(patientssn, visitdatetime = visitdatetime1) %>%
  inner_join(., cdw_visn23_fy21, by = c("patientssn" = "patientssn", "visitdatetime" = "visitdatetime"))
#7,444
cdw_anti_join <- cdw_visn23_fy21 %>%
  anti_join(., vssc_visn23_fy21 %>% select(patientssn, visitdatetime = visitdatetime1), by = c("patientssn" = "patientssn", "visitdatetime" = "visitdatetime"))
#
vssc_anti_join <- vssc_visn23_fy21 %>%
  rename(visitdatetime = visitdatetime1) %>%
  anti_join(., cdw_visn23_fy21 %>% select(patientssn, visitdatetime), by = c("patientssn", "visitdatetime"))
