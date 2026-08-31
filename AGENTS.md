# precip-quantiles

Project that plots Edmonton (CYXD, station 27214) year-to-date cumulative
precipitation against historical percentile envelopes (1961–present).

## Data

- `data/raw/EDM1867.rds` — raw `weathercan` daily data, station 1867 (older/longer record; unused by current pipeline).
- `data/raw/edm27214.rds` — raw `weathercan` daily data, station 27214 (Edmonton City Centre), used as cached fallback for `weather_dl()`.
- Live data is pulled via `weathercan::weather_dl(station_ids = 27214, interval = "day")` in `R/render_plot.R`, covering 1961-01-01 through today.

## Pipeline (`R/render_plot.R`)

1. Download/load daily data for station 27214 (`total_precip`, `NA` → 0).
2. `R/calculate_cumulative_precip.R`: adds `cum_precip`, a within-year cumulative sum of `total_precip`.
3. `R/prep_historic_data.R`: reshapes historical (pre-current-year) data wide by `month-day`, one row per year.
4. Historical data is pivoted back to long form and summarized by day-of-year into percentiles (p5, p10, p25, p50, p75, p90, p95) → `envelopes`.
5. Current year's cumulative precipitation series → `current`.
6. Plot: `p_cumul` (ribbons/lines for percentile envelope + current year cumulative line, via ggplot2/patchwork) stacked above `p_bars` (current year daily precip bars).
7. Saved to working directory as `YEG_<year>_CUMUL_PRECIP_YTD_<YYYYMMDD>.png` (735x538px, dpi 96).

Note: `outputs/` directory exists but is currently empty — plots are saved to the project root, not `outputs/`.

## Key packages

`weathercan`, `dplyr`, `tidyr`, `lubridate`, `ggplot2`, `patchwork`.
