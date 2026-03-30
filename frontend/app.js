const list = document.getElementById("paradigm-list");
const backendSwitcher = document.getElementById("backend-switcher");
const backendSelect = document.getElementById("backend-select");
const backendTarget = document.getElementById("backend-target");
const statusText = document.getElementById("status");
const appConfig = window.APP_CONFIG ?? {};
const backendStorageKey = "dev-paradigm-showdown.backend-target";
const backendTargets = resolveBackendTargets();
let activeBackendKey = resolveInitialBackendKey();

renderBackendSelector();
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
    setStatus(`Could not load data from ${describeBackendTarget(getActiveBackendTarget())}.`);
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
    setStatus(`Could not save your vote to ${describeBackendTarget(getActiveBackendTarget())}.`);
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
  const activeTarget = getActiveBackendTarget();
  return activeTarget.apiBaseUrl ? `${activeTarget.apiBaseUrl}${path}` : path;
}

function normalizeApiBaseUrl(value) {
  if (!value) {
    return "";
  }

  return value.endsWith("/") ? value.slice(0, -1) : value;
}

function resolveBackendTargets() {
  const configuredTargets = Array.isArray(appConfig.backendTargets)
    ? appConfig.backendTargets
    : [];
  const seenKeys = new Set();
  const normalizedTargets = configuredTargets
    .filter(
      (target) =>
        target &&
        typeof target.key === "string" &&
        typeof target.label === "string",
    )
    .map((target) => ({
      key: target.key,
      label: target.label,
      apiBaseUrl: normalizeApiBaseUrl(target.apiBaseUrl ?? ""),
    }))
    .filter((target) => {
      if (seenKeys.has(target.key)) {
        return false;
      }
      seenKeys.add(target.key);
      return true;
    });

  if (normalizedTargets.length > 0) {
    return normalizedTargets;
  }

  return [
    {
      key: appConfig.defaultBackendKey || "default",
      label: appConfig.backendLabel || "Configured backend",
      apiBaseUrl: normalizeApiBaseUrl(appConfig.apiBaseUrl),
    },
  ];
}

function resolveInitialBackendKey() {
  const storedKey = readStoredBackendKey();
  if (storedKey && backendTargets.some((target) => target.key === storedKey)) {
    return storedKey;
  }

  if (
    appConfig.defaultBackendKey &&
    backendTargets.some((target) => target.key === appConfig.defaultBackendKey)
  ) {
    return appConfig.defaultBackendKey;
  }

  return backendTargets[0].key;
}

function readStoredBackendKey() {
  try {
    return window.localStorage.getItem(backendStorageKey);
  } catch (error) {
    return null;
  }
}

function saveStoredBackendKey(value) {
  try {
    window.localStorage.setItem(backendStorageKey, value);
  } catch (error) {
    // Ignore storage access failures; the selector still works for the current page.
  }
}

function getActiveBackendTarget() {
  return (
    backendTargets.find((target) => target.key === activeBackendKey) ??
    backendTargets[0]
  );
}

function renderBackendSelector() {
  if (!backendSwitcher || !backendSelect) {
    return;
  }

  if (backendTargets.length <= 1) {
    backendSwitcher.hidden = true;
    return;
  }

  backendSwitcher.hidden = false;
  backendSelect.innerHTML = "";

  backendTargets.forEach((target) => {
    const option = document.createElement("option");
    option.value = target.key;
    option.textContent = target.label;
    backendSelect.appendChild(option);
  });

  backendSelect.value = activeBackendKey;
  backendSelect.addEventListener("change", handleBackendChange);
}

function renderBackendTarget() {
  if (!backendTarget) {
    return;
  }

  backendTarget.textContent = `Active backend: ${describeBackendTarget(
    getActiveBackendTarget(),
  )}`;
}

function describeBackendTarget(target) {
  if (target.apiBaseUrl) {
    return `${target.label} (${target.apiBaseUrl})`;
  }

  return `${target.label} (/api)`;
}

function handleBackendChange(event) {
  activeBackendKey = event.target.value;
  saveStoredBackendKey(activeBackendKey);
  renderBackendTarget();
  fetchParadigms();
}

fetchParadigms();
