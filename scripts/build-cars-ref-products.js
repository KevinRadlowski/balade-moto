import fs from "node:fs";
import path from "node:path";

const OUT_DIR = path.resolve("data/vehicles/cars");
const YEARS = { start: 1995, end: 2025 };

// IMPORTANT: commence bas pour éviter le ban
const MAX_CONCURRENCY = 2;

// Delai entre requêtes (ms) pour être “polite”
const BASE_DELAY_MS = 350;

// Retry/backoff
const MAX_RETRIES = 8;
const BACKOFF_BASE_MS = 1200;

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

async function fetchJson(url, attempt = 0) {
  // throttle global minimal
  await sleep(BASE_DELAY_MS);

  const res = await fetch(url, {
    headers: {
      "User-Agent": "RideTogether-RefBuilder/1.0",
      "Accept": "application/json"
    }
  });

  if (res.ok) return res.json();

  const status = res.status;

  // 403/429/5xx : on retry avec backoff
  const retryable = status === 403 || status === 429 || (status >= 500 && status <= 599);

  if (!retryable || attempt >= MAX_RETRIES) {
    throw new Error(`HTTP ${status} for ${url}`);
  }

  const retryAfter = getRetryAfterMs(res);
  const backoff = retryAfter ?? (BACKOFF_BASE_MS * Math.pow(2, attempt));
  const jitter = Math.floor(Math.random() * 250);

  console.warn(`HTTP ${status} => retry in ${backoff + jitter}ms (attempt ${attempt + 1}/${MAX_RETRIES})`);
  await sleep(backoff + jitter);
  return fetchJson(url, attempt + 1);
}

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

  const workers = Array.from({ length: Math.min(limit, items.length) }, () => worker());
  await Promise.all(workers);
  return results;
}

async function getMakesForYear(year) {
  const url = `https://api.nhtsa.gov/products/vehicle/makes?modelYear=${year}&issueType=r`;
  const data = await fetchJson(url);

  const raw = (data?.results || data?.Results || [])
    .map(x => (x.make || x.Make || "").trim())
    .filter(Boolean);

  return Array.from(new Set(raw)).sort((a, b) => a.localeCompare(b));
}

async function getModelsForMakeYear(make, year) {
  const url =
    `https://api.nhtsa.gov/products/vehicle/models?modelYear=${year}` +
    `&make=${encodeURIComponent(make)}&issueType=r`;

  const data = await fetchJson(url);

  const raw = (data?.results || data?.Results || [])
    .map(x => (x.model || x.Model || "").trim())
    .filter(Boolean);

  return Array.from(new Set(raw)).sort((a, b) => a.localeCompare(b));
}

function yearFile(year) {
  return path.join(OUT_DIR, `${year}.json`);
}

function alreadyBuilt(year) {
  return fs.existsSync(yearFile(year)) && fs.statSync(yearFile(year)).size > 0;
}

async function buildYear(year) {
  const makes = await getMakesForYear(year);

  // Pour éviter de taper trop fort : on ajoute aussi un mini délai par make
  const makeBlocks = await mapLimit(makes, MAX_CONCURRENCY, async (make) => {
    try {
      const models = await getModelsForMakeYear(make, year);
      return { make, models };
    } catch (e) {
      // si une marque échoue, on la garde vide, puis on filtrera
      return { make, models: [] };
    }
  });

  const filtered = makeBlocks
    .filter(m => m.models.length > 0)
    .sort((a, b) => a.make.localeCompare(b.make));

  return { year, makes: filtered };
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  for (let year = YEARS.start; year <= YEARS.end; year++) {
    if (alreadyBuilt(year)) {
      console.log(`Skipping ${year} (already built)`);
      continue;
    }

    console.log(`Building ${year}...`);
    const payload = await buildYear(year);

    fs.writeFileSync(yearFile(year), JSON.stringify(payload, null, 2), "utf-8");
    console.log(`✔ Wrote ${yearFile(year)} (${payload.makes.length} marques)`);
  }

  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
