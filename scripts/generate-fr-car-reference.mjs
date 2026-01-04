import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import https from 'https';
import { parse } from 'csv-parse/sync';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const outputDir = path.join(rootDir, 'src/assets/reference/vehicles/cars/fr');
const tmpDir = path.join(rootDir, '.tmp');

// Mapping des générations de modèles par marque
const modelGenerations = {
  "RENAULT": [
    { model: "CLIO", generations: [
      { name: "CLIO II", start: 1998, end: 2005 },
      { name: "CLIO III", start: 2005, end: 2012 },
      { name: "CLIO IV", start: 2012, end: 2019 },
      { name: "CLIO V", start: 2019, end: 2030 }
    ]},
    { model: "MEGANE", generations: [
      { name: "MEGANE II", start: 2002, end: 2008 },
      { name: "MEGANE III", start: 2008, end: 2015 },
      { name: "MEGANE IV", start: 2015, end: 2023 },
      { name: "MEGANE E-TECH", start: 2022, end: 2030 }
    ]},
    { model: "SCENIC", generations: [
      { name: "SCENIC II", start: 2003, end: 2009 },
      { name: "SCENIC III", start: 2009, end: 2016 },
      { name: "SCENIC IV", start: 2016, end: 2022 }
    ]},
    { model: "CAPTUR", generations: [
      { name: "CAPTUR I", start: 2013, end: 2019 },
      { name: "CAPTUR II", start: 2019, end: 2030 }
    ]},
    { model: "KADJAR", generations: [
      { name: "KADJAR", start: 2015, end: 2022 }
    ]},
    { model: "TALISMAN", generations: [
      { name: "TALISMAN", start: 2015, end: 2022 }
    ]}
  ],
  "PEUGEOT": [
    { model: "206", generations: [
      { name: "206", start: 1998, end: 2012 }
    ]},
    { model: "207", generations: [
      { name: "207", start: 2006, end: 2014 }
    ]},
    { model: "208", generations: [
      { name: "208 I", start: 2012, end: 2019 },
      { name: "208 II", start: 2019, end: 2030 }
    ]},
    { model: "307", generations: [
      { name: "307", start: 2001, end: 2008 }
    ]},
    { model: "308", generations: [
      { name: "308 I", start: 2007, end: 2013 },
      { name: "308 II", start: 2013, end: 2021 },
      { name: "308 III", start: 2021, end: 2030 }
    ]},
    { model: "3008", generations: [
      { name: "3008 I", start: 2009, end: 2016 },
      { name: "3008 II", start: 2016, end: 2023 },
      { name: "3008 III", start: 2023, end: 2030 }
    ]},
    { model: "5008", generations: [
      { name: "5008 I", start: 2009, end: 2017 },
      { name: "5008 II", start: 2017, end: 2030 }
    ]},
    { model: "2008", generations: [
      { name: "2008 I", start: 2013, end: 2019 },
      { name: "2008 II", start: 2019, end: 2030 }
    ]}
  ],
  "CITROEN": [
    { model: "C3", generations: [
      { name: "C3 I", start: 2002, end: 2009 },
      { name: "C3 II", start: 2009, end: 2016 },
      { name: "C3 III", start: 2016, end: 2023 },
      { name: "C3 IV", start: 2023, end: 2030 }
    ]},
    { model: "C4", generations: [
      { name: "C4 I", start: 2004, end: 2010 },
      { name: "C4 II", start: 2010, end: 2018 },
      { name: "C4 III", start: 2018, end: 2030 }
    ]},
    { model: "C5", generations: [
      { name: "C5 I", start: 2001, end: 2008 },
      { name: "C5 II", start: 2008, end: 2017 }
    ]},
    { model: "BERLINGO", generations: [
      { name: "BERLINGO II", start: 2008, end: 2018 },
      { name: "BERLINGO III", start: 2018, end: 2030 }
    ]},
    { model: "C4 PICASSO", generations: [
      { name: "C4 PICASSO", start: 2006, end: 2020 }
    ]}
  ],
  "VOLKSWAGEN": [
    { model: "GOLF", generations: [
      { name: "GOLF IV", start: 1997, end: 2003 },
      { name: "GOLF V", start: 2003, end: 2008 },
      { name: "GOLF VI", start: 2008, end: 2012 },
      { name: "GOLF VII", start: 2012, end: 2019 },
      { name: "GOLF VIII", start: 2019, end: 2030 }
    ]},
    { model: "POLO", generations: [
      { name: "POLO IV", start: 2001, end: 2009 },
      { name: "POLO V", start: 2009, end: 2017 },
      { name: "POLO VI", start: 2017, end: 2030 }
    ]},
    { model: "PASSAT", generations: [
      { name: "PASSAT B6", start: 2005, end: 2010 },
      { name: "PASSAT B7", start: 2010, end: 2014 },
      { name: "PASSAT B8", start: 2014, end: 2022 }
    ]},
    { model: "TOURAN", generations: [
      { name: "TOURAN I", start: 2003, end: 2015 },
      { name: "TOURAN II", start: 2015, end: 2022 }
    ]},
    { model: "TIGUAN", generations: [
      { name: "TIGUAN I", start: 2007, end: 2016 },
      { name: "TIGUAN II", start: 2016, end: 2023 },
      { name: "TIGUAN III", start: 2023, end: 2030 }
    ]}
  ],
  "FORD": [
    { model: "FIESTA", generations: [
      { name: "FIESTA VI", start: 2002, end: 2008 },
      { name: "FIESTA VII", start: 2008, end: 2017 },
      { name: "FIESTA VIII", start: 2017, end: 2023 }
    ]},
    { model: "FOCUS", generations: [
      { name: "FOCUS II", start: 2004, end: 2011 },
      { name: "FOCUS III", start: 2011, end: 2018 },
      { name: "FOCUS IV", start: 2018, end: 2023 }
    ]},
    { model: "KUGA", generations: [
      { name: "KUGA I", start: 2008, end: 2012 },
      { name: "KUGA II", start: 2012, end: 2019 },
      { name: "KUGA III", start: 2019, end: 2030 }
    ]},
    { model: "MONDEO", generations: [
      { name: "MONDEO III", start: 2000, end: 2007 },
      { name: "MONDEO IV", start: 2007, end: 2014 },
      { name: "MONDEO V", start: 2014, end: 2022 }
    ]}
  ],
  "TOYOTA": [
    { model: "YARIS", generations: [
      { name: "YARIS I", start: 1999, end: 2005 },
      { name: "YARIS II", start: 2005, end: 2011 },
      { name: "YARIS III", start: 2011, end: 2020 },
      { name: "YARIS IV", start: 2020, end: 2030 }
    ]},
    { model: "COROLLA", generations: [
      { name: "COROLLA E12", start: 2006, end: 2013 },
      { name: "COROLLA E210", start: 2018, end: 2030 }
    ]},
    { model: "AURIS", generations: [
      { name: "AURIS I", start: 2006, end: 2012 },
      { name: "AURIS II", start: 2012, end: 2018 }
    ]},
    { model: "RAV4", generations: [
      { name: "RAV4 III", start: 2005, end: 2012 },
      { name: "RAV4 IV", start: 2012, end: 2018 },
      { name: "RAV4 V", start: 2018, end: 2030 }
    ]},
    { model: "PRIUS", generations: [
      { name: "PRIUS II", start: 2003, end: 2009 },
      { name: "PRIUS III", start: 2009, end: 2015 },
      { name: "PRIUS IV", start: 2015, end: 2022 }
    ]}
  ],
  "BMW": [
    { model: "SERIE 1", generations: [
      { name: "SERIE 1 E87", start: 2004, end: 2011 },
      { name: "SERIE 1 F20", start: 2011, end: 2019 },
      { name: "SERIE 1 F40", start: 2019, end: 2030 }
    ]},
    { model: "SERIE 3", generations: [
      { name: "SERIE 3 E46", start: 1998, end: 2005 },
      { name: "SERIE 3 E90", start: 2005, end: 2012 },
      { name: "SERIE 3 F30", start: 2012, end: 2019 },
      { name: "SERIE 3 G20", start: 2019, end: 2030 }
    ]},
    { model: "SERIE 5", generations: [
      { name: "SERIE 5 E60", start: 2003, end: 2010 },
      { name: "SERIE 5 F10", start: 2010, end: 2017 },
      { name: "SERIE 5 G30", start: 2017, end: 2023 }
    ]},
    { model: "X1", generations: [
      { name: "X1 E84", start: 2009, end: 2015 },
      { name: "X1 F48", start: 2015, end: 2022 },
      { name: "X1 U11", start: 2022, end: 2030 }
    ]},
    { model: "X3", generations: [
      { name: "X3 E83", start: 2003, end: 2010 },
      { name: "X3 F25", start: 2010, end: 2017 },
      { name: "X3 G01", start: 2017, end: 2023 }
    ]}
  ],
  "AUDI": [
    { model: "A3", generations: [
      { name: "A3 8P", start: 2003, end: 2012 },
      { name: "A3 8V", start: 2012, end: 2020 },
      { name: "A3 8Y", start: 2020, end: 2030 }
    ]},
    { model: "A4", generations: [
      { name: "A4 B7", start: 2004, end: 2008 },
      { name: "A4 B8", start: 2008, end: 2015 },
      { name: "A4 B9", start: 2015, end: 2023 }
    ]},
    { model: "A6", generations: [
      { name: "A6 C6", start: 2004, end: 2011 },
      { name: "A6 C7", start: 2011, end: 2018 },
      { name: "A6 C8", start: 2018, end: 2023 }
    ]},
    { model: "Q3", generations: [
      { name: "Q3 8U", start: 2011, end: 2018 },
      { name: "Q3 FY", start: 2018, end: 2023 }
    ]},
    { model: "Q5", generations: [
      { name: "Q5 8R", start: 2008, end: 2017 },
      { name: "Q5 FY", start: 2017, end: 2023 }
    ]}
  ],
  "MERCEDES-BENZ": [
    { model: "CLASSE A", generations: [
      { name: "CLASSE A W168", start: 1997, end: 2004 },
      { name: "CLASSE A W169", start: 2004, end: 2012 },
      { name: "CLASSE A W176", start: 2012, end: 2018 },
      { name: "CLASSE A W177", start: 2018, end: 2030 }
    ]},
    { model: "CLASSE C", generations: [
      { name: "CLASSE C W203", start: 2000, end: 2007 },
      { name: "CLASSE C W204", start: 2007, end: 2014 },
      { name: "CLASSE C W205", start: 2014, end: 2021 },
      { name: "CLASSE C W206", start: 2021, end: 2030 }
    ]},
    { model: "CLASSE E", generations: [
      { name: "CLASSE E W211", start: 2002, end: 2009 },
      { name: "CLASSE E W212", start: 2009, end: 2016 },
      { name: "CLASSE E W213", start: 2016, end: 2023 }
    ]},
    { model: "GLA", generations: [
      { name: "GLA X156", start: 2013, end: 2020 },
      { name: "GLA H247", start: 2020, end: 2030 }
    ]},
    { model: "GLC", generations: [
      { name: "GLC X253", start: 2015, end: 2022 },
      { name: "GLC X254", start: 2022, end: 2030 }
    ]}
  ],
  "NISSAN": [
    { model: "MICRA", generations: [
      { name: "MICRA K12", start: 2002, end: 2010 },
      { name: "MICRA K13", start: 2010, end: 2016 },
      { name: "MICRA K14", start: 2016, end: 2023 }
    ]},
    { model: "QASHQAI", generations: [
      { name: "QASHQAI J10", start: 2006, end: 2013 },
      { name: "QASHQAI J11", start: 2013, end: 2021 },
      { name: "QASHQAI J12", start: 2021, end: 2030 }
    ]},
    { model: "X-TRAIL", generations: [
      { name: "X-TRAIL T31", start: 2007, end: 2014 },
      { name: "X-TRAIL T32", start: 2014, end: 2021 }
    ]},
    { model: "LEAF", generations: [
      { name: "LEAF ZE0", start: 2010, end: 2017 },
      { name: "LEAF ZE1", start: 2017, end: 2023 }
    ]}
  ],
  "FIAT": [
    { model: "PUNTO", generations: [
      { name: "PUNTO II", start: 1999, end: 2005 },
      { name: "PUNTO III", start: 2005, end: 2018 }
    ]},
    { model: "PANDA", generations: [
      { name: "PANDA II", start: 2003, end: 2011 },
      { name: "PANDA III", start: 2011, end: 2023 }
    ]},
    { model: "500", generations: [
      { name: "500", start: 2007, end: 2015 },
      { name: "500 II", start: 2015, end: 2030 }
    ]},
    { model: "TIPO", generations: [
      { name: "TIPO", start: 2015, end: 2023 }
    ]}
  ],
  "OPEL": [
    { model: "CORSA", generations: [
      { name: "CORSA C", start: 2000, end: 2006 },
      { name: "CORSA D", start: 2006, end: 2014 },
      { name: "CORSA E", start: 2014, end: 2019 },
      { name: "CORSA F", start: 2019, end: 2030 }
    ]},
    { model: "ASTRA", generations: [
      { name: "ASTRA H", start: 2004, end: 2009 },
      { name: "ASTRA J", start: 2009, end: 2015 },
      { name: "ASTRA K", start: 2015, end: 2021 }
    ]},
    { model: "INSIGNIA", generations: [
      { name: "INSIGNIA A", start: 2008, end: 2017 },
      { name: "INSIGNIA B", start: 2017, end: 2022 }
    ]},
    { model: "CROSSLAND", generations: [
      { name: "CROSSLAND X", start: 2017, end: 2023 }
    ]}
  ],
  "SEAT": [
    { model: "LEON", generations: [
      { name: "LEON I", start: 1999, end: 2005 },
      { name: "LEON II", start: 2005, end: 2012 },
      { name: "LEON III", start: 2012, end: 2020 },
      { name: "LEON IV", start: 2020, end: 2030 }
    ]},
    { model: "IBIZA", generations: [
      { name: "IBIZA IV", start: 2008, end: 2017 },
      { name: "IBIZA V", start: 2017, end: 2023 }
    ]},
    { model: "ATECA", generations: [
      { name: "ATECA", start: 2016, end: 2023 }
    ]}
  ],
  "SKODA": [
    { model: "OCTAVIA", generations: [
      { name: "OCTAVIA II", start: 2004, end: 2012 },
      { name: "OCTAVIA III", start: 2012, end: 2020 },
      { name: "OCTAVIA IV", start: 2020, end: 2030 }
    ]},
    { model: "FABIA", generations: [
      { name: "FABIA II", start: 2007, end: 2014 },
      { name: "FABIA III", start: 2014, end: 2021 },
      { name: "FABIA IV", start: 2021, end: 2030 }
    ]},
    { model: "SUPERB", generations: [
      { name: "SUPERB II", start: 2008, end: 2015 },
      { name: "SUPERB III", start: 2015, end: 2023 }
    ]},
    { model: "KODIAQ", generations: [
      { name: "KODIAQ", start: 2016, end: 2023 }
    ]}
  ],
  "HYUNDAI": [
    { model: "I20", generations: [
      { name: "I20 I", start: 2008, end: 2014 },
      { name: "I20 II", start: 2014, end: 2020 },
      { name: "I20 III", start: 2020, end: 2030 }
    ]},
    { model: "I30", generations: [
      { name: "I30 I", start: 2007, end: 2012 },
      { name: "I30 II", start: 2012, end: 2017 },
      { name: "I30 III", start: 2017, end: 2023 }
    ]},
    { model: "TUCSON", generations: [
      { name: "TUCSON I", start: 2004, end: 2009 },
      { name: "TUCSON II", start: 2009, end: 2015 },
      { name: "TUCSON III", start: 2015, end: 2021 },
      { name: "TUCSON IV", start: 2021, end: 2030 }
    ]},
    { model: "KONA", generations: [
      { name: "KONA", start: 2017, end: 2023 }
    ]}
  ],
  "KIA": [
    { model: "RIO", generations: [
      { name: "RIO II", start: 2005, end: 2011 },
      { name: "RIO III", start: 2011, end: 2017 },
      { name: "RIO IV", start: 2017, end: 2023 }
    ]},
    { model: "CEED", generations: [
      { name: "CEED I", start: 2006, end: 2012 },
      { name: "CEED II", start: 2012, end: 2018 },
      { name: "CEED III", start: 2018, end: 2023 }
    ]},
    { model: "SPORTAGE", generations: [
      { name: "SPORTAGE II", start: 2010, end: 2016 },
      { name: "SPORTAGE III", start: 2016, end: 2021 },
      { name: "SPORTAGE IV", start: 2021, end: 2030 }
    ]},
    { model: "NIRO", generations: [
      { name: "NIRO", start: 2016, end: 2023 }
    ]}
  ],
  "SUZUKI": [
    { model: "SWIFT", generations: [
      { name: "SWIFT II", start: 2004, end: 2010 },
      { name: "SWIFT III", start: 2010, end: 2017 },
      { name: "SWIFT IV", start: 2017, end: 2023 }
    ]},
    { model: "SX4", generations: [
      { name: "SX4", start: 2006, end: 2013 },
      { name: "SX4 S-CROSS", start: 2013, end: 2021 }
    ]},
    { model: "VITARA", generations: [
      { name: "VITARA III", start: 2005, end: 2015 },
      { name: "VITARA IV", start: 2015, end: 2023 }
    ]}
  ],
  "ALFA ROMEO": [
    { model: "147", generations: [
      { name: "147", start: 2000, end: 2010 }
    ]},
    { model: "GIULIETTA", generations: [
      { name: "GIULIETTA", start: 2010, end: 2020 }
    ]},
    { model: "STELVIO", generations: [
      { name: "STELVIO", start: 2016, end: 2023 }
    ]}
  ],
  "SMART": [
    { model: "FORTWO", generations: [
      { name: "FORTWO 450", start: 1998, end: 2007 },
      { name: "FORTWO 451", start: 2007, end: 2014 },
      { name: "FORTWO 453", start: 2014, end: 2023 }
    ]},
    { model: "FORFOUR", generations: [
      { name: "FORFOUR I", start: 2004, end: 2006 },
      { name: "FORFOUR II", start: 2014, end: 2021 }
    ]}
  ]
};

// Fallback pour les années 2005-2010 (top 20 marques cohérent)
const fallbackTopBrands = {
  2005: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"],
  2006: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"],
  2007: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"],
  2008: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"],
  2009: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"],
  2010: ["RENAULT", "PEUGEOT", "CITROEN", "VOLKSWAGEN", "FORD", "TOYOTA", "OPEL", "BMW", "AUDI", "MERCEDES-BENZ", "NISSAN", "FIAT", "SEAT", "SKODA", "HYUNDAI", "KIA", "SUZUKI", "ALFA ROMEO", "SMART", "HONDA"]
};

// Normaliser le nom de marque (MAJUSCULES, sans accents)
function normalizeBrand(brand) {
  return brand
    .toUpperCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim();
}

// Calculer les modèles pour une marque et une année
function computeModelsForMakeYear(make, year) {
  const normalizedMake = normalizeBrand(make);
  const makeData = modelGenerations[normalizedMake];
  
  if (!makeData) {
    return [];
  }
  
  const models = [];
  for (const modelData of makeData) {
    for (const gen of modelData.generations) {
      if (year >= gen.start && year <= gen.end) {
        models.push(gen.name);
      }
    }
  }
  
  // Dédupliquer et trier alphabétiquement
  return [...new Set(models)].sort();
}

// Télécharger un fichier
function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        return downloadFile(response.headers.location, dest).then(resolve).catch(reject);
      }
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download: ${response.statusCode}`));
        return;
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlinkSync(dest);
      reject(err);
    });
  });
}

// Récupérer le dataset SDES depuis data.gouv.fr
async function fetchSDESDataset() {
  console.log('🔍 Recherche du dataset SDES sur data.gouv.fr...');
  
  // Essayer plusieurs requêtes de recherche
  const searchQueries = [
    'immatriculations%20vehicules%20routiers%20SDES',
    'immatriculations%20vehicules%20particuliers',
    'sdes%20immatriculations',
    'vehicules%20routiers%20immatriculations'
  ];
  
  for (const query of searchQueries) {
    const searchUrl = `https://www.data.gouv.fr/api/1/datasets/?q=${query}&page_size=10`;
    
    try {
      const dataset = await new Promise((resolve, reject) => {
        https.get(searchUrl, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            try {
              const json = JSON.parse(data);
              const datasets = json.data || [];
              
              // Trouver le dataset SDES le plus pertinent
              const sdesDataset = datasets.find(d => 
                d.title && (
                  d.title.toLowerCase().includes('sdes') ||
                  d.title.toLowerCase().includes('immatriculation') ||
                  d.title.toLowerCase().includes('véhicules') ||
                  d.title.toLowerCase().includes('vehicules')
                ) && (
                  d.organization && d.organization.slug === 'sdes' ||
                  d.organization && d.organization.name && d.organization.name.toLowerCase().includes('sdes')
                )
              ) || datasets.find(d => 
                d.title && (
                  d.title.toLowerCase().includes('immatriculation') ||
                  d.title.toLowerCase().includes('véhicules')
                )
              ) || datasets[0];
              
              if (sdesDataset) {
                resolve(sdesDataset);
              } else {
                reject(new Error('Aucun dataset SDES trouvé'));
              }
            } catch (err) {
              reject(err);
            }
          });
        }).on('error', reject);
      });
      
      console.log(`✅ Dataset trouvé: ${dataset.title}`);
      return dataset;
    } catch (err) {
      // Continuer avec la prochaine requête
      continue;
    }
  }
  
  throw new Error('Aucun dataset SDES trouvé après plusieurs tentatives');
}

// Récupérer la ressource CSV la plus récente
async function fetchCSVResource(dataset) {
  console.log('🔍 Recherche de la ressource CSV la plus récente...');
  
  const datasetUrl = `https://www.data.gouv.fr/api/1/datasets/${dataset.id}/`;
  
  return new Promise((resolve, reject) => {
    https.get(datasetUrl, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const resources = json.resources || [];
          
          // Trouver la ressource CSV la plus récente
          const csvResources = resources
            .filter(r => r.format === 'csv' || r.url?.endsWith('.csv'))
            .sort((a, b) => new Date(b.last_modified || 0) - new Date(a.last_modified || 0));
          
          if (csvResources.length === 0) {
            reject(new Error('Aucune ressource CSV trouvée'));
            return;
          }
          
          const resource = csvResources[0];
          console.log(`✅ Ressource CSV trouvée: ${resource.title || resource.url}`);
          resolve(resource);
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject);
  });
}

// Parser le CSV et extraire les données par année/marque
async function parseCSV(csvPath) {
  console.log('📊 Parsing du CSV...');
  
  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  
  // Détecter le séparateur
  const separator = csvContent.includes(';') ? ';' : ',';
  
  const records = parse(csvContent, {
    columns: true,
    skip_empty_lines: true,
    delimiter: separator,
    relax_column_count: true
  });
  
  // Détecter les colonnes
  const headers = Object.keys(records[0] || {});
  const yearCol = headers.find(h => 
    /annee|année|year/i.test(h)
  ) || headers[0];
  
  const brandCol = headers.find(h => 
    /marque|brand|make/i.test(h)
  ) || headers[1];
  
  const countCol = headers.find(h => 
    /nb|nombre|immatriculation|count|volume|total/i.test(h)
  ) || headers[2];
  
  console.log(`📋 Colonnes détectées: année=${yearCol}, marque=${brandCol}, nombre=${countCol}`);
  
  // Agréger par année et marque
  const dataByYear = {};
  
  for (const record of records) {
    const yearStr = String(record[yearCol] || '').trim();
    const brand = String(record[brandCol] || '').trim();
    const countStr = String(record[countCol] || '').trim().replace(/\s/g, '');
    
    if (!yearStr || !brand || !countStr) continue;
    
    const year = parseInt(yearStr);
    const count = parseInt(countStr) || 0;
    
    if (isNaN(year) || year < 2011 || year > 2024) continue;
    if (isNaN(count) || count <= 0) continue;
    
    if (!dataByYear[year]) {
      dataByYear[year] = {};
    }
    
    const normalizedBrand = normalizeBrand(brand);
    dataByYear[year][normalizedBrand] = (dataByYear[year][normalizedBrand] || 0) + count;
  }
  
  return dataByYear;
}

// Générer les fichiers JSON pour une année
function generateYearFiles(year, makes) {
  const makeBlocks = makes.map(make => ({
    make: make,
    models: computeModelsForMakeYear(make, year)
  }));
  
  // Fichier _models.json
  const modelsFile = {
    year: year,
    makes: makes
  };
  
  // Fichier _makes.json
  const makesFile = {
    year: year,
    makeBlocks: makeBlocks
  };
  
  const modelsPath = path.join(outputDir, `${year}_models.json`);
  const makesPath = path.join(outputDir, `${year}_makes.json`);
  
  fs.writeFileSync(modelsPath, JSON.stringify(modelsFile, null, 2), 'utf-8');
  fs.writeFileSync(makesPath, JSON.stringify(makesFile, null, 2), 'utf-8');
  
  console.log(`  ✅ ${year}_models.json et ${year}_makes.json générés`);
}

// Fonction principale
async function main() {
  console.log('🚀 Génération du référentiel véhicules français (2005-2024)\n');
  
  // Créer les dossiers
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }
  
  // Récupérer les données SDES pour 2011-2024
  let sdesData = {};
  
  try {
    const dataset = await fetchSDESDataset();
    const resource = await fetchCSVResource(dataset);
    
    const csvPath = path.join(tmpDir, 'sdes_immatriculations.csv');
    console.log(`📥 Téléchargement du CSV...`);
    await downloadFile(resource.url, csvPath);
    console.log(`✅ CSV téléchargé: ${csvPath}`);
    
    sdesData = await parseCSV(csvPath);
    console.log(`✅ Données parsées pour ${Object.keys(sdesData).length} années\n`);
  } catch (error) {
    console.warn(`⚠️  Impossible de récupérer les données SDES: ${error.message}`);
    console.warn(`⚠️  Utilisation des fallbacks pour toutes les années\n`);
  }
  
  // Générer les fichiers pour chaque année
  console.log('📝 Génération des fichiers JSON...\n');
  
  for (let year = 2005; year <= 2024; year++) {
    let makes;
    
    if (year >= 2011 && sdesData[year]) {
      // Utiliser les données SDES
      const brandCounts = Object.entries(sdesData[year])
        .sort((a, b) => b[1] - a[1])
        .slice(0, 20)
        .map(([brand]) => brand);
      
      makes = brandCounts;
    } else {
      // Utiliser le fallback
      makes = fallbackTopBrands[year] || fallbackTopBrands[2010];
    }
    
    generateYearFiles(year, makes);
  }
  
  console.log(`\n✅ Génération terminée ! ${2024 - 2005 + 1} années -> ${outputDir}`);
}

// Exécuter
main().catch(error => {
  console.error('❌ Erreur:', error);
  process.exit(1);
});

