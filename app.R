# Daynamica Data Explorer
#
# An interactive tour of the example Daynamica dataset, built on the rDaynamica
# package. Helper functions in R/ are loaded automatically by Shiny.

library(shiny)
library(bslib)
library(dplyr)
library(data.table)
library(rDaynamica)

example_data <- readRDS("data/example_data.rds")

# Survey tables are tidied once; linking answers to items then keeps only the
# days included by the sidebar setting
cis_tidy <- tidy_calendar_item_survey(example_data$calendar_item_survey)
ema_tidy <- tidy_ema_survey(example_data$ema_survey)
cis_codebook <- survey_codebook(cis_tidy)
ema_codebook <- survey_codebook(ema_tidy)
all_days <- suppressMessages(suppressWarnings(filter_valid_days(example_data, "(interact_with_app>=0)")))
cis_question_types <- survey_question_types(link_survey_to_items(cis_tidy, all_days$ucalitems_temporal_plot))

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

# Daynamica brand colors, taken from the logo
daynamica_green <- "#6BAA43"
daynamica_green_dark <- "#538037"
daynamica_ink <- "#1A1A1A"

app_theme <- bs_theme(
  version = 5,
  primary = daynamica_green_dark,
  secondary = daynamica_ink,
  success = daynamica_green,
  fg = daynamica_ink,
  bg = "#ffffff",
  base_font = font_google("Inter"),
  "link-color" = daynamica_green_dark
) |>
  bs_add_rules(sprintf("
    .skip-to-content {
      position: absolute;
      top: -100px;
      left: 0;
      background: %2$s;
      color: #ffffff;
      padding: .5rem 1rem;
      z-index: 9999;
      font-weight: 600;
      text-decoration: none;
      border-radius: 0 0 4px 0;
      transition: top 0.2s ease;
    }
    .skip-to-content:focus, .skip-to-content:focus-visible {
      top: 0;
      outline: 2px solid %1$s;
      outline-offset: 2px;
    }
    .navbar { border-bottom: 3px solid %1$s; }
    .navbar .nav-link:focus-visible { outline: 2px solid %1$s; outline-offset: -2px; border-radius: 4px; }
    .navbar .nav-link.active { color: %2$s !important; font-weight: 600; box-shadow: inset 0 -3px 0 %1$s; }
    .nav-link:focus-visible, a:focus-visible { outline: 2px solid %1$s; outline-offset: 2px; border-radius: 2px; }
    .navbar-brand img { height: 28px; margin-right: .5rem; vertical-align: -6px; }
    .about-figure { font-size: .925rem; }
    .research-questions { background: #f2f7ee; border-left: 4px solid %1$s; border-radius: 4px;
                          padding: .6rem .9rem; margin: .5rem 0 .75rem; }
    .research-questions .rq-label { display: block; font-weight: 600; color: %2$s; margin-bottom: .2rem; }
    .research-questions ul { margin: 0; padding-left: 1.1rem; }
    .bslib-value-box { border-left: 4px solid %1$s; }
    .bslib-value-box .value-box-value { color: %2$s; }
    .chord-wrap { position: relative; }
    .chord-loading { display: none; position: absolute; inset: auto 0 calc(50%% - 110px) 0; flex-direction: column;
                     align-items: center; gap: .25rem; text-align: center; color: %2$s; pointer-events: none; }
    .chord-loading span { color: #6c757d; font-size: .875rem; }
    .chord-wrap:has(#chord_plot.recalculating) .chord-loading {
      display: flex; opacity: 0; animation: chord-loading-in .2s ease-out .5s forwards; }
    @keyframes chord-loading-in { to { opacity: 1; } }
    .code-panel { margin-top: .75rem; }
    .code-panel > summary { cursor: pointer; color: %2$s; font-weight: 600; font-size: .9rem; border-radius: 4px; }
    .code-panel > summary:focus-visible { outline: 2px solid %1$s; outline-offset: 2px; }
    .code-block { position: relative; margin-top: .5rem; }
    .chord-label-badge { display: inline-block; background: #f2f7ee; border: 1px solid #dfe7da;
                         border-left: 3px solid %1$s; padding: .4rem .75rem; border-radius: 4px;
                         font-weight: 500; font-size: .875rem; color: %2$s; margin-top: .5rem; }
    .code-block pre { background: #f6f8f5; border: 1px solid #dfe7da; border-radius: 4px; padding: .75rem;
                      font-size: .8rem; white-space: pre; overflow-x: auto; margin: 0; }
    .code-block .copy-code { position: absolute; top: .4rem; right: .4rem; background: #fff; transition: background-color .15s ease-in-out, border-color .15s ease-in-out, color .15s ease-in-out; }
    .code-block .copy-code.copied { background-color: %1$s; color: #fff; border-color: %1$s; }
    .code-block .copy-code:focus-visible { outline: 2px solid %1$s; outline-offset: 2px; }
    .slider-animate-button:focus-visible { outline: 2px solid %1$s; outline-offset: 2px; border-radius: 50%%; }
  ", daynamica_green, daynamica_green_dark))

copy_code_js <- tags$script(HTML("
  document.addEventListener('click', function (e) {
    var button = e.target.closest('.copy-code');
    if (!button) return;
    var pre = button.parentElement.querySelector('pre');
    var selectCode = function () {
      var range = document.createRange();
      range.selectNodeContents(pre);
      var selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      button.textContent = 'Press Ctrl+C to copy';
      button.classList.add('btn-success', 'copied');
      button.classList.remove('btn-outline-secondary');
      button.setAttribute('aria-label', 'Press Ctrl+C to copy code');
      button.setAttribute('title', 'Press Ctrl+C to copy code');
      setTimeout(function () {
        button.textContent = 'Copy';
        button.classList.remove('btn-success', 'copied');
        button.classList.add('btn-outline-secondary');
        button.setAttribute('aria-label', 'Copy code to clipboard');
        button.setAttribute('title', 'Copy code to clipboard');
      }, 3000);
    };
    if (!navigator.clipboard) { selectCode(); return; }
    navigator.clipboard.writeText(pre.innerText).then(function () {
      button.textContent = 'Copied';
      button.classList.add('btn-success', 'copied');
      button.classList.remove('btn-outline-secondary');
      button.setAttribute('aria-label', 'Copied to clipboard');
      button.setAttribute('title', 'Copied to clipboard');
      setTimeout(function () {
        button.textContent = 'Copy';
        button.classList.remove('btn-success', 'copied');
        button.classList.add('btn-outline-secondary');
        button.setAttribute('aria-label', 'Copy code to clipboard');
        button.setAttribute('title', 'Copy code to clipboard');
      }, 1500);
    }, selectCode);
  });
"))

slider_animate_js <- tags$script(HTML("
  document.addEventListener('DOMContentLoaded', function () {
    function updateSliderBtn(btn) {
      if (!btn) return;
      if (!btn.hasAttribute('role')) btn.setAttribute('role', 'button');
      var stopSpan = btn.querySelector('.stop, .glyphicon-pause, .fa-pause');
      var isPlaying = (stopSpan && window.getComputedStyle(stopSpan).display !== 'none') || btn.classList.contains('playing');
      var label = isPlaying ? 'Pause time of day animation' : 'Play time of day animation';
      var title = isPlaying ? 'Pause animation' : 'Play animation';
      btn.setAttribute('aria-label', label);
      btn.setAttribute('title', title);
    }

    function initButtons() {
      document.querySelectorAll('.slider-animate-button').forEach(updateSliderBtn);
    }

    initButtons();
    setTimeout(initButtons, 500);

    document.addEventListener('click', function (e) {
      var btn = e.target.closest('.slider-animate-button');
      if (btn) {
        setTimeout(function () { updateSliderBtn(btn); }, 50);
      }
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === ' ' || e.key === 'Enter') {
        var btn = e.target.closest('.slider-animate-button');
        if (btn) {
          setTimeout(function () { updateSliderBtn(btn); }, 50);
        }
      }
    });
  });
"))

stat_box <- function(title, output_id) {
  value_box(title, textOutput(output_id), theme = value_box_theme(bg = "#f6f9f3", fg = daynamica_ink))
}

# "What this shows" text plus example research questions for a figure or table
about_figure <- function(shows, questions) {
  div(
    class = "about-figure",
    p(shows),
    div(class = "research-questions",
        span(class = "rq-label", "Questions you could explore"),
        tags$ul(lapply(questions, tags$li)))
  )
}

intro <- function(...) p(class = "lead fs-6 mb-3", ...)

ui <- page_navbar(
  title = tags$span(tags$img(src = "logo.png", alt = "", `aria-hidden` = "true"), "Daynamica Data Explorer"),
  window_title = "Daynamica Data Explorer",
  theme = app_theme,
  navbar_options = navbar_options(bg = "#ffffff", theme = "light"),
  fillable = FALSE,
  header = tagList(
    tags$a(href = "#main-content", class = "skip-to-content", "Skip to main content"),
    tags$head(tags$link(rel = "icon", type = "image/png", href = "logo.png")),
    copy_code_js,
    slider_animate_js,
    # The delay keeps the spinner from flickering on quick updates
    useBusyIndicators(spinners = TRUE, pulse = TRUE),
    busyIndicatorOptions(spinner_type = "ring2", spinner_color = daynamica_green, spinner_size = "48px",
                         spinner_delay = "0.5s", pulse_background = daynamica_green)
  ),
  sidebar = sidebar(
    width = 300,
    h6("Which days count?"),
    sliderInput("min_hours", "Minimum hours of recorded activities and trips per day",
                min = 4, max = 24, value = 12, step = 1),
    helpText("Phones don't always record a full day, for example when the battery runs out. Days with less recorded data than this are left out of every tab."),
    hr(),
    helpText(
      "This app uses an anonymized sample of Daynamica data and the open-source ",
      a("rDaynamica R package", href = "https://github.com/Daynamica-Repositories/rDaynamica", target = "_blank", rel = "noopener noreferrer", title = "opens in new tab", `aria-label` = "rDaynamica R package (opens in new tab)"),
      ". Everything shown here can be reproduced in R with your own data."
    )
  ),

  nav_panel(
    "Overview",
    div(id = "main-content", tabindex = "-1"),
    intro("Daynamica is a smartphone app that detects participants' activities and trips throughout the day. ",
          "Participants review them in a daily calendar, label what they were doing and how they traveled, and answer ",
          "short surveys about specific activities and trips and about how they are feeling in the moment. ",
          "The result is a detailed, multi-day record of how people spend their time and move around."),
    layout_column_wrap(
      width = "200px", fill = FALSE,
      stat_box("Participants", "n_users"),
      stat_box("Days included", "n_days"),
      stat_box("Activities & trips", "n_items"),
      stat_box("Survey responses", "n_surveys")
    ),
    card(
      card_header("How many days meet each data-completeness threshold?"),
      about_figure(
        "Each row is a day of the week. \"Total # of Days\" counts the days on which participants opened the app; the other columns show how many of those days (and what share) have at least 24, 20, 16, 12, or 8 hours of recorded activities and trips. This table always covers the full dataset, regardless of the sidebar setting.",
        list("How complete is passively collected smartphone data, and does completeness differ between weekdays and weekends?",
             "What completeness threshold gives the best balance between sample size and data quality for a given study?",
             "Are some participants or days systematically less complete, which could bias results?")
      ),
      DT::DTOutput("valid_days_table", fill = FALSE),
      show_code("code_valid_days")
    ),
    card(
      card_header("A typical day in the data"),
      about_figure(
        "Each statistic is first calculated for every included participant-day, then summarized across days (median, mean, standard deviation, minimum, and maximum), separately for weekdays and weekends.",
        list("How much time do people spend traveling each day, and how far do they go?",
             "How many activities and trips make up a typical day, and how much does this vary between people?",
             "Do daily travel time budgets differ between weekdays and weekends?")
      ),
      DT::DTOutput("overview_table", fill = FALSE),
      show_code("code_overview")
    )
  ),

  nav_panel(
    "Daily timelines",
    intro("Each row is one day for the selected participant, from midnight to midnight. Tall bars are activities, ",
          "thin bars are trips, and striped gray bars are periods when the phone recorded nothing. Hover over any bar for details; ",
          "click legend entries to hide or show categories."),
    card(
      about_figure(
        "Looking at individual days is often the first step in analyzing Daynamica data: it shows the structure of people's days and how they vary.",
        list("How regular are people's schedules from one day to the next, and how do weekdays differ from weekends?",
             "When do people leave home in the morning and return in the evening?",
             "Which activities are reached by which travel modes, and how often do people make several stops on one outing?")
      ),
      selectInput("timeline_user", "Participant", choices = NULL, width = "320px"),
      show_code("code_timeline")
    ),
    card(full_screen = TRUE, plotly::plotlyOutput("timeline_plot", height = "auto"))
  ),

  nav_panel(
    "Activities & trips",
    intro("How do people divide their day between different activities, and how do they get around?"),
    layout_columns(
      col_widths = c(4, 4, 4),
      radioButtons("summary_type", "Show", c("Activities" = "ACTIVITY", "Trips" = "TRIP"), inline = TRUE),
      selectInput("summary_measure", "Measure", measure_choices$ACTIVITY),
      selectInput("summary_group", "Group by", group_choices$ACTIVITY)
    ),
    card(
      full_screen = TRUE,
      card_header(textOutput("summary_title", inline = TRUE)),
      about_figure(
        textOutput("summary_description", inline = TRUE),
        list("How do people allocate their time across work, home, errands, and leisure (time-use research)?",
             "What is the mode share for different trip purposes, for example how many shopping trips are made on foot?",
             "How do activity and travel patterns differ between weekdays and weekends, or between groups of participants?")
      ),
      plotly::plotlyOutput("summary_plot", height = "450px")
    ),
    card(
      card_header("Table"),
      p(class = "about-figure", "The numbers behind the chart. Each value is an average per day: the total across all included days divided by the number of days, for all days, weekdays only, and weekends only."),
      DT::DTOutput("summary_table", fill = FALSE),
      show_code("code_summary")
    )
  ),

  nav_panel(
    "Daily rhythm",
    intro("How people move between activities and trips over the course of a day. Press play to watch the day unfold."),
    layout_columns(
      col_widths = c(4, 8),
      card(
        sliderInput("chord_time", "Time of day", min = day_start, max = day_start + 1425 * 60,
                    value = day_start + 480 * 60, step = 15 * 60, timeFormat = "%H:%M", timezone = "+0000",
                    ticks = FALSE, animate = animationOptions(interval = 1500)),
        div(`aria-live` = "polite", `aria-atomic` = "true", textOutput("chord_label")),
        about_figure(
          "Each segment around the circle is a category, sized by the number of participant-days flowing out of and into it at this time. Ribbons show what people were doing 15 minutes later: a ribbon that loops back to its own segment means they kept doing the same thing, and a ribbon to another segment means they switched. Detailed categories are grouped (for example, car, bus, and rail are all Motorized Trip) to keep the diagram readable.",
          list("When are transitions between activities most common, and when are travel peaks?",
               "How synchronized are people's daily rhythms, for example when most people are at work or at home?",
               "At what times of day are people exposed to travel, which matters for questions about physical activity, air pollution, or traffic safety?")
        ),
        show_code("code_chord")
      ),
      card(div(
        class = "chord-wrap",
        plotOutput("chord_plot", height = "620px"),
        div(class = "chord-loading", role = "status", `aria-live` = "polite",
            strong("Preparing the daily rhythm diagram…"),
            span("This takes a few seconds the first time, and after changing which days count."))
      ))
    )
  ),

  nav_panel(
    "Activity chains",
    intro("An activity chain summarizes a day as a sequence of letters: H for home, W for work, O for other activities, ",
          "and T for trips. For example, HWH means the person went from home to work and back home."),
    layout_columns(
      col_widths = c(4, 4, 4),
      checkboxInput("chain_trips", "Include trips (T)", FALSE),
      sliderInput("chain_min_duration", "Ignore activities and trips shorter than (minutes)", min = 0, max = 60, value = 15, step = 5),
      checkboxInput("chain_collapse", "Combine repeated letters (HHW becomes HW)", TRUE)
    ),
    about_figure(
      "Activity chains are a standard way to describe the structure of a day in travel behavior research and in activity-based travel demand models.",
      list("How complex are people's days: simple home-work-home patterns, or many stops?",
           "Do people combine errands into a single outing (trip chaining), and how does that relate to how they travel?",
           "How often does a day include a stop on the way to or from work?")
    ),
    layout_columns(
      col_widths = c(4, 8),
      card(
        card_header("Most common chains"),
        p(class = "about-figure", "Each row is a distinct chain, with the number and share of included days that followed it exactly."),
        DT::DTOutput("chain_table", fill = FALSE)
      ),
      card(
        full_screen = TRUE,
        card_header("How days branch out from home"),
        p(class = "about-figure", "Reading left to right, each column is the next step in the day, starting from home (H). Node labels show the chain so far, and the thickness of each branch is the number of days that took that path. X marks the end of the day."),
        sliderInput("sankey_min", "Hide branches with fewer than this share of days", min = 0.01, max = 0.1,
                    value = 0.02, step = 0.01, width = "100%"),
        networkD3::sankeyNetworkOutput("chain_sankey", height = "500px")
      )
    ),
    card(show_code("code_chains"))
  ),

  nav_panel(
    "Surveys",
    intro("Besides recording activities and trips, Daynamica asks participants short survey questions: about specific ",
          "activities and trips (for example, who they were with or how safe a trip felt), and about their day as a whole. ",
          "Survey questions differ between studies; these are the questions in the example study."),
    card(
      card_header("How often do participants answer?"),
      about_figure(
        "Response rates count each activity, and each complete trip (all its legs), once. Response time is the number of hours from the start of the activity or trip to the participant's answer. The chart shows how response rates vary between participants.",
        list("How much response burden do the surveys place on participants?",
             "Are some kinds of activities or trips answered more often than others, which could bias survey results?",
             "How long after an activity do people answer, and how might recall affect their answers?")
      ),
      layout_columns(
        col_widths = c(6, 6),
        DT::DTOutput("survey_rates_table", fill = FALSE),
        plotly::plotlyOutput("survey_participant_plot", height = "300px")
      ),
      show_code("code_survey_participation")
    ),
    card(
      card_header("Questions about activities and trips"),
      about_figure(
        "Pick a question to see how participants answered and how answers compare across activity types, travel modes, trip purposes, or days. Rating questions are compared by their average answer (what the ends of each scale mean isn't recorded in the data); other questions by the share of responses choosing each answer. A trip's main mode is the mode of its longest leg.",
        list("Do people feel safer, or less stressed, on some travel modes than others?",
             "Which activities do people do alone, and which with family or friends?",
             "How does the experience of a trip depend on its purpose, or differ between weekdays and weekends?")
      ),
      layout_columns(
        col_widths = c(6, 3, 3),
        selectInput("survey_question", "Question", choices = survey_question_choices(cis_codebook, cis_question_types), width = "100%"),
        selectInput("survey_by", "Compare by", choices = NULL, width = "100%"),
        sliderInput("survey_min_n", "Hide groups with fewer responses than", min = 5, max = 100, value = 20, step = 5, width = "100%")
      ),
      layout_columns(
        col_widths = c(4, 8),
        div(h6("All answers"), DT::DTOutput("survey_answers", fill = FALSE)),
        plotly::plotlyOutput("survey_compare_plot", height = "460px")
      ),
      show_code("code_survey_question")
    ),
    card(
      card_header("End-of-day questions"),
      about_figure(
        "Each evening, participants answer a few questions about their whole day. The table compares days with each answer using what the app recorded on those days, which shows how self-reports relate to measured behavior. If a participant answered more than once in a day, the latest answers are used.",
        list("Do people who shop online make fewer shopping trips?",
             "Which transportation barriers keep people from making trips they would like to make?",
             "Do days on which people report discrimination look different in how they travel?")
      ),
      selectInput("ema_question", "Question", choices = ema_question_choices(ema_codebook), width = "100%"),
      layout_columns(
        col_widths = c(5, 7),
        plotly::plotlyOutput("ema_answers_plot", height = "360px"),
        div(h6("Recorded behavior on days with each answer"), DT::DTOutput("ema_behavior", fill = FALSE))
      ),
      show_code("code_ema_question")
    )
  ),

  nav_panel(
    "Use it in R",
    intro("Every table and figure in this app comes from the rDaynamica R package, and each one has a ",
          "\"Show the R code\" link with the code that reproduces it using the app's current settings."),
    card(
      card_header("Setup: install rDaynamica and prepare the example data"),
      p(class = "about-figure", "Run this once in R or RStudio before the code from the other tabs. It installs the package, loads the anonymized example data that ships with it, and runs the standard preprocessing steps. Takes about a minute."),
      div(class = "code-block",
          tags$button(type = "button", class = "btn btn-sm btn-outline-secondary copy-code", `aria-label` = "Copy code to clipboard", `aria-live` = "polite", "Copy"),
          tags$pre(setup_code))
    ),
    card(
      card_header("Using your own Daynamica data"),
      p(class = "about-figure",
        "Point ", code("path2dict()"), " at the folder containing your Daynamica CSV export instead of the example data, and set ",
        code("file_prefix"), " to match your file names. The package's ",
        a("README", href = "https://github.com/Daynamica-Repositories/rDaynamica#readme", target = "_blank", rel = "noopener noreferrer", title = "opens in new tab", `aria-label` = "rDaynamica R package README (opens in new tab)"),
        " and example analysis script describe the full workflow, including ready-made HTML reports.")
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
                  rownames = FALSE, fillContainer = FALSE, options = list(dom = "t", ordering = FALSE))
  })

  output$overview_table <- DT::renderDT({
    stats <- overview_statistics(filtered())
    stats[, Days := fifelse(IsWeekend, "Weekends", "Weekdays")]
    stats <- stats[order(Statistics, Days), .(Statistic = Statistics, Days, Median, Mean, SD, Min, Max)]
    DT::datatable(stats, rownames = FALSE, fillContainer = FALSE,
                  options = list(dom = "t", pageLength = 50, ordering = FALSE)) |>
      DT::formatRound(c("Median", "Mean", "SD", "Min", "Max"), digits = 1)
  })

  output$code_valid_days <- renderText(code_valid_days())
  output$code_overview <- renderText(code_overview(input$min_hours))

  # Daily timelines -------------------------------------------------------
  output$code_timeline <- renderText({
    req(input$timeline_user)
    code_timeline(input$min_hours, input$timeline_user)
  })

  observe({
    users <- sort(unique(filtered()$day_summary$user_id))
    days <- table(filtered()$day_summary$user_id)[users]
    choices <- stats::setNames(users, sprintf("%s (%d days)", users, as.integer(days)))
    selected <- if (isolate(input$timeline_user) %in% users) isolate(input$timeline_user) else users[1]
    updateSelectInput(session, "timeline_user", choices = choices, selected = selected)
  })

  output$timeline_plot <- plotly::renderPlotly({
    req(input$timeline_user)
    fig <- plot_timeline(filtered()$ucalitems_temporal_plot, input$timeline_user)
    validate(need(!is.null(fig), "No days for this participant at the current threshold."))
    fig
  })

  # Activities & trips ----------------------------------------------------
  observeEvent(input$summary_type, {
    updateSelectInput(session, "summary_measure", choices = measure_choices[[input$summary_type]])
    updateSelectInput(session, "summary_group", choices = group_choices[[input$summary_type]])
  })

  summary_args <- reactive({
    req(input$summary_measure %in% measure_choices[[input$summary_type]],
        input$summary_group %in% group_choices[[input$summary_type]])
    list(type = input$summary_type, measure = input$summary_measure, group = input$summary_group,
         measure_label = names(which(measure_choices[[input$summary_type]] == input$summary_measure)),
         group_label = names(which(group_choices[[input$summary_type]] == input$summary_group)))
  })

  output$code_summary <- renderText({
    a <- summary_args()
    code_summary(input$min_hours, a$type, a$group, a$measure)
  })

  output$summary_title <- renderText({
    a <- summary_args()
    sprintf("%s per day, by %s", a$measure_label, tolower(a$group_label))
  })

  output$summary_description <- renderText({
    a <- summary_args()
    measure_phrase <- switch(
      paste(a$type, a$measure),
      "ACTIVITY id" = "number of activities",
      "ACTIVITY duration_after_split" = "time spent in each activity",
      "TRIP id" = "number of trips",
      "TRIP duration_after_split" = "time spent traveling",
      "TRIP distance_after_split" = "distance traveled"
    )
    extra <-if (a$type == "ACTIVITY" && a$measure == "duration_after_split") {
      " Time spent traveling (Trip) and time with no recorded data (Device Off) are included so the bars add up to the whole recorded day."
    } else if (a$type == "TRIP" && a$group == "trip_purpose") {
      " A trip's purpose is the activity at its destination."
    } else ""
    sprintf("Each bar is an average day, for all days, weekdays only, and weekends only, split by %s. Bar length is the %s on an average day.%s",
            tolower(a$group_label), measure_phrase, extra)
  })

  output$summary_plot <- plotly::renderPlotly({
    a <- summary_args()
    fig <- activity_trip_figure(
      ucalitems = filtered()$ucalitems_temporal_plot, tb = "ucalitems_temporal_plot",
      day_summary = filtered()$day_summary, mytype = a$type, by_field = a$group, agg_col = a$measure
    )
    fig <- suppressWarnings(plotly::plotly_build(fig))
    for (i in seq_along(fig$x$data)) {
      category <- fig$x$data[[i]]$name
      fig$x$data[[i]]$marker$color <- category_color(category)
      fig$x$data[[i]]$marker$line <- list(color = "white", width = 1)
      fig$x$data[[i]]$name <- pretty_label(category)
      fig$x$data[[i]]$hovertemplate <- paste0("<b>", pretty_label(category), "</b><br>%{y}: %{x:.2f}<extra></extra>")
    }
    fig$x$layout$width <- NULL
    fig$x$layout$height <- NULL
    fig$x$layout$legend$title$text <- a$group_label
    fig$x$layout$xaxis$title$text <- a$measure_label
    fig$x$layout$font <- list(family = "Inter, sans-serif")
    plotly::config(fig, displaylogo = FALSE)
  })

  output$summary_table <- DT::renderDT({
    a <- summary_args()
    tbl <- activity_trip(ucalitems = filtered()$ucalitems_temporal_plot, day_summary = filtered()$day_summary,
                         mytype = a$type, by_field = a$group)
    tbl[[1]] <- pretty_label(tbl[[1]])
    setnames(tbl, c(a$group_label, sub("_", ": ", names(tbl)[-1])))
    DT::datatable(tbl, rownames = FALSE, fillContainer = FALSE,
                  options = list(dom = "t", pageLength = 50, scrollX = TRUE)) |>
      DT::formatRound(names(tbl)[-1], digits = 2)
  })

  # Daily rhythm ----------------------------------------------------------
  chord <- reactive(prepare_chord_flows(filtered())) |> bindCache(input$min_hours)

  output$code_chord <- renderText(code_chord(input$min_hours))

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

  output$code_chains <- renderText({
    code_chains(input$min_hours, input$chain_trips, input$chain_min_duration, input$chain_collapse, input$sankey_min)
  })

  output$chain_table <- DT::renderDT({
    tbl <- chains() |>
      count(Chain = string, name = "Days", sort = TRUE) |>
      mutate(Share = Days / sum(Days))
    DT::datatable(tbl, rownames = FALSE, fillContainer = FALSE, options = list(dom = "tp", pageLength = 12)) |>
      DT::formatPercentage("Share", digits = 1)
  })

  output$chain_sankey <- networkD3::renderSankeyNetwork({
    sankey_data <- create_sankey_data(chains(), lower_limit = input$sankey_min)
    validate(need(any(substr(sankey_data$prev, 1, 1) == "H"), "No chains start at home with these settings."))
    p <- create_plot_from_data(sankey_data, start_from_H = TRUE)
    p$x$options$colourScale <- htmlwidgets::JS(sprintf(
      'd3.scaleOrdinal().domain(["H","W","O","T","X"]).range(["%s","%s","%s","%s","%s"])',
      chord_colors[["HOME"]], chord_colors[["WORK"]], chord_colors[["OTHER"]], chord_colors[["MOTORIZED TRIP"]],
      chord_colors[["MISSING"]]
    ))
    p
  })

  # Surveys --------------------------------------------------------------
  survey_items <- reactive(filtered()$ucalitems_temporal_plot)
  survey_linked <- reactive(link_survey_to_items(cis_tidy, survey_items())) |> bindCache(input$min_hours)

  output$survey_rates_table <- DT::renderDT({
    rates <- survey_response_rates(survey_items(), cis_tidy)
    tbl <- rates[, .(`Item type` = pretty_label(type_decoded), Total = units, Surveyed = surveyed,
                     `Response rate` = response_rate, `Median hours to respond` = median_delay_hours,
                     `90th percentile hours` = p90_delay_hours)]
    DT::datatable(tbl, rownames = FALSE, fillContainer = FALSE, options = list(dom = "t", ordering = FALSE)) |>
      DT::formatPercentage("Response rate", digits = 1) |>
      DT::formatRound(c("Median hours to respond", "90th percentile hours"), digits = 1)
  })

  output$survey_participant_plot <- plotly::renderPlotly({
    rates <- survey_response_rates(survey_items(), cis_tidy, by = c("type_decoded", "user_id"))
    plotly::plot_ly(rates, x = ~response_rate, color = ~pretty_label(type_decoded), colors = c("#538037", "#3F5A6B"),
                    type = "histogram", xbins = list(start = 0, end = 1.0001, size = 0.1),
                    hovertemplate = "%{y} participants<extra>%{fullData.name}</extra>") |>
      plotly::layout(barmode = "group", xaxis = list(title = "Share of items surveyed", tickformat = ".0%", fixedrange = TRUE),
                     yaxis = list(title = "Participants", fixedrange = TRUE), legend = list(orientation = "h", y = 1.12),
                     font = list(family = "Inter, sans-serif")) |>
      plotly::config(displaylogo = FALSE)
  })

  output$code_survey_participation <- renderText(code_survey_participation(input$min_hours))

  survey_question_type <- reactive({
    cis_question_types[question_id == as.integer(req(input$survey_question)), type_decoded]
  })

  observeEvent(input$survey_question, {
    choices <- survey_group_choices[[survey_question_type()]]
    selected <- if (isTRUE(input$survey_by %in% choices)) input$survey_by else choices[[1]]
    updateSelectInput(session, "survey_by", choices = choices, selected = selected)
  })

  survey_args <- reactive({
    q <- as.integer(req(input$survey_question))
    choices <- survey_group_choices[[survey_question_type()]]
    req(input$survey_by %in% choices)
    list(q = q, by = input$survey_by, group_label = names(which(choices == input$survey_by)),
         measure = if (is_rating_question(cis_codebook, q)) "mean" else "share")
  })

  output$survey_answers <- DT::renderDT({
    q <- as.integer(req(input$survey_question))
    tbl <- survey_codebook(survey_linked())[question_id == q, .(Answer = option, Responses = n, Share = share)]
    DT::datatable(tbl, rownames = FALSE, fillContainer = FALSE,
                  options = list(dom = "t", pageLength = 50, ordering = FALSE)) |>
      DT::formatPercentage("Share", digits = 1)
  })

  output$survey_compare_plot <- plotly::renderPlotly({
    a <- survey_args()
    s <- summarize_survey_by(cis_tidy, survey_items(), by = a$by, measure = a$measure, questions = a$q,
                             min_responses = input$survey_min_n)
    validate(need(nrow(s) > 0, "No group has enough responses. Try lowering the minimum."))
    if (a$measure == "mean") {
      survey_bar_plot(s, a$by, a$group_label)
    } else {
      survey_heatmap(s, a$by, a$group_label, cis_codebook[question_id == a$q, option])
    }
  })

  output$code_survey_question <- renderText({
    a <- survey_args()
    code_survey_question(input$min_hours, a$q, a$by, a$measure, input$survey_min_n)
  })

  ema_filtered <- reactive({
    days <- unique(as.data.table(filtered()$day_summary)[, .(user_id, start_date = as.Date(start_date))])
    merge(ema_tidy, days, by = c("user_id", "start_date"))
  }) |> bindCache(input$min_hours)

  ema_filtered_codebook <- reactive(survey_codebook(ema_filtered())) |> bindCache(input$min_hours)

  output$ema_answers_plot <- plotly::renderPlotly({
    q <- as.integer(req(input$ema_question))
    codebook <- ema_filtered_codebook()
    validate(need(nrow(codebook[question_id == q]) > 0, "No answers on the included days."))
    answer_share_plot(codebook, q)
  })

  output$ema_behavior <- DT::renderDT({
    q <- as.integer(req(input$ema_question))
    tbl <- ema_behavior_table(ema_filtered(), filtered()$day_summary, ema_filtered_codebook(), q)
    DT::datatable(tbl, rownames = FALSE, fillContainer = FALSE,
                  options = list(dom = "t", pageLength = 50, ordering = FALSE)) |>
      DT::formatRound(c("Trips per day", "Activities per day", "Hours recorded"), digits = 1)
  })

  output$code_ema_question <- renderText(code_ema_question(input$min_hours, as.integer(req(input$ema_question))))

  # Code panels start collapsed, and Shiny doesn't render hidden outputs by default
  for (id in c("code_valid_days", "code_overview", "code_timeline", "code_summary", "code_chord", "code_chains",
               "code_survey_participation", "code_survey_question", "code_ema_question")) {
    outputOptions(output, id, suspendWhenHidden = FALSE)
  }
}

shinyApp(ui, server)
