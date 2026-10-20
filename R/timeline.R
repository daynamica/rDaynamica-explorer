# Interactive day timeline for one participant.
#
# rDaynamica::plot_indi_temp() draws each item as a line segment, and plotly
# only shows hover information at a segment's two endpoints. Drawing items as
# horizontal bars instead makes the whole item hoverable, with a readable
# tooltip.

# Colors for category groups that aren't in rDaynamica::color_discrete_maps
extra_category_colors <- c("TRIP" = "#538037", "DEVICE OFF" = "#bdbdbd", "UNKNOWN" = "#bdbdbd")

category_color <- function(categories) {
  palette <- c(rDaynamica::color_discrete_maps, extra_category_colors)
  palette <- palette[!duplicated(names(palette), fromLast = TRUE)]
  cols <- unname(palette[categories])
  cols[is.na(cols)] <- "#9e9e9e"
  cols
}

pretty_label <- function(x) {
  x <- tools::toTitleCase(tolower(x))
  sub("^Car - ", "Car, ", sub("Taxi/uber/lyft", "Taxi/Uber/Lyft", x))
}

format_clock <- function(hours) {
  h <- floor(hours) %% 24
  m <- round((hours - floor(hours)) * 60)
  h <- ifelse(m == 60, (h + 1) %% 24, h)
  m <- ifelse(m == 60, 0, m)
  sprintf("%d:%02d %s", ifelse(h %% 12 == 0, 12, h %% 12), m, ifelse(h < 12, "AM", "PM"))
}

format_duration <- function(hours) {
  mins <- round(hours * 60)
  ifelse(mins < 60, sprintf("%d min", mins), sprintf("%d h %02d min", mins %/% 60, mins %% 60))
}

plot_timeline <- function(items, user) {
  df <- data.table::copy(items[user_id == user])
  if (nrow(df) == 0) return(NULL)

  df[, start_h := as.numeric(data.table::as.ITime(start_time)) / 3600]
  df[, end_h := as.numeric(data.table::as.ITime(end_time)) / 3600]
  df[end_h <= start_h & end_h == 0, end_h := 24]
  df <- df[end_h > start_h]
  data.table::setorder(df, start_date, start_h)

  df[, day := paste0(format(start_date, "%a %b "), as.integer(format(start_date, "%d")))]
  day_levels <- unique(df$day)

  df[, group := data.table::fcase(type_decoded == "ACTIVITY", "Activities",
                                  type_decoded == "TRIP", "Trips",
                                  default = "No data")]
  df[group == "No data", subtype_decoded := "DEVICE OFF"]
  df[, category := pretty_label(subtype_decoded)]
  df[group == "No data", category := "Phone off / no data"]

  df[, hover := paste0(
    "<b>", category, "</b>  ", format_clock(start_h), " to ", format_clock(end_h),
    " (", format_duration(end_h - start_h), ")<br>",
    format(start_date, "%A, %B "), as.integer(format(start_date, "%d")), format(start_date, ", %Y"),
    data.table::fifelse(group == "Trips" & !trip_purpose %in% c("UNKNOWN", NA),
                        paste0("<br>Trip purpose: ", pretty_label(trip_purpose)), ""),
    data.table::fifelse(group == "Trips" & distance_after_split > 0,
                        sprintf("<br>Distance: %.1f miles", distance_after_split / 1609.34), ""),
    data.table::fifelse(group != "No data",
                        data.table::fifelse(survey_not_null, "<br>Survey answered", "<br>No survey answered"), "")
  )]

  bar_width <- c("Activities" = 0.7, "Trips" = 0.45, "No data" = 0.7)
  group_order <- c("Activities", "Trips", "No data")

  fig <- plotly::plot_ly(height = 140 + 32 * length(day_levels))
  for (g in group_order) {
    for (cat in sort(unique(df[group == g, category]))) {
      d <- df[group == g & category == cat]
      marker <- list(color = category_color(d$subtype_decoded[1]), line = list(color = "white", width = 0.5))
      if (g == "No data") {
        marker$color <- "#f4f4f4"
        marker$pattern <- list(shape = "/", fgcolor = "#b0b0b0", size = 6, solidity = 0.3)
      }
      fig <- plotly::add_trace(
        fig, type = "bar", orientation = "h",
        x = d$end_h - d$start_h, base = d$start_h,
        y = factor(d$day, levels = day_levels),
        width = bar_width[[g]],
        name = cat, legendgroup = g, legendgrouptitle = list(text = g),
        marker = marker,
        hovertext = d$hover, hoverinfo = "text", hoverlabel = list(align = "left")
      )
    }
  }

  ticks <- seq(0, 24, by = 3)
  plotly::layout(
    fig,
    barmode = "overlay",
    xaxis = list(title = "", range = c(0, 24), tickvals = ticks, ticktext = format_clock(ticks),
                 side = "top", gridcolor = "#e6e6e6", zeroline = FALSE, fixedrange = TRUE),
    yaxis = list(title = "", autorange = "reversed", fixedrange = TRUE),
    legend = list(groupclick = "toggleitem", tracegroupgap = 12),
    hovermode = "closest",
    margin = list(l = 90, t = 40),
    font = list(family = "Inter, sans-serif", size = 12)
  ) |>
    plotly::config(displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"))
}
