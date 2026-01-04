import fs from "node:fs";
import path from "node:path";

const OUT_DIR = path.resolve("data/vehicles/cars");
const WDQS = "https://query.wikidata.org/sparql";

const YEAR_MIN = 1970;
const YEAR_MAX = 2026; // ajuste si tu veux (ex: new Date().getFullYear())
const LIMIT = 10000;

const USER_AGENT = "RideTogetherRefBuilder/1.0 (contact: you@example.com)"; // mets un contact réel

function normalizeMake(name) {
  if (!name) return name;

  let s = name.trim();

  s = s
    .replace(
      /\b(AG|GmbH|Inc\.?|Ltd\.?|LLC|S\.A\.|S\.p\.A\.|PLC|Group|Groupe|Company|Corporation|Motors|Motor Company)\b/gi,
      ""
    )
    .replace(/\s{2,}/g, " ")
    .trim();

  const map = new Map([
    ["Groupe BMW", "BMW"],
    ["Volkswagen Group", "Volkswagen"],
    ["Mercedes-Benz Group", "Mercedes-Benz"],
    ["Audi AG", "Audi"],
    ["Fiat Chrysler Automobiles", "Fiat"],
    ["Stellantis North America", "Stellantis"],
  ]);

  return map.get(name) ?? s;
}

function isLikelyConceptModel(model) {
  return /(concept|prototype|show car|one-off|study|vision)/i.test(model);
}

function isBadLabel(label) {
  return /^Q\d+$/.test(label);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function sparqlQuery(offset) {
    return `
  SELECT ?model ?modelLabel ?make ?makeLabel ?brand ?brandLabel ?start ?end WHERE {
    ?model wdt:P31/wdt:P279* wd:Q3231690 .
    ?model wdt:P176 ?make .
    OPTIONAL { ?model wdt:P1716 ?brand . }   # brand
    OPTIONAL { ?model wdt:P571 ?start . }
    OPTIONAL { ?model wdt:P576 ?end . }
    SERVICE wikibase:label { bd:serviceParam wikibase:language "en,fr". }
  }
  LIMIT ${LIMIT}
  OFFSET ${offset}
  `.trim();
  }
  

async function fetchWdqs(offset) {
  // Respect des limites publiques : évite le spam, 1 requête / ~1-2s
  await sleep(1200);

  const query = sparqlQuery(offset);
  const url = `${WDQS}?format=json&query=${encodeURIComponent(query)}`;

  const res = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "application/sparql-results+json",
    },
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(
      `WDQS HTTP ${res.status} offset=${offset} ${txt.slice(0, 200)}`
    );
  }
  return res.json();
}

function yearFromDateLiteral(lit) {
  // Ex: "1998-01-01T00:00:00Z"
  if (!lit) return null;
  const m = /^(\d{4})-/.exec(lit);
  return m ? Number(m[1]) : null;
}

function ensureYearMap(store, year) {
  if (!store.has(year)) store.set(year, new Map()); // make -> Set(models)
  return store.get(year);
}

function addModel(store, year, make, model) {
  const y = ensureYearMap(store, year);
  if (!y.has(make)) y.set(make, new Set());
  y.get(make).add(model);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  // year -> (make -> Set(models))
  const store = new Map();

  let offset = 0;
  let totalRows = 0;

  while (true) {
    console.log(`Fetching offset=${offset}...`);
    const data = await fetchWdqs(offset);
    const rows = data?.results?.bindings ?? [];

    if (rows.length === 0) break;

    for (const r of rows) {
      // brand en priorité si tu l’as dans la requête, sinon manufacturer
      const makeRaw = (r.brandLabel?.value ?? r.makeLabel?.value)?.trim();
      const model = r.modelLabel?.value?.trim();

      if (!makeRaw || !model) continue;
      if (isBadLabel(model)) continue;
      if (isLikelyConceptModel(model)) continue; // ✅ ICI

      const make = normalizeMake(makeRaw);

      if (!make || !model) continue;

      const startY = yearFromDateLiteral(r.start?.value) ?? null;
      const endY = yearFromDateLiteral(r.end?.value) ?? null;

      // Si pas de date de début, difficile de placer par année -> on ignore (ou on pourrait mettre dans "unknown")
      if (!startY) continue;

      const from = Math.max(YEAR_MIN, startY);
      const to = Math.min(YEAR_MAX, endY ?? YEAR_MAX);

      if (from > to) continue;

      for (let y = from; y <= to; y++) {
        addModel(store, y, make, model);
      }
    }

    totalRows += rows.length;
    console.log(`Rows processed so far: ${totalRows}`);

    offset += LIMIT;
  }

  // Écriture fichiers par année
  const years = [];
  for (let year = YEAR_MIN; year <= YEAR_MAX; year++) {
    const makesMap = store.get(year);
    if (!makesMap) continue;

    const makes = Array.from(makesMap.entries())
      .map(([make, modelsSet]) => ({
        make,
        models: Array.from(modelsSet).sort((a, b) => a.localeCompare(b)),
      }))
      .sort((a, b) => a.make.localeCompare(b.make));

    const payload = { year, makes };

    const file = path.join(OUT_DIR, `${year}.json`);
    fs.writeFileSync(file, JSON.stringify(payload, null, 2), "utf-8");
    years.push(year);

    console.log(`✔ wrote ${file} (${makes.length} marques)`);
  }

  fs.writeFileSync(
    path.join(OUT_DIR, "years.json"),
    JSON.stringify({ years }, null, 2),
    "utf-8"
  );

  console.log("Done.");
  console.log(
    `Years generated: ${years[0]}..${years[years.length - 1]} (${years.length})`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
