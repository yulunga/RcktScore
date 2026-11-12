(function () {
  const dialog = document.querySelector(".registration-dialog");
  const message = dialog.querySelector("[data-registration-message]");

  document.querySelectorAll("[data-start-scoring]").forEach((link) => {
    link.addEventListener("click", async (event) => {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      if (link.getAttribute("aria-busy") === "true") return;

      link.setAttribute("aria-busy", "true");
      try {
        const response = await fetch("/registration/status", {
          cache: "no-store",
          credentials: "omit",
          signal: AbortSignal.timeout(4000),
        });
        const { data } = await response.json();
        if (response.ok && data?.enabled === false && typeof data.message === "string") {
          message.textContent = data.message;
          if (!dialog.open) dialog.showModal();
          return;
        }
        window.location.assign(link.href);
      } catch {
        window.location.assign(link.href);
      } finally {
        link.removeAttribute("aria-busy");
      }
    });
  });
}());
