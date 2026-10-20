# Chord diagram helpers. These mirror rDaynamica::create_individual_plots(),
# which writes every frame to PNG for a GIF, but draw a single frame so the
# app can render it on demand.

# Subtype groups used for the chord diagram (same mapping as the package README)
chord_categories <- c(
  "CAR - DRIVER" = "MOTORIZED TRIP", "CAR - PASSENGER" = "MOTORIZED TRIP",
  "OTHER TRIPS" = "MOTORIZED TRIP", "RAIL" = "MOTORIZED TRIP", "BUS" = "MOTORIZED TRIP",
  "TAXI/UBER/LYFT" = "MOTORIZED TRIP", "VEHICLE" = "MOTORIZED TRIP",
  "WAIT" = "NON-MOTORIZED TRIP", "WALK" = "NON-MOTORIZED TRIP", "BIKE" = "NON-MOTORIZED TRIP",
  "HOME" = "HOME", "WORKPLACE" = "WORK", "FOOD & MEAL" = "EAT OUT",
  "SHOPPING ERRANDS" = "SHOP", "UNKNOWN" = "MISSING",
  "CARE GIVING" = "OTHER", "CIVIL ERRANDS" = "OTHER", "COMMUNITY & CULTURAL" = "OTHER",
  "EDUCATION" = "OTHER", "FUN & LEISURE" = "OTHER", "MEDICAL & FITNESS" = "OTHER",
  "OTHER ACTIVITIES" = "OTHER", "RELIGIOUS & SPIRITUAL" = "OTHER"
)

# Fixed colors per group, anchored on the Daynamica brand green for Home
chord_colors <- c(
  "HOME" = "#6BAA43", "WORK" = "#3F5A6B", "OTHER" = "#A7B3BB", "SHOP" = "#9B6FB0",
  "EAT OUT" = "#E3A33B", "MOTORIZED TRIP" = "#D1495B", "NON-MOTORIZED TRIP" = "#4FA3A5",
  "MISSING" = "#D0D0D0"
)
chord_fallback <- c("#80B1D3", "#FDB462", "#FCCDE5", "#BEBADA", "#FFED6F")

# "NON-MOTORIZED TRIP" -> "Non-motorized\ntrip", so labels fit around the circle
chord_label <- function(x) {
  x <- paste0(substr(x, 1, 1), tolower(substring(x, 2)))
  sub(" ", "\n", x)
}

# Returns flow rates between grouped categories for every 15-minute step
prepare_chord_flows <- function(csv_dict_sub) {
  grouped <- suppressMessages(suppressWarnings(rDaynamica::recategorize_calendar_items(
    csv_dict_sub["ucalitems_temporal_plot"],
    orig_cats = names(chord_categories),
    new_cats = unname(chord_categories)
  )))
  seq_data <- rDaynamica::generate_sequence_data(grouped$ucalitems_temporal_plot, unit_length = 5)

  n <- nrow(seq_data$id_key)
  colors <- unname(chord_colors[seq_data$id_key$subtype_decoded])
  colors[is.na(colors)] <- chord_fallback[seq_len(sum(is.na(colors)))]
  category_data <- data.frame(
    label = seq_data$id_key$letters_subtype,
    subtype = seq_data$id_key$subtype_decoded,
    order = seq_len(n),
    color = colors,
    stringsAsFactors = FALSE
  )

  flows <- rDaynamica::flow_rate_calculator(seq_data$wide_sequence_data, split_size = 3) %>%
    rDaynamica::process_flow_data(category_data = category_data)

  list(flows = flows, category_data = category_data)
}

draw_chord_frame <- function(chord, frame) {
  category_data <- chord$category_data
  frame_data <- dplyr::filter(chord$flows, .frame == frame)
  if (nrow(frame_data) == 0) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No transitions recorded at this time.")
    return(invisible())
  }

  present <- dplyr::filter(category_data, subtype %in% unique(frame_data$starting_state))
  grid_col <- stats::setNames(present$color, present$subtype)

  circlize::circos.clear()
  graphics::par(mar = rep(0, 4), cex = 1)
  circlize::circos.par(start.degree = 90, track.margin = c(-0.1, 0.1), gap.after = 10,
                       points.overflow.warning = FALSE, clock.wise = FALSE)

  suppressMessages(circlize::chordDiagram(
    x = frame_data[, c("starting_state", "ending_state", "flow_rate")],
    directional = 1,
    order = category_data$subtype[category_data$subtype %in% names(grid_col)],
    grid.col = grid_col,
    annotationTrack = "grid",
    transparency = 0.25, annotationTrackHeight = c(0.05, 0.12),
    direction.type = c("diffHeight", "arrows"), link.arr.type = "big.arrow",
    diffHeight = -0.04, link.sort = TRUE, link.largest.ontop = TRUE
  ))

  # Name only sectors wide enough to hold a label; the legend covers the rest
  total_flow <- 2 * sum(frame_data$flow_rate)
  circlize::circos.track(track.index = 1, bg.border = NA, panel.fun = function(x, y) {
    xlim <- circlize::get.cell.meta.data("xlim")
    if (diff(xlim) / total_flow > 0.07) {
      circlize::circos.text(x = mean(xlim), y = 4, labels = chord_label(circlize::get.cell.meta.data("sector.index")),
                            facing = "bending", cex = 0.85)
    }
    circlize::circos.axis(h = "top", labels.cex = 0.6, labels.niceFacing = FALSE, labels.pos.adjust = FALSE)
  })
  circlize::circos.clear()

  graphics::legend("bottomleft", legend = gsub("\n", " ", chord_label(category_data$subtype)),
                   fill = category_data$color, border = NA, bty = "n", cex = 0.8, inset = 0.01)
}
