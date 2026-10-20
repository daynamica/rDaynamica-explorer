# R code shown in the app's "Show the R code" panels.
#
# Each snippet reproduces an output with rDaynamica, using the app's current
# settings. Snippets assume the setup code (setup_code) has been run first.

setup_code <- paste(
  '# Install rDaynamica (once)',
  'install.packages("pak")',
  'pak::pak("daynamica/rDaynamica")',
  '',
  'library(rDaynamica)',
  '',
  '# Load the example data that ships with the package',
  'data_path <- system.file("extdata", "anonymized_data", package = "rDaynamica")',
  'csv_dict <- path2dict(folder_path = data_path, file_prefix = "anonymized_")',
  '',
  '# Clean the data and remove test accounts',
  'csv_dict <- ucal_items_version_updater(csv_dict)',
  'csv_dict <- exclude_user(csv_dict, c("test", "user_id_382", "user_id_422", "0"))',
  'csv_dict$ucalitems$cal_item_id <- as.integer(csv_dict$ucalitems$cal_item_id)',
  'csv_dict[["ucalitems"]] <- assign_trip_purpose(csv_dict[["ucalitems"]])',
  '',
  '# Attach survey responses to the activities and trips they describe',
  'csv_dict[["ucalitems_survey"]] <- survey_join_id(csv_dict[["calendar_item_survey"]], csv_dict[["ucalitems"]])',
  'csv_dict[["ucalitems_ljoin_ucisurvey"]] <- ucalitems_ljoin_ucisurvey(csv_dict[["ucalitems_survey"]], csv_dict[["ucalitems"]])',
  '',
  '# Split items that cross midnight, then summarize each participant-day',
  'csv_dict[["ucalitems_ljoin_ucisurvey_split"]] <- split_ucalitems(',
  '  csv_dict[["ucalitems_ljoin_ucisurvey"]],',
  '  local_timezone = "US/Central",',
  '  day_start_hour = 0',
  ')',
  'csv_dict[["day_summary"]] <- get_per_day_duration(csv_dict[["ucalitems_ljoin_ucisurvey_split"]])',
  sep = "\n"
)

code_header <- '# Run the setup code from the "Use it in R" tab first'

filter_code <- function(min_hours) {
  c("# Keep days with enough recorded data (the sidebar setting)",
    sprintf('csv_dict_sub <- filter_valid_days(csv_dict, query_text = "(interact_with_app>0)&(with_subtype>=%d)")', min_hours))
}

snippet <- function(...) paste(c(code_header, ...), collapse = "\n")

code_valid_days <- function() {
  snippet("", "# Uses all days, so no filtering step is needed",
          "count_valid_per_days(csv_dict$day_summary)")
}

code_overview <- function(min_hours) {
  snippet(filter_code(min_hours), "",
          "overview_statistics(csv_dict_sub)")
}

code_timeline <- function(min_hours, user) {
  snippet(filter_code(min_hours), "",
          "# The app draws an enhanced, hoverable version of this plot (R/timeline.R in the app's repository)",
          sprintf('plot_indi_temp(csv_dict_sub$ucalitems_temporal_plot, UserId = "%s")', user))
}

code_summary <- function(min_hours, type, group, measure) {
  snippet(filter_code(min_hours), "",
          "# Chart",
          "activity_trip_figure(",
          "  ucalitems = csv_dict_sub$ucalitems_temporal_plot,",
          '  tb = "ucalitems_temporal_plot",',
          "  day_summary = csv_dict_sub$day_summary,",
          sprintf('  mytype = "%s",', type),
          sprintf('  by_field = "%s",', group),
          sprintf('  agg_col = "%s"', measure),
          ")",
          "",
          "# Table",
          "activity_trip(",
          "  ucalitems = csv_dict_sub$ucalitems_temporal_plot,",
          "  day_summary = csv_dict_sub$day_summary,",
          sprintf('  mytype = "%s",', type),
          sprintf('  by_field = "%s"', group),
          ")")
}

code_chord <- function(min_hours) {
  mapping <- sprintf('  "%s" = "%s"', names(chord_categories), unname(chord_categories))
  snippet(filter_code(min_hours), "",
          "# Group detailed categories so the diagram stays readable",
          "groups <- c(",
          paste0(mapping, c(rep(",", length(mapping) - 1), "")),
          ")",
          "csv_dict_grouped <- recategorize_calendar_items(",
          "  csv_dict_sub, orig_cats = names(groups), new_cats = unname(groups)",
          ")",
          "",
          "# Draw a frame every 30 minutes and combine them into an animated GIF",
          "# (saved to outputs/plot-gif/; the app draws one frame at a time instead)",
          'generate_chord_diagram_gif(csv_dict_grouped, output_dir = "outputs/plot-gif")')
}

code_chains <- function(min_hours, include_trips, min_duration, collapse, sankey_min) {
  snippet(filter_code(min_hours), "",
          "chains <- create_activity_chains(",
          "  csv_dict_sub$ucalitems_temporal_plot,",
          sprintf("  include_trips = %s,", include_trips),
          sprintf("  minimum_duration_min = %d,", as.integer(min_duration)),
          sprintf("  collapse_identical_labels = %s", collapse),
          ")",
          "",
          "# Most common chains",
          "dplyr::count(chains, string, sort = TRUE)",
          "",
          "# How days branch out from home",
          sprintf("sankey_data <- create_sankey_data(chains, lower_limit = %s)", format(sankey_min)),
          "create_plot_from_data(sankey_data, start_from_H = TRUE)")
}

# Collapsible code panel with a copy button
show_code <- function(output_id) {
  tags$details(
    class = "code-panel",
    tags$summary("Show the R code"),
    div(class = "code-block",
        tags$button(type = "button", class = "btn btn-sm btn-outline-secondary copy-code", "Copy"),
        verbatimTextOutput(output_id, placeholder = FALSE))
  )
}
