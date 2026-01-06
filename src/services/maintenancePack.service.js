const MaintenanceItem = require('../models/MaintenanceItem');

/**
 * Configuration des packs d'entretien recommandés par type de véhicule
 */
const RECOMMENDED_PACKS = {
  voiture: [
    {
      label: 'Vidange moteur',
      category: 'vidange',
      intervalKm: 15000,
      intervalMonths: 12,
      notes: 'Vidange complète avec changement de filtre à huile'
    },
    {
      label: 'Remplacement des pneus',
      category: 'pneus',
      intervalKm: 40000,
      intervalMonths: 36,
      notes: 'Vérification et remplacement si nécessaire'
    },
    {
      label: 'Plaquettes de frein',
      category: 'freins',
      intervalKm: 30000,
      intervalMonths: 24,
      notes: 'Vérification et remplacement des plaquettes avant/arrière'
    },
    {
      label: 'Liquide de frein',
      category: 'liquide_freins',
      intervalMonths: 24,
      notes: 'Purge et remplacement du liquide de frein'
    },
    {
      label: 'Liquide de refroidissement',
      category: 'liquide_refroidissement',
      intervalMonths: 48,
      notes: 'Vérification et remplacement si nécessaire'
    },
    {
      label: 'Batterie',
      category: 'batterie',
      intervalMonths: 48,
      notes: 'Contrôle de la batterie et remplacement si nécessaire'
    },
    {
      label: 'Contrôle technique',
      category: 'revision',
      intervalMonths: 24,
      notes: 'Contrôle technique obligatoire'
    }
  ],
  moto: [
    {
      label: 'Vidange moteur',
      category: 'vidange',
      intervalKm: 6000,
      intervalMonths: 12,
      notes: 'Vidange complète avec changement de filtre à huile'
    },
    {
      label: 'Kit chaîne',
      category: 'chaines',
      intervalKm: 20000,
      intervalMonths: 24,
      notes: 'Remplacement de la chaîne, pignon et couronne'
    },
    {
      label: 'Remplacement des pneus',
      category: 'pneus',
      intervalKm: 15000,
      intervalMonths: 24,
      notes: 'Vérification et remplacement si nécessaire'
    },
    {
      label: 'Plaquettes de frein',
      category: 'freins',
      intervalKm: 15000,
      intervalMonths: 24,
      notes: 'Vérification et remplacement des plaquettes avant/arrière'
    },
    {
      label: 'Liquide de frein',
      category: 'liquide_freins',
      intervalMonths: 24,
      notes: 'Purge et remplacement du liquide de frein'
    },
    {
      label: 'Liquide de refroidissement',
      category: 'liquide_refroidissement',
      intervalMonths: 48,
      notes: 'Vérification et remplacement si nécessaire'
    },
    {
      label: 'Batterie',
      category: 'batterie',
      intervalMonths: 48,
      notes: 'Contrôle de la batterie et remplacement si nécessaire'
    }
  ]
};

/**
 * Crée les éléments de maintenance recommandés pour un véhicule
 * @param {Object} vehicle - Le véhicule pour lequel créer les maintenances
 * @param {String} userId - L'ID de l'utilisateur propriétaire
 * @returns {Promise<Array>} - Liste des MaintenanceItem créés
 */
async function createRecommendedMaintenancePack(vehicle, userId) {
  const vehicleType = vehicle.type;
  
  if (!RECOMMENDED_PACKS[vehicleType]) {
    throw new Error(`Type de véhicule non supporté pour le pack recommandé: ${vehicleType}`);
  }

  const packItems = RECOMMENDED_PACKS[vehicleType];
  const odometerCurrentKm = vehicle.odometerCurrentKm || 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const createdItems = [];

  for (const itemConfig of packItems) {
    // Calculer dueAtKm si intervalKm est défini
    let dueAtKm = null;
    if (itemConfig.intervalKm) {
      dueAtKm = odometerCurrentKm + itemConfig.intervalKm;
    }

    // Calculer dueAtDate si intervalMonths est défini
    let dueAtDate = null;
    if (itemConfig.intervalMonths) {
      dueAtDate = new Date(today);
      dueAtDate.setMonth(dueAtDate.getMonth() + itemConfig.intervalMonths);
      dueAtDate.setHours(0, 0, 0, 0);
    }

    // Déterminer le statut initial
    let status = 'UPCOMING';
    if (dueAtKm && odometerCurrentKm >= dueAtKm) {
      status = 'DUE';
    } else if (dueAtDate && today >= dueAtDate) {
      status = 'DUE';
    }

    const maintenanceItem = new MaintenanceItem({
      vehicleId: vehicle._id,
      label: itemConfig.label,
      category: itemConfig.category,
      intervalKm: itemConfig.intervalKm || null,
      intervalMonths: itemConfig.intervalMonths || null,
      lastDoneAtKm: null,
      lastDoneAtDate: null,
      dueAtKm,
      dueAtDate,
      status,
      notes: itemConfig.notes || '',
      active: true
    });

    await maintenanceItem.save();
    createdItems.push(maintenanceItem);
  }

  return createdItems;
}

module.exports = {
  createRecommendedMaintenancePack,
  RECOMMENDED_PACKS
};







