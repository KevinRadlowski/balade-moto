const Vehicle = require('../models/Vehicle');
const OdometerEntry = require('../models/OdometerEntry');
const MaintenanceItem = require('../models/MaintenanceItem');
const MaintenanceLog = require('../models/MaintenanceLog');
const VehicleReminder = require('../models/VehicleReminder');
const VehicleDocument = require('../models/VehicleDocument');
const { NotFoundError, ForbiddenError, BadRequestError } = require('../utils/errors');
const { createRecommendedMaintenancePack } = require('../services/maintenancePack.service');
const { getMaintenanceSuggestions } = require('../services/maintenanceSuggestions.service');

/**
 * @swagger
 * tags:
 *   name: Garage
 *   description: Gestion du garage (véhicules, odomètre, maintenance)
 */

/**
 * @swagger
 * /api/garage/vehicles:
 *   post:
 *     summary: Créer un nouveau véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - type
 *             properties:
 *               type: { type: string, enum: [moto, voiture], example: "moto", description: "Type de véhicule (requis)" }
 *               selectionSource: 
 *                 type: string
 *                 enum: [MANUAL, CATALOG]
 *                 default: MANUAL
 *                 example: CATALOG
 *                 description: "Source de sélection. 'MANUAL' pour saisie manuelle, 'CATALOG' pour sélection via catalogue externe (CarAPI.app). Si 'CATALOG', make, model, year et externalCatalog sont obligatoires."
 *               nickname: { type: string, example: "Ma moto", description: "Surnom du véhicule (optionnel)" }
 *               make: { type: string, example: "Yamaha", description: "Marque (obligatoire si selectionSource='CATALOG')" }
 *               model: { type: string, example: "MT-07", description: "Modèle (obligatoire si selectionSource='CATALOG')" }
 *               trim: { type: string, example: "ABS", description: "Finition (optionnel)" }
 *               year: { type: number, example: 2020, description: "Année (obligatoire si selectionSource='CATALOG')" }
 *               engine: 
 *                 type: object
 *                 description: "Informations moteur (optionnel)"
 *                 properties:
 *                   fuel: { type: string, enum: [essence, diesel, electrique, hybride, autre] }
 *                   displacementCc: { type: number, example: 689 }
 *                   powerHp: { type: number, example: 73 }
 *                   powerKw: { type: number, example: 54 }
 *                   transmission: { type: string, enum: [manuelle, automatique, cvt, autre] }
 *               odometerCurrentKm: { type: number, example: 5000, default: 0 }
 *               purchase:
 *                 type: object
 *                 description: "Informations d'achat (optionnel)"
 *                 properties:
 *                   date: { type: string, format: date }
 *                   price: { type: number }
 *                   sellerType: { type: string, enum: [particulier, professionnel, concessionnaire, autre] }
 *               insurance:
 *                 type: object
 *                 description: "Informations assurance (optionnel)"
 *                 properties:
 *                   company: { type: string }
 *                   policyNumber: { type: string }
 *                   renewalDate: { type: string, format: date }
 *               notes: { type: string, description: "Notes générales (optionnel)" }
 *               externalCatalog:
 *                 type: object
 *                 description: "Données du catalogue externe (requis si selectionSource='CATALOG'). Utilise CarAPI.app pour les voitures et CarAPI.app PowerSports pour les motos."
 *                 required:
 *                   - provider
 *                   - vehicleType
 *                   - makeId
 *                   - modelId
 *                 properties:
 *                   provider: { type: string, enum: [CARAPI], example: "CARAPI", description: "Fournisseur du catalogue (toujours 'CARAPI')" }
 *                   vehicleType: { type: string, enum: [voiture, moto], example: "moto", description: "Type de véhicule dans le catalogue" }
 *                   makeId: { type: string, example: "abc123", description: "ID de la marque dans le catalogue (string, jamais d'entier)" }
 *                   modelId: { type: string, example: "def456", description: "ID du modèle dans le catalogue (string, jamais d'entier)" }
 *                   year: { type: number, example: 2020, description: "Année du véhicule dans le catalogue (optionnel, utilise year du véhicule si non fourni)" }
 *                   raw: { type: object, description: "Données brutes du catalogue (optionnel)" }
 *               enableRecommendedMaintenancePack: 
 *                 type: boolean
 *                 example: true
 *                 description: "Si true, crée automatiquement un pack d'entretien recommandé adapté au type de véhicule (moto ou voiture). Les MaintenanceItem créés peuvent ensuite être modifiés via PATCH /api/garage/vehicles/:id/maintenance/items/:itemId"
 *     responses:
 *       201:
 *         description: Véhicule créé avec succès (et pack d'entretien si demandé)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   properties:
 *                     vehicle: { $ref: '#/components/schemas/Vehicle' }
 *                     maintenanceItemsCreated: { type: number, description: "Nombre d'éléments de maintenance créés (si enableRecommendedMaintenancePack=true)" }
 *                     maintenanceItems: 
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           _id: { type: string }
 *                           label: { type: string }
 *                           category: { type: string }
 *                           dueAtKm: { type: number }
 *                           dueAtDate: { type: string, format: date }
 *                           status: { type: string, enum: [DUE, UPCOMING, DONE, SKIPPED] }
 *       400:
 *         description: Erreur de validation
 *       401:
 *         description: Non authentifié
 */
exports.createVehicle = async (req, res, next) => {
  try {
    const {
      nickname,
      make,
      model,
      trim,
      year,
      type,
      engine,
      odometerCurrentKm = 0,
      purchase,
      insurance,
      notes,
      enableRecommendedMaintenancePack = false,
      selectionSource = 'MANUAL',
      externalCatalog // Nouveau format unifié
    } = req.body;

    // Compatibilité avec anciens champs
    const nicknameValue = nickname || req.body.name;
    const makeValue = make || req.body.brand;
    const purchaseDate = purchase?.date || req.body.purchaseDate;

    // Validation: si selectionSource='CATALOG' ou 'CATALOG_LOCAL', make, model, year et externalCatalog sont obligatoires
    if (selectionSource === 'CATALOG' || selectionSource === 'CATALOG_LOCAL') {
      if (!makeValue || makeValue.trim().length === 0) {
        throw new BadRequestError(`La marque est requise lorsque selectionSource="${selectionSource}"`);
      }
      if (!model || model.trim().length === 0) {
        throw new BadRequestError(`Le modèle est requis lorsque selectionSource="${selectionSource}"`);
      }
      if (!year) {
        throw new BadRequestError(`L'année est requise lorsque selectionSource="${selectionSource}"`);
      }
      if (!externalCatalog || !externalCatalog.provider) {
        throw new BadRequestError(`externalCatalog.provider est requis lorsque selectionSource="${selectionSource}"`);
      }
      if (!externalCatalog.makeId || typeof externalCatalog.makeId !== 'string' || externalCatalog.makeId.trim().length === 0) {
        throw new BadRequestError(`externalCatalog.makeId (string) est requis lorsque selectionSource="${selectionSource}"`);
      }
      if (!externalCatalog.modelId || typeof externalCatalog.modelId !== 'string' || externalCatalog.modelId.trim().length === 0) {
        throw new BadRequestError(`externalCatalog.modelId (string) est requis lorsque selectionSource="${selectionSource}"`);
      }
      if (!['CARAPI', 'LOCAL_FR', 'SUGGESTION'].includes(externalCatalog.provider)) {
        throw new BadRequestError('externalCatalog.provider doit être "CARAPI", "LOCAL_FR" ou "SUGGESTION"');
      }
      if (!externalCatalog.vehicleType || !['voiture', 'moto'].includes(externalCatalog.vehicleType)) {
        throw new BadRequestError('externalCatalog.vehicleType doit être "voiture" ou "moto"');
      }
    }

    // Validation: si selectionSource='SUGGESTION', make, model, year sont obligatoires
    if (selectionSource === 'SUGGESTION') {
      if (!makeValue || makeValue.trim().length === 0) {
        throw new BadRequestError('La marque est requise lorsque selectionSource="SUGGESTION"');
      }
      if (!model || model.trim().length === 0) {
        throw new BadRequestError('Le modèle est requis lorsque selectionSource="SUGGESTION"');
      }
      if (!year) {
        throw new BadRequestError('L\'année est requise lorsque selectionSource="SUGGESTION"');
      }
      if (externalCatalog && externalCatalog.provider !== 'SUGGESTION') {
        throw new BadRequestError('externalCatalog.provider doit être "SUGGESTION" lorsque selectionSource="SUGGESTION"');
      }
    }

    // Construire l'objet externalCatalog (nouveau format unifié)
    let externalCatalogData = undefined;
    
    if ((selectionSource === 'CATALOG' || selectionSource === 'CATALOG_LOCAL') && externalCatalog) {
      externalCatalogData = {
        provider: externalCatalog.provider || 'LOCAL_FR', // Utiliser le provider fourni ou LOCAL_FR par défaut
        vehicleType: externalCatalog.vehicleType || type, // Utiliser type du véhicule si non fourni
        makeId: String(externalCatalog.makeId).trim(), // Forcer string
        modelId: String(externalCatalog.modelId).trim(), // Forcer string
        year: year,
        raw: externalCatalog.raw
      };
    } else if (selectionSource === 'SUGGESTION' && externalCatalog) {
      externalCatalogData = {
        provider: 'SUGGESTION',
        vehicleType: externalCatalog.vehicleType || type,
        year: year,
        make: makeValue ? makeValue.toUpperCase().trim() : undefined,
        model: model ? model.toUpperCase().trim() : undefined,
        raw: externalCatalog.raw
      };
    }

    const vehicle = new Vehicle({
      ownerUserId: req.user._id,
      type,
      nickname: nicknameValue,
      make: makeValue,
      model,
      trim,
      year,
      engine: engine || {},
      odometerCurrentKm,
      purchase: purchase || (purchaseDate ? { date: purchaseDate } : {}),
      insurance: insurance || {},
      notes: notes || req.body.description || '',
      selectionSource: selectionSource,
      externalCatalog: externalCatalogData
    });

    await vehicle.save();

    // Créer le pack d'entretien recommandé si demandé
    let maintenanceItems = [];
    if (enableRecommendedMaintenancePack) {
      try {
        maintenanceItems = await createRecommendedMaintenancePack(vehicle, req.user._id);
      } catch (packError) {
        // Logger l'erreur mais ne pas faire échouer la création du véhicule
        console.error('Erreur lors de la création du pack d\'entretien recommandé:', packError);
        // On continue quand même, le véhicule est créé
      }
    }

    res.status(201).json({
      success: true,
      data: { 
        vehicle,
        ...(enableRecommendedMaintenancePack && {
          maintenanceItemsCreated: maintenanceItems.length,
          maintenanceItems: maintenanceItems.map(item => ({
            _id: item._id,
            label: item.label,
            category: item.category,
            dueAtKm: item.dueAtKm,
            dueAtDate: item.dueAtDate,
            status: item.status
          }))
        })
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles:
 *   get:
 *     summary: Liste des véhicules de l'utilisateur
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [moto, voiture] }
 *     responses:
 *       200:
 *         description: Liste des véhicules
 */
exports.getVehicles = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    const { type } = req.query;

    const query = {
      ownerUserId: req.user._id,
      active: true
    };

    if (type) {
      query.type = type;
    }

    const vehicles = await Vehicle.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Vehicle.countDocuments(query);

    res.json({
      success: true,
      data: {
        vehicles,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}:
 *   get:
 *     summary: Détails d'un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Détails du véhicule
 *       404:
 *         description: Véhicule non trouvé
 */
exports.getVehicle = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    res.json({
      success: true,
      data: { vehicle }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}:
 *   patch:
 *     summary: Mettre à jour un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Véhicule mis à jour
 *       404:
 *         description: Véhicule non trouvé
 */
exports.updateVehicle = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    Object.assign(vehicle, req.body);
    await vehicle.save();

    res.json({
      success: true,
      data: { vehicle }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}:
 *   delete:
 *     summary: Supprimer un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Véhicule supprimé
 *       404:
 *         description: Véhicule non trouvé
 */
exports.deleteVehicle = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    vehicle.active = false;
    await vehicle.save();

    res.json({
      success: true,
      message: 'Véhicule supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/odometer:
 *   post:
 *     summary: Ajouter une entrée odomètre
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       201:
 *         description: Entrée odomètre créée
 */
exports.createOdometer = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const { km, date, note } = req.body;

    if (km < vehicle.odometerCurrentKm) {
      throw new BadRequestError('Le kilométrage ne peut pas être inférieur au kilométrage actuel du véhicule');
    }

    const odometerEntry = new OdometerEntry({
      vehicleId: vehicle._id,
      createdBy: req.user._id,
      km,
      date: date || new Date(),
      note: note || req.body.notes || ''
    });

    await odometerEntry.save();

    // Le pre-save hook mettra à jour vehicle.odometerCurrentKm automatiquement
    // Recharger le véhicule pour avoir la valeur à jour
    const updatedVehicle = await Vehicle.findById(vehicle._id);

    res.status(201).json({
      success: true,
      data: { 
        odometerEntry,
        vehicle: updatedVehicle
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/odometer:
 *   get:
 *     summary: Liste des entrées odomètre
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200:
 *         description: Liste des entrées odomètre
 */
exports.getOdometers = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const odometerEntries = await OdometerEntry.find({
      vehicleId: vehicle._id,
      createdBy: req.user._id
    })
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit);

    const total = await OdometerEntry.countDocuments({
      vehicleId: vehicle._id,
      createdBy: req.user._id
    });

    res.json({
      success: true,
      data: {
        odometerEntries,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/items:
 *   post:
 *     summary: Créer un élément de maintenance
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       201:
 *         description: Élément de maintenance créé
 */
exports.createMaintenanceItem = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const {
      label,
      category,
      intervalKm,
      intervalMonths,
      lastDoneAtKm,
      lastDoneAtDate,
      notes
    } = req.body;

    // Compatibilité avec anciens champs
    const labelValue = label || req.body.name;
    const categoryValue = category || req.body.type;
    const intervalMonthsValue = intervalMonths || (req.body.intervalDays ? Math.round(req.body.intervalDays / 30) : null);

    // Calculer dueAtKm et dueAtDate si lastDoneAtKm ou lastDoneAtDate sont fournis
    let dueAtKm = null;
    let dueAtDate = null;

    if (lastDoneAtKm !== undefined && intervalKm) {
      dueAtKm = lastDoneAtKm + intervalKm;
    }

    if (lastDoneAtDate && intervalMonthsValue) {
      dueAtDate = new Date(lastDoneAtDate);
      dueAtDate.setMonth(dueAtDate.getMonth() + intervalMonthsValue);
    }

    const maintenanceItem = new MaintenanceItem({
      vehicleId: vehicle._id,
      label: labelValue,
      category: categoryValue,
      intervalKm,
      intervalMonths: intervalMonthsValue,
      lastDoneAtKm,
      lastDoneAtDate: lastDoneAtDate ? new Date(lastDoneAtDate) : null,
      dueAtKm,
      dueAtDate,
      notes: notes || req.body.description || ''
    });

    await maintenanceItem.save();

    res.status(201).json({
      success: true,
      data: { maintenanceItem }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/dashboard:
 *   get:
 *     summary: Dashboard de maintenance avec statuts DUE/UPCOMING
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Dashboard de maintenance
 */
exports.getMaintenanceDashboard = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    // Récupérer les fenêtres de rappel depuis les variables d'environnement
    const upcomingKmWindow = parseInt(process.env.MAINTENANCE_UPCOMING_KM_WINDOW) || 500;
    const upcomingDaysWindow = parseInt(process.env.MAINTENANCE_UPCOMING_DAYS_WINDOW) || 30;

    const odometerCurrentKm = vehicle.odometerCurrentKm;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Récupérer tous les éléments de maintenance actifs
    const maintenanceItems = await MaintenanceItem.find({
      vehicleId: vehicle._id,
      active: true
    });

    // Calculer les statuts pour chaque élément et mettre à jour si nécessaire
    const itemsWithStatus = await Promise.all(maintenanceItems.map(async (item) => {
      const itemObj = item.toObject();
      let status = itemObj.status || 'UPCOMING';
      let isDue = false;
      let isUpcoming = false;
      let needsUpdate = false;

      // Vérifier si DUE (kilométrage)
      if (itemObj.dueAtKm !== null && itemObj.dueAtKm !== undefined) {
        if (odometerCurrentKm >= itemObj.dueAtKm) {
          status = 'DUE';
          isDue = true;
          if (itemObj.status !== 'DUE' && itemObj.status !== 'SKIPPED') {
            needsUpdate = true;
          }
        } else if (odometerCurrentKm >= (itemObj.dueAtKm - upcomingKmWindow)) {
          status = 'UPCOMING';
          isUpcoming = true;
          if (itemObj.status !== 'UPCOMING' && itemObj.status !== 'DUE' && itemObj.status !== 'SKIPPED') {
            needsUpdate = true;
          }
        }
      }

      // Vérifier si DUE (date) - prioritaire si les deux sont définis
      if (itemObj.dueAtDate) {
        const dueDate = new Date(itemObj.dueAtDate);
        dueDate.setHours(0, 0, 0, 0);

        if (today >= dueDate) {
          status = 'DUE';
          isDue = true;
          if (itemObj.status !== 'DUE' && itemObj.status !== 'SKIPPED') {
            needsUpdate = true;
          }
        } else {
          const daysUntilDue = Math.ceil((dueDate - today) / (1000 * 60 * 60 * 24));
          if (daysUntilDue <= upcomingDaysWindow) {
            status = 'UPCOMING';
            isUpcoming = true;
            if (itemObj.status !== 'UPCOMING' && itemObj.status !== 'DUE' && itemObj.status !== 'SKIPPED') {
              needsUpdate = true;
            }
          }
        }
      }

      // Si aucun dueAt n'est défini et que le statut n'est pas DONE ou SKIPPED, mettre à jour
      if (!itemObj.dueAtKm && !itemObj.dueAtDate && itemObj.status !== 'DONE' && itemObj.status !== 'SKIPPED') {
        status = 'UPCOMING';
        isUpcoming = true;
        if (itemObj.status !== 'UPCOMING') {
          needsUpdate = true;
        }
      }

      // Mettre à jour le statut dans la base si nécessaire
      if (needsUpdate && itemObj.status !== 'DONE' && itemObj.status !== 'SKIPPED') {
        item.status = status;
        await item.save();
      }

      return {
        ...itemObj,
        status,
        isDue,
        isUpcoming
      };
    }));

    // Séparer par statut
    const dueItems = itemsWithStatus.filter(item => item.isDue);
    const upcomingItems = itemsWithStatus.filter(item => item.isUpcoming && !item.isDue);
    const okItems = itemsWithStatus.filter(item => !item.isDue && !item.isUpcoming);

    res.json({
      success: true,
      data: {
        vehicle: {
          _id: vehicle._id,
          nickname: vehicle.nickname,
          make: vehicle.make,
          model: vehicle.model,
          odometerCurrentKm
        },
        dashboard: {
          due: dueItems,
          upcoming: upcomingItems,
          ok: okItems
        },
        summary: {
          total: itemsWithStatus.length,
          due: dueItems.length,
          upcoming: upcomingItems.length,
          ok: okItems.length
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/items/{itemId}:
 *   patch:
 *     summary: Mettre à jour un élément de maintenance
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: itemId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Élément de maintenance mis à jour
 */
exports.updateMaintenanceItem = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const maintenanceItem = await MaintenanceItem.findById(req.params.itemId);

    if (!maintenanceItem) {
      throw new NotFoundError('Élément de maintenance');
    }

    if (maintenanceItem.vehicleId.toString() !== vehicle._id.toString()) {
      throw new BadRequestError('Cet élément de maintenance n\'appartient pas à ce véhicule');
    }

    const {
      label,
      category,
      intervalKm,
      intervalMonths,
      lastDoneAtKm,
      lastDoneAtDate,
      notes
    } = req.body;

    // Compatibilité avec anciens champs
    const labelValue = label !== undefined ? label : (req.body.name !== undefined ? req.body.name : maintenanceItem.label);
    const categoryValue = category !== undefined ? category : (req.body.type !== undefined ? req.body.type : maintenanceItem.category);
    const intervalMonthsValue = intervalMonths !== undefined ? intervalMonths : (req.body.intervalDays !== undefined ? Math.round(req.body.intervalDays / 30) : maintenanceItem.intervalMonths);

    // Recalculer dueAtKm et dueAtDate si nécessaire
    let dueAtKm = maintenanceItem.dueAtKm;
    let dueAtDate = maintenanceItem.dueAtDate;

    const finalLastDoneAtKm = lastDoneAtKm !== undefined ? lastDoneAtKm : maintenanceItem.lastDoneAtKm;
    const finalIntervalKm = intervalKm !== undefined ? intervalKm : maintenanceItem.intervalKm;
    const finalLastDoneAtDate = lastDoneAtDate !== undefined ? lastDoneAtDate : maintenanceItem.lastDoneAtDate;

    if (finalLastDoneAtKm !== undefined && finalIntervalKm) {
      dueAtKm = finalLastDoneAtKm + finalIntervalKm;
    }

    if (finalLastDoneAtDate && intervalMonthsValue) {
      dueAtDate = new Date(finalLastDoneAtDate);
      dueAtDate.setMonth(dueAtDate.getMonth() + intervalMonthsValue);
    }

    Object.assign(maintenanceItem, {
      label: labelValue,
      category: categoryValue,
      intervalKm,
      intervalMonths: intervalMonthsValue,
      lastDoneAtKm,
      lastDoneAtDate: lastDoneAtDate ? new Date(lastDoneAtDate) : maintenanceItem.lastDoneAtDate,
      dueAtKm,
      dueAtDate,
      notes: notes !== undefined ? notes : maintenanceItem.notes
    });

    await maintenanceItem.save();

    res.json({
      success: true,
      data: { maintenanceItem }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/items/{itemId}:
 *   delete:
 *     summary: Supprimer un élément de maintenance
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: itemId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Élément de maintenance supprimé
 */
exports.deleteMaintenanceItem = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const maintenanceItem = await MaintenanceItem.findById(req.params.itemId);

    if (!maintenanceItem) {
      throw new NotFoundError('Élément de maintenance');
    }

    if (maintenanceItem.vehicleId.toString() !== vehicle._id.toString()) {
      throw new BadRequestError('Cet élément de maintenance n\'appartient pas à ce véhicule');
    }

    maintenanceItem.active = false;
    await maintenanceItem.save();

    res.json({
      success: true,
      message: 'Élément de maintenance supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/logs:
 *   post:
 *     summary: Créer un log de maintenance
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       201:
 *         description: Log de maintenance créé
 */
exports.createMaintenanceLog = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const {
      maintenanceItem: maintenanceItemId,
      label,
      category,
      date,
      kmAtService,
      cost,
      garageName,
      invoiceFileUrl,
      notes
    } = req.body;

    // Compatibilité avec anciens champs
    const labelValue = label || req.body.description || '';
    const categoryValue = category || req.body.type;
    const kmValue = kmAtService || req.body.km;

    // Validation : le kilométrage de l'entretien ne peut pas être supérieur au kilométrage actuel du véhicule
    if (kmValue > vehicle.odometerCurrentKm) {
      throw new BadRequestError(`Le kilométrage de l'entretien (${kmValue} km) ne peut pas être supérieur au kilométrage actuel du véhicule (${vehicle.odometerCurrentKm} km)`);
    }

    // Si un maintenanceItem est fourni, vérifier qu'il existe et appartient au véhicule
    let maintenanceItem = null;
    if (maintenanceItemId) {
      maintenanceItem = await MaintenanceItem.findById(maintenanceItemId);

      if (!maintenanceItem) {
        throw new NotFoundError('Élément de maintenance');
      }

      if (maintenanceItem.vehicleId.toString() !== vehicle._id.toString()) {
        throw new BadRequestError('Cet élément de maintenance n\'appartient pas à ce véhicule');
      }

      // Marquer comme fait : mettre à jour lastDoneAtKm/Date et recalculer dueAt
      maintenanceItem.lastDoneAtKm = kmValue;
      maintenanceItem.lastDoneAtDate = date ? new Date(date) : new Date();

      if (maintenanceItem.intervalKm) {
        maintenanceItem.dueAtKm = kmValue + maintenanceItem.intervalKm;
      }

      if (maintenanceItem.intervalMonths) {
        const newDueDate = new Date(maintenanceItem.lastDoneAtDate);
        newDueDate.setMonth(newDueDate.getMonth() + maintenanceItem.intervalMonths);
        maintenanceItem.dueAtDate = newDueDate;
      }

      await maintenanceItem.save();
    }

    // Gérer l'upload de document si présent
    let documentUrl = invoiceFileUrl || '';
    if (req.file && req.file.path) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      const uploadsIndex = req.file.path.indexOf('uploads');
      if (uploadsIndex !== -1) {
        documentUrl = `${baseUrl}/${req.file.path.substring(uploadsIndex).replace(/\\/g, '/')}`;
      } else {
        documentUrl = `${baseUrl}/uploads/maintenance-logs/${req.file.filename}`;
      }
    }

    const maintenanceLog = new MaintenanceLog({
      vehicleId: vehicle._id,
      label: labelValue,
      category: categoryValue,
      date: date ? new Date(date) : new Date(),
      kmAtService: kmValue,
      cost: cost || 0,
      garageName: garageName || '',
      invoiceFileUrl: documentUrl,
      notes: notes || ''
    });

    await maintenanceLog.save();

    res.status(201).json({
      success: true,
      data: { maintenanceLog }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/logs:
 *   get:
 *     summary: Liste des logs de maintenance
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200:
 *         description: Liste des logs de maintenance
 */
exports.getMaintenanceLogs = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const maintenanceLogs = await MaintenanceLog.find({
      vehicleId: vehicle._id
    })
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit);

    const total = await MaintenanceLog.countDocuments({
      vehicleId: vehicle._id
    });

    res.json({
      success: true,
      data: {
        maintenanceLogs,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
          hasMore: skip + limit < total
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Récupérer un log de maintenance spécifique
exports.getMaintenanceLog = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const maintenanceLog = await MaintenanceLog.findById(req.params.logId);

    if (!maintenanceLog) {
      throw new NotFoundError('Log de maintenance');
    }

    if (maintenanceLog.vehicleId.toString() !== vehicle._id.toString()) {
      throw new ForbiddenError('Ce log de maintenance n\'appartient pas à ce véhicule');
    }

    res.json({
      success: true,
      data: { maintenanceLog }
    });
  } catch (error) {
    next(error);
  }
};

// Modifier un log de maintenance
exports.updateMaintenanceLog = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const maintenanceLog = await MaintenanceLog.findById(req.params.logId);

    if (!maintenanceLog) {
      throw new NotFoundError('Log de maintenance');
    }

    if (maintenanceLog.vehicleId.toString() !== vehicle._id.toString()) {
      throw new ForbiddenError('Ce log de maintenance n\'appartient pas à ce véhicule');
    }

    const {
      label,
      category,
      date,
      kmAtService,
      cost,
      garageName,
      invoiceFileUrl,
      notes
    } = req.body;

    // Compatibilité avec anciens champs
    const labelValue = label || req.body.description;
    const categoryValue = category || req.body.type;
    const kmValue = kmAtService !== undefined ? (kmAtService || req.body.km) : undefined;

    // Validation : si le kilométrage est modifié, il ne peut pas être supérieur au kilométrage actuel du véhicule
    if (kmValue !== undefined && kmValue > vehicle.odometerCurrentKm) {
      throw new BadRequestError(`Le kilométrage de l'entretien (${kmValue} km) ne peut pas être supérieur au kilométrage actuel du véhicule (${vehicle.odometerCurrentKm} km)`);
    }

    // Gérer l'upload de document si présent
    let documentUrl = invoiceFileUrl;
    if (req.file && req.file.path) {
      // Supprimer l'ancien document si présent
      if (maintenanceLog.invoiceFileUrl && maintenanceLog.invoiceFileUrl.includes('/uploads/maintenance-logs/')) {
        const fs = require('fs');
        const path = require('path');
        const filename = maintenanceLog.invoiceFileUrl.split('/').pop();
        const filePath = path.join(__dirname, '..', 'uploads', 'maintenance-logs', filename);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }

      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      const uploadsIndex = req.file.path.indexOf('uploads');
      if (uploadsIndex !== -1) {
        documentUrl = `${baseUrl}/${req.file.path.substring(uploadsIndex).replace(/\\/g, '/')}`;
      } else {
        documentUrl = `${baseUrl}/uploads/maintenance-logs/${req.file.filename}`;
      }
    }

    // Mettre à jour les champs
    if (labelValue !== undefined) maintenanceLog.label = labelValue;
    if (categoryValue !== undefined) maintenanceLog.category = categoryValue;
    if (date !== undefined) maintenanceLog.date = new Date(date);
    if (kmValue !== undefined) maintenanceLog.kmAtService = kmValue;
    if (cost !== undefined) maintenanceLog.cost = cost;
    if (garageName !== undefined) maintenanceLog.garageName = garageName || '';
    if (documentUrl !== undefined) maintenanceLog.invoiceFileUrl = documentUrl || '';
    if (notes !== undefined) maintenanceLog.notes = notes || '';

    await maintenanceLog.save();

    res.json({
      success: true,
      data: { maintenanceLog },
      message: 'Log de maintenance mis à jour avec succès'
    });
  } catch (error) {
    next(error);
  }
};

// Supprimer un log de maintenance
exports.deleteMaintenanceLog = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const maintenanceLog = await MaintenanceLog.findById(req.params.logId);

    if (!maintenanceLog) {
      throw new NotFoundError('Log de maintenance');
    }

    if (maintenanceLog.vehicleId.toString() !== vehicle._id.toString()) {
      throw new ForbiddenError('Ce log de maintenance n\'appartient pas à ce véhicule');
    }

    // Supprimer le document associé si présent
    if (maintenanceLog.invoiceFileUrl && maintenanceLog.invoiceFileUrl.includes('/uploads/maintenance-logs/')) {
      const fs = require('fs');
      const path = require('path');
      const filename = maintenanceLog.invoiceFileUrl.split('/').pop();
      const filePath = path.join(__dirname, '..', 'uploads', 'maintenance-logs', filename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    await maintenanceLog.deleteOne();

    res.json({
      success: true,
      message: 'Log de maintenance supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/documents:
 *   post:
 *     summary: Créer un document pour un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - type
 *               - label
 *               - fileUrl
 *             properties:
 *               type: { type: string, enum: [ASSURANCE, CT, FACTURE, AUTRE], example: "ASSURANCE" }
 *               label: { type: string, example: "Assurance 2024" }
 *               fileUrl: { type: string, example: "https://example.com/document.pdf" }
 *               date: { type: string, format: date, example: "2024-01-15" }
 *               notes: { type: string, example: "Assurance tous risques" }
 *     responses:
 *       201:
 *         description: Document créé avec succès
 */
exports.createDocument = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const { type, label, fileUrl, date, notes } = req.body;

    // Si un fichier a été uploadé, utiliser son chemin au lieu de fileUrl
    let finalFileUrl = fileUrl;
    if (req.file) {
      const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
      const path = require('path');
      let filePath = '';
      
      // Extraire le chemin relatif depuis le dossier uploads
      if (req.file.path) {
        const uploadsIndex = req.file.path.indexOf('uploads');
        if (uploadsIndex !== -1) {
          filePath = '/' + req.file.path.substring(uploadsIndex).replace(/\\/g, '/');
        } else {
          filePath = `/uploads/vehicle-documents/${req.file.filename}`;
        }
      } else {
        filePath = `/uploads/vehicle-documents/${req.file.filename}`;
      }
      
      finalFileUrl = `${baseUrl}${filePath}`;
    }

    if (!finalFileUrl) {
      throw new BadRequestError('fileUrl est requis ou un fichier doit être uploadé');
    }

    const document = new VehicleDocument({
      vehicleId: vehicle._id,
      ownerUserId: req.user._id,
      type,
      label,
      fileUrl: finalFileUrl,
      date: date ? new Date(date) : new Date(),
      notes: notes || ''
    });

    await document.save();

    res.status(201).json({
      success: true,
      data: { document }
    });
  } catch (error) {
    // Supprimer le fichier uploadé en cas d'erreur
    if (req.file && req.file.path) {
      const fs = require('fs');
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
    }
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/documents:
 *   get:
 *     summary: Liste des documents d'un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [ASSURANCE, CT, FACTURE, AUTRE] }
 *     responses:
 *       200:
 *         description: Liste des documents
 */
exports.getDocuments = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    const type = req.query.type;

    const query = { vehicleId: vehicle._id };
    if (type) {
      query.type = type;
    }

    const [documents, total] = await Promise.all([
      VehicleDocument.find(query)
        .sort({ date: -1 })
        .skip(skip)
        .limit(limit),
      VehicleDocument.countDocuments(query)
    ]);

    const pages = Math.ceil(total / limit);

    res.json({
      success: true,
      data: {
        documents,
        pagination: {
          page,
          limit,
          total,
          pages
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/documents/{documentId}:
 *   get:
 *     summary: Récupérer un document
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: documentId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Document trouvé
 */
exports.getDocument = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const document = await VehicleDocument.findById(req.params.documentId);

    if (!document) {
      throw new NotFoundError('Document');
    }

    if (document.vehicleId.toString() !== vehicle._id.toString()) {
      throw new BadRequestError('Ce document n\'appartient pas à ce véhicule');
    }

    res.json({
      success: true,
      data: { document }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/documents/{documentId}:
 *   patch:
 *     summary: Mettre à jour un document
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: documentId
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               type: { type: string, enum: [ASSURANCE, CT, FACTURE, AUTRE] }
 *               label: { type: string }
 *               fileUrl: { type: string }
 *               date: { type: string, format: date }
 *               notes: { type: string }
 *     responses:
 *       200:
 *         description: Document mis à jour
 */
exports.updateDocument = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const document = await VehicleDocument.findById(req.params.documentId);

    if (!document) {
      throw new NotFoundError('Document');
    }

    if (document.vehicleId.toString() !== vehicle._id.toString()) {
      throw new BadRequestError('Ce document n\'appartient pas à ce véhicule');
    }

    if (document.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce document');
    }

    const { type, label, fileUrl, date, notes } = req.body;

    if (type) document.type = type;
    if (label) document.label = label;
    if (fileUrl) document.fileUrl = fileUrl;
    if (date) document.date = new Date(date);
    if (notes !== undefined) document.notes = notes;

    await document.save();

    res.json({
      success: true,
      data: { document }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/documents/{documentId}:
 *   delete:
 *     summary: Supprimer un document
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: documentId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Document supprimé
 */
exports.deleteDocument = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const document = await VehicleDocument.findById(req.params.documentId);

    if (!document) {
      throw new NotFoundError('Document');
    }

    if (document.vehicleId.toString() !== vehicle._id.toString()) {
      throw new BadRequestError('Ce document n\'appartient pas à ce véhicule');
    }

    if (document.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce document');
    }

    // Supprimer le fichier physique si c'est un upload local
    if (document.fileUrl && document.fileUrl.startsWith('/uploads/')) {
      const fs = require('fs');
      const path = require('path');
      const filePath = path.join(__dirname, '..', document.fileUrl);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    await VehicleDocument.findByIdAndDelete(req.params.documentId);

    res.json({
      success: true,
      message: 'Document supprimé avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/photo:
 *   post:
 *     summary: Uploader une photo pour un véhicule
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - photo
 *             properties:
 *               photo:
 *                 type: string
 *                 format: binary
 *                 description: Image du véhicule (jpeg, jpg, png, gif, webp, max 5MB)
 *     responses:
 *       200:
 *         description: Photo uploadée avec succès
 *       400:
 *         description: Erreur de validation ou fichier invalide
 *       401:
 *         description: Non authentifié
 *       403:
 *         description: Non autorisé
 *       404:
 *         description: Véhicule non trouvé
 */
exports.uploadVehiclePhoto = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    if (!req.file) {
      throw new BadRequestError('Aucun fichier uploadé');
    }

    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    const path = require('path');
    let filePath = '';
    
    // Extraire le chemin relatif depuis le dossier uploads
    if (req.file.path) {
      const uploadsIndex = req.file.path.indexOf('uploads');
      if (uploadsIndex !== -1) {
        filePath = '/' + req.file.path.substring(uploadsIndex).replace(/\\/g, '/');
      } else {
        filePath = `/uploads/vehicles/${req.file.filename}`;
      }
    } else {
      filePath = `/uploads/vehicles/${req.file.filename}`;
    }

    const photoUrl = `${baseUrl}${filePath}`;

    // Supprimer l'ancienne photo si elle existe et est locale
    if (vehicle.photoUrl && vehicle.photoUrl.startsWith('/uploads/')) {
      const fs = require('fs');
      const oldFilePath = path.join(__dirname, '..', vehicle.photoUrl);
      if (fs.existsSync(oldFilePath)) {
        fs.unlinkSync(oldFilePath);
      }
    }

    vehicle.photoUrl = photoUrl;
    await vehicle.save();

    res.json({
      success: true,
      data: { 
        vehicle,
        photoUrl 
      },
      message: 'Photo uploadée avec succès'
    });
  } catch (error) {
    // Supprimer le fichier uploadé en cas d'erreur
    if (req.file && req.file.path) {
      const fs = require('fs');
      if (fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
    }
    next(error);
  }
};

// Ajouter plusieurs photos à la galerie d'un véhicule
exports.addVehiclePhotos = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    if (!req.files || req.files.length === 0) {
      throw new BadRequestError('Aucun fichier uploadé');
    }

    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    const path = require('path');
    const uploadedPhotos = [];

    // Initialiser le tableau photos s'il n'existe pas
    if (!vehicle.photos) {
      vehicle.photos = [];
    }

    // Traiter chaque fichier uploadé
    for (const file of req.files) {
      let filePath = '';
      
      // Extraire le chemin relatif depuis le dossier uploads
      if (file.path) {
        const uploadsIndex = file.path.indexOf('uploads');
        if (uploadsIndex !== -1) {
          filePath = '/' + file.path.substring(uploadsIndex).replace(/\\/g, '/');
        } else {
          filePath = `/uploads/vehicles/${file.filename}`;
        }
      } else {
        filePath = `/uploads/vehicles/${file.filename}`;
      }

      const photoUrl = `${baseUrl}${filePath}`;
      
      // Ajouter la photo à la galerie
      vehicle.photos.push({
        url: photoUrl,
        uploadedAt: new Date(),
        order: vehicle.photos.length
      });

      uploadedPhotos.push(photoUrl);
    }

    await vehicle.save();

    res.json({
      success: true,
      data: { 
        vehicle,
        photos: uploadedPhotos,
        totalPhotos: vehicle.photos.length
      },
      message: `${req.files.length} photo(s) ajoutée(s) avec succès`
    });
  } catch (error) {
    // Supprimer les fichiers uploadés en cas d'erreur
    if (req.files && req.files.length > 0) {
      const fs = require('fs');
      for (const file of req.files) {
        if (file.path && fs.existsSync(file.path)) {
          fs.unlinkSync(file.path);
        }
      }
    }
    next(error);
  }
};

// Lister les photos d'un véhicule avec pagination
exports.listVehiclePhotos = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 24;
    const skip = (page - 1) * limit;

    const photos = vehicle.photos || [];
    const total = photos.length;
    const totalPages = Math.ceil(total / limit);
    const hasMore = page < totalPages;

    // Trier par order (croissant) puis par uploadedAt (décroissant)
    const sortedPhotos = [...photos].sort((a, b) => {
      if (a.order !== b.order) {
        return a.order - b.order;
      }
      return new Date(b.uploadedAt) - new Date(a.uploadedAt);
    });

    // Paginer
    const paginatedPhotos = sortedPhotos.slice(skip, skip + limit);

    res.json({
      success: true,
      data: {
        items: paginatedPhotos,
        pagination: {
          page,
          limit,
          total,
          totalPages,
          hasMore
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Supprimer une photo de la galerie
exports.deleteVehiclePhoto = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const photoIndex = parseInt(req.params.photoIndex);
    
    if (isNaN(photoIndex) || photoIndex < 0 || !vehicle.photos || photoIndex >= vehicle.photos.length) {
      throw new BadRequestError('Index de photo invalide');
    }

    const photo = vehicle.photos[photoIndex];
    
    // Supprimer le fichier physique si c'est un upload local
    if (photo.url && photo.url.includes('/uploads/vehicles/')) {
      const fs = require('fs');
      const path = require('path');
      const filename = photo.url.split('/').pop();
      const filePath = path.join(__dirname, '..', 'uploads', 'vehicles', filename);
      
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    // Supprimer la photo du tableau
    vehicle.photos.splice(photoIndex, 1);
    
    // Réorganiser les ordres
    vehicle.photos.forEach((p, index) => {
      p.order = index;
    });

    await vehicle.save();

    res.json({
      success: true,
      data: { 
        vehicle,
        totalPhotos: vehicle.photos.length
      },
      message: 'Photo supprimée avec succès'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/garage/vehicles/{id}/maintenance/suggestions:
 *   get:
 *     summary: Obtenir les suggestions d'entretiens basées sur l'historique et le kilométrage
 *     tags: [Garage]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Liste des suggestions d'entretiens
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   properties:
 *                     suggestions:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           maintenanceItemId: { type: string }
 *                           label: { type: string }
 *                           category: { type: string }
 *                           reason: { type: string }
 *                           priority: { type: string, enum: [urgent, normal, upcoming] }
 *                           currentStatus: { type: string }
 *                           estimatedKm: { type: number }
 *                           estimatedDate: { type: string, format: date }
 *                           intervalKm: { type: number }
 *                           intervalMonths: { type: number }
 *                           lastDoneAtKm: { type: number }
 *                           lastDoneAtDate: { type: string, format: date }
 *                           notes: { type: string }
 *       401:
 *         description: Non authentifié
 *       403:
 *         description: Non autorisé
 *       404:
 *         description: Véhicule non trouvé
 */
exports.getMaintenanceSuggestions = async (req, res, next) => {
  try {
    const vehicle = await Vehicle.findById(req.params.id);

    if (!vehicle) {
      throw new NotFoundError('Véhicule');
    }

    if (vehicle.ownerUserId.toString() !== req.user._id.toString()) {
      throw new ForbiddenError('Vous n\'êtes pas propriétaire de ce véhicule');
    }

    const currentKm = vehicle.odometerCurrentKm || 0;
    const suggestions = await getMaintenanceSuggestions(vehicle, currentKm);

    res.json({
      success: true,
      data: {
        suggestions,
        currentKm,
        vehicleType: vehicle.type
      }
    });
  } catch (error) {
    next(error);
  }
};

