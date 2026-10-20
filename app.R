# rDaynamica Explorer
#
# An interactive tour of the example Daynamica dataset, built on the rDaynamica
# package. Helper functions in R/ are loaded automatically by Shiny.

library(shiny)
library(bslib)
library(dplyr)
library(data.table)
library(rDaynamica)

example_data <- readRDS("data/example_data.rds")

all_users <- sort(unique(example_data$day_summary$user_id))
format_minutes <- function(m) sprintf("%d:%02d", m %/% 60, m %% 60)
# The time-of-day slider works in clock times on an arbitrary date
day_start <- as.POSIXct("2000-01-01 00:00", tz = "UTC")

measure_choices <- list(
  ACTIVITY = c("Number of activities" = "id", "Time spent (hours)" = "duration_after_split"),
  TRIP = c("Number of trips" = "id", "Time spent (minutes)" = "duration_after_split",
           "Distance (miles)" = "distance_after_split")
)
group_choices <- list(
  ACTIVITY = c("Activity type" = "subtype_decoded"),
  TRIP = c("Travel mode" = "subtype_decoded", "Trip purpose" = "trip_purpose")
)

explainer <- function(...) p(class = "text-muted mb-3", ...)

ui <- page_navbar(
  title = "rDaynamica Explorer",
  theme = bs_theme(version = 5, primary = "#2a6f97", base_font = font_google("Inter")),
  fillable = FALSE,
  sidebar = sidebar(
    width = 300,
    h6("Which days count?"),
    sliderInput("min_hours", "Minimum hours of recorded activities and trips per day",
                min = 4, max = 24, value = 12, step = 1),
    helpText("Phones don't always record a full day. Days with less recorded data than this are left out of every tab."),
    hr(),
    helpText(
      "This app uses an anonymized sample of Daynamica data and the open-source ",
      a("rDaynamica R package", href = "https://github.com/daynamica/rDaynamica", target = "_blank"),
      ". Everything shown here can be reproduced in R with your own data."
    )
  ),

  nav_panel(
    "Overview",
    explainer("Daynamica is a smartphone app that records people's activities and trips over the day, ",
              "and asks short survey questions about them. This page summarizes the sample dataset."),
    layout_column_wrap(
      width = "200px", fill = FALSE,
      value_box("Participants", textOutput("n_users"), theme = "primary"),
      value_box("Days included", textOutput("n_days"), theme = "secondary"),
      value_box("Activities & trips", textOutput("n_items"), theme = "secondary"),
      value_box("Survey responses", textOutput("n_surveys"), theme = "secondary")
    ),
    card(
      card_header("How many days meet each data-completeness threshold?"),
      explainer("Days on which the participant used the app, by day of week, and how many of them have at least 24, 20, 16, 12, or 8 hours of recorded data."),
      DT::DTOutput("valid_days_table")
    ),
    card(
      card_header("A typical day in the data"),
      explainer("Per-day statistics for the days included, split into weekdays (FALSE) and weekends (TRUE)."),
      DT::DTOutput("overview_table")
    )
  ),

  nav_panel(
    "Daily timelines",
    explainer("Each row is one day for one participant, showing what they were doing from midnight to midnight. ",
              "Hover over a segment for details; click legend entries to hide or show categories."),
    selectInput("timeline_user", "Participant", choices = NULL),
    card(full_screen = TRUE, plotly::plotlyOutput("timeline_plot", height = "auto"))
  ),

  nav_panel(
    "Activities & trips",
    explainer("Averages per day across all included days, for all days, weekdays, and weekends."),
    layout_columns(
      col_widths = c(4, 4, 4),
      radioButtons("summary_type", "Show", c("Activities" = "ACTIVITY", "Trips" = "TRIP"), inline = TRUE),
      selectInput("summary_measure", "Measure", measure_choices$ACTIVITY),
      selectInput("summary_group", "Group by", group_choices$ACTIVITY)
    ),
    card(full_screen = TRUE, plotly::plotlyOutput("summary_plot", height = "450px")),
    card(card_header("Table"), DT::DTOutput("summary_table"))
  ),

  nav_panel(
    "Daily rhythm",
    explainer("How people move between activities and trips over the course of a day. Each ribbon shows how many ",
              "participant-days went from one category to another in the next 15 minutes; ribbons that loop back ",
              "to the same category are people who kept doing the same thing. Press play to watch the day unfold."),
    layout_columns(
      col_widths = c(4, 8),
      card(
        sliderInput("chord_time", "Time of day", min = day_start, max = day_start + 1425 * 60,
                    value = day_start + 480 * 60, step = 15 * 60, timeFormat = "%H:%M", timezone = "+0000",
                    ticks = FALSE, animate = animationOptions(interval = 1500)),
        textOutput("chord_label"),
        helpText("Detailed categories are grouped (for example, car, bus, and rail are all Motorized Trip) to keep the diagram readable.")
      ),
      card(plotOutput("chord_plot", height = "620px"))
    )
  ),

  nav_panel(
    "Activity chains",
    explainer("An activity chain summarizes a day as a sequence of letters: H for home, W for work, O for other activities, ",
              "and T for trips. For example, HWH means the person went from home to work and back home."),
    layout_columns(
      col_widths = c(4, 4, 4),
      checkboxInput("chain_trips", "Include trips (T)", FALSE),
      sliderInput("chain_min_duration", "Ignore activities shorter than (minutes)", min = 0, max = 60, value = 15, step = 5),
      checkboxInput("chain_collapse", "Combine repeated letters (HHW becomes HW)", TRUE)
    ),
    layout_columns(
      col_widths = c(4, 8),
      card(card_header("Most common chains"), DT::DTOutput("chain_table")),
      card(
        full_screen = TRUE,
        card_header("How days branch out from home"),
        sliderInput("sankey_min", "Hide branches with fewer than this share of days", min = 0.01, max = 0.1,
                    value = 0.02, step = 0.01, width = "100%"),
        networkD3::sankeyNetworkOutput("chain_sankey", height = "500px")
      )
    )
  )
)

server <- function(input, output, session) {

  filtered <- reactive({
    query <- paste0("(interact_with_app>0)&(with_subtype>=", input$min_hours, ")")
    suppressMessages(suppressWarnings(filter_valid_days(example_data, query)))
  }) |> bindCache(input$min_hours)

  # Overview -------------------------------------------------------------
  output$n_users <- renderText(format(uniqueN(filtered()$day_summary$user_id), big.mark = ","))
  output$n_days <- renderText(format(nrow(filtered()$day_summary), big.mark = ","))
  output$n_items <- renderText(format(nrow(filtered()$ucalitems_temporal_plot), big.mark = ","))
  output$n_surveys <- renderText({
    d <- filtered()
    format(sum(!is.na(d$calendar_item_survey$response)) + sum(!is.na(d$ema_survey$response)), big.mark = ",")
  })

  output$valid_days_table <- DT::renderDT({
    DT::datatable(suppressMessages(count_valid_per_days(data.table::copy(example_data$day_summary))),
                  rownames = FALSE, options = list(dom = "t", ordering = FALSE))
  })

  output$overview_table <- DT::renderDT({
    stats <- overview_statistics(filtered())
    setnames(stats, "IsWeekend", "Weekend")
    DT::datatable(stats, rownames = FALSE, options = list(dom = "t", pageLength = 50)) |>
      DT::formatRound(c("Median", "Mean", "SD", "Min", "Max"), digits = 1)
  })

  # Daily timelines -------------------------------------------------------
  observe({
    users <- sort(unique(filtered()$day_summary$user_id))
    days <- table(filtered()$day_summary$user_id)[users]
    choices <- stats::setNames(users, sprintf("%s (%d days)", users, as.integer(days)))
    selected <- if (isolate(input$timeline_user) %in% users) isolate(input$timeline_user) else users[1]
    updateSelectInput(session, "timeline_user", choices = choices, selected = selected)
  })

  output$timeline_plot <- plotly::renderPlotly({
    req(input$timeline_user)
    fig <- plot_indi_temp(filtered()$ucalitems_temporal_plot, input$timeline_user)
    validate(need(!is.null(fig), "No days for this participant at the current threshold."))
    fig$x$layout$width <- NULL
    plotly::layout(fig, font = list(size = 13), margin = list(l = 140))
  })

  # Activities & trips ----------------------------------------------------
  observeEvent(input$summary_type, {
    updateSelectInput(session, "summary_measure", choices = measure_choices[[input$summary_type]])
    updateSelectInput(session, "summary_group", choices = group_choices[[input$summary_type]])
  })

  summary_args <- reactive({
    req(input$summary_measure %in% measure_choices[[input$summary_type]],
        input$summary_group %in% group_choices[[input$summary_type]])
    list(type = input$summary_type, measure = input$summary_measure, group = input$summary_group)
  })

  output$summary_plot <- plotly::renderPlotly({
    a <- summary_args()
    fig <- activity_trip_figure(
      ucalitems = filtered()$ucalitems_temporal_plot, tb = "ucalitems_temporal_plot",
      day_summary = filtered()$day_summary, mytype = a$type, by_field = a$group, agg_col = a$measure
    )
    fig$x$layout$width <- NULL
    fig$x$layout$height <- NULL
    plotly::layout(fig, legend = list(title = list(text = names(which(group_choices[[a$type]] == a$group)))))
  })

  output$summary_table <- DT::renderDT({
    a <- summary_args()
    tbl <- activity_trip(ucalitems = filtered()$ucalitems_temporal_plot, day_summary = filtered()$day_summary,
                         mytype = a$type, by_field = a$group)
    DT::datatable(tbl, rownames = FALSE, options = list(dom = "t", pageLength = 50, scrollX = TRUE)) |>
      DT::formatRound(names(tbl)[-1], digits = 2)
  })

  # Daily rhythm ----------------------------------------------------------
  chord <- reactive(prepare_chord_flows(filtered())) |> bindCache(input$min_hours)

  chord_minutes <- reactive(round(as.numeric(difftime(input$chord_time, day_start, units = "mins"))))

  output$chord_label <- renderText({
    sprintf("Showing changes from %s to %s", format_minutes(chord_minutes()),
            format_minutes((chord_minutes() + 15) %% 1440))
  })

  output$chord_plot <- renderPlot({
    draw_chord_frame(chord(), frame = chord_minutes() / 15 + 1)
  }, res = 96) |> bindCache(input$min_hours, chord_minutes())

  # Activity chains -------------------------------------------------------
  chains <- reactive({
    create_activity_chains(
      filtered()$ucalitems_temporal_plot,
      include_trips = input$chain_trips,
      minimum_duration_min = input$chain_min_duration,
      collapse_identical_labels = input$chain_collapse
    )
  })

  output$chain_table <- DT::renderDT({
    tbl <- chains() |>
      count(Chain = string, name = "Days", sort = TRUE) |>
      mutate(Share = Days / sum(Days))
    DT::datatable(tbl, rownames = FALSE, options = list(dom = "tp", pageLength = 12)) |>
      DT::formatPercentage("Share", digits = 1)
  })

  output$chain_sankey <- networkD3::renderSankeyNetwork({
    sankey_data <- create_sankey_data(chains(), lower_limit = input$sankey_min)
    validate(need(any(substr(sankey_data$prev, 1, 1) == "H"), "No chains start at home with these settings."))
    create_plot_from_data(sankey_data, start_from_H = TRUE)
  })
}

shinyApp(ui, server)
