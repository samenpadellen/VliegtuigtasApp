// Scant de huidige pagina naar tasafmetingen (L × B × D in cm), gewicht (kg)
// en productcontext (naam + afbeelding). Draait alleen op verzoek van de
// popup — geen achtergrond-scraping of tracking.

(function () {
  function numberFrom(value) {
    if (value == null) return null;
    if (typeof value === "number") return value;
    const n = parseFloat(String(value).replace(",", "."));
    return Number.isFinite(n) ? n : null;
  }

  // Plausibele handbagagematen: voorkomt dat we bv. "180 x 90 x 75 cm"
  // meubelmaten of "2 x 3 x 4" verpakkingsaantallen oppikken.
  function plausibleDims(dims) {
    const vals = [dims.length, dims.width, dims.depth].filter((v) => v != null);
    if (vals.length < 2) return false;
    return vals.every((v) => v >= 4 && v <= 120);
  }

  function unwrapValue(v) {
    return v && v.value !== undefined ? v.value : v;
  }

  function productFromJsonLd() {
    const scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"]'));
    for (const script of scripts) {
      let parsed;
      try {
        parsed = JSON.parse(script.textContent);
      } catch (e) {
        continue;
      }
      const candidates = Array.isArray(parsed) ? parsed : [parsed];
      for (const node of candidates) {
        const items = node && node["@graph"] ? node["@graph"] : [node];
        for (const item of items) {
          if (!item || typeof item !== "object") continue;
          const type = item["@type"];
          const isProduct = type === "Product" || (Array.isArray(type) && type.includes("Product"));
          if (!isProduct) continue;
          return item;
        }
      }
    }
    return null;
  }

  function dimsFromJsonLd(product) {
    if (!product) return null;
    const dims = {
      length: numberFrom(unwrapValue(product.height)),
      width: numberFrom(unwrapValue(product.width)),
      depth: numberFrom(unwrapValue(product.depth)),
      weight: numberFrom(unwrapValue(product.weight))
    };
    return plausibleDims(dims) ? dims : null;
  }

  function dimsFromText() {
    const text = document.body ? document.body.innerText : "";
    if (!text) return null;

    // Alle "55 x 40 x 20 cm"-achtige matches verzamelen en de meest
    // plausibele kiezen (sommige pagina's noemen ook doos-/wielmaten).
    const re = /(\d{1,3}(?:[.,]\d)?)\s*[x×]\s*(\d{1,3}(?:[.,]\d)?)\s*[x×]\s*(\d{1,3}(?:[.,]\d)?)\s*cm/gi;
    let best = null;
    let match;
    while ((match = re.exec(text)) !== null) {
      const dims = {
        length: numberFrom(match[1]),
        width: numberFrom(match[2]),
        depth: numberFrom(match[3])
      };
      if (!plausibleDims(dims)) continue;
      // Voorkeur voor de eerste plausibele match met de grootste zijde
      // in het typische handbagagebereik (30–70 cm).
      const maxSide = Math.max(dims.length, dims.width, dims.depth);
      if (!best || (maxSide >= 30 && maxSide <= 70 && best.score < 1)) {
        best = { dims, score: maxSide >= 30 && maxSide <= 70 ? 1 : 0 };
      }
      if (best && best.score === 1) break;
    }
    if (!best) {
      // Gelabelde losse maten: "Hoogte: 55 cm" / "Breedte 40cm" / "Diepte: 20 cm"
      const grab = (label) => {
        const m = text.match(new RegExp(label + "\\s*:?\\s*(\\d{1,3}(?:[.,]\\d)?)\\s*cm", "i"));
        return m ? numberFrom(m[1]) : null;
      };
      const labeled = {
        length: grab("(?:hoogte|height)"),
        width: grab("(?:breedte|width)"),
        depth: grab("(?:diepte|depth)")
      };
      if (plausibleDims(labeled)) best = { dims: labeled, score: 0 };
    }
    if (!best) return null;

    const weightMatch = text.match(/(\d{1,2}(?:[.,]\d{1,2})?)\s*kg/i);
    return {
      length: best.dims.length,
      width: best.dims.width,
      depth: best.dims.depth,
      weight: weightMatch ? numberFrom(weightMatch[1]) : null
    };
  }

  function metaContent(selector) {
    const el = document.querySelector(selector);
    return el ? el.getAttribute("content") : null;
  }

  function productContext(product) {
    let name = product && typeof product.name === "string" ? product.name : null;
    let image = null;
    if (product && product.image) {
      const img = Array.isArray(product.image) ? product.image[0] : product.image;
      image = typeof img === "string" ? img : img && img.url ? img.url : null;
    }
    name = name || metaContent('meta[property="og:title"]') || document.title || null;
    image = image || metaContent('meta[property="og:image"]');
    return { name, image };
  }

  function scan() {
    const product = productFromJsonLd();
    const dims = dimsFromJsonLd(product) || dimsFromText();
    const context = productContext(product);
    if (!dims && !context.name) return null;
    return Object.assign({}, dims || {}, {
      productName: context.name,
      productImage: context.image,
      source: dims ? (dimsFromJsonLd(product) ? "structured" : "text") : null
    });
  }

  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message && message.type === "VT_SCAN") {
      sendResponse(scan());
      return true;
    }
  });
})();
