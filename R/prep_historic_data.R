source("R/calculate_cumulative_precip.R")

prep_historic_data <- function(weathercan) {
  calculate_cumulative_precip(weathercan) |>
    dplyr::select(-date) |>
    dplyr::mutate(month_day = paste0(month, "-", day)) |>
    dplyr::arrange(month, day) |>
    dplyr::select(-c(month, day)) |>
    tidyr::pivot_wider(names_from  = c("month_day"),
                       values_from = "cum_precip",
                       id_cols     = "year")
}


