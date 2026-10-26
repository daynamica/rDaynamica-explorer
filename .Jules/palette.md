## 2025-05-10 - Dynamic ARIA labels and Focus Indicators on Code Snippet Copy Controls
**Learning:** Collapsible code panels (`<details>` / `<summary>`) and action buttons in Shiny web applications often lack dynamic `aria-label` announcements when state changes (e.g., after copying code) and default focus indicators can be missing or inconsistent during keyboard tab navigation.
**Action:** Always provide explicit `aria-label` attributes on icon/action buttons in code panels, dynamically update the `aria-label` attribute in JavaScript on user interaction, and add clear `:focus-visible` CSS outline rules for interactive `<summary>` and `.copy-code` elements.

## 2025-10-26 - Keyboard Event Listeners for Shiny Slider Animation ARIA Updates
**Learning:** Shiny's animated sliders (`sliderInput` with `animate = TRUE`) generate a `.slider-animate-button` that can be toggled via keyboard (Space or Enter keys) as well as mouse clicks. Standard click-only JS event listeners miss keyboard toggles, leaving dynamic screen reader announcements (`aria-label`) out of sync during keyboard navigation.
**Action:** Attach keydown event listeners checking for Space (`' '`) and `'Enter'` keys alongside click listeners to ensure ARIA label updates run on all user interactions.
