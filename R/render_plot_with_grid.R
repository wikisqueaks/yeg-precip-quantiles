library(weathercan)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(patchwork)
library(purrr)
library(RColorBrewer)

source("R/calculate_cumulative_precip.R")
source("R/prep_historic_data.R")

# Station 27214 (Edmonton Blatchford), daily records 1961–present
raw <- weather_dl(
  station_ids = 27214,
  start       = "1961-01-01",
  end         = format(Sys.Date(), "%Y-%m-%d"),
  interval    = "day"
)

df <- raw |>
  select(date, total_precip) |>
  mutate(
    year = as.integer(format(date, "%Y")),
    month = as.integer(format(date, "%m")),
    day = as.integer(format(date, "%d")),
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

x_scale <- scale_x_date(
  date_labels = "%b", date_breaks = "1 month",
  limits = c(make_date(2000, 1, 1), make_date(2001, 1, 1))
)

# Non-overlapping bands between adjacent percentiles, driest (bottom) to wettest (top)
band_defs <- tibble::tribble(
  ~band,        ~lower, ~upper,
  "5th-10th",   "p5",   "p10",
  "10th-25th",  "p10",  "p25",
  "25th-50th",  "p25",  "p50",
  "50th-75th",  "p50",  "p75",
  "75th-90th",  "p75",  "p90",
  "90th-95th",  "p90",  "p95"
)

bands <- purrr::pmap_dfr(band_defs, function(band, lower, upper) {
  envelopes |>
    transmute(doy, band = band, ymin = .data[[lower]], ymax = .data[[upper]])
}) |>
  mutate(band = factor(band, levels = rev(band_defs$band)))

# Diverging dry (brown/orange) -> wet (blue) palette, one colour per band
band_colours <- brewer.pal(6, name = "RdYlBu")
names(band_colours) <- c(
  "5th-10th", "10th-25th", "25th-50th",
  "50th-75th", "75th-90th", "90th-95th"
)


current_label <- as.character(current_year)
line_colours <- c("Median (50th)" = "grey30")
current_yr_col <- "black"

# Generate grid dates (every 1 day for x-axis) and grid values (every 10mm for y-axis)
grid_dates <- seq.Date(make_date(2000, 1, 1), make_date(2001, 1, 1), by = "1 day")
grid_precips <- seq(0, 800, by = 10)

p_cumul <- ggplot() +
  geom_vline(xintercept = grid_dates, colour = "grey80", linewidth = 0.1, alpha = 0.5) +
  geom_segment(aes(x = make_date(2000, 1, 1), xend = make_date(2001, 1, 1), y = grid_precips, yend = grid_precips),
               colour = "grey80", linewidth = 0.1, alpha = 0.5, data = tibble::tibble(grid_precips = grid_precips)) +
  geom_ribbon(data = bands, aes(x = doy, ymin = ymin, ymax = ymax, fill = band), alpha = 0.5) +
  scale_fill_manual(name = "Historic\nPercentile", values = band_colours) +
  geom_line(
    data = envelopes, aes(x = doy, y = p50, colour = "Median (50th)"),
    linewidth = 0.7, linetype = "dotted"
  ) +
  geom_line(
    data = current, aes(x = doy, y = CTP),
    colour = current_yr_col, linewidth = 0.5, linetype = "solid"
  ) +
  geom_text(
    data = current |> filter(doy == max(doy)),
    aes(x = doy - 15, y = CTP + 14, label = current_label),
    hjust = 0, nudge_x = 1, size = 3, colour = current_yr_col
  ) +
  scale_colour_manual(name = NULL, values = line_colours) +
  scale_x_date(
    date_labels = "%b", date_breaks = "1 month",
    limits = c(make_date(2000, 1, 1), make_date(2001, 1, 1))
  ) +
  labs(
    x = NULL,
    y = "Cumulative precipitation (mm)",
    title = paste0("Cumulative Precipitation: Historical Percentiles (1961 - Present)"),
    subtitle = "Edmonton, AB"
  ) +
  theme_classic() +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), legend.position = "right", legend.justification = c(1, 0.35))

p_bars <- ggplot(daily_bars, aes(x = doy, y = total_precip)) +
  geom_col(fill = "blue4", alpha = 0.7) +
  x_scale +
  labs(x = NULL, y = "2026 Daily (mm)") +
  theme_classic()

p <- p_cumul / p_bars + plot_layout(heights = c(3, 1))


ggsave(paste0("outputs/YEG_2026_CUMUL_PRECIP_YTD_GRID_", format(Sys.Date(), "%Y%m%d"), ".png"), p, width = 2880, height = 2160, units = "px", dpi = 400)
