# Prepares the example dataset used by the app.
#
# Runs the slow rDaynamica preprocessing steps once (import, cleaning, survey
# join, multi-day splitting, per-day summaries) and saves the result, so the
# app only has to load a file at startup. Re-run this script from the project
# root whenever the package's preprocessing changes:
#
#   Rscript scripts/prepare_data.R

library(rDaynamica)
library(data.table)

data_path <- system.file("extdata", "anonymized_data", package = "rDaynamica")
csv_dict <- path2dict(folder_path = data_path, file_prefix = "anonymized_")

csv_dict <- ucal_items_version_updater(csv_dict)
csv_dict <- exclude_user(csv_dict, c("test", "user_id_382", "user_id_422", "0"))
csv_dict$ucalitems$cal_item_id <- as.integer(csv_dict$ucalitems$cal_item_id)
csv_dict[["ucalitems"]] <- assign_trip_purpose(csv_dict[["ucalitems"]])

csv_dict[["ucalitems_survey"]] <- survey_join_id(csv_dict[["calendar_item_survey"]], csv_dict[["ucalitems"]])
csv_dict[["ucalitems_ljoin_ucisurvey"]] <- ucalitems_ljoin_ucisurvey(csv_dict[["ucalitems_survey"]], csv_dict[["ucalitems"]])

csv_dict[["ucalitems_ljoin_ucisurvey_split"]] <- split_ucalitems(
  csv_dict[["ucalitems_ljoin_ucisurvey"]],
  local_timezone = "US/Central",
  day_start_hour = 0,
  min_time_stamp = 0
)
csv_dict[["day_summary"]] <- get_per_day_duration(csv_dict[["ucalitems_ljoin_ucisurvey_split"]])

# Keep only the tables filter_valid_days() and the app need
keep <- c("day_summary", "ucalitems_ljoin_ucisurvey_split", "ema_survey", "calendar_item_survey")
example_data <- csv_dict[keep]

dir.create("data", showWarnings = FALSE)
saveRDS(example_data, "data/example_data.rds", compress = "xz")
cli::cli_alert_success("Saved data/example_data.rds ({format(file.size('data/example_data.rds'), big.mark = ',')} bytes)")
