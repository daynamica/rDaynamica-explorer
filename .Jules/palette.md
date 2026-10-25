## 2025-05-10 - Dynamic ARIA labels and Focus Indicators on Code Snippet Copy Controls
**Learning:** Collapsible code panels (`<details>` / `<summary>`) and action buttons in Shiny web applications often lack dynamic `aria-label` announcements when state changes (e.g., after copying code) and default focus indicators can be missing or inconsistent during keyboard tab navigation.
**Action:** Always provide explicit `aria-label` attributes on icon/action buttons in code panels, dynamically update the `aria-label` attribute in JavaScript on user interaction, and add clear `:focus-visible` CSS outline rules for interactive `<summary>` and `.copy-code` elements.

## 2025-05-11 - Accessible Live Announcements for Shiny Reactive Outputs and Slider Animation Controls
**Learning:** Built-in Shiny `sliderInput(animate = TRUE)` components generate `.slider-animate-button` elements that lack explicit `aria-label` attributes for play/pause states, and dynamic `textOutput()` elements do not automatically announce text changes to assistive technology unless wrapped in an `aria-live="polite"` container.
**Action:** Wrap dynamic text outputs representing time/status updates in `div(aria-live = "polite", aria-atomic = "true", ...)` and attach JavaScript handlers to dynamically assign "Start animation" / "Pause animation" `aria-label` attributes to `.slider-animate-button`.
