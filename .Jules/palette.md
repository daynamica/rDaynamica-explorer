## 2025-05-10 - Dynamic ARIA labels and Focus Indicators on Code Snippet Copy Controls
**Learning:** Collapsible code panels (`<details>` / `<summary>`) and action buttons in Shiny web applications often lack dynamic `aria-label` announcements when state changes (e.g., after copying code) and default focus indicators can be missing or inconsistent during keyboard tab navigation.
**Action:** Always provide explicit `aria-label` attributes on icon/action buttons in code panels, dynamically update the `aria-label` attribute in JavaScript on user interaction, and add clear `:focus-visible` CSS outline rules for interactive `<summary>` and `.copy-code` elements.

## 2025-10-26 - Keyboard Event Listeners for Shiny Slider Animation ARIA Updates
**Learning:** Shiny's animated sliders (`sliderInput` with `animate = TRUE`) generate a `.slider-animate-button` that can be toggled via keyboard (Space or Enter keys) as well as mouse clicks. Standard click-only JS event listeners miss keyboard toggles, leaving dynamic screen reader announcements (`aria-label`) out of sync during keyboard navigation.
**Action:** Attach keydown event listeners checking for Space (`' '`) and `'Enter'` keys alongside click listeners to ensure ARIA label updates run on all user interactions.

## 2026-11-01 - Dynamic Reactive Alt Text for Base R Graphics in Shiny
**Learning:** Non-ggplot base R plots rendered via `renderPlot()` default to `alt = "Plot object"` or generic non-descriptive alt attributes on the underlying `<img>` tag. For time-series or animated diagrams (like chord diagrams driven by slider inputs), this leaves screen reader users unaware of the specific time window or data state being viewed.
**Action:** Provide a reactive expression to the `alt` parameter of `renderPlot(..., alt = ...)` that dynamically interpolates active filters or animation time frames into descriptive text (e.g., "Daily rhythm chord diagram showing activity and trip transitions from HH:MM to HH:MM").

## 2026-11-03 - Tab-Aware Skip-to-Content Navigation and Main Landmark in Shiny Navbar Apps
**Learning:** In tabbed Shiny applications (`bslib::page_navbar`), static `#main-content` targets placed inside a single `nav_panel` break keyboard skip-to-content navigation on other tabs because inactive tab panes are hidden (`display: none`), while missing landmarks leave assistive technologies without a main landmark.
**Action:** Intercept skip-link activation to dynamically focus and scroll to the currently active tab pane (`.tab-content > .tab-pane.active`) with `tabindex="-1"`, and assign `role="main"` to `.tab-content` on DOM load.

## 2026-11-04 - Visible Focus Indicators for bslib Full-Screen Card Toggle Controls
**Learning:** In `bslib` cards configured with `full_screen = TRUE`, the expand button (`.bslib-full-screen-enter`) and close anchor (`.bslib-full-screen-exit`) lack explicit `:focus-visible` styling matching the custom design system theme, leaving keyboard users with browser-default or low-contrast outlines when tabbing through expandable cards and overlays.
**Action:** Provide explicit `:focus-visible` CSS rules for both `.bslib-full-screen-enter` and `.bslib-full-screen-exit` using the primary brand color and an offset matching other interactive controls.

## 2026-11-05 - Dynamic ARIA Labels and Focus Indicators for bslib Sidebar Toggles
**Learning:** In `bslib` sidebar layouts, the collapse toggle button (`.collapse-toggle`) is an icon-only button that lacks an explicit `aria-label` (relying only on a static `title` attribute) and lacks design-system `:focus-visible` outline styling. Furthermore, the accessible name is not synchronized when toggled between collapsed and expanded states.
**Action:** Add explicit `:focus-visible` styling to `.collapse-toggle` using brand outline variables, and dynamically set `aria-label` and `title` to "Collapse sidebar" or "Expand sidebar" on user interaction and the `bslib.sidebar` event.
