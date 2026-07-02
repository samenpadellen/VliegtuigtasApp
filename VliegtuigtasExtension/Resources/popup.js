(function () {
  const API_BASE = "https://www.vliegtuigtas.com/api/public/v1";
  const API_KEY = "lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf";
  const SHOP_URL = "https://www.vliegtuigtas.com/tassen";
  const AIRLINES_CACHE_KEY = "vt_airlines_cache";
  const AIRLINES_CACHE_TTL_MS = 5 * 60 * 1000;
  const LAST_AIRLINE_KEY = "vt_last_airline_slug";

  const els = {
    airline: document.getElementById("airline"),
    length: document.getElementById("length"),
    width: document.getElementById("width"),
    depth: document.getElementById("depth"),
    weight: document.getElementById("weight"),
    product: document.getElementById("product"),
    productImage: document.getElementById("productImage"),
    productName: document.getElementById("productName"),
    autoDetectNote: document.getElementById("autoDetectNote"),
    checkButton: document.getElementById("checkButton"),
    result: document.getElementById("result")
  };

  let autoCheckDone = false;

  function apiHeaders(extra) {
    return Object.assign(
      { Authorization: `Bearer ${API_KEY}`, Accept: "application/json" },
      extra || {}
    );
  }

  async function fetchAirlines() {
    const cached = await browser.storage.local.get(AIRLINES_CACHE_KEY);
    const entry = cached[AIRLINES_CACHE_KEY];
    if (entry && Date.now() - entry.at < AIRLINES_CACHE_TTL_MS) {
      return entry.value;
    }
    const res = await fetch(`${API_BASE}/airlines`, { headers: apiHeaders() });
    if (!res.ok) throw new Error(`Server fout (${res.status})`);
    const json = await res.json();
    const airlines = json.data || [];
    await browser.storage.local.set({
      [AIRLINES_CACHE_KEY]: { value: airlines, at: Date.now() }
    });
    return airlines;
  }

  async function populateAirlines() {
    try {
      const airlines = await fetchAirlines();
      const stored = await browser.storage.local.get(LAST_AIRLINE_KEY);
      const lastSlug = stored[LAST_AIRLINE_KEY];

      els.airline.innerHTML = "";
      const placeholder = document.createElement("option");
      placeholder.value = "";
      placeholder.textContent = "Kies een maatschappij…";
      els.airline.appendChild(placeholder);

      airlines.forEach((airline) => {
        const option = document.createElement("option");
        option.value = airline.slug;
        option.textContent = airline.name;
        els.airline.appendChild(option);
      });

      if (lastSlug && airlines.some((a) => a.slug === lastSlug)) {
        els.airline.value = lastSlug;
      }

      els.airline.disabled = false;
      updateCheckButtonState();
      maybeAutoCheck();
    } catch (e) {
      els.airline.innerHTML = '<option value="">Kon maatschappijen niet laden</option>';
    }
  }

  function setPrefilled(input, value) {
    input.value = value;
    input.classList.remove("prefilled");
    // Herstart de glow-animatie ook bij een tweede scan.
    void input.offsetWidth;
    input.classList.add("prefilled");
  }

  async function prefillFromPage() {
    try {
      const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
      if (!tab || !tab.id) return;
      const scan = await browser.tabs.sendMessage(tab.id, { type: "VT_SCAN" });
      if (!scan) return;

      if (scan.productName) {
        els.productName.textContent = scan.productName;
        if (scan.productImage) {
          els.productImage.src = scan.productImage;
          els.productImage.classList.remove("hidden");
        }
        els.product.classList.remove("hidden");
      }

      if (scan.length) setPrefilled(els.length, Math.round(scan.length));
      if (scan.width) setPrefilled(els.width, Math.round(scan.width));
      if (scan.depth) setPrefilled(els.depth, Math.round(scan.depth));
      if (scan.weight) setPrefilled(els.weight, scan.weight);

      if (scan.length || scan.width || scan.depth) {
        els.autoDetectNote.textContent =
          scan.source === "structured"
            ? "Maten gevonden in de productdata van deze pagina."
            : "Maten gevonden op deze pagina — controleer ze even.";
        els.autoDetectNote.classList.remove("hidden");
      }

      updateCheckButtonState();
      maybeAutoCheck();
    } catch (e) {
      // Content script niet beschikbaar op deze pagina (bv. interne pagina's) — negeren.
    }
  }

  function formComplete() {
    return (
      !!els.airline.value &&
      [els.length, els.width, els.depth, els.weight].every(
        (input) => parseFloat(input.value) > 0
      )
    );
  }

  function updateCheckButtonState() {
    els.checkButton.disabled = !formComplete();
  }

  // Alles al bekend (onthouden maatschappij + gescande maten)? Dan meteen
  // checken — de gebruiker opent de popup en ziet direct het antwoord.
  function maybeAutoCheck() {
    if (autoCheckDone || !formComplete()) return;
    autoCheckDone = true;
    runCheck();
  }

  function verdictInfo(status, target) {
    switch (status) {
      case "fit":
        return {
          cssClass: "ok",
          title: "Je tas past! ✓",
          message:
            target === "large"
              ? "Past als grote handbagage (cabin bag)."
              : target === "small"
              ? "Past als klein persoonlijk item (onder de stoel)."
              : "Past als handbagage."
        };
      case "too_large":
        return { cssClass: "fail", title: "Helaas, te groot", message: "De afmetingen overschrijden de toegestane maten." };
      case "too_heavy":
        return { cssClass: "fail", title: "Helaas, te zwaar", message: "Het gewicht is te hoog voor dit ticket type." };
      case "no_match":
        return { cssClass: "warning", title: "Helaas, geen match", message: "Geen passende variant gevonden voor deze maten." };
      default:
        return { cssClass: "fail", title: "Helaas", message: "" };
    }
  }

  // Per-dimensie vergelijking van jouw maten met de toegestane maten van het
  // ticket, zodat je precies ziet wélke kant te groot is en met hoeveel.
  function dimComparisonHtml(data) {
    const variant = data.variant;
    if (!variant) return "";

    const useLarge = data.target !== "small" && variant.large_l_cm != null;
    const allowed = useLarge
      ? { l: variant.large_l_cm, w: variant.large_w_cm, d: variant.large_d_cm }
      : { l: variant.small_l_cm, w: variant.small_w_cm, d: variant.small_d_cm };
    if (allowed.l == null && allowed.w == null && allowed.d == null) return "";

    const entered = {
      l: parseFloat(els.length.value),
      w: parseFloat(els.width.value),
      d: parseFloat(els.depth.value)
    };
    // Vergelijk gesorteerd (grootste bij grootste), net als bij het inpakken:
    // een tas mag "gedraaid" worden ingepakt.
    const sortedEntered = [entered.l, entered.w, entered.d].sort((a, b) => b - a);
    const sortedAllowed = [allowed.l, allowed.w, allowed.d]
      .filter((v) => v != null)
      .sort((a, b) => b - a);

    const labels = ["Langste zijde", "Middelste zijde", "Kortste zijde"];
    const rows = sortedAllowed
      .map((max, i) => {
        const val = sortedEntered[i];
        if (val == null) return "";
        const diff = val - max;
        const cls = diff > 0 ? "over" : "under";
        const diffText = diff > 0 ? ` (+${diff.toFixed(0)} cm)` : "";
        return `<li><span class="dim-label">${labels[i]}</span><span class="dim-value ${cls}">${val.toFixed(0)} / max ${max.toFixed(0)} cm${diffText}</span></li>`;
      })
      .join("");

    let weightRow = "";
    if (variant.max_weight_kg != null) {
      const w = parseFloat(els.weight.value);
      const over = w > variant.max_weight_kg;
      weightRow = `<li><span class="dim-label">Gewicht</span><span class="dim-value ${over ? "over" : "under"}">${w.toFixed(1)} / max ${Number(variant.max_weight_kg).toFixed(0)} kg</span></li>`;
    }

    return `<ul class="dim-compare">${rows}${weightRow}</ul>`;
  }

  function escapeHtml(s) {
    const div = document.createElement("div");
    div.textContent = s;
    return div.innerHTML;
  }

  async function runCheck() {
    els.checkButton.disabled = true;
    els.checkButton.textContent = "Controleren…";
    els.result.classList.add("hidden");

    const slug = els.airline.value;
    await browser.storage.local.set({ [LAST_AIRLINE_KEY]: slug });

    try {
      const res = await fetch(`${API_BASE}/check`, {
        method: "POST",
        headers: apiHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({
          airline_slug: slug,
          length_cm: parseFloat(els.length.value),
          width_cm: parseFloat(els.width.value),
          depth_cm: parseFloat(els.depth.value),
          weight_kg: parseFloat(els.weight.value),
          source: "safari-extension"
        })
      });
      if (!res.ok) throw new Error(`Server fout (${res.status})`);
      const json = await res.json();
      if (!json.data) throw new Error("Geen data ontvangen");

      const info = verdictInfo(json.data.status, json.data.target);
      const isFit = json.data.status === "fit";
      const airlineName = els.airline.options[els.airline.selectedIndex].textContent;

      let html = `
        <p class="result-title">${info.title}</p>
        <p class="result-message">${escapeHtml(airlineName)} · ${info.message}</p>
        ${dimComparisonHtml(json.data)}
      `;
      if (!isFit) {
        const cta = `${SHOP_URL}?airline=${encodeURIComponent(slug)}`;
        html += `<a class="result-cta" href="${cta}" target="_blank" rel="noopener">Bekijk tassen die wél passen →</a>`;
      }

      els.result.className = `result ${info.cssClass}`;
      els.result.innerHTML = html;
    } catch (e) {
      els.result.className = "result fail";
      els.result.innerHTML = `<p class="result-title">Oeps</p><p class="result-message">${escapeHtml(e.message || "Er ging iets mis.")}</p>`;
    } finally {
      els.result.classList.remove("hidden");
      els.checkButton.textContent = "Controleer nu";
      updateCheckButtonState();
    }
  }

  els.airline.addEventListener("change", updateCheckButtonState);
  [els.length, els.width, els.depth, els.weight].forEach((input) =>
    input.addEventListener("input", updateCheckButtonState)
  );
  els.checkButton.addEventListener("click", runCheck);

  populateAirlines();
  prefillFromPage();
})();
