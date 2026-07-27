library(weathercan)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(patchwork)

source("R/calculate_cumulative_precip.R")
source("R/prep_historic_data.R")

# Edmonton City Centre (CYXD), station 27214, daily records 1961–present
raw <- weather_dl(
  station_ids = 27214,
  start       = "1961-01-01",
  end         = format(Sys.Date(), "%Y-%m-%d"),
  interval    = "day",
  quiet       = FALSE
)

df <- raw |>
  select(date, total_precip) |>
  mutate(
    year  = as.integer(format(date, "%Y")),
    month = as.integer(format(date, "%m")),
    day   = as.integer(format(date, "%d")),
    total_precip = replace_na(total_precip, 0)
  )

current_year <- as.integer(format(Sys.Date(), "%Y"))

current <- df |>
  filter(year == current_year) |>
  mutate(
    cum_precip = cumsum(total_precip),
    date       = make_date(2000, month, day)
  ) |>
  select(doy = date, CTP = cum_precip)

envelopes <- prep_historic_data(df |> filter(year < current_year)) |>
  pivot_longer(2:last_col(), names_to = "month_day", values_to = "cum_precip") |>
  group_by(doy = month_day) |>
  summarise(
    p5     = quantile(cum_precip, 0.05, na.rm = TRUE),
    p10    = quantile(cum_precip, 0.10, na.rm = TRUE),
    p25    = quantile(cum_precip, 0.25, na.rm = TRUE),
    p50    = quantile(cum_precip, 0.50, na.rm = TRUE),
    p75    = quantile(cum_precip, 0.75, na.rm = TRUE),
    p90    = quantile(cum_precip, 0.90, na.rm = TRUE),
    p95    = quantile(cum_precip, 0.95, na.rm = TRUE)
  ) |>
  mutate(doy = as_date(paste0("00-", doy)))

daily_bars <- df |>
  filter(year == current_year) |>
  mutate(doy = make_date(2000, month, day))

x_scale  <- scale_x_date(date_labels = "%b", date_breaks = "1 month",
                         limits = c(make_date(2000, 1, 1), make_date(2001, 1, 20)))

label_data <- envelopes |>
  filter(doy == max(doy)) |>
  tidyr::pivot_longer(c(p5, p10, p25, p50, p75, p90, p95), names_to = "pct", values_to = "y") |>
  mutate(label = recode(pct, p5 = "5", p10 = "10", p25 = "25", p50 = "50",
                             p75 = "75", p90 = "90", p95 = "95"))

p_cumul <- ggplot(envelopes, aes(x = doy)) +
  geom_ribbon(aes(ymin = p5,  ymax = p95), fill = "steelblue", alpha = 0.15) +
  geom_ribbon(aes(ymin = p10, ymax = p90), fill = "steelblue", alpha = 0.15) +
  geom_ribbon(aes(ymin = p25, ymax = p75), fill = "steelblue", alpha = 0.20) +
  geom_line(aes(y = p5),  colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_line(aes(y = p10), colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_line(aes(y = p25), colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_line(aes(y = p50), colour = "steelblue", linewidth = 0.7, linetype = "dashed") +
  geom_line(aes(y = p75), colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_line(aes(y = p90), colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_line(aes(y = p95), colour = "steelblue", linewidth = 0.4, linetype = "dotted") +
  geom_text(data = label_data, aes(x = doy, y = y, label = label),
            hjust = 0, nudge_x = 1, size = 3, colour = "steelblue") +
  geom_line(data = current, aes(x = doy, y = CTP), colour = "firebrick", linewidth = 0.6) +
  geom_text(data = current |> filter(doy == max(doy)),
            aes(x = doy, y = CTP, label = as.character(current_year)),
            hjust = 0, nudge_x = 1, size = 3, colour = "firebrick") +
  scale_x_date(date_labels = "%b", date_breaks = "1 month",
               limits = c(make_date(2000, 1, 1), make_date(2001, 1, 20))) +
  labs(
    x     = NULL,
    y     = "Cumulative precipitation (mm)",
    title = paste0("Cumulative Precipitation: Historical Percentiles (1961 - Present)"),
    subtitle = "Edmonton, AB"
  ) +
  theme_classic() +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

p_bars <- ggplot(daily_bars, aes(x = doy, y = total_precip)) +
  geom_col(fill = "blue4", alpha = 0.7) +
  x_scale +
  labs(x = NULL, y = "2026 Daily (mm)") +
  theme_classic()

p_cumul / p_bars + plot_layout(heights = c(3, 1))
