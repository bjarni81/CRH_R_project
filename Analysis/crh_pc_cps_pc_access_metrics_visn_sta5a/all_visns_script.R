library(tidyverse)
library(here)
#==
render_report_fxn <- function(visn_num){
  visn_char <- as.character(visn_num)
  #
  rmarkdown::render(
    here("Analysis","crh_pc_cps_pc_access_metrics_visn_sta5a", "crh_pc_cps_pc_access_metrics_template.Rmd"),
    params = list(
      visn_char_param = visn_char,
      visn_num_param = visn_num
    ),
    output_file = paste0("crh_pc_cps_pc_access_metrics_visn_", visn_char, ".html")
  )
}
#----
render_report_fxn(2)
#
visns <- read_csv(here("Input", "Data","VAST_from_A06_11jan21.csv")) %>%
  select(parent_visn) %>%
  filter(is.na(parent_visn) == F) %>%
  distinct %>% pull
#--
for (i in 1:length(visns)){
  current_visn <- visns[i]
  render_report_fxn(current_visn)
}

