# Helpers for the Surveys tab.

day_order <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

survey_group_choices <- list(
  ACTIVITY = c("Activity type" = "subtype_decoded", "Weekday or weekend" = "IsWeekend", "Day of week" = "dow"),
  TRIP = c("Main travel mode" = "trip_mode", "Trip purpose" = "trip_purpose", "Weekday or weekend" = "IsWeekend")
)

# The item type (ACTIVITY or TRIP) each calendar item question was asked about
survey_question_types <- function(linked) {
  linked[, .N, by = .(question_id, type_decoded)][order(question_id, -N)][, .SD[1], by = question_id][
    type_decoded %in% c("ACTIVITY", "TRIP")]
}

# Grouped choices for the question picker: "Activity questions" and "Trip questions"
survey_question_choices <- function(codebook, question_types) {
  questions <- unique(codebook[, .(question_id, question_text)])
  questions <- merge(questions, question_types, by = "question_id")
  label <- function(d) stats::setNames(d$question_id, sprintf("Q%d: %s", d$question_id, d$question_text))
  list(
    "Activity questions" = label(questions[type_decoded == "ACTIVITY"]),
    "Trip questions" = label(questions[type_decoded == "TRIP"])
  )
}

ema_question_choices <- function(codebook) {
  questions <- unique(codebook[, .(question_id, question_text)])
  stats::setNames(questions$question_id, sprintf("Q%d: %s", questions$question_id, questions$question_text))
}

is_rating_question <- function(codebook, q) {
  rows <- codebook[question_id == q]
  nrow(rows) > 0 && all(rows$question_type == "single") && !anyNA(suppressWarnings(as.numeric(rows$option)))
}

order_groups <- function(groups, by) {
  if (by == "dow") factor(groups, levels = day_order) else groups
}

survey_bar_plot <- function(means, by, group_label) {
  means <- data.table::copy(means)
  means[, group := if (by == "dow") factor(get(by), levels = rev(day_order)) else
    stats::reorder(pretty_label(get(by)), mean)]
  plotly::plot_ly(
    means, x = ~mean, y = ~group, type = "bar", orientation = "h",
    marker = list(color = "#538037"),
    text = ~sprintf("%.2f (n = %d)", mean, responses), textposition = "outside", cliponaxis = FALSE,
    hovertemplate = "<b>%{y}</b><br>Average: %{x:.2f}<extra></extra>"
  ) |>
    plotly::layout(
      xaxis = list(title = "Average answer", range = c(0, max(means$mean) * 1.25), fixedrange = TRUE),
      yaxis = list(title = group_label, fixedrange = TRUE, automargin = TRUE, ticksuffix = "  "),
      margin = list(l = 10, r = 30),
      font = list(family = "Inter, sans-serif")
    ) |>
    plotly::config(displaylogo = FALSE)
}

survey_heatmap <- function(shares, by, group_label, option_order) {
  shares <- data.table::copy(shares)
  groups <- unique(shares[, c(by, "responses"), with = FALSE])
  groups[, label := sprintf("%s (n = %d)", pretty_label(get(by)), responses)]
  if (by == "dow") groups <- groups[order(factor(get(by), levels = day_order))]
  shares <- merge(shares, groups[, c(by, "label"), with = FALSE], by = by)

  grid <- data.table::CJ(option = option_order, label = groups$label)
  grid <- merge(grid, shares[, .(option, label, share)], by = c("option", "label"), all.x = TRUE)
  grid[is.na(share), share := 0]
  z <- matrix(grid[order(match(option, option_order), match(label, groups$label)), share],
              nrow = length(option_order), byrow = TRUE)

  plotly::plot_ly(
    x = groups$label, y = option_order, z = z, type = "heatmap",
    colorscale = list(c(0, "#f6f9f3"), c(1, "#538037")), zmin = 0, zmax = 1,
    text = matrix(sprintf("%.0f%%", 100 * z), nrow = nrow(z)), texttemplate = "%{text}",
    hovertemplate = "<b>%{y}</b><br>%{x}<br>%{z:.1%} of responses<extra></extra>",
    colorbar = list(title = "Share", tickformat = ".0%")
  ) |>
    plotly::layout(
      xaxis = list(title = group_label, tickangle = -30, fixedrange = TRUE),
      yaxis = list(title = "", autorange = "reversed", fixedrange = TRUE, automargin = TRUE),
      margin = list(l = 10, b = 10),
      font = list(family = "Inter, sans-serif")
    ) |>
    plotly::config(displaylogo = FALSE)
}

answer_share_plot <- function(codebook, q) {
  rows <- codebook[question_id == q]
  plotly::plot_ly(
    rows, x = ~share, y = ~factor(option, levels = rev(option)), type = "bar", orientation = "h",
    marker = list(color = "#538037"),
    text = ~sprintf("%.0f%% (%d)", 100 * share, n), textposition = "outside", cliponaxis = FALSE,
    hovertemplate = "<b>%{y}</b><br>%{x:.1%} of responses<extra></extra>"
  ) |>
    plotly::layout(
      xaxis = list(title = "Share of responses", tickformat = ".0%", range = c(0, max(rows$share) * 1.3), fixedrange = TRUE),
      yaxis = list(title = "", fixedrange = TRUE, automargin = TRUE, ticksuffix = "  "),
      margin = list(l = 10, r = 30),
      font = list(family = "Inter, sans-serif")
    ) |>
    plotly::config(displaylogo = FALSE)
}

# Recorded behavior on days with each answer to an EMA question
ema_behavior_table <- function(ema_tidy, day_summary, codebook, q) {
  latest <- ema_tidy[question_id == q][, .SD[timestamp == max(timestamp)], by = .(user_id, start_date)]
  answers <- latest[, .(option = unlist(response_options)), by = .(user_id, start_date)]
  days <- data.table::as.data.table(day_summary)[, .(user_id, start_date = as.Date(start_date), trip_count, activity_count, with_subtype)]
  answers <- merge(answers, days, by = c("user_id", "start_date"))
  result <- answers[, .(Days = .N, `Trips per day` = mean(trip_count), `Activities per day` = mean(activity_count),
                        `Hours recorded` = mean(with_subtype)), by = .(Answer = option)]
  result[order(match(Answer, codebook[question_id == q, option]))]
}
