library(tidyverse)
library(here)
#==
render_report_fxn <- function(care_type){
  rmarkdown::render(
    here("Analysis", "National & VISN reports", "national_and_visn_report_template.Rmd"),
    params = list(
      care_type_param = care_type
    ),
    output_file = paste0(str_replace(tolower(care_type), " ", "_"), "_crh_encounters_national_visn.html")
  )
}
#----
render_report_fxn("Primary Care")
#
render_report_fxn("Pharmacy")
#
render_report_fxn("Mental Health")
#
render_report_fxn("PCMHI")