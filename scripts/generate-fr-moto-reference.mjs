import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Utilitaires
function slug(str) {
  return str
    .toUpperCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // Remove accents
    .replace(/[^A-Z0-9]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
}

function writeJson(filePath, obj) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(filePath, JSON.stringify(obj, null, 2), 'utf8');
}

// Top 20 marques motos (stable pour toutes les années 2005-2024)
const fallbackTopMotoBrands = [
  'HONDA',
  'YAMAHA',
  'KAWASAKI',
  'SUZUKI',
  'BMW',
  'KTM',
  'DUCATI',
  'TRIUMPH',
  'HARLEY-DAVIDSON',
  'PIAGGIO',
  'APRILIA',
  'MOTO GUZZI',
  'HUSQVARNA',
  'INDIAN',
  'BENELLI',
  'CFMOTO',
  'KYMCO',
  'SYM',
  'ZERO',
  'PEUGEOT MOTOCYCLES'
];

// Mapping des générations de modèles par marque
const modelGenerationsMoto = {
  'HONDA': [
    {
      model: 'CB 500',
      generations: [
        { name: 'CB 500', start: 1994, end: 2003 },
        { name: 'CB 500F', start: 2013, end: 2024 }
      ]
    },
    {
      model: 'CBF 600',
      generations: [
        { name: 'CBF 600', start: 2004, end: 2012 }
      ]
    },
    {
      model: 'CB 650',
      generations: [
        { name: 'CB 650F', start: 2014, end: 2018 },
        { name: 'CB 650R', start: 2019, end: 2024 }
      ]
    },
    {
      model: 'Africa Twin',
      generations: [
        { name: 'Africa Twin CRF1000L', start: 2016, end: 2019 },
        { name: 'Africa Twin CRF1100L', start: 2020, end: 2024 }
      ]
    },
    {
      model: 'Forza',
      generations: [
        { name: 'Forza 125', start: 2015, end: 2024 }
      ]
    },
    {
      model: 'CBR',
      generations: [
        { name: 'CBR 600RR', start: 2003, end: 2024 },
        { name: 'CBR 1000RR', start: 2004, end: 2024 }
      ]
    },
    {
      model: 'NC',
      generations: [
        { name: 'NC 700X', start: 2012, end: 2024 },
        { name: 'NC 750X', start: 2014, end: 2024 }
      ]
    }
  ],
  'YAMAHA': [
    {
      model: 'MT',
      generations: [
        { name: 'MT-07', start: 2014, end: 2024 },
        { name: 'MT-09', start: 2014, end: 2024 },
        { name: 'MT-10', start: 2016, end: 2024 }
      ]
    },
    {
      model: 'TMAX',
      generations: [
        { name: 'TMAX 500', start: 2001, end: 2011 },
        { name: 'TMAX 530', start: 2012, end: 2016 },
        { name: 'TMAX 560', start: 2020, end: 2024 }
      ]
    },
    {
      model: 'Tracer',
      generations: [
        { name: 'Tracer 900', start: 2015, end: 2020 },
        { name: 'Tracer 9', start: 2021, end: 2024 }
      ]
    },
    {
      model: 'XMAX',
      generations: [
        { name: 'XMAX 125', start: 2006, end: 2024 },
        { name: 'XMAX 300', start: 2017, end: 2024 }
      ]
    },
    {
      model: 'YZF',
      generations: [
        { name: 'YZF-R6', start: 1999, end: 2020 },
        { name: 'YZF-R1', start: 1998, end: 2024 }
      ]
    }
  ],
  'KAWASAKI': [
    {
      model: 'Z',
      generations: [
        { name: 'Z750', start: 2004, end: 2012 },
        { name: 'Z800', start: 2013, end: 2016 },
        { name: 'Z900', start: 2017, end: 2024 }
      ]
    },
    {
      model: 'ER-6N / Z650',
      generations: [
        { name: 'ER-6N', start: 2006, end: 2016 },
        { name: 'Z650', start: 2017, end: 2024 }
      ]
    },
    {
      model: 'Versys',
      generations: [
        { name: 'Versys 650', start: 2007, end: 2024 },
        { name: 'Versys 1000', start: 2012, end: 2024 }
      ]
    },
    {
      model: 'Ninja',
      generations: [
        { name: 'Ninja 650', start: 2006, end: 2024 },
        { name: 'Ninja ZX-6R', start: 2003, end: 2024 },
        { name: 'Ninja ZX-10R', start: 2004, end: 2024 }
      ]
    }
  ],
  'SUZUKI': [
    {
      model: 'SV',
      generations: [
        { name: 'SV650', start: 1999, end: 2016 },
        { name: 'SV650', start: 2017, end: 2024 }
      ]
    },
    {
      model: 'GSX-S',
      generations: [
        { name: 'GSX-S750', start: 2017, end: 2021 },
        { name: 'GSX-S1000', start: 2015, end: 2024 }
      ]
    },
    {
      model: 'V-Strom',
      generations: [
        { name: 'V-Strom 650', start: 2004, end: 2024 },
        { name: 'V-Strom 1000', start: 2002, end: 2024 }
      ]
    },
    {
      model: 'GSX-R',
      generations: [
        { name: 'GSX-R600', start: 1997, end: 2024 },
        { name: 'GSX-R750', start: 1985, end: 2024 },
        { name: 'GSX-R1000', start: 2001, end: 2024 }
      ]
    }
  ],
  'BMW': [
    {
      model: 'R GS',
      generations: [
        { name: 'R 1200 GS', start: 2004, end: 2012 },
        { name: 'R 1250 GS', start: 2019, end: 2024 }
      ]
    },
    {
      model: 'F GS',
      generations: [
        { name: 'F 800 GS', start: 2008, end: 2018 },
        { name: 'F 850 GS', start: 2018, end: 2024 }
      ]
    },
    {
      model: 'S',
      generations: [
        { name: 'S 1000 RR', start: 2010, end: 2024 },
        { name: 'S 1000 R', start: 2014, end: 2024 }
      ]
    },
    {
      model: 'K',
      generations: [
        { name: 'K 1600 GT', start: 2011, end: 2024 },
        { name: 'K 1600 GTL', start: 2011, end: 2024 }
      ]
    }
  ],
  'KTM': [
    {
      model: 'Duke',
      generations: [
        { name: '390 Duke', start: 2013, end: 2024 },
        { name: '790 Duke', start: 2018, end: 2020 },
        { name: '890 Duke', start: 2021, end: 2024 },
        { name: '1290 Super Duke R', start: 2014, end: 2024 }
      ]
    },
    {
      model: 'Adventure',
      generations: [
        { name: '1290 Super Adventure', start: 2015, end: 2024 },
        { name: '790 Adventure', start: 2019, end: 2024 }
      ]
    },
    {
      model: 'RC',
      generations: [
        { name: 'RC 390', start: 2014, end: 2024 }
      ]
    }
  ],
  'DUCATI': [
    {
      model: 'Monster',
      generations: [
        { name: 'Monster 696', start: 2008, end: 2014 },
        { name: 'Monster 796', start: 2008, end: 2014 },
        { name: 'Monster 1100', start: 2008, end: 2014 },
        { name: 'Monster 821', start: 2014, end: 2020 },
        { name: 'Monster', start: 2021, end: 2024 }
      ]
    },
    {
      model: 'Multistrada',
      generations: [
        { name: 'Multistrada 1200', start: 2010, end: 2017 },
        { name: 'Multistrada 1260', start: 2018, end: 2020 },
        { name: 'Multistrada V4', start: 2021, end: 2024 }
      ]
    },
    {
      model: 'Panigale',
      generations: [
        { name: 'Panigale 899', start: 2013, end: 2015 },
        { name: 'Panigale 959', start: 2016, end: 2020 },
        { name: 'Panigale V2', start: 2021, end: 2024 },
        { name: 'Panigale V4', start: 2018, end: 2024 }
      ]
    }
  ],
  'TRIUMPH': [
    {
      model: 'Street Triple',
      generations: [
        { name: 'Street Triple', start: 2007, end: 2024 }
      ]
    },
    {
      model: 'Tiger',
      generations: [
        { name: 'Tiger 800', start: 2011, end: 2019 },
        { name: 'Tiger 900', start: 2020, end: 2024 }
      ]
    },
    {
      model: 'Bonneville',
      generations: [
        { name: 'Bonneville T100', start: 2016, end: 2024 },
        { name: 'Bonneville T120', start: 2016, end: 2024 }
      ]
    },
    {
      model: 'Speed Triple',
      generations: [
        { name: 'Speed Triple', start: 1994, end: 2024 }
      ]
    }
  ],
  'HARLEY-DAVIDSON': [
    {
      model: 'Sportster',
      generations: [
        { name: 'Sportster', start: 2005, end: 2020 },
        { name: 'Sportster S', start: 2021, end: 2024 }
      ]
    },
    {
      model: 'Street',
      generations: [
        { name: 'Street 750', start: 2015, end: 2020 }
      ]
    },
    {
      model: 'Softail',
      generations: [
        { name: 'Softail', start: 2000, end: 2024 }
      ]
    }
  ],
  'PIAGGIO': [
    {
      model: 'Vespa',
      generations: [
        { name: 'Vespa Primavera', start: 2013, end: 2024 },
        { name: 'Vespa GTS', start: 2005, end: 2024 }
      ]
    },
    {
      model: 'MP3',
      generations: [
        { name: 'MP3', start: 2006, end: 2024 }
      ]
    },
    {
      model: 'Beverly',
      generations: [
        { name: 'Beverly 300', start: 2009, end: 2024 }
      ]
    }
  ],
  'APRILIA': [
    {
      model: 'RSV',
      generations: [
        { name: 'RSV4', start: 2009, end: 2024 }
      ]
    },
    {
      model: 'Tuono',
      generations: [
        { name: 'Tuono V4', start: 2011, end: 2024 }
      ]
    },
    {
      model: 'Shiver',
      generations: [
        { name: 'Shiver 750', start: 2007, end: 2017 }
      ]
    }
  ]
};

// Calculer les modèles pour une marque et une année
function computeModelsForMakeYear(makeUpper, year) {
  const models = modelGenerationsMoto[makeUpper];
  if (!models) {
    return [];
  }

  const result = new Set();
  for (const modelItem of models) {
    for (const gen of modelItem.generations) {
      if (year >= gen.start && year <= gen.end) {
        result.add(gen.name);
      }
    }
  }
  return Array.from(result).sort();
}

// Générer les fichiers pour une année
function generateYearFiles(year, outputDir) {
  console.log(`Génération année ${year}...`);

  // Top 20 marques (stable pour toutes les années)
  const makes = [...fallbackTopMotoBrands];

  // Générer YYYY_models.json
  const modelsJson = {
    year: year,
    makes: makes
  };
  const modelsPath = path.join(outputDir, `${year}_models.json`);
  writeJson(modelsPath, modelsJson);
  console.log(`  ✓ ${year}_models.json (${makes.length} marques)`);

  // Générer YYYY_makes.json avec makeBlocks
  const makeBlocks = [];
  for (const makeUpper of makes) {
    const models = computeModelsForMakeYear(makeUpper, year);
    makeBlocks.push({
      make: makeUpper,
      models: models
    });
  }

  const makesJson = {
    year: year,
    makeBlocks: makeBlocks
  };
  const makesPath = path.join(outputDir, `${year}_makes.json`);
  writeJson(makesPath, makesJson);
  
  const totalModels = makeBlocks.reduce((sum, block) => sum + block.models.length, 0);
  console.log(`  ✓ ${year}_makes.json (${makeBlocks.length} makeBlocks, ${totalModels} modèles)`);
}

// Main
function main() {
  const outputDir = path.join(__dirname, '..', 'src', 'assets', 'reference', 'vehicles', 'motos', 'fr');
  
  console.log('🚀 Génération référentiel motos FR (2005-2024)...');
  console.log(`📁 Dossier de sortie: ${outputDir}`);

  // Créer le dossier si nécessaire
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Générer pour chaque année
  for (let year = 2005; year <= 2024; year++) {
    generateYearFiles(year, outputDir);
  }

  console.log(`\n✅ Génération terminée: 20 années (2005-2024) -> ${outputDir}`);
}

main();

