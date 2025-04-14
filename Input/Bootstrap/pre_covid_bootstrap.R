# Prediction Function
lmer_fxn <- function(data, outcome, indices, ...){
  d <- data[indices,]
  #
  lmer_formula <- as.formula(paste0({{outcome}}, 
                                    " ~ treat * post * time2 + panel_ratio_x_10 + pct_male + pct_rural + nosos_x_10 + adi_div_10 + (1|sta5a)"))
  #
  fit <- lmer(lmer_formula,
              data = d,
              REML = TRUE)
  #
  ctrl_pre_slope <- summary(fit)$coefficients[4,1]
  trtd_pre_slope <- summary(fit)$coefficients[4,1] + summary(fit)$coefficients[11,1]
  #
  ctrl_post_slope <- summary(fit)$coefficients[4,1] + summary(fit)$coefficients[12,1]
  trtd_post_slope <- summary(fit)$coefficients[4,1] + summary(fit)$coefficients[12,1] + summary(fit)$coefficients[13,1]
  #
  ctrl_jump <- summary(fit)$coefficients[3,1]
  trtd_jump <- summary(fit)$coefficients[3,1] + summary(fit)$coefficients[10,1]
  #--
  b_time <- summary(fit)$coefficients[4,1]
  b_treat_x_time <- summary(fit)$coefficients[11,1]
  b_post_x_time <- summary(fit)$coefficients[12,1]
  b_post_x_time_x_treat <- summary(fit)$coefficients[13,1]
  b_post <- summary(fit)$coefficients[3,1]
  b_treat_x_post <- summary(fit)$coefficients[10,1]
  b_treat <- summary(fit)$coefficients[2,1]
  #--
  return(c(ctrl_pre_slope, trtd_pre_slope, ctrl_post_slope, trtd_post_slope, ctrl_jump, trtd_jump,
           b_time, b_treat_x_time, b_post_x_time, b_post_x_time_x_treat, b_post, b_treat_x_post, b_treat))
}
#
lmer_fxn(outcome = "new_pc_pt_wt", data = analytic_df)
#-=================
#boot function
boot_fxn <- function(outcome, R_var, ...){
  #--
  boot::boot(analytic_df, lmer_fxn,
             R = R_var,
             outcome = outcome
             ,parallel = "snow",
             ncpus = 8,
             cl = cl_make
  )$t %>%
    as.data.frame() %>%
    rename(ctrl_pre_slope = V1,
           trtd_pre_slope = V2,
           ctrl_post_slope = V3,
           trtd_post_slope = V4,
           ctrl_jump = V5,
           trtd_jump = V6,
           b_time = V7, 
           b_treat_x_time = V8, 
           b_post_x_time = V9, 
           b_post_x_time_x_treat = V10, 
           b_post = V11, 
           b_treat_x_post = V12,
           b_treat = V13)
}
##--=================================
#cluster connection
cl_make <- parallel::makeCluster(8)
parallel::clusterExport(cl_make, "lmer_fxn")
#load libraries
parallel::clusterCall(cl_make, function() {library(modelr); library(tidyverse); library(lme4)})
#
set.seed(1234)
tictoc::tic()
new_pt_boot <- boot_fxn(outcome = "new_pc_pt_wt",
                        R_var = 5000)
est_pt_boot <- boot_fxn(outcome = "est_pc_pt_wt_pid",
                        R_var = 5000)
tna_boot <- boot_fxn(outcome = "third_next_avail",
                     R_var = 5000)
tictoc::toc()#4 minutes, 35 seconds
parallel::stopCluster(cl_make)
write_csv(new_pt_boot,
          here("Input", "Bootstrap", "new_pc_pt_wt_boot.csv"))
write_csv(est_pt_boot,
          here("Input", "Bootstrap", "est_pc_pt_wt_boot.csv"))
write_csv(tna_boot,
          here("Input", "Bootstrap", "third_next_avail_boot.csv"))
