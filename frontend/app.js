const list = document.getElementById("paradigm-list");
const statusText = document.getElementById("status");

async function fetchParadigms() {
  setStatus("Loading...");

  try {
    const response = await fetch("/api/paradigms");
    if (!response.ok) {
      throw new Error("Failed to load paradigms");
    }

    const paradigms = await response.json();
    renderParadigms(paradigms);
    setStatus("");
  } catch (error) {
    setStatus("Could not load data. Check that the API container is running.");
  }
}

async function vote(id) {
  setStatus("Saving vote...");

  try {
    const response = await fetch(`/api/paradigms/${id}/vote`, {
      method: "POST",
    });

    if (!response.ok) {
      throw new Error("Failed to submit vote");
    }

    await fetchParadigms();
    setStatus("Vote recorded.");
  } catch (error) {
    setStatus("Could not save your vote. Try again.");
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

fetchParadigms();
