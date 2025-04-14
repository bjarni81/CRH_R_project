#read_fxn for reading .csv files from vssc
read_fxn = function(search_str, col_name){
  file_loc = list.files(here("Input", "PC Engagement", "Data"),
                        pattern = {{search_str}},
                        full.names = TRUE)
  #
  start_df = if (search_str == "3rd"){
    read_csv(file_loc) %>%
      rename(full_name = 1,
             fy = 2,
             var_name = 3) 
  }
  else {
    read_csv(file_loc) %>%
      rename(full_name = 2,
             fy = 1,
             var_name = 3) 
  }
  #
  start_df %>%
    mutate(pos11 = str_sub(full_name, start = 11, end = 11),
           sta5a = if_else(pos11 == ")",
                           str_sub(full_name, start = 8, end = 10),
                           str_sub(full_name, start = 8, end = 12)),
           month_c = str_to_title(str_sub(fy, end = 3)),
           month_n = match(month_c, month.abb),
           fy_n = as.numeric(str_c("20", str_sub(fy, start = 7))),
           cy_n = if_else(month_n > 9, fy_n - 1, fy_n),
           vssc_month = ymd(str_c(cy_n, month_n, "01", sep = "-"))) %>%
    select(sta5a, vssc_month, {{col_name}} := var_name)
}