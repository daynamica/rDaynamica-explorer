# Daynamica Data Explorer

An interactive web app for seeing what Daynamica data looks like and how it works, using the anonymized example dataset and without writing any R code. It is built with [Shiny](https://shiny.posit.co/) on top of the [rDaynamica](https://github.com/Daynamica-Repositories/rDaynamica) package.

## What's in the app

A sidebar setting (minimum hours of recorded data per day) controls which days are included in every tab.

| Tab | What it shows | rDaynamica functions used |
|---|---|---|
| Overview | Dataset size, how many days meet each completeness threshold, per-day statistics | `filter_valid_days()`, `count_valid_per_days()`, `overview_statistics()` |
| Daily timelines | One participant's days, midnight to midnight, with hover details | rDaynamica's color scheme (`color_discrete_maps`); drawn by `R/timeline.R` |
| Activities & trips | Average counts, time, and distance per day by activity type, travel mode, or trip purpose | `activity_trip_figure()`, `activity_trip()` |
| Daily rhythm | Animated chord diagram of transitions between activities and trips across the day | `recategorize_calendar_items()`, `generate_sequence_data()`, `flow_rate_calculator()`, `process_flow_data()` |
| Activity chains | Most common daily sequences (e.g. HWH) and a Sankey diagram of how days branch out from home | `create_activity_chains()`, `create_sankey_data()`, `create_plot_from_data()` |
| Surveys | Survey response rates and timing; answers to each activity and trip question compared by activity type, travel mode, trip purpose, or day; end-of-day answers next to each day's recorded behavior | `tidy_calendar_item_survey()`, `tidy_ema_survey()`, `survey_codebook()`, `link_survey_to_items()`, `summarize_survey_by()`, `survey_response_rates()` |
| Use it in R | Setup code that installs rDaynamica and prepares the example data | `path2dict()` and the preprocessing functions |

Every table and figure has a "Show the R code" panel with rDaynamica code that reproduces it using the app's current settings.

## Running locally

Install the package and app dependencies, then run the app from this folder:

```r
install.packages("pak")
pak::pak(c("Daynamica-Repositories/rDaynamica", "shiny", "bslib", "DT"))
shiny::runApp()
```

## Project layout

- `app.R`: the user interface and server logic
- `R/chord.R`: helpers that draw one chord-diagram frame (loaded automatically by Shiny)
- `R/code.R`: the R code shown in the "Show the R code" panels and on the "Use it in R" tab
- `R/surveys.R`: charts and tables for the Surveys tab
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
pak::pak(c("Daynamica-Repositories/rDaynamica", "rsconnect"))
rsconnect::writeManifest(appFiles = c("app.R", "R/chord.R", "R/code.R", "R/surveys.R", "R/timeline.R", "data/example_data.rds", "www/logo.png"))
```

rDaynamica must be installed from GitHub (as above) when you write the manifest, so Connect knows where to get it.
