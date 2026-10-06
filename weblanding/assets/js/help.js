(function () {
  const search = document.getElementById("knowledge-search");
  const items = Array.from(document.querySelectorAll("[data-knowledge-item]"));
  const empty = document.getElementById("knowledge-empty");

  search?.addEventListener("input", function () {
    const query = search.value.trim().toLowerCase();
    let visibleCount = 0;
    items.forEach(function (item) {
      const searchable = `${item.textContent || ""} ${item.dataset.keywords || ""}`.toLowerCase();
      const visible = !query || searchable.includes(query);
      item.hidden = !visible;
      if (visible) visibleCount += 1;
    });
    if (empty) empty.hidden = visibleCount !== 0;
  });

  const form = document.getElementById("feedback-form");
  const status = document.getElementById("feedback-status");
  const submitButton = document.getElementById("feedback-submit");
  const apiBaseUrl = "https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod";

  if (!form || !status || !submitButton) return;

  function setStatus(message, tone) {
    status.textContent = message;
    status.className = "feedback-form__status";
    if (tone) status.classList.add(`feedback-form__status--${tone}`);
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault();
    const formData = new FormData(form);
    const payload = {
      name: String(formData.get("name") || "").trim(),
      email: String(formData.get("email") || "").trim(),
      category: String(formData.get("category") || "").trim(),
      message: String(formData.get("feedback") || "").trim(),
      username: "landing-site",
      organization_name: "Public Landing Page",
      version: "weblanding",
      build: "static-help",
      page_url: window.location.href,
      user_agent: window.navigator.userAgent,
    };

    if (!payload.name || !payload.email || !payload.category || payload.message.length < 5) {
      setStatus("Please complete all fields and add a bit more detail.", "error");
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Sending...";
    setStatus("", "");

    try {
      const response = await fetch(`${apiBaseUrl}/feedback`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const responseBody = await response.json().catch(function () { return {}; });
      if (!response.ok || responseBody.success === false) {
        throw new Error(responseBody?.error?.message || "Unable to send feedback right now.");
      }
      form.reset();
      setStatus("Thanks. Your feedback has been sent.", "success");
    } catch (error) {
      setStatus(error.message || "Unable to send feedback right now.", "error");
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = "Send Feedback";
    }
  });
}());
