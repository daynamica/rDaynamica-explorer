# rDaynamica Explorer

An interactive web app for exploring the anonymized Daynamica example dataset without writing any R code. It is built with [Shiny](https://shiny.posit.co/) on top of the [rDaynamica](https://github.com/daynamica/rDaynamica) package.

## What's in the app

A sidebar setting (minimum hours of recorded data per day) controls which days are included in every tab.

| Tab | What it shows | rDaynamica functions used |
|---|---|---|
| Overview | Dataset size, how many days meet each completeness threshold, per-day statistics | `filter_valid_days()`, `count_valid_per_days()`, `overview_statistics()` |
| Daily timelines | One participant's days, midnight to midnight, with hover details | rDaynamica's color scheme (`color_discrete_maps`); drawn by `R/timeline.R` |
| Activities & trips | Average counts, time, and distance per day by activity type, travel mode, or trip purpose | `activity_trip_figure()`, `activity_trip()` |
| Daily rhythm | Animated chord diagram of transitions between activities and trips across the day | `recategorize_calendar_items()`, `generate_sequence_data()`, `flow_rate_calculator()`, `process_flow_data()` |
| Activity chains | Most common daily sequences (e.g. HWH) and a Sankey diagram of how days branch out from home | `create_activity_chains()`, `create_sankey_data()`, `create_plot_from_data()` |

## Running locally

Install the package and app dependencies, then run the app from this folder:

```r
install.packages("pak")
pak::pak(c("daynamica/rDaynamica", "shiny", "bslib", "DT"))
shiny::runApp()
```

## Project layout

- `app.R`: the user interface and server logic
- `R/chord.R`: helpers that draw one chord-diagram frame (loaded automatically by Shiny)
- `R/timeline.R`: the daily timeline, drawn as hoverable bars (`rDaynamica::plot_indi_temp()` only shows hover details at the ends of each item)
- `www/logo.png`: the Daynamica logo, used in the header and as the browser tab icon
- `data/example_data.rds`: the preprocessed example dataset
- `scripts/prepare_data.R`: rebuilds `data/example_data.rds` from the data bundled with rDaynamica
- `manifest.json`: package versions for Posit Connect

## Updating the data

The app loads preprocessed data so it starts quickly. If rDaynamica's preprocessing changes, rebuild it from this folder:

```r
source("scripts/prepare_data.R")
```

## Deploying to Posit Connect

Posit Connect deploys this app directly from GitHub using `manifest.json`. After changing the app or updating rDaynamica on GitHub, regenerate the manifest and commit it:

```r
pak::pak(c("daynamica/rDaynamica", "rsconnect"))
rsconnect::writeManifest(appFiles = c("app.R", "R/chord.R", "R/timeline.R", "data/example_data.rds", "www/logo.png"))
```

rDaynamica must be installed from GitHub (as above) when you write the manifest, so Connect knows where to get it.
