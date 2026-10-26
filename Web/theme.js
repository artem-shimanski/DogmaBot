// Colour theme of the pages: as the system, light or dark, chosen with a [data-theme-toggle] button and remembered
// in the browser. Loaded in <head> without defer, so the theme is set before the first paint.
//
// The root element gets data-theme-choice (system, light or dark: what the viewer picked) and data-theme (light or
// dark: what is shown). The pages style the dark theme by data-theme alone, so the system preference is resolved
// here and followed while the page is open.
(() => {
  const key = "theme";
  const choices = ["system", "light", "dark"];
  const root = document.documentElement;
  const system = matchMedia("(prefers-color-scheme: dark)");

  // Storage can be missing or throw (private windows, blocked site data); the theme then follows the system.
  function stored() {
    try {
      const value = localStorage.getItem(key);
      return choices.includes(value) ? value : "system";
    } catch {
      return "system";
    }
  }

  function apply(choice) {
    root.dataset.themeChoice = choice;
    root.dataset.theme = choice === "system" ? (system.matches ? "dark" : "light") : choice;
  }

  apply(stored());
  system.addEventListener("change", () => apply(root.dataset.themeChoice));

  // Delegated, as the fit page draws its header again on every change.
  document.addEventListener("click", event => {
    if (!event.target.closest("[data-theme-toggle]")) return;
    const next = choices[(choices.indexOf(root.dataset.themeChoice) + 1) % choices.length];
    try {
      localStorage.setItem(key, next);
    } catch {
      // Not remembered; it still applies to this page.
    }
    apply(next);
  });
})();
