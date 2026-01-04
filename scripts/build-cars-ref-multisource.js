import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const YEARS = { start: 1970, end: 2026 };

// Dossiers
const OUT_FINAL_DIR = path.resolve("data/vehicles/cars");
const OUT_RAW_DIR = path.resolve("data/vehicles/raw/cars");
const CACHE_DIR = path.resolve(".cache/vehicles");
const JWT_CACHE_DIR = path.resolve(".cache/auth");

// =========================
// CONFIG SOURCES
// =========================
const SOURCES = {
  wikidata: { enabled: true },
  nhtsaProducts: { enabled: true }, // peut 403 -> throttling + retry
  apiNinjas: { enabled: false }, // nécessite API key
  carApiApp: { enabled: true }, // nécessite token+secret => JWT
};

// API keys
const API_NINJAS_KEY = "/fhpYowgK0Ogmu5prwDVBw==0WpuLGJCoyCGSnR8"

// CarAPI credentials (NE JAMAIS coder en dur)
const CARAPI_TOKEN = "d982be3e-f112-46ae-9ea1-c5ddc62c5edb"
const CARAPI_SECRET = "101559ecac4d954ee6a07243143f65d3"

// =========================
// THROTTLING / RETRY
// =========================
function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function getRetryAfterMs(res) {
  const ra = res.headers.get("retry-after");
  if (!ra) return null;
  const seconds = Number(ra);
  if (Number.isFinite(seconds)) return seconds * 1000;
  return null;
}

function sha1(s) {
  return crypto.createHash("sha1").update(s).digest("hex");
}

async function fetchJsonWithCache({
  url,
  cacheKey,
  headers = {},
  baseDelayMs = 400,
  maxRetries = 6,
  backoffBaseMs = 800,
}) {
  const cachePath = path.join(CACHE_DIR, `${cacheKey}.json`);
  if (fs.existsSync(cachePath)) {
    return JSON.parse(fs.readFileSync(cachePath, "utf-8"));
  }

  await sleep(baseDelayMs);

  let attempt = 0;
  while (true) {
    const res = await fetch(url, { headers });

    if (res.ok) {
      const data = await res.json();
      fs.mkdirSync(CACHE_DIR, { recursive: true });
      fs.writeFileSync(cachePath, JSON.stringify(data), "utf-8");
      return data;
    }

    const status = res.status;
    const retryable =
      status === 403 || status === 429 || (status >= 500 && status <= 599);

    if (!retryable || attempt >= maxRetries) {
      const txt = await res.text().catch(() => "");
      throw new Error(`HTTP ${status} for ${url} :: ${txt.slice(0, 200)}`);
    }

    const retryAfter = getRetryAfterMs(res);
    const backoff = retryAfter ?? backoffBaseMs * Math.pow(2, attempt);
    const jitter = Math.floor(Math.random() * 250);

    console.warn(
      `HTTP ${status} => retry in ${backoff + jitter}ms (attempt ${
        attempt + 1
      }/${maxRetries})`
    );
    await sleep(backoff + jitter);
    attempt++;
  }
}

// =========================
// NORMALISATION / DEDUPE
// =========================
function stripDiacritics(s) {
  return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function normalizeMakeName(name) {
  if (!name) return "";
  let s = name.trim();

  s = s
    .replace(
      /\b(AG|GmbH|Inc\.?|Ltd\.?|LLC|S\.A\.|S\.p\.A\.|PLC|Group|Groupe|Company|Corporation|Motors|Motor Company|Holdings?)\b/gi,
      ""
    )
    .replace(/\s{2,}/g, " ")
    .trim();

  const map = new Map([
    ["Audi AG", "Audi"],
    ["Volkswagen Group", "Volkswagen"],
    ["Groupe BMW", "BMW"],
    ["Mercedes-Benz Group", "Mercedes-Benz"],
    ["Fiat Chrysler Automobiles", "Fiat"],
    ["Stellantis North America", "Stellantis"],
  ]);

  return map.get(name) ?? s;
}

function normalizeModelName(model) {
  if (!model) return "";
  let s = model.trim();
  s = s.replace(/\s{2,}/g, " ").trim();
  return s;
}

function isLikelyNonCommercialModel(model) {
  const m = stripDiacritics(model).toLowerCase();
  return /(concept|prototype|show car|one-off|study|vision|concept car|design study)/i.test(
    m
  );
}

function isBadLabel(label) {
  return /^Q\d+$/.test(label);
}

// =========================
// DATA STRUCTURE
// =========================
function ensureYear(store, year) {
  if (!store.has(year)) store.set(year, new Map());
  return store.get(year);
}

function ensureMake(yearMap, make) {
  if (!yearMap.has(make)) {
    yearMap.set(make, {
      models: new Set(),
      sources: new Set(),
      modelSources: new Map(),
    });
  }
  return yearMap.get(make);
}

function addRecord(store, { year, make, model, source }) {
  if (!year || !make || !model) return;

  const yearMap = ensureYear(store, year);
  const makeNode = ensureMake(yearMap, make);

  makeNode.models.add(model);
  makeNode.sources.add(source);

  if (!makeNode.modelSources.has(model))
    makeNode.modelSources.set(model, new Set());
  makeNode.modelSources.get(model).add(source);
}

// =========================
// CONCURRENCY HELPER
// =========================
async function mapLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let i = 0;

  async function worker() {
    while (true) {
      const idx = i++;
      if (idx >= items.length) return;
      results[idx] = await mapper(items[idx], idx);
    }
  }

  const workers = Array.from({ length: Math.min(limit, items.length) }, () =>
    worker()
  );
  await Promise.all(workers);
  return results;
}

// =========================
// SOURCE: WIKIDATA (Best effort)
// =========================
const WDQS = "https://query.wikidata.org/sparql";
const WDQS_LIMIT = 10000;

function wikidataSparql(offset) {
  return `
SELECT ?model ?modelLabel ?make ?makeLabel ?start ?end WHERE {
  ?model wdt:P31/wdt:P279* wd:Q3231690 .
  ?model wdt:P176 ?make .
  OPTIONAL { ?model wdt:P571 ?start . }
  OPTIONAL { ?model wdt:P576 ?end . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en,fr". }
}
LIMIT ${WDQS_LIMIT}
OFFSET ${offset}
`.trim();
}

function yearFromDateLiteral(lit) {
  if (!lit) return null;
  const m = /^(\d{4})-/.exec(lit);
  return m ? Number(m[1]) : null;
}

async function fetchWikidataAll() {
  const headers = {
    "User-Agent": "RideTogetherRefBuilder/1.0 (contact: you@example.com)",
    Accept: "application/sparql-results+json",
  };

  let offset = 0;
  let total = 0;
  const rowsAll = [];

  while (true) {
    const query = wikidataSparql(offset);
    const url = `${WDQS}?format=json&query=${encodeURIComponent(query)}`;
    const cacheKey = `wikidata_${sha1(url)}`;

    console.log(`[wikidata] Fetching offset=${offset}...`);
    const data = await fetchJsonWithCache({
      url,
      cacheKey,
      headers,
      baseDelayMs: 1200,
      maxRetries: 5,
      backoffBaseMs: 1200,
    });

    const rows = data?.results?.bindings ?? [];
    if (rows.length === 0) break;

    rowsAll.push(...rows);
    total += rows.length;
    console.log(`[wikidata] Rows so far: ${total}`);

    offset += WDQS_LIMIT;
    if (offset % (WDQS_LIMIT * 2) === 0) await sleep(1500);
  }

  return rowsAll;
}

async function runWikidata(store) {
  if (!SOURCES.wikidata.enabled) return;

  const rows = await fetchWikidataAll();

  const rawPath = path.join(OUT_RAW_DIR, "wikidata", `rows.json`);
  fs.mkdirSync(path.dirname(rawPath), { recursive: true });
  fs.writeFileSync(rawPath, JSON.stringify({ rows }, null, 2), "utf-8");

  for (const r of rows) {
    const makeRaw = r.makeLabel?.value?.trim();
    const modelRaw = r.modelLabel?.value?.trim();
    if (!makeRaw || !modelRaw) continue;

    const model = normalizeModelName(modelRaw);
    if (!model || isBadLabel(model)) continue;
    if (isLikelyNonCommercialModel(model)) continue;

    const make = normalizeMakeName(makeRaw);
    if (!make) continue;

    const startY = yearFromDateLiteral(r.start?.value);
    const endY = yearFromDateLiteral(r.end?.value);

    if (!startY) continue;

    const from = Math.max(YEARS.start, startY);
    const to = Math.min(YEARS.end, endY ?? YEARS.end);
    if (from > to) continue;

    for (let y = from; y <= to; y++) {
      addRecord(store, { year: y, make, model, source: "wikidata" });
    }
  }

  console.log(`[wikidata] integrated`);
}

// =========================
// SOURCE: NHTSA PRODUCTS (USA oriented, may 403)
// =========================
async function nhtsaGetMakes(year) {
  const url = `https://api.nhtsa.gov/products/vehicle/makes?modelYear=${year}&issueType=r`;
  const cacheKey = `nhtsa_makes_${year}`;
  const data = await fetchJsonWithCache({
    url,
    cacheKey,
    headers: { "User-Agent": "RideTogetherRefBuilder/1.0" },
    baseDelayMs: 900,
    maxRetries: 8,
    backoffBaseMs: 1200,
  });

  const list = (data?.results || data?.Results || [])
    .map((x) => (x.make || x.Make || "").trim())
    .filter(Boolean);

  return Array.from(new Set(list)).sort((a, b) => a.localeCompare(b));
}

async function nhtsaGetModels(year, make) {
  const url = `https://api.nhtsa.gov/products/vehicle/models?modelYear=${year}&make=${encodeURIComponent(
    make
  )}&issueType=r`;
  const cacheKey = `nhtsa_models_${year}_${sha1(make)}`;
  const data = await fetchJsonWithCache({
    url,
    cacheKey,
    headers: { "User-Agent": "RideTogetherRefBuilder/1.0" },
    baseDelayMs: 900,
    maxRetries: 8,
    backoffBaseMs: 1200,
  });

  const list = (data?.results || data?.Results || [])
    .map((x) => (x.model || x.Model || "").trim())
    .filter(Boolean);

  return Array.from(new Set(list)).sort((a, b) => a.localeCompare(b));
}

async function runNhtsaProducts(store) {
  if (!SOURCES.nhtsaProducts.enabled) return;

  for (let year = YEARS.start; year <= YEARS.end; year++) {
    console.log(`[nhtsa] year=${year} (makes...)`);

    let makes;
    try {
      makes = await nhtsaGetMakes(year);
    } catch (e) {
      console.warn(`[nhtsa] year=${year} makes failed: ${e.message}`);
      continue;
    }

    const rawMakesPath = path.join(OUT_RAW_DIR, "nhtsa", `${year}_makes.json`);
    fs.mkdirSync(path.dirname(rawMakesPath), { recursive: true });
    fs.writeFileSync(
      rawMakesPath,
      JSON.stringify({ year, makes }, null, 2),
      "utf-8"
    );

    const CONCURRENCY = 2;

    const makeBlocks = await mapLimit(makes, CONCURRENCY, async (make) => {
      try {
        const models = await nhtsaGetModels(year, make);
        return { make, models };
      } catch (e) {
        return { make, models: [], error: e.message };
      }
    });

    const rawModelsPath = path.join(OUT_RAW_DIR, "nhtsa", `${year}_models.json`);
    fs.mkdirSync(path.dirname(rawModelsPath), { recursive: true });
    fs.writeFileSync(
      rawModelsPath,
      JSON.stringify({ year, makeBlocks }, null, 2),
      "utf-8"
    );

    for (const b of makeBlocks) {
      if (!b.models || b.models.length === 0) continue;

      const makeNorm = normalizeMakeName(b.make);
      for (const m of b.models) {
        const modelNorm = normalizeModelName(m);
        if (!modelNorm) continue;
        if (isLikelyNonCommercialModel(modelNorm)) continue;
        addRecord(store, { year, make: makeNorm, model: modelNorm, source: "nhtsa" });
      }
    }

    console.log(`[nhtsa] year=${year} integrated`);
  }
}

// =========================
// SOURCE: API NINJAS (seed-driven)
// =========================
const API_NINJAS_BASE = "https://api.api-ninjas.com/v1/cars";

async function runApiNinjas(store) {
  if (!SOURCES.apiNinjas.enabled) return;
  if (!API_NINJAS_KEY) throw new Error("API_NINJAS_KEY manquant");

  const seedPath = path.resolve("data/vehicles/seeds/makes-top.json");
  if (!fs.existsSync(seedPath)) {
    throw new Error("Missing seed file data/vehicles/seeds/makes-top.json for apiNinjas");
  }

  const seedMakes = JSON.parse(fs.readFileSync(seedPath, "utf-8")).makes || [];
  const headers = { "X-Api-Key": API_NINJAS_KEY };

  for (let year = YEARS.start; year <= YEARS.end; year++) {
    console.log(`[apiNinjas] year=${year}`);
    const modelsByMake = [];

    for (const make of seedMakes) {
      const url = `${API_NINJAS_BASE}?make=${encodeURIComponent(make)}&year=${year}&limit=200`;
      const cacheKey = `apin_${year}_${sha1(url)}`;

      let rows = [];
      try {
        rows = await fetchJsonWithCache({
          url,
          cacheKey,
          headers,
          baseDelayMs: 600,
          maxRetries: 6,
          backoffBaseMs: 900,
        });
      } catch {
        continue;
      }

      const models = Array.from(
        new Set((rows || []).map((r) => (r.model || "").trim()).filter(Boolean))
      );

      if (models.length) {
        modelsByMake.push({ make, models });
        for (const model of models) {
          addRecord(store, {
            year,
            make: normalizeMakeName(make),
            model: normalizeModelName(model),
            source: "apiNinjas",
          });
        }
      }
    }

    const rawPath = path.join(OUT_RAW_DIR, "apiNinjas", `${year}.json`);
    fs.mkdirSync(path.dirname(rawPath), { recursive: true });
    fs.writeFileSync(rawPath, JSON.stringify({ year, modelsByMake }, null, 2), "utf-8");
  }
}

// =========================
// SOURCE: CarAPI.app (JWT auth + seed-driven)
// =========================
const CARAPI_BASE = "https://carapi.app/api";
const CARAPI_JWT_CACHE = path.join(JWT_CACHE_DIR, "carapi_jwt.txt");

function readJwtCache() {
  if (!fs.existsSync(CARAPI_JWT_CACHE)) return null;
  const jwt = fs.readFileSync(CARAPI_JWT_CACHE, "utf-8").trim();
  if (!jwt || jwt.split(".").length !== 3) return null;
  return jwt;
}

function isJwtExpired(jwt) {
  try {
    const payload = JSON.parse(
      Buffer.from(jwt.split(".")[1], "base64").toString("utf-8")
    );
    if (!payload?.exp) return false;
    return Date.now() >= payload.exp * 1000;
  } catch {
    return true;
  }
}

async function carApiLogin() {
  if (!CARAPI_TOKEN || !CARAPI_SECRET) {
    throw new Error("CARAPI_TOKEN / CARAPI_SECRET manquants (vars env)");
  }

  const url = `${CARAPI_BASE}/auth/login`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      accept: "text/plain",
      "content-type": "application/json",
      "user-agent": "RideTogetherRefBuilder/1.0",
    },
    body: JSON.stringify({ api_token: CARAPI_TOKEN, api_secret: CARAPI_SECRET }),
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(`CarAPI login failed HTTP ${res.status}: ${txt.slice(0, 200)}`);
  }

  const jwt = (await res.text()).trim();
  if (!jwt || jwt.split(".").length !== 3) {
    throw new Error("CarAPI login: JWT invalide");
  }

  fs.mkdirSync(JWT_CACHE_DIR, { recursive: true });
  fs.writeFileSync(CARAPI_JWT_CACHE, jwt, "utf-8");
  return jwt;
}

async function getCarApiJwt() {
  const cached = readJwtCache();
  if (cached && !isJwtExpired(cached)) return cached;
  return carApiLogin();
}

async function carApiFetchJson(url, jwt) {
  const doFetch = async (token) =>
    fetch(url, {
      headers: {
        accept: "application/json",
        authorization: `Bearer ${token}`,
        "user-agent": "RideTogetherRefBuilder/1.0",
      },
    });

  let res = await doFetch(jwt);

  if (res.status === 401 || res.status === 403) {
    const newJwt = await carApiLogin();
    res = await doFetch(newJwt);
  }

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(`CarAPI HTTP ${res.status}: ${txt.slice(0, 200)}`);
  }

  return res.json();
}

async function runCarApiApp(store) {
  if (!SOURCES.carApiApp.enabled) return;

  const seedPath = path.resolve("data/vehicles/seeds/makes-top.json");
  if (!fs.existsSync(seedPath)) {
    throw new Error("Missing seed file data/vehicles/seeds/makes-top.json for carApiApp");
  }
  const seedMakes = JSON.parse(fs.readFileSync(seedPath, "utf-8")).makes || [];

  const jwt = await getCarApiJwt();

  // IMPORTANT: les query params exacts peuvent varier selon CarAPI.
  // Cette version est "best effort": /models?year=YYYY&make=XXX
  for (let year = YEARS.start; year <= YEARS.end; year++) {
    console.log(`[carApiApp] year=${year}`);
    const modelsByMake = [];

    for (const make of seedMakes) {
      const url = `${CARAPI_BASE}/models?year=${year}&make=${encodeURIComponent(make)}`;
      const cacheKey = `carapi_models_${year}_${sha1(url)}`;

      let data;
      try {
        // Cache + auth via JSON fetch direct (on n'utilise pas fetchJsonWithCache ici car Authorization dynamique)
        // On cache la réponse CarAPI manuellement :
        const cachePath = path.join(CACHE_DIR, `${cacheKey}.json`);
        if (fs.existsSync(cachePath)) {
          data = JSON.parse(fs.readFileSync(cachePath, "utf-8"));
        } else {
          await sleep(400); // throttle léger
          data = await carApiFetchJson(url, jwt);
          fs.mkdirSync(CACHE_DIR, { recursive: true });
          fs.writeFileSync(cachePath, JSON.stringify(data), "utf-8");
        }
      } catch (e) {
        continue;
      }

      const list = (data?.data || data?.models || data?.results || [])
        .map((x) => (x.name || x.model || x.model_name || "").trim())
        .filter(Boolean);

      const models = Array.from(new Set(list));
      if (models.length) {
        modelsByMake.push({ make, models });
        for (const model of models) {
          const mn = normalizeModelName(model);
          if (!mn) continue;
          addRecord(store, {
            year,
            make: normalizeMakeName(make),
            model: mn,
            source: "carApiApp",
          });
        }
      }
    }

    const rawPath = path.join(OUT_RAW_DIR, "carApiApp", `${year}.json`);
    fs.mkdirSync(path.dirname(rawPath), { recursive: true });
    fs.writeFileSync(rawPath, JSON.stringify({ year, modelsByMake }, null, 2), "utf-8");
  }

  console.log("[carApiApp] integrated");
}

// =========================
// MERGE -> FINAL
// =========================
function exportFinal(store) {
  fs.mkdirSync(OUT_FINAL_DIR, { recursive: true });

  const yearsOut = [];
  const stats = { years: 0, makes: 0, models: 0, perSource: {} };

  for (let year = YEARS.start; year <= YEARS.end; year++) {
    const yearMap = store.get(year);
    if (!yearMap) continue;

    const makes = Array.from(yearMap.entries())
      .map(([make, node]) => {
        const models = Array.from(node.models)
          .filter((m) => m && !isLikelyNonCommercialModel(m))
          .sort((a, b) => a.localeCompare(b));

        for (const src of node.sources) {
          stats.perSource[src] = (stats.perSource[src] || 0) + 1;
        }

        return { make, models };
      })
      .filter((m) => m.models.length > 0)
      .sort((a, b) => a.make.localeCompare(b.make));

    const payload = { year, makes };
    const file = path.join(OUT_FINAL_DIR, `${year}.json`);
    fs.writeFileSync(file, JSON.stringify(payload, null, 2), "utf-8");
    yearsOut.push(year);

    stats.makes += makes.length;
    stats.models += makes.reduce((acc, m) => acc + m.models.length, 0);
  }

  fs.writeFileSync(
    path.join(OUT_FINAL_DIR, "years.json"),
    JSON.stringify({ years: yearsOut }, null, 2),
    "utf-8"
  );

  stats.years = yearsOut.length;

  fs.writeFileSync(
    path.join(OUT_FINAL_DIR, "stats.json"),
    JSON.stringify(stats, null, 2),
    "utf-8"
  );

  console.log(
    `[final] years=${stats.years} makes(total across years)=${stats.makes} models(total across years)=${stats.models}`
  );
  console.log(`[final] wrote ${OUT_FINAL_DIR}`);
}

// =========================
// MAIN
// =========================
async function main() {
  fs.mkdirSync(OUT_RAW_DIR, { recursive: true });
  fs.mkdirSync(OUT_FINAL_DIR, { recursive: true });
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.mkdirSync(JWT_CACHE_DIR, { recursive: true });

  const store = new Map();

  const tasks = [];
  if (SOURCES.wikidata.enabled) tasks.push(runWikidata(store));
  if (SOURCES.apiNinjas.enabled) tasks.push(runApiNinjas(store));
  if (SOURCES.carApiApp.enabled) tasks.push(runCarApiApp(store));

  await Promise.all(tasks);

  if (SOURCES.nhtsaProducts.enabled) {
    await runNhtsaProducts(store);
  }

  exportFinal(store);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
