const list = document.getElementById("paradigm-list");
const backendTarget = document.getElementById("backend-target");
const statusText = document.getElementById("status");
const appConfig = window.APP_CONFIG ?? {};
const apiBaseUrl = normalizeApiBaseUrl(appConfig.apiBaseUrl);

renderBackendTarget();

async function fetchParadigms() {
  setStatus("Loading...");

  try {
    const response = await fetch(buildApiUrl("/api/paradigms"));
    if (!response.ok) {
      throw new Error("Failed to load paradigms");
    }

    const paradigms = await response.json();
    renderParadigms(paradigms);
    setStatus("");
  } catch (error) {
    setStatus(`Could not load data from ${describeBackendTarget()}.`);
  }
}

async function vote(id) {
  setStatus("Saving vote...");

  try {
    const response = await fetch(buildApiUrl(`/api/paradigms/${id}/vote`), {
      method: "POST",
    });

    if (!response.ok) {
      throw new Error("Failed to submit vote");
    }

    await fetchParadigms();
    setStatus("Vote recorded.");
  } catch (error) {
    setStatus(`Could not save your vote to ${describeBackendTarget()}.`);
  }
}

function renderParadigms(paradigms) {
  list.innerHTML = "";

  paradigms.forEach((paradigm) => {
    const card = document.createElement("article");
    card.className = "card";

    const copy = document.createElement("div");
    copy.className = "copy";

    const title = document.createElement("h2");
    title.textContent = paradigm.name;

    const votes = document.createElement("p");
    votes.className = "votes";
    votes.textContent = `${paradigm.votes} vote${paradigm.votes === 1 ? "" : "s"}`;

    const button = document.createElement("button");
    button.className = "vote-button";
    button.textContent = "Vote +1";
    button.addEventListener("click", () => vote(paradigm.id));

    copy.append(title, votes);
    card.append(copy, button);
    list.appendChild(card);
  });
}

function setStatus(message) {
  statusText.textContent = message;
}

function buildApiUrl(path) {
  return apiBaseUrl ? `${apiBaseUrl}${path}` : path;
}

function normalizeApiBaseUrl(value) {
  if (!value) {
    return "";
  }

  return value.endsWith("/") ? value.slice(0, -1) : value;
}

function renderBackendTarget() {
  if (!backendTarget) {
    return;
  }

  backendTarget.textContent = `Backend: ${describeBackendTarget()}`;
}

function describeBackendTarget() {
  if (appConfig.backendLabel && apiBaseUrl) {
    return `${appConfig.backendLabel} (${apiBaseUrl})`;
  }

  if (appConfig.backendLabel) {
    return appConfig.backendLabel;
  }

  if (apiBaseUrl) {
    return apiBaseUrl;
  }

  return "local Docker proxy (/api)";
}

fetchParadigms();
