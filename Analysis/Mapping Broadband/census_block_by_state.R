library(tigris)
library(tidyverse)
library(DBI)
#
#connect to rb03
rb03_con = DBI::dbConnect(odbc::odbc(),
                          Driver = "SQL Server",
                          Server = "vhacdwrb03.vha.med.va.gov",
                          Database = "VINCI_GIS_DATA",
                          Trusted_Connection = "true")
#
tigris_cache_dir("U:\\Users\\VHAIOWHaralB\\Desktop\\maps")
readRenviron('~/.Renviron')
#---
map_fxn = function(statef){
  statefc = str_to_upper(statef)
  #
  blocks_map = blocks(statef)
  #
  unserved_blocks = dbGetQuery(rb03_con,
                               str_remove_all(paste0("select *
                                    from [OABI_MyVAAccess_TEXT].fcc_data.bband_summary_2024_06
                                    where (n_25_3_2024_06 = 0 OR n_25_3_2024_06 IS NULL)
                                    	AND state_usps = '", statefc, "'"), c("\n|\t")))
  #
  underserved_blocks = dbGetQuery(rb03_con,
                                  str_remove_all(paste0("select *
                                    from [OABI_MyVAAccess_TEXT].fcc_data.bband_summary_2024_06
                                    where (n_100_20_2024_06 = 0 OR n_100_20_2024_06 IS NULL)
                                    	AND state_usps = '", statefc, "'"), c("\n|\t")))
  #---
  map = blocks_map %>%
    rename(block_geoid = GEOID20) %>%
    mutate(`Broadband Access` = factor(
      case_when(block_geoid %in% unserved_blocks$block_geoid ~ "Unserved",
                block_geoid %in% underserved_blocks$block_geoid ~ "Underserved",
                TRUE ~ NA))) %>%
    ggplot(data = .,
           aes(fill = `Broadband Access`, geometry = geometry),
           color = alpha("grey", 0.2),
           linewidth = 0) +
    geom_sf() +
    scale_fill_manual(breaks = c("Unserved", "Underserved"),
                      values = c("red", "orange"),
                      na.value = "lightgreen",
                      limits = c("Unserved", "Underserved")) +
    theme(axis.text = element_blank(),
          legend.title = element_blank(),
          axis.ticks = element_blank(),
          plot.background = element_blank(),
          panel.grid = element_blank(),
          plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm"),
          legend.text = element_text(size = 24))
  #=======
  ggsave(paste0("U:\\Users\\VHAIOWHaralB\\Desktop\\maps\\", statef, "_map.png"),
         plot = map,
         height = 12, width = 12,
         dpi = "retina")
}
#
map_fxn("ia")
map_fxn("mn")
map_fxn("wi")
map_fxn("co")
map_fxn("wy")
map_fxn("wa")
map_fxn("or")
map_fxn("al")
map_fxn("va")
map_fxn("wv")

