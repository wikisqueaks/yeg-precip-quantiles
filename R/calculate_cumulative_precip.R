
calculate_cumulative_precip <- function(weathercan_df) {
  weathercan_df |>
    select(date, year, month, day, total_precip) |> 
    mutate(cum_precip = cumsum(replace_na(total_precip,0)),
           .by = "year")
}
