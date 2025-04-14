library(tidyverse)
library(here)
library(jsonlite)
library(httr)
library(DBI)
#--
headers = c(
  `apikey` = 'IXCQi6rtiZFA4tMhDOWpHqJf6oeA1Cg1'
)
#==
render_sta5a_report_fxn <- function(sta5a){
  #
  sta5a_for_pull <- sta5a
  url_for_pull = paste0("https://sandbox-api.va.gov/services/va_facilities/v0/facilities/vha_", sta5a_for_pull)
  #--
  apiResults <- fromJSON(content(GET(url = url_for_pull,
                                     add_headers(.headers=headers)), 
                                 "text"),
                         flatten = TRUE)
  visn_of_sta5a <- str_pad(apiResults$data$attributes$visn, width = 2, side = "left", pad = "0")
  #-----
  rmarkdown::render(
    here("Analysis", "example_sta5as", "example_sta5a_pc_crh_report_template.Rmd"),
    params = list(
      sta5a_param = sta5a
    ),
    output_dir = here("Analysis","example_sta5as","Reports"),
    output_file = paste0("V", visn_of_sta5a, "_", sta5a, "_pc_crh_report.html")
  )
}
#======================================================================•
rural_prop <- dbGetQuery(oabi_con,
                         "select urh.sta5a, urh.urh_rural_count, urh.scrssn_count
                              
                    	, crh_flag = case
                    		when c1.crh_10_flag = 1 then 1
                    		else 0 end
                      from [crh_eval].D2_race_gender_urh_count as urh
                      inner join [OABI_MyVAAccess].[crh_eval].C1_crh_flag as c1
	                    on urh.sta5a = c1.sta5a
                              where urh.fy = 2020 AND urh.qtr = 1") %>%
  mutate(prop_rural = urh_rural_count / scrssn_count) %>%
  filter(crh_flag == 1) %>%
  left_join(., penRate %>% group_by(sta5a) %>% summarise(total_pc_crh = sum(crh_encounter_count, na.rm = T)))
#-------------------------------------
small_clinics_3_4ths_rural <- rural_prop %>%
  filter(scrssn_count < 4500 
         & prop_rural > 0.75
         & total_pc_crh > 1000) %>%
  select(sta5a) %>%
  pull
####
for (i in 1:length(small_clinics_3_4ths_rural)){
  render_sta5a_report_fxn(small_clinics_3_4ths_rural[i])
}
