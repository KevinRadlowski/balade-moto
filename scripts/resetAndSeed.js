/* eslint-disable no-console */
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
require("dotenv").config();

const User = require("../src/models/User");
const Ride = require("../src/models/Ride");
const Group = require("../src/models/Group");
const Message = require("../src/models/Message");

const Vehicle = require("../src/models/Vehicle");
const VehicleDocument = require("../src/models/VehicleDocument");
const MaintenanceItem = require("../src/models/MaintenanceItem");
const MaintenanceLog = require("../src/models/MaintenanceLog");

const MONGO_URI =
  process.env.MONGO_URI || "mongodb://localhost:27017/moto_car_rides";

// Mot de passe UNIQUE pour tous les comptes mock (simple pour tester)
const PLAIN_PASSWORD = "RideTogether123!";
let U = {}; // rempli après insertMany(User)
let vehiclesByUser = {}; // rempli après insertMany(Vehicle)

// Helpers
function point(lng, lat) {
  return { type: "Point", coordinates: [lng, lat] };
}

function addDays(base, days, hour, minute) {
  const d = new Date(base);
  d.setDate(d.getDate() + days);
  d.setHours(hour, minute, 0, 0);
  return d;
}

function addHours(base, hours) {
  const d = new Date(base);
  d.setHours(d.getHours() + hours);
  return d;
}

function addMinutes(base, minutes) {
  const d = new Date(base);
  d.setMinutes(d.getMinutes() + minutes);
  return d;
}

function pickRandom(arr) {
  if (!arr || arr.length === 0) return null;
  return arr[Math.floor(Math.random() * arr.length)];
}

/**
 * Retourne un vehicleId cohérent pour un pseudo et un type de balade.
 * - typeVehicule attendu: "moto" | "voiture"
 * - fallback: si pas trouvé, renvoie null
 */
function vehicleIdForUser(pseudo, typeVehicule) {
  const bucket = vehiclesByUser[pseudo];
  if (!bucket) return null;

  if (typeVehicule === "moto") return pickRandom(bucket.moto)?._id || null;
  if (typeVehicule === "voiture")
    return pickRandom(bucket.voiture)?._id || null;

  return null;
}

/**
 * Participants réalistes basés sur les pseudos.
 * Auto-assigne un véhicule compatible avec le typeVehicule de la balade.
 */
function participantsFromPseudos(pseudos, typeVehicule, options = {}) {
  const { organizerPseudo = null } = options;

  return pseudos
    .map((p) => {
      const user = U[p];
      if (!user) {
        // si un pseudo est invalide, on ne casse pas le seed
        return null;
      }

      const vehicleId = vehicleIdForUser(p, typeVehicule);

      return {
        userId: user._id,
        vehicleId,
        arrivalTime: null,
        isOnTime: null,
        validatedBy: null,
        validatedAt: null,
        // Optionnel : tu peux rajouter un statut si ton schema le supporte
        // status: p === organizerPseudo ? "accepted" : "invited",
      };
    })
    .filter(Boolean);
}

function rideWaypoints({
  departAddress,
  departLng,
  departLat,
  checkpoints = [],
  arriveeAddress,
  arriveeLng,
  arriveeLat,
}) {
  const wps = [];
  wps.push({
    type: "depart",
    address: departAddress,
    coordinates: point(departLng, departLat),
    order: 0,
  });

  checkpoints.forEach((cp, idx) => {
    wps.push({
      type: "checkpoint",
      address: cp.address,
      coordinates: point(cp.lng, cp.lat),
      order: idx + 1,
    });
  });

  wps.push({
    type: "arrivee",
    address: arriveeAddress,
    coordinates: point(arriveeLng, arriveeLat),
    order: checkpoints.length + 1,
  });

  return wps;
}

async function resetAndSeed() {
  console.log("🔌 Connexion MongoDB...");
  await mongoose.connect(MONGO_URI);
  console.log("✅ Connecté:", MONGO_URI);

  console.log("\n🧨 DROP COMPLET de la base...");
  await mongoose.connection.db.dropDatabase();
  console.log("✅ Base supprimée (dropDatabase)");

  // Recréation indexes depuis les schemas (syncIndexes = source de vérité)
  console.log("\n🧷 Recréation des indexes via syncIndexes()...");
  await User.syncIndexes();
  await Ride.syncIndexes();
  await Group.syncIndexes();
  await Message.syncIndexes();
  await Vehicle.syncIndexes();
  await VehicleDocument.syncIndexes();
  await MaintenanceItem.syncIndexes();
  await MaintenanceLog.syncIndexes();

  console.log("✅ Indexes recréés");

  // ---------- USERS ----------
  console.log("\n👤 Création des utilisateurs mock...");
  const hashed = await bcrypt.hash(PLAIN_PASSWORD, 10);

  // Téléphone E.164 OBLIGATOIRE pour tes users (sauf OAuth)
  // => on met des numéros uniques type +3360000000X
  const usersPayload = [
    {
      pseudo: "admin_ride",
      email: "admin@ridetogether.dev",
      phoneE164: "+33600000001",
      firstName: "Admin",
      lastName: "Ride",
      vehiclePreference: "les deux",
      roles: ["admin"],
    },
    {
      pseudo: "lyon_moto",
      email: "lyon.moto@ridetogether.dev",
      phoneE164: "+33600000002",
      firstName: "Léo",
      lastName: "Lyon",
      vehiclePreference: "moto",
    },
    {
      pseudo: "paris_car",
      email: "paris.car@ridetogether.dev",
      phoneE164: "+33600000003",
      firstName: "Paula",
      lastName: "Paris",
      vehiclePreference: "voiture",
    },
    {
      pseudo: "marseille_mix",
      email: "marseille@ridetogether.dev",
      phoneE164: "+33600000004",
      firstName: "Marius",
      lastName: "Marseille",
      vehiclePreference: "les deux",
    },
    {
      pseudo: "bordeaux_moto",
      email: "bordeaux@ridetogether.dev",
      phoneE164: "+33600000005",
      firstName: "Boris",
      lastName: "Bordeaux",
      vehiclePreference: "moto",
    },
    {
      pseudo: "toulouse_car",
      email: "toulouse@ridetogether.dev",
      phoneE164: "+33600000006",
      firstName: "Tina",
      lastName: "Toulouse",
      vehiclePreference: "voiture",
    },
    {
      pseudo: "nice_moto",
      email: "nice@ridetogether.dev",
      phoneE164: "+33600000007",
      firstName: "Nina",
      lastName: "Nice",
      vehiclePreference: "moto",
    },
    {
      pseudo: "lille_car",
      email: "lille@ridetogether.dev",
      phoneE164: "+33600000008",
      firstName: "Liam",
      lastName: "Lille",
      vehiclePreference: "voiture",
    },
  ];

  const createdUsers = await User.insertMany(
    usersPayload.map((u) => ({
      ...u,
      password: hashed,
      role: u.roles?.includes("admin") ? "ADMIN" : "MEMBER",
      roles: u.roles || ["user"],
      emailVerified: true,
      phoneVerified: true,
      status: "active",
      banned: false,
      isDeleted: false,
      twoFactorEnabled: false,
      isTwoFactorEnabled: false,
    })),
    { ordered: true }
  );

  U = Object.fromEntries(createdUsers.map((u) => [u.pseudo, u]));
  console.log(`✅ ${createdUsers.length} utilisateurs créés`);

  // ---------- VEHICLES ----------
  console.log(
    "\n🚗🏍️  Création des véhicules (1 moto + 1 voiture par utilisateur)..."
  );

  // Helpers photos/docs
  const photoUrl = (seed) =>
    `https://picsum.photos/seed/${encodeURIComponent(seed)}/900/600`;
  const fileUrl = (seed) =>
    `https://example.com/mock-files/${encodeURIComponent(seed)}.pdf`;

  // Petit catalogue simple (tu peux enrichir si tu veux)
  const motoTemplates = [
    {
      make: "Yamaha",
      model: "MT-07",
      year: 2021,
      displacementCc: 689,
      fuel: "essence",
      powerHp: 74,
      transmission: "manuelle",
    },
    {
      make: "Kawasaki",
      model: "Z900",
      year: 2020,
      displacementCc: 948,
      fuel: "essence",
      powerHp: 125,
      transmission: "manuelle",
    },
    {
      make: "Honda",
      model: "CB650R",
      year: 2022,
      displacementCc: 649,
      fuel: "essence",
      powerHp: 95,
      transmission: "manuelle",
    },
    {
      make: "BMW",
      model: "R 1250 GS",
      year: 2019,
      displacementCc: 1254,
      fuel: "essence",
      powerHp: 136,
      transmission: "manuelle",
    },
  ];

  const carTemplates = [
    {
      make: "Peugeot",
      model: "308",
      year: 2020,
      fuel: "diesel",
      powerHp: 130,
      transmission: "manuelle",
    },
    {
      make: "Renault",
      model: "Clio",
      year: 2021,
      fuel: "essence",
      powerHp: 100,
      transmission: "manuelle",
    },
    {
      make: "Volkswagen",
      model: "Golf",
      year: 2019,
      fuel: "diesel",
      powerHp: 150,
      transmission: "automatique",
    },
    {
      make: "Tesla",
      model: "Model 3",
      year: 2022,
      fuel: "electrique",
      powerHp: 283,
      transmission: "automatique",
    },
  ];

  function pick(arr, idx) {
    return arr[idx % arr.length];
  }

  // Génère un odomètre réaliste
  function randomKm(min, max) {
    return Math.floor(min + Math.random() * (max - min));
  }

  const vehiclesPayload = [];

  createdUsers.forEach((user, idx) => {
    const moto = pick(motoTemplates, idx);
    const car = pick(carTemplates, idx);

    vehiclesPayload.push({
      ownerUserId: user._id,
      type: "moto",
      nickname: `${moto.make} ${moto.model}`,
      make: moto.make,
      model: moto.model,
      year: moto.year,
      engine: {
        fuel: moto.fuel,
        displacementCc: moto.displacementCc,
        powerHp: moto.powerHp,
        transmission: moto.transmission,
      },
      odometerCurrentKm: randomKm(8000, 60000),
      purchase: {
        date: new Date(new Date().setFullYear(new Date().getFullYear() - 2)),
        price: 6500 + idx * 250,
        sellerType: "professionnel",
      },
      insurance: {
        company: "AXA",
        policyNumber: `MOTO-${100000 + idx}`,
        renewalDate: new Date(new Date().setMonth(new Date().getMonth() + 3)),
      },
      photos: [
        { url: photoUrl(`moto_${user.pseudo}_1`), order: 0 },
        { url: photoUrl(`moto_${user.pseudo}_2`), order: 1 },
      ],
      active: true,
    });

    vehiclesPayload.push({
      ownerUserId: user._id,
      type: "voiture",
      nickname: `${car.make} ${car.model}`,
      make: car.make,
      model: car.model,
      year: car.year,
      engine: {
        fuel: car.fuel,
        displacementCc: null,
        powerHp: car.powerHp,
        transmission: car.transmission,
      },
      odometerCurrentKm: randomKm(12000, 120000),
      purchase: {
        date: new Date(new Date().setFullYear(new Date().getFullYear() - 3)),
        price: 12000 + idx * 500,
        sellerType: "concessionnaire",
      },
      insurance: {
        company: "MAIF",
        policyNumber: `AUTO-${200000 + idx}`,
        renewalDate: new Date(new Date().setMonth(new Date().getMonth() + 2)),
      },
      photos: [
        { url: photoUrl(`car_${user.pseudo}_1`), order: 0 },
        { url: photoUrl(`car_${user.pseudo}_2`), order: 1 },
      ],
      active: true,
    });
  });

  // Ajout d’un 3ème véhicule pour 4 utilisateurs (pour tester multi-vehicules)
  const extraVehicles = [
    {
      pseudo: "admin_ride",
      type: "moto",
      make: "Ducati",
      model: "Monster 821",
      year: 2020,
      fuel: "essence",
      displacementCc: 821,
      powerHp: 109,
      transmission: "manuelle",
    },
    {
      pseudo: "lyon_moto",
      type: "moto",
      make: "Triumph",
      model: "Street Triple 765",
      year: 2021,
      fuel: "essence",
      displacementCc: 765,
      powerHp: 118,
      transmission: "manuelle",
    },
    {
      pseudo: "paris_car",
      type: "voiture",
      make: "BMW",
      model: "Série 1",
      year: 2018,
      fuel: "diesel",
      powerHp: 150,
      transmission: "automatique",
    },
    {
      pseudo: "marseille_mix",
      type: "voiture",
      make: "Audi",
      model: "A3",
      year: 2019,
      fuel: "essence",
      powerHp: 150,
      transmission: "automatique",
    },
  ];

  extraVehicles.forEach((ev, idx) => {
    const user = createdUsers.find((u) => u.pseudo === ev.pseudo);
    if (!user) return;

    vehiclesPayload.push({
      ownerUserId: user._id,
      type: ev.type,
      nickname: `${ev.make} ${ev.model} (2)`,
      make: ev.make,
      model: ev.model,
      year: ev.year,
      engine: {
        fuel: ev.fuel,
        displacementCc: ev.displacementCc ?? null,
        powerHp: ev.powerHp ?? null,
        transmission: ev.transmission ?? "manuelle",
      },
      odometerCurrentKm: randomKm(5000, 90000),
      purchase: {
        date: new Date(new Date().setFullYear(new Date().getFullYear() - 1)),
        price: 9000 + idx * 800,
        sellerType: "particulier",
      },
      insurance: {
        company: "Groupama",
        policyNumber: `EXTRA-${300000 + idx}`,
        renewalDate: new Date(new Date().setMonth(new Date().getMonth() + 5)),
      },
      photos: [
        { url: photoUrl(`extra_${user.pseudo}_1`), order: 0 },
        { url: photoUrl(`extra_${user.pseudo}_2`), order: 1 },
        { url: photoUrl(`extra_${user.pseudo}_3`), order: 2 },
      ],
      active: true,
    });
  });

  const createdVehicles = await Vehicle.insertMany(vehiclesPayload);
  // Map robuste: { pseudo: { moto: [v1,v2], voiture: [v1,...] } }
  vehiclesByUser = {};

  createdVehicles.forEach((v) => {
    const owner = createdUsers.find(
      (u) => u._id.toString() === v.ownerUserId.toString()
    );
    if (!owner) return;

    vehiclesByUser[owner.pseudo] = vehiclesByUser[owner.pseudo] || {
      moto: [],
      voiture: [],
    };

    if (v.type === "moto") vehiclesByUser[owner.pseudo].moto.push(v);
    if (v.type === "voiture") vehiclesByUser[owner.pseudo].voiture.push(v);
  });

  // Bonus documents : 2 docs supplémentaires par véhicule (pour plus de variété)
  const extraDocsPayload = createdVehicles.flatMap((v, idx) => [
    {
      vehicleId: v._id,
      ownerUserId: v.ownerUserId,
      type: "FACTURE",
      label: "Facture pneus (mock)",
      fileUrl: fileUrl(`facture_pneus_${v._id}`),
      date: new Date(new Date().setMonth(new Date().getMonth() - 4)),
      notes: "Facture mock",
    },
    {
      vehicleId: v._id,
      ownerUserId: v.ownerUserId,
      type: "AUTRE",
      label: "Scan document (mock)",
      fileUrl: fileUrl(`scan_${v._id}`),
      date: new Date(new Date().setMonth(new Date().getMonth() - 1)),
      notes: "Scan mock",
    },
  ]);

  await VehicleDocument.insertMany(extraDocsPayload);
  console.log(`✅ ${extraDocsPayload.length} documents bonus créés`);

  console.log(`✅ ${createdVehicles.length} véhicules créés`);

  // ---------- VEHICLE DOCUMENTS ----------
  console.log(
    "\n📄 Création des documents véhicules (assurance + carte grise + facture/CT)..."
  );

  const documentsPayload = [];
  createdUsers.forEach((user, idx) => {
    const motoV = vehiclesByUser[user.pseudo]?.moto?.[0] || null;
    const carV = vehiclesByUser[user.pseudo]?.voiture?.[0] || null;

    // Moto: assurance + carte grise (AUTRE) + facture
    if (motoV) {
      documentsPayload.push(
        {
          vehicleId: motoV._id,
          ownerUserId: user._id,
          type: "ASSURANCE",
          label: "Attestation assurance moto",
          fileUrl: fileUrl(`assurance_moto_${user.pseudo}`),
          date: new Date(),
          notes: "Document mock",
        },
        {
          vehicleId: motoV._id,
          ownerUserId: user._id,
          type: "AUTRE",
          label: "Carte grise moto",
          fileUrl: fileUrl(`carte_grise_moto_${user.pseudo}`),
          date: new Date(),
          notes: "Document mock",
        },
        {
          vehicleId: motoV._id,
          ownerUserId: user._id,
          type: "FACTURE",
          label: "Facture entretien moto",
          fileUrl: fileUrl(`facture_moto_${user.pseudo}`),
          date: new Date(new Date().setMonth(new Date().getMonth() - 2)),
          notes: "Facture mock",
        }
      );

      // Bonus docs : 1 facture + 1 autre doc si l'utilisateur a un 3ème véhicule
      const extraMoto =
        vehiclesByUser[user.pseudo]?.moto &&
        vehiclesByUser[user.pseudo]?.moto._id;
      // NOTE: vehiclesByUser ne stocke qu’un seul véhicule par type. Si tu veux viser le 3ème, le plus simple est de générer bonus docs "par véhicule" après insertMany.
    }

    // Voiture: assurance + carte grise (AUTRE) + CT
    if (carV) {
      documentsPayload.push(
        {
          vehicleId: carV._id,
          ownerUserId: user._id,
          type: "ASSURANCE",
          label: "Attestation assurance voiture",
          fileUrl: fileUrl(`assurance_voiture_${user.pseudo}`),
          date: new Date(),
          notes: "Document mock",
        },
        {
          vehicleId: carV._id,
          ownerUserId: user._id,
          type: "AUTRE",
          label: "Carte grise voiture",
          fileUrl: fileUrl(`carte_grise_voiture_${user.pseudo}`),
          date: new Date(),
          notes: "Document mock",
        },
        {
          vehicleId: carV._id,
          ownerUserId: user._id,
          type: "CT",
          label: "Contrôle technique",
          fileUrl: fileUrl(`ct_voiture_${user.pseudo}`),
          date: new Date(new Date().setMonth(new Date().getMonth() - 6)),
          notes: "CT mock",
        }
      );
    }
  });

  await VehicleDocument.insertMany(documentsPayload);
  console.log(`✅ ${documentsPayload.length} documents créés`);

  // ---------- MAINTENANCE LOGS + ITEMS ----------
  console.log(
    "\n🧰 Création des entretiens (logs) + maintenances planifiées (items)..."
  );

  const maintenanceLogsPayload = [];
  const maintenanceItemsPayload = [];

  const maintenanceCatalog = [
    { category: "vidange", label: "Vidange" },
    { category: "pneus", label: "Changement pneus" },
    { category: "freins", label: "Plaquettes de frein" },
    { category: "revision", label: "Révision générale" },
  ];

  createdVehicles.forEach((v, idx) => {
    const baseKm = v.odometerCurrentKm || 0;

    // 2 logs passés
    // 4 logs passés
    maintenanceLogsPayload.push(
      {
        vehicleId: v._id,
        category: "vidange",
        label: "Vidange + filtre huile",
        date: new Date(new Date().setMonth(new Date().getMonth() - 3)),
        kmAtService: Math.max(0, baseKm - 3500),
        cost: 180 + (idx % 3) * 40,
        garageName: "Garage Mock Center",
        invoiceFileUrl: fileUrl(`invoice_vidange_${v._id}`),
        notes: "Entretien mock",
      },
      {
        vehicleId: v._id,
        category: "freins",
        label: "Contrôle freins",
        date: new Date(new Date().setMonth(new Date().getMonth() - 8)),
        kmAtService: Math.max(0, baseKm - 9000),
        cost: 0,
        garageName: "Garage Mock Center",
        invoiceFileUrl: null,
        notes: "Contrôle mock",
      },
      {
        vehicleId: v._id,
        category: "pneus",
        label: "Permutation / contrôle pneus",
        date: new Date(new Date().setMonth(new Date().getMonth() - 5)),
        kmAtService: Math.max(0, baseKm - 6000),
        cost: 60 + (idx % 4) * 15,
        garageName: "Pneus Express",
        invoiceFileUrl: fileUrl(`invoice_pneus_${v._id}`),
        notes: "Service mock",
      },
      {
        vehicleId: v._id,
        category: "revision",
        label: "Révision",
        date: new Date(new Date().setMonth(new Date().getMonth() - 11)),
        kmAtService: Math.max(0, baseKm - 14000),
        cost: 250 + (idx % 5) * 30,
        garageName: "Garage Mock Center",
        invoiceFileUrl: fileUrl(`invoice_revision_${v._id}`),
        notes: "Révision mock",
      }
    );

    // 3 items à venir
    const dueVidangeKm = baseKm + 4000;
    maintenanceItemsPayload.push(
      {
        vehicleId: v._id,
        category: "vidange",
        label: "Prochaine vidange",
        intervalKm: 8000,
        intervalMonths: 12,
        lastDoneAtKm: Math.max(0, baseKm - 3500),
        lastDoneAtDate: new Date(
          new Date().setMonth(new Date().getMonth() - 3)
        ),
        dueAtKm: dueVidangeKm,
        dueAtDate: new Date(new Date().setMonth(new Date().getMonth() + 9)),
        status: "UPCOMING",
        notes: "Planifié (mock)",
        active: true,
      },
      {
        vehicleId: v._id,
        category: "pneus",
        label: "Contrôle usure pneus",
        intervalKm: 15000,
        intervalMonths: 18,
        lastDoneAtKm: Math.max(0, baseKm - 7000),
        lastDoneAtDate: new Date(
          new Date().setMonth(new Date().getMonth() - 6)
        ),
        dueAtKm: baseKm + 8000,
        dueAtDate: new Date(new Date().setMonth(new Date().getMonth() + 12)),
        status: "UPCOMING",
        notes: "Planifié (mock)",
        active: true,
      },
      {
        vehicleId: v._id,
        category: "revision",
        label: "Révision annuelle",
        intervalKm: null,
        intervalMonths: 12,
        lastDoneAtKm: null,
        lastDoneAtDate: new Date(
          new Date().setMonth(new Date().getMonth() - 11)
        ),
        dueAtKm: null,
        dueAtDate: new Date(new Date().setMonth(new Date().getMonth() + 1)),
        status: "DUE",
        notes: "À faire bientôt (mock)",
        active: true,
      }
    );

    maintenanceItemsPayload.push(
      {
        vehicleId: v._id,
        category: "freins",
        label: "Contrôle plaquettes",
        intervalKm: 12000,
        intervalMonths: 18,
        lastDoneAtKm: Math.max(0, baseKm - 9000),
        lastDoneAtDate: new Date(
          new Date().setMonth(new Date().getMonth() - 8)
        ),
        dueAtKm: baseKm + 6000,
        dueAtDate: new Date(new Date().setMonth(new Date().getMonth() + 10)),
        status: "UPCOMING",
        notes: "Planifié (mock)",
        active: true,
      },
      {
        vehicleId: v._id,
        category: "ct", // <-- très souvent l'enum est en minuscule
        label: "Contrôle technique (voitures)",
        intervalKm: null,
        intervalMonths: 24,
        lastDoneAtKm: null,
        lastDoneAtDate: new Date(
          new Date().setMonth(new Date().getMonth() - 14)
        ),
        dueAtKm: null,
        dueAtDate: new Date(new Date().setMonth(new Date().getMonth() + 10)),
        status: v.type === "voiture" ? "UPCOMING" : "SKIPPED",
        notes: "Applicable voitures seulement (mock)",
        active: v.type === "voiture",
      }
    );
  });

  console.log(
    "MaintenanceItem.category enumValues =",
    MaintenanceItem.schema.path("category")?.enumValues
  );
  await MaintenanceLog.insertMany(maintenanceLogsPayload);
  await MaintenanceItem.insertMany(maintenanceItemsPayload);

  console.log(`✅ ${maintenanceLogsPayload.length} logs d'entretien créés`);
  console.log(
    `✅ ${maintenanceItemsPayload.length} maintenances planifiées créées`
  );

  // ---------- RIDES ----------
  console.log("\n🗺️  Création des balades mock...");

  const now = new Date();

  // Centres villes (lng,lat)
  const cities = {
    paris: { name: "Paris", lat: 48.8566, lng: 2.3522 },
    lyon: { name: "Lyon", lat: 45.764, lng: 4.8357 },
    marseille: { name: "Marseille", lat: 43.2965, lng: 5.3698 },
    bordeaux: { name: "Bordeaux", lat: 44.8378, lng: -0.5792 },
    lille: { name: "Lille", lat: 50.6292, lng: 3.0573 },
    toulouse: { name: "Toulouse", lat: 43.6047, lng: 1.4442 },
    nantes: { name: "Nantes", lat: 47.2184, lng: -1.5536 },
    nice: { name: "Nice", lat: 43.7102, lng: 7.262 },
  };

  const ridesPayload = [
    // PARIS (publique, checkpoints)
    {
      titre: "Boucle Paris → Vallée de Chevreuse",
      description: "Balade détente avec arrêts café + points de vue.",
      typeVehicule: "moto",
      date: addDays(now, 1, 10, 0),
      heure: "10:00",
      lieuDepart: "Paris - Bastille",
      lieuArrivee: "Saint-Rémy-lès-Chevreuse",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.paris_car._id,
      participants: participantsFromPseudos(
        ["paris_car", "lyon_moto"],
        "moto",
        {
          organizerPseudo: "paris_car",
        }
      ),
      localisation: point(cities.paris.lng, cities.paris.lat),
      waypoints: rideWaypoints({
        departAddress: "Paris - Bastille",
        departLng: 2.369,
        departLat: 48.853,
        checkpoints: [
          { address: "Sceaux - Parc", lng: 2.295, lat: 48.776 },
          { address: "Gif-sur-Yvette - centre", lng: 2.133, lat: 48.701 },
        ],
        arriveeAddress: "Saint-Rémy-lès-Chevreuse",
        arriveeLng: 2.076,
        arriveeLat: 48.706,
      }),
    },

    // LYON (publique, sans checkpoints)
    {
      titre: "Lyon → Monts du Lyonnais",
      description: "Petite sortie après-midi, route sympa et accessible.",
      typeVehicule: "moto",
      date: addDays(now, 2, 14, 30),
      heure: "14:30",
      lieuDepart: "Lyon - Bellecour",
      lieuArrivee: "Yzeron",
      visibilite: "publique",
      ridingStyle: "modere",
      organisateur: U.lyon_moto._id,
      participants: participantsFromPseudos(
        ["lyon_moto", "admin_ride"],
        "moto",
        {
          organizerPseudo: "lyon_moto",
        }
      ),
      localisation: point(cities.lyon.lng, cities.lyon.lat),
      waypoints: rideWaypoints({
        departAddress: "Lyon - Bellecour",
        departLng: 4.832,
        departLat: 45.7579,
        checkpoints: [],
        arriveeAddress: "Yzeron",
        arriveeLng: 4.52,
        arriveeLat: 45.72,
      }),
    },

    // MARSEILLE (privée, checkpoints)
    {
      titre: "Marseille → Calanques (Privé)",
      description: "Groupe fermé, invitation requise.",
      typeVehicule: "voiture",
      date: addDays(now, 3, 9, 0),
      heure: "09:00",
      lieuDepart: "Marseille - Vieux Port",
      lieuArrivee: "Cassis",
      visibilite: "privee",
      ridingStyle: "calme",
      organisateur: U.marseille_mix._id,
      participants: participantsFromPseudos(["marseille_mix"], "voiture", {
        organizerPseudo: "marseille_mix",
      }),
      localisation: point(cities.marseille.lng, cities.marseille.lat),
      waypoints: rideWaypoints({
        departAddress: "Marseille - Vieux Port",
        departLng: 5.3764,
        departLat: 43.2964,
        checkpoints: [
          { address: "Goudes - belvédère", lng: 5.344, lat: 43.212 },
        ],
        arriveeAddress: "Cassis - Port",
        arriveeLng: 5.538,
        arriveeLat: 43.214,
      }),
    },

    // BORDEAUX (publique, checkpoints)
    {
      titre: "Bordeaux → Route des vins",
      description: "On roule tranquille, on s’arrête, photos.",
      typeVehicule: "moto",
      date: addDays(now, 4, 10, 15),
      heure: "10:15",
      lieuDepart: "Bordeaux - Quinconces",
      lieuArrivee: "Saint-Émilion",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.bordeaux_moto._id,
      participants: participantsFromPseudos(
        ["bordeaux_moto", "paris_car"],
        "moto",
        {
          organizerPseudo: "bordeaux_moto",
        }
      ),
      localisation: point(cities.bordeaux.lng, cities.bordeaux.lat),
      waypoints: rideWaypoints({
        departAddress: "Bordeaux - Quinconces",
        departLng: -0.573,
        departLat: 44.845,
        checkpoints: [{ address: "Pessac - arrêt", lng: -0.634, lat: 44.806 }],
        arriveeAddress: "Saint-Émilion",
        arriveeLng: -0.155,
        arriveeLat: 44.894,
      }),
    },

    // LILLE (publique)
    {
      titre: "Lille → Belgique (frontière)",
      description: "Sortie courte, roadtrip cool.",
      typeVehicule: "voiture",
      date: addDays(now, 5, 11, 0),
      heure: "11:00",
      lieuDepart: "Lille - Grand Place",
      lieuArrivee: "Tournai",
      visibilite: "publique",
      ridingStyle: "modere",
      organisateur: U.lille_car._id,
      participants: participantsFromPseudos(
        ["lille_car", "admin_ride"],
        "voiture",
        {
          organizerPseudo: "lille_car",
        }
      ),
      localisation: point(cities.lille.lng, cities.lille.lat),
      waypoints: rideWaypoints({
        departAddress: "Lille - Grand Place",
        departLng: 3.063,
        departLat: 50.636,
        checkpoints: [],
        arriveeAddress: "Tournai",
        arriveeLng: 3.389,
        arriveeLat: 50.607,
      }),
    },

    // TOULOUSE (privée)
    {
      titre: "Toulouse → Lac (Privé)",
      description: "Balade privée, uniquement invités.",
      typeVehicule: "voiture",
      date: addDays(now, 6, 15, 0),
      heure: "15:00",
      lieuDepart: "Toulouse - Capitole",
      lieuArrivee: "Lac de Saint-Ferréol",
      visibilite: "privee",
      ridingStyle: "calme",
      organisateur: U.toulouse_car._id,
      participants: participantsFromPseudos(["toulouse_car"], "voiture", {
        organizerPseudo: "toulouse_car",
      }),
      localisation: point(cities.toulouse.lng, cities.toulouse.lat),
      waypoints: rideWaypoints({
        departAddress: "Toulouse - Capitole",
        departLng: 1.444,
        departLat: 43.6045,
        checkpoints: [
          { address: "Castelnaudary - pause", lng: 1.952, lat: 43.318 },
        ],
        arriveeAddress: "Lac de Saint-Ferréol",
        arriveeLng: 2.01,
        arriveeLat: 43.454,
      }),
    },

    // NICE (publique, sportif)
    {
      titre: "Nice → Col de Turini",
      description: "Rythme soutenu, routes de montagne.",
      typeVehicule: "moto",
      date: addDays(now, 7, 8, 30),
      heure: "08:30",
      lieuDepart: "Nice - Promenade des Anglais",
      lieuArrivee: "Col de Turini",
      visibilite: "publique",
      ridingStyle: "sportif",
      organisateur: U.nice_moto._id,
      participants: participantsFromPseudos(
        ["nice_moto", "marseille_mix"],
        "moto",
        {
          organizerPseudo: "nice_moto",
        }
      ),
      localisation: point(cities.nice.lng, cities.nice.lat),
      waypoints: rideWaypoints({
        departAddress: "Nice - Promenade des Anglais",
        departLng: 7.265,
        departLat: 43.695,
        checkpoints: [{ address: "Sospel", lng: 7.449, lat: 43.878 }],
        arriveeAddress: "Col de Turini",
        arriveeLng: 7.395,
        arriveeLat: 43.992,
      }),
    },

    // NANTES (publique)
    {
      titre: "Nantes → Côte (Pornic)",
      description: "Balade chill vers la mer.",
      typeVehicule: "moto",
      date: addDays(now, 8, 10, 0),
      heure: "10:00",
      lieuDepart: "Nantes - Centre",
      lieuArrivee: "Pornic",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.admin_ride._id,
      participants: participantsFromPseudos(
        ["admin_ride", "bordeaux_moto"],
        "moto",
        {
          organizerPseudo: "admin_ride",
        }
      ),
      localisation: point(cities.nantes.lng, cities.nantes.lat),
      waypoints: rideWaypoints({
        departAddress: "Nantes - Centre",
        departLng: -1.5536,
        departLat: 47.2184,
        checkpoints: [{ address: "Bouaye - pause", lng: -1.693, lat: 47.142 }],
        arriveeAddress: "Pornic",
        arriveeLng: -2.103,
        arriveeLat: 47.115,
      }),
    },

    // Une balade passée (pour tester historique)
    {
      titre: "Balade test passée (Lyon)",
      description: "Balade terminée, utile pour test historique et notes.",
      typeVehicule: "moto",
      date: addDays(now, -3, 10, 0),
      heure: "10:00",
      lieuDepart: "Lyon - Part-Dieu",
      lieuArrivee: "Lyon - Part-Dieu",
      visibilite: "publique",
      ridingStyle: "mixte",
      status: "completed",
      organisateur: U.lyon_moto._id,
      participants: participantsFromPseudos(
        ["lyon_moto", "paris_car", "admin_ride"],
        "moto",
        { organizerPseudo: "lyon_moto" }
      ),
      localisation: point(cities.lyon.lng, cities.lyon.lat),
      waypoints: rideWaypoints({
        departAddress: "Lyon - Part-Dieu",
        departLng: 4.858,
        departLat: 45.76,
        checkpoints: [{ address: "Miribel - lac", lng: 5.02, lat: 45.83 }],
        arriveeAddress: "Lyon - Part-Dieu",
        arriveeLng: 4.858,
        arriveeLat: 45.76,
      }),
    },

    // ====== AJOUT : +15 balades ======
    // PARIS / IDF
    {
      titre: "IDF - Paris → Chantilly",
      description: "Sortie matinale, route rapide et propre.",
      typeVehicule: "voiture",
      date: addDays(now, 2, 9, 15),
      heure: "09:15",
      lieuDepart: "Paris - Porte de la Chapelle",
      lieuArrivee: "Chantilly",
      visibilite: "publique",
      ridingStyle: "modere",
      organisateur: U.paris_car._id,
      participants: participantsFromPseudos(["paris_car"], "voiture", {
        organizerPseudo: "paris_car",
      }),
      localisation: point(cities.paris.lng, cities.paris.lat),
      waypoints: rideWaypoints({
        departAddress: "Paris - Porte de la Chapelle",
        departLng: 2.359,
        departLat: 48.899,
        checkpoints: [{ address: "St-Denis - pause", lng: 2.357, lat: 48.936 }],
        arriveeAddress: "Chantilly",
        arriveeLng: 2.472,
        arriveeLat: 49.193,
      }),
    },
    {
      titre: "IDF - Boucle Fontainebleau",
      description: "Routes forêt, photos au spot.",
      typeVehicule: "moto",
      date: addDays(now, 4, 9, 45),
      heure: "09:45",
      lieuDepart: "Paris - Porte d'Italie",
      lieuArrivee: "Fontainebleau",
      visibilite: "publique",
      ridingStyle: "mixte",
      organisateur: U.admin_ride._id,
      participants: participantsFromPseudos(
        ["admin_ride", "paris_car"],
        "moto",
        {
          organizerPseudo: "admin_ride",
        }
      ),
      localisation: point(cities.paris.lng, cities.paris.lat),
      waypoints: rideWaypoints({
        departAddress: "Paris - Porte d'Italie",
        departLng: 2.362,
        departLat: 48.817,
        checkpoints: [{ address: "Melun - pause", lng: 2.653, lat: 48.54 }],
        arriveeAddress: "Fontainebleau",
        arriveeLng: 2.701,
        arriveeLat: 48.404,
      }),
    },

    // LYON / AURA
    {
      titre: "Lyon → Pérouges",
      description: "Balade courte + arrêt dans la cité médiévale.",
      typeVehicule: "moto",
      date: addDays(now, 3, 10, 30),
      heure: "10:30",
      lieuDepart: "Lyon - Confluence",
      lieuArrivee: "Pérouges",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.lyon_moto._id,
      participants: participantsFromPseudos(
        ["lyon_moto", "lille_car"],
        "moto",
        {
          organizerPseudo: "lyon_moto",
        }
      ),
      localisation: point(cities.lyon.lng, cities.lyon.lat),
      waypoints: rideWaypoints({
        departAddress: "Lyon - Confluence",
        departLng: 4.819,
        departLat: 45.74,
        checkpoints: [],
        arriveeAddress: "Pérouges",
        arriveeLng: 5.178,
        arriveeLat: 45.904,
      }),
    },
    {
      titre: "AURA - Lyon → Beaujolais (Privé)",
      description: "Balade privée, groupe restreint.",
      typeVehicule: "voiture",
      date: addDays(now, 6, 13, 0),
      heure: "13:00",
      lieuDepart: "Lyon - Part-Dieu",
      lieuArrivee: "Villefranche-sur-Saône",
      visibilite: "privee",
      ridingStyle: "modere",
      organisateur: U.admin_ride._id,
      participants: participantsFromPseudos(["admin_ride"], "voiture", {
        organizerPseudo: "admin_ride",
      }),
      localisation: point(cities.lyon.lng, cities.lyon.lat),
      waypoints: rideWaypoints({
        departAddress: "Lyon - Part-Dieu",
        departLng: 4.86,
        departLat: 45.76,
        checkpoints: [{ address: "Limonest - pause", lng: 4.772, lat: 45.834 }],
        arriveeAddress: "Villefranche-sur-Saône",
        arriveeLng: 4.719,
        arriveeLat: 45.989,
      }),
    },

    // MARSEILLE / PACA
    {
      titre: "PACA - Marseille → La Ciotat",
      description: "Côte + panorama, rythme cool.",
      typeVehicule: "moto",
      date: addDays(now, 5, 9, 0),
      heure: "09:00",
      lieuDepart: "Marseille - Prado",
      lieuArrivee: "La Ciotat",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.marseille_mix._id,
      participants: participantsFromPseudos(
        ["marseille_mix", "nice_moto"],
        "moto",
        {
          organizerPseudo: "marseille_mix",
        }
      ),
      localisation: point(cities.marseille.lng, cities.marseille.lat),
      waypoints: rideWaypoints({
        departAddress: "Marseille - Prado",
        departLng: 5.372,
        departLat: 43.261,
        checkpoints: [{ address: "Cassis - photo", lng: 5.539, lat: 43.214 }],
        arriveeAddress: "La Ciotat",
        arriveeLng: 5.604,
        arriveeLat: 43.175,
      }),
    },
    {
      titre: "PACA - Route des Crêtes (Privé)",
      description: "Privé: invitation requise.",
      typeVehicule: "voiture",
      date: addDays(now, 7, 7, 45),
      heure: "07:45",
      lieuDepart: "Cassis",
      lieuArrivee: "La Ciotat",
      visibilite: "privee",
      ridingStyle: "sportif",
      organisateur: U.marseille_mix._id,
      participants: participantsFromPseudos(["marseille_mix"], "voiture", {
        organizerPseudo: "marseille_mix",
      }),
      localisation: point(cities.marseille.lng, cities.marseille.lat),
      waypoints: rideWaypoints({
        departAddress: "Cassis",
        departLng: 5.539,
        departLat: 43.214,
        checkpoints: [
          { address: "Belvédère Route des Crêtes", lng: 5.56, lat: 43.19 },
        ],
        arriveeAddress: "La Ciotat",
        arriveeLng: 5.604,
        arriveeLat: 43.175,
      }),
    },

    // BORDEAUX / NOUVELLE-AQUITAINE
    {
      titre: "Bordeaux → Arcachon",
      description: "Sortie mer, pause au port.",
      typeVehicule: "voiture",
      date: addDays(now, 3, 8, 30),
      heure: "08:30",
      lieuDepart: "Bordeaux - Gare",
      lieuArrivee: "Arcachon",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.bordeaux_moto._id,
      participants: participantsFromPseudos(["bordeaux_moto"], "voiture", {
        organizerPseudo: "bordeaux_moto",
      }),
      localisation: point(cities.bordeaux.lng, cities.bordeaux.lat),
      waypoints: rideWaypoints({
        departAddress: "Bordeaux - Gare",
        departLng: -0.556,
        departLat: 44.826,
        checkpoints: [{ address: "Biganos - pause", lng: -0.979, lat: 44.642 }],
        arriveeAddress: "Arcachon",
        arriveeLng: -1.172,
        arriveeLat: 44.661,
      }),
    },
    {
      titre: "Bordeaux - Boucle Médoc",
      description: "Châteaux + routes longues.",
      typeVehicule: "moto",
      date: addDays(now, 9, 9, 0),
      heure: "09:00",
      lieuDepart: "Bordeaux - Lac",
      lieuArrivee: "Pauillac",
      visibilite: "publique",
      ridingStyle: "mixte",
      organisateur: U.bordeaux_moto._id,
      participants: participantsFromPseudos(
        ["bordeaux_moto", "admin_ride"],
        "moto",
        {
          organizerPseudo: "bordeaux_moto",
        }
      ),
      localisation: point(cities.bordeaux.lng, cities.bordeaux.lat),
      waypoints: rideWaypoints({
        departAddress: "Bordeaux - Lac",
        departLng: -0.58,
        departLat: 44.89,
        checkpoints: [{ address: "Blanquefort", lng: -0.637, lat: 44.91 }],
        arriveeAddress: "Pauillac",
        arriveeLng: -0.748,
        arriveeLat: 45.201,
      }),
    },

    // NICE / arrière-pays
    {
      titre: "Nice → Gorges du Loup",
      description: "Routes sinueuses, photo spot.",
      typeVehicule: "moto",
      date: addDays(now, 10, 9, 0),
      heure: "09:00",
      lieuDepart: "Nice - Centre",
      lieuArrivee: "Pont du Loup",
      visibilite: "publique",
      ridingStyle: "modere",
      organisateur: U.nice_moto._id,
      participants: participantsFromPseudos(["nice_moto"], "moto", {
        organizerPseudo: "nice_moto",
      }),
      localisation: point(cities.nice.lng, cities.nice.lat),
      waypoints: rideWaypoints({
        departAddress: "Nice - Centre",
        departLng: 7.262,
        departLat: 43.71,
        checkpoints: [{ address: "Vence - pause", lng: 7.111, lat: 43.722 }],
        arriveeAddress: "Pont du Loup",
        arriveeLng: 7.0,
        arriveeLat: 43.745,
      }),
    },

    // TOULOUSE / OCCITANIE
    {
      titre: "Toulouse → Albi",
      description: "Sortie journée, patrimoine et routes.",
      typeVehicule: "voiture",
      date: addDays(now, 11, 10, 0),
      heure: "10:00",
      lieuDepart: "Toulouse - Matabiau",
      lieuArrivee: "Albi",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.toulouse_car._id,
      participants: participantsFromPseudos(
        ["toulouse_car", "bordeaux_moto"],
        "voiture",
        {
          organizerPseudo: "toulouse_car",
        }
      ),
      localisation: point(cities.toulouse.lng, cities.toulouse.lat),
      waypoints: rideWaypoints({
        departAddress: "Toulouse - Matabiau",
        departLng: 1.454,
        departLat: 43.611,
        checkpoints: [{ address: "Gaillac - pause", lng: 1.898, lat: 43.901 }],
        arriveeAddress: "Albi",
        arriveeLng: 2.148,
        arriveeLat: 43.929,
      }),
    },

    // LILLE / HAUTS-DE-FRANCE (autres)
    {
      titre: "Lille → Côte d’Opale",
      description: "Longue route, arrivée mer.",
      typeVehicule: "voiture",
      date: addDays(now, 12, 8, 0),
      heure: "08:00",
      lieuDepart: "Lille - Euratechnologies",
      lieuArrivee: "Boulogne-sur-Mer",
      visibilite: "publique",
      ridingStyle: "modere",
      organisateur: U.lille_car._id,
      participants: participantsFromPseudos(["lille_car"], "voiture", {
        organizerPseudo: "lille_car",
      }),
      localisation: point(cities.lille.lng, cities.lille.lat),
      waypoints: rideWaypoints({
        departAddress: "Lille - Euratechnologies",
        departLng: 3.035,
        departLat: 50.634,
        checkpoints: [{ address: "Arras - pause", lng: 2.778, lat: 50.291 }],
        arriveeAddress: "Boulogne-sur-Mer",
        arriveeLng: 1.614,
        arriveeLat: 50.725,
      }),
    },

    // NANTES / PDL
    {
      titre: "Nantes → Angers",
      description: "Sortie facile, rythme cool.",
      typeVehicule: "moto",
      date: addDays(now, 13, 9, 30),
      heure: "09:30",
      lieuDepart: "Nantes - Beaulieu",
      lieuArrivee: "Angers",
      visibilite: "publique",
      ridingStyle: "calme",
      organisateur: U.admin_ride._id,
      participants: participantsFromPseudos(
        ["admin_ride", "lille_car"],
        "moto",
        {
          organizerPseudo: "admin_ride",
        }
      ),
      localisation: point(cities.nantes.lng, cities.nantes.lat),
      waypoints: rideWaypoints({
        departAddress: "Nantes - Beaulieu",
        departLng: -1.529,
        departLat: 47.206,
        checkpoints: [{ address: "Ancenis - pause", lng: -1.173, lat: 47.366 }],
        arriveeAddress: "Angers",
        arriveeLng: -0.553,
        arriveeLat: 47.478,
      }),
    },

    // 2 balades "secretes" pour tester les liens
    {
      titre: "Secret - Spot IDF (lien)",
      description: "Balade secrète via lien.",
      typeVehicule: "moto",
      date: addDays(now, 6, 23, 0),
      heure: "23:00",
      lieuDepart: "Paris (spot secret)",
      lieuArrivee: "IDF (spot secret)",
      visibilite: "secrete",
      ridingStyle: "mixte",
      organisateur: U.admin_ride._id,
      participants: participantsFromPseudos(["admin_ride"], "moto", {
        organizerPseudo: "admin_ride",
      }),
      secretLink: `secret-${Date.now()}-idf`,
      localisation: point(cities.paris.lng, cities.paris.lat),
      waypoints: rideWaypoints({
        departAddress: "Paris (spot secret)",
        departLng: 2.3522,
        departLat: 48.8566,
        checkpoints: [],
        arriveeAddress: "IDF (spot secret)",
        arriveeLng: 2.5,
        arriveeLat: 48.9,
      }),
    },
    {
      titre: "Secret - Turini Night (lien)",
      description: "Balade secrète via lien.",
      typeVehicule: "moto",
      date: addDays(now, 9, 22, 15),
      heure: "22:15",
      lieuDepart: "Nice (spot secret)",
      lieuArrivee: "Col de Turini (spot secret)",
      visibilite: "secrete",
      ridingStyle: "sportif",
      organisateur: U.nice_moto._id,
      participants: participantsFromPseudos(["nice_moto"], "moto", {
        organizerPseudo: "nice_moto",
      }),
      secretLink: `secret-${Date.now()}-turini`,
      localisation: point(cities.nice.lng, cities.nice.lat),
      waypoints: rideWaypoints({
        departAddress: "Nice (spot secret)",
        departLng: 7.262,
        departLat: 43.71,
        checkpoints: [{ address: "Sospel (spot)", lng: 7.449, lat: 43.878 }],
        arriveeAddress: "Col de Turini (spot secret)",
        arriveeLng: 7.395,
        arriveeLat: 43.992,
      }),
    },
  ];

  const createdRides = await Ride.insertMany(
    ridesPayload.map((r) => {
      const doc = {
        ...r,
        status: r.status || "scheduled",
        notes: [],
        noteMoyenne: 0,
      };

      // IMPORTANT: ne jamais insérer secretLink: null
      if (doc.secretLink == null) {
        delete doc.secretLink;
      }

      // Optionnel: si visibilite n'est pas 'secrete', on supprime aussi
      if (doc.visibilite !== "secrete") {
        delete doc.secretLink;
      }

      return doc;
    })
  );

  console.log(`✅ ${createdRides.length} balades créées`);

  // ---------- GROUPS ----------
  console.log("\n💬 Création des groupes mock...");
  const groupsPayload = [
    {
      nom: "RideTogether - Accueil",
      description: "Discussions générales, annonces et entraide.",
      visibilite: "publique",
      createur: U.admin_ride._id,
      membres: [
        { userId: U.admin_ride._id, role: "admin" },
        { userId: U.lyon_moto._id, role: "membre" },
        { userId: U.paris_car._id, role: "membre" },
      ],
    },
    {
      nom: "Lyon Riders",
      description: "Groupe des sorties autour de Lyon.",
      visibilite: "publique",
      createur: U.lyon_moto._id,
      membres: [
        { userId: U.lyon_moto._id, role: "admin" },
        { userId: U.admin_ride._id, role: "membre" },
      ],
    },
    {
      nom: "Privé - Sorties Sud",
      description: "Groupe privé (Marseille / Nice).",
      visibilite: "privee",
      createur: U.marseille_mix._id,
      membres: [
        { userId: U.marseille_mix._id, role: "admin" },
        { userId: U.nice_moto._id, role: "membre" },
      ],
    },
    {
      nom: "Roadtrip Ouest",
      description: "Bordeaux / Nantes / côte.",
      visibilite: "publique",
      createur: U.bordeaux_moto._id,
      membres: [
        { userId: U.bordeaux_moto._id, role: "admin" },
        { userId: U.admin_ride._id, role: "membre" },
      ],
    },
    {
      nom: "Privé - Organisation (staff)",
      description: "Groupe privé pour tests / modération.",
      visibilite: "privee",
      createur: U.admin_ride._id,
      membres: [
        { userId: U.admin_ride._id, role: "admin" },
        { userId: U.paris_car._id, role: "membre" },
      ],
    },
    {
      nom: "Paris & IDF Riders",
      description: "Balades autour de Paris / IDF.",
      visibilite: "publique",
      createur: U.paris_car._id,
      membres: [
        { userId: U.paris_car._id, role: "admin" },
        { userId: U.admin_ride._id, role: "membre" },
        { userId: U.lyon_moto._id, role: "membre" },
      ],
    },
    {
      nom: "PACA Riders",
      description: "Marseille / Nice / cols / calanques.",
      visibilite: "publique",
      createur: U.marseille_mix._id,
      membres: [
        { userId: U.marseille_mix._id, role: "admin" },
        { userId: U.nice_moto._id, role: "membre" },
      ],
    },
    {
      nom: "Moto Only",
      description: "Discussions 100% moto, équipement, routes, conseils.",
      visibilite: "publique",
      createur: U.lyon_moto._id,
      membres: [
        { userId: U.lyon_moto._id, role: "admin" },
        { userId: U.bordeaux_moto._id, role: "membre" },
        { userId: U.nice_moto._id, role: "membre" },
        { userId: U.admin_ride._id, role: "membre" },
      ],
    },
    {
      nom: "Privé - Spots & Secrets",
      description: "Groupe privé, partage de spots (lien secret).",
      visibilite: "privee",
      createur: U.admin_ride._id,
      membres: [
        { userId: U.admin_ride._id, role: "admin" },
        { userId: U.nice_moto._id, role: "membre" },
        { userId: U.marseille_mix._id, role: "membre" },
      ],
    },
  ];

  const createdGroups = await Group.insertMany(groupsPayload);
  console.log(`✅ ${createdGroups.length} groupes créés`);

  // ---------- MESSAGES ----------
  console.log("\n✉️  Création de messages mock...");
  const groupByName = Object.fromEntries(createdGroups.map((g) => [g.nom, g]));

  // Base: il y a 2 jours à 18:00 (heure locale serveur)
  const baseMsgTime = addDays(new Date(), -2, 18, 0);

  // Helper interne pour éviter de répéter addMinutes(baseMsgTime, x)
  const t = (mins) => addMinutes(baseMsgTime, mins);

  const messagesPayload = [
    // ===== RideTogether - Accueil =====
    {
      idGroupe: groupByName["RideTogether - Accueil"]._id,
      auteur: U.admin_ride._id,
      contenu:
        "Bienvenue sur RideTogether. Présentez-vous (moto/voiture + région) !",
      date: t(0),
    },
    {
      idGroupe: groupByName["RideTogether - Accueil"]._id,
      auteur: U.paris_car._id,
      contenu:
        "Hello, Paris côté voiture, je teste les balades autour de l’IDF.",
      date: t(6),
    },
    {
      idGroupe: groupByName["RideTogether - Accueil"]._id,
      auteur: U.lyon_moto._id,
      contenu: "Salut, Lyonnais ici, plutôt moto et sorties week-end.",
      date: t(14),
    },
    {
      idGroupe: groupByName["RideTogether - Accueil"]._id,
      auteur: U.marseille_mix._id,
      contenu: "Marseille ici. Je roule moto/voiture selon les sorties.",
      date: t(22),
    },
    {
      idGroupe: groupByName["RideTogether - Accueil"]._id,
      auteur: U.admin_ride._id,
      contenu:
        "Pensez à renseigner vos véhicules dans le profil, ça aide pour filtrer les balades.",
      date: t(35),
    },

    // ===== Lyon Riders ===== (un peu plus tard le même soir)
    {
      idGroupe: groupByName["Lyon Riders"]._id,
      auteur: U.lyon_moto._id,
      contenu: "Qui est chaud pour une boucle Monts du Lyonnais samedi ?",
      date: t(90),
    },
    {
      idGroupe: groupByName["Lyon Riders"]._id,
      auteur: U.admin_ride._id,
      contenu: "Partant. Je peux créer la balade et mettre 2-3 checkpoints.",
      date: t(98),
    },
    {
      idGroupe: groupByName["Lyon Riders"]._id,
      auteur: U.lyon_moto._id,
      contenu: "Top. Je propose départ Bellecour, arrivée Yzeron.",
      date: t(110),
    },

    // ===== Privé - Sorties Sud ===== (le lendemain)
    {
      idGroupe: groupByName["Privé - Sorties Sud"]._id,
      auteur: U.marseille_mix._id,
      contenu: "Groupe privé : ici on prépare les sorties Calanques / cols.",
      date: t(60 * 12), // +12h
    },
    {
      idGroupe: groupByName["Privé - Sorties Sud"]._id,
      auteur: U.nice_moto._id,
      contenu: "Turini bientôt si la météo tient.",
      date: t(60 * 12 + 18),
    },
    {
      idGroupe: groupByName["Privé - Sorties Sud"]._id,
      auteur: U.marseille_mix._id,
      contenu: "OK. On garde la sortie en privé, invitation seulement.",
      date: t(60 * 12 + 27),
    },

    // ===== Roadtrip Ouest ===== (même jour, un peu après)
    {
      idGroupe: groupByName["Roadtrip Ouest"]._id,
      auteur: U.bordeaux_moto._id,
      contenu: "Route des vins : départ 10h, checkpoint à Pessac.",
      date: t(60 * 14), // +14h
    },
    {
      idGroupe: groupByName["Roadtrip Ouest"]._id,
      auteur: U.admin_ride._id,
      contenu: "Nickel. On peut aussi pousser jusqu’à l’océan une autre fois.",
      date: t(60 * 14 + 12),
    },
    {
      idGroupe: groupByName["Roadtrip Ouest"]._id,
      auteur: U.bordeaux_moto._id,
      contenu: "Yes, on fera un Arcachon la prochaine.",
      date: t(60 * 14 + 22),
    },

    // ===== Privé - Organisation (staff) ===== (le surlendemain)
    {
      idGroupe: groupByName["Privé - Organisation (staff)"]._id,
      auteur: U.admin_ride._id,
      contenu: "TODO: vérifier la recherche par rayon + invitations balades.",
      date: t(60 * 36), // +36h
    },
    {
      idGroupe: groupByName["Privé - Organisation (staff)"]._id,
      auteur: U.paris_car._id,
      contenu: "OK, je teste ce soir avec Paris/Lyon/Marseille.",
      date: t(60 * 36 + 9),
    },
    {
      idGroupe: groupByName["Privé - Organisation (staff)"]._id,
      auteur: U.admin_ride._id,
      contenu: "Pensez aussi à tester les balades secrètes via lien.",
      date: t(60 * 36 + 18),
    },

    // ===== Paris & IDF Riders =====
    {
      idGroupe: groupByName["Paris & IDF Riders"]._id,
      auteur: U.paris_car._id,
      contenu: "IDF: qui veut une sortie vers Fontainebleau ce week-end ?",
      date: t(60 * 5), // +5h
    },
    {
      idGroupe: groupByName["Paris & IDF Riders"]._id,
      auteur: U.admin_ride._id,
      contenu: "Partant. On met un checkpoint à Melun pour regrouper.",
      date: t(60 * 5 + 11),
    },

    // ===== PACA Riders =====
    {
      idGroupe: groupByName["PACA Riders"]._id,
      auteur: U.marseille_mix._id,
      contenu: "PACA: on vise La Ciotat dimanche matin, rythme cool.",
      date: t(60 * 20), // +20h
    },
    {
      idGroupe: groupByName["PACA Riders"]._id,
      auteur: U.nice_moto._id,
      contenu: "Je peux rejoindre si départ pas trop tôt.",
      date: t(60 * 20 + 16),
    },

    // ===== Moto Only =====
    {
      idGroupe: groupByName["Moto Only"]._id,
      auteur: U.lyon_moto._id,
      contenu: "Moto only: vos meilleurs spots routes autour de Lyon ?",
      date: t(60 * 10), // +10h
    },
    {
      idGroupe: groupByName["Moto Only"]._id,
      auteur: U.nice_moto._id,
      contenu: "PACA: arrière-pays niçois, gorges et cols tôt le matin.",
      date: t(60 * 10 + 9),
    },
    {
      idGroupe: groupByName["Moto Only"]._id,
      auteur: U.bordeaux_moto._id,
      contenu: "Bordeaux: Médoc tôt, routes très propres hors saison.",
      date: t(60 * 10 + 18),
    },

    // ===== Privé - Spots & Secrets =====
    {
      idGroupe: groupByName["Privé - Spots & Secrets"]._id,
      auteur: U.admin_ride._id,
      contenu: "Ici: partage de spots uniquement via liens secrets.",
      date: t(60 * 30), // +30h
    },
    {
      idGroupe: groupByName["Privé - Spots & Secrets"]._id,
      auteur: U.nice_moto._id,
      contenu: "Je partage un spot Turini night dès que le lien est prêt.",
      date: t(60 * 30 + 12),
    },
  ];

  await Message.insertMany(
    messagesPayload.map((m) => ({
      ...m,
      type: "text",
      date: m.date, // obligatoire ici, on veut des dates différentes partout
    }))
  );

  console.log(`✅ ${messagesPayload.length} messages créés`);

  // Résumé
  console.log("\n📊 Résumé seed:");
  console.log("   Users   :", await User.countDocuments());
  console.log("   Rides   :", await Ride.countDocuments());
  console.log("   Groups  :", await Group.countDocuments());
  console.log("   Messages:", await Message.countDocuments());

  console.log("\n🔑 Comptes de test (tous le même mot de passe):");
  createdUsers.forEach((u) => {
    console.log(`   - ${u.pseudo} | ${u.email} | ${u.phoneE164}`);
  });
  console.log(`\n   Password: ${PLAIN_PASSWORD}`);

  await mongoose.disconnect();
  console.log("\n✅ Reset + seed terminé.");
  process.exit(0);
}

resetAndSeed().catch(async (err) => {
  console.error("\n❌ Erreur reset/seed:", err);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
