(function () {
  "use strict";

  const sanitizer = window.SafePasteSanitizer;

  const inputText = document.getElementById("input-text");
  const outputText = document.getElementById("output-text");
  const sanitizeButton = document.getElementById("sanitize-button");
  const copyButton = document.getElementById("copy-button");
  const clearButton = document.getElementById("clear-button");
  const redactIp = document.getElementById("redact-ip");
  const redactionCount = document.getElementById("redaction-count");
  const categoryList = document.getElementById("category-list");
  const statusMessage = document.getElementById("status-message");
  const outputPreview = optionalSelector("[data-output-preview]");
  const scanRegion = optionalSelector("[data-scan-region]");
  const workspaceShell = optionalSelector("[data-workspace-shell]");
  let copyResetTimer = null;

  function optionalSelector(selector) {
    if (typeof document.querySelector !== "function") {
      return null;
    }
    return document.querySelector(selector);
  }

  function renderCategories(categories) {
    categoryList.replaceChildren();

    if (categories.length === 0) {
      const emptyItem = document.createElement("li");
      emptyItem.textContent = "No sensitive categories detected.";
      categoryList.appendChild(emptyItem);
      return;
    }

    categories.forEach(function (category) {
      const item = document.createElement("li");
      item.className = "category-chip";
      item.textContent = category.replace(/_/g, " ");
      categoryList.appendChild(item);
    });
  }

  function markerCategory(marker) {
    return marker.replace(/^\[REDACTED_/, "").replace(/\]$/, "").replace(/_/g, " ");
  }

  function markerSeverity(marker) {
    if (/API_KEY|PASSWORD|AUTHORIZATION|BEARER|JWT|AWS|SLACK/.test(marker)) {
      return "high";
    }
    if (/EMAIL|USERNAME|USER/.test(marker)) {
      return "medium";
    }
    return "low";
  }

  function appendTextNode(parent, value) {
    if (!value) {
      return;
    }
    if (typeof document.createTextNode === "function") {
      parent.appendChild(document.createTextNode(value));
    } else {
      const span = document.createElement("span");
      span.textContent = value;
      parent.appendChild(span);
    }
  }

  function renderVisualPreview(value) {
    if (!outputPreview) {
      return;
    }

    outputPreview.replaceChildren();

    if (!value) {
      outputPreview.classList.add("empty");
      outputPreview.textContent = "Your visual redaction preview appears here.";
      return;
    }

    outputPreview.classList.remove("empty");

    const markerPattern = /\[REDACTED_[A-Z_]+\]/g;
    let cursor = 0;
    let match = markerPattern.exec(value);

    while (match) {
      appendTextNode(outputPreview, value.slice(cursor, match.index));

      const marker = match[0];
      const bar = document.createElement("span");
      bar.className = `redaction-bar ${markerSeverity(marker)}`;
      bar.setAttribute("data-category", markerCategory(marker));
      bar.textContent = "████████";
      outputPreview.appendChild(bar);

      cursor = match.index + marker.length;
      match = markerPattern.exec(value);
    }

    appendTextNode(outputPreview, value.slice(cursor));
  }

  function pulseScan() {
    [scanRegion, workspaceShell].forEach(function (element) {
      if (element && element.classList) {
        element.classList.add("is-scanning");
      }
    });

    if (typeof setTimeout === "function") {
      setTimeout(function () {
        [scanRegion, workspaceShell].forEach(function (element) {
          if (element && element.classList) {
            element.classList.remove("is-scanning");
          }
        });
      }, 420);
    }
  }

  function resetCopyFeedback() {
    if (copyResetTimer && typeof clearTimeout === "function") {
      clearTimeout(copyResetTimer);
    }
    copyResetTimer = null;
    copyButton.textContent = "Copy sanitized text";
  }

  function runSanitize() {
    resetCopyFeedback();
    pulseScan();

    const result = sanitizer.sanitize(inputText.value, {
      redactIpAddresses: redactIp.checked
    });

    outputText.value = result.sanitized;
    renderVisualPreview(result.sanitized);
    redactionCount.textContent = String(result.redactionCount);
    renderCategories(result.categories);
    copyButton.disabled = result.sanitized.length === 0;

    if (result.redactionCount === 0) {
      statusMessage.textContent = "No sensitive patterns detected. Review the text before sharing.";
    } else {
      const plural = result.redactionCount === 1 ? "value" : "values";
      statusMessage.textContent = `Sanitized locally - ${result.redactionCount} sensitive ${plural} found. Review before copying.`;
    }
  }

  function clearAll() {
    resetCopyFeedback();
    inputText.value = "";
    outputText.value = "";
    renderVisualPreview("");
    redactionCount.textContent = "0";
    renderCategories([]);
    copyButton.disabled = true;
    statusMessage.textContent = "Cleared. Paste logs to begin.";
    inputText.focus();
  }

  async function copySanitizedText() {
    if (!outputText.value) {
      return;
    }

    try {
      await navigator.clipboard.writeText(outputText.value);
      copyButton.textContent = "Copied";
      statusMessage.textContent = "Copied sanitized text. Review where you paste it next.";
      if (typeof setTimeout === "function") {
        copyResetTimer = setTimeout(function () {
          copyButton.textContent = "Copy sanitized text";
          copyResetTimer = null;
        }, 1800);
      }
    } catch (error) {
      resetCopyFeedback();
      outputText.focus();
      outputText.select();
      statusMessage.textContent = "Clipboard permission unavailable. Sanitized text is selected for manual copy.";
    }
  }

  sanitizeButton.addEventListener("click", runSanitize);
  clearButton.addEventListener("click", clearAll);
  copyButton.addEventListener("click", copySanitizedText);
  redactIp.addEventListener("change", function () {
    if (inputText.value || outputText.value) {
      runSanitize();
    }
  });
})();
