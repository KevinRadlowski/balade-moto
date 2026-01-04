const MaintenanceItem = require('../models/MaintenanceItem');
const MaintenanceLog = require('../models/MaintenanceLog');
const OdometerEntry = require('../models/OdometerEntry');
const { RECOMMENDED_PACKS } = require('./maintenancePack.service');

/**
 * Calcule les suggestions d'entretiens basées sur :
 * - L'historique des entretiens effectués
 * - Le kilométrage actuel
 * - Les intervalles recommandés par le constructeur
 * 
 * @param {Object} vehicle - Le véhicule
 * @param {Number} currentKm - Kilométrage actuel
 * @returns {Promise<Array>} - Liste des suggestions d'entretiens
 */
async function getMaintenanceSuggestions(vehicle, currentKm) {
  const vehicleType = vehicle.type;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Récupérer tous les MaintenanceItem actifs du véhicule
  const maintenanceItems = await MaintenanceItem.find({
    vehicleId: vehicle._id,
    active: true
  }).sort({ dueAtKm: 1, dueAtDate: 1 });

  // Récupérer l'historique des entretiens effectués
  const maintenanceLogs = await MaintenanceLog.find({
    vehicleId: vehicle._id
  }).sort({ date: -1, kmAtService: -1 });

  // Récupérer l'historique des relevés d'odomètre pour estimer la progression
  const odometerEntries = await OdometerEntry.find({
    vehicleId: vehicle._id
  }).sort({ date: -1 }).limit(10);

  const suggestions = [];

  // Pour chaque MaintenanceItem, calculer si un entretien est suggéré
  for (const item of maintenanceItems) {
    let shouldSuggest = false;
    let reason = '';
    let priority = 'normal'; // 'urgent', 'normal', 'upcoming'
    let estimatedKm = null;
    let estimatedDate = null;

    // Vérifier si l'entretien est déjà DUE
    if (item.status === 'DUE') {
      shouldSuggest = true;
      reason = 'Entretien dû';
      priority = 'urgent';
      
      if (item.dueAtKm) {
        estimatedKm = item.dueAtKm;
      }
      if (item.dueAtDate) {
        estimatedDate = item.dueAtDate;
      }
    } else if (item.status === 'UPCOMING') {
      // Vérifier si on approche de la date/km prévu
      const daysUntilDue = item.dueAtDate ? 
        Math.ceil((item.dueAtDate - today) / (1000 * 60 * 60 * 24)) : null;
      const kmUntilDue = item.dueAtKm ? (item.dueAtKm - currentKm) : null;

      // Suggérer si moins de 30 jours ou moins de 500km
      if ((daysUntilDue !== null && daysUntilDue <= 30) || 
          (kmUntilDue !== null && kmUntilDue <= 500)) {
        shouldSuggest = true;
        reason = 'Entretien à venir';
        priority = 'normal';
        
        if (item.dueAtKm) {
          estimatedKm = item.dueAtKm;
        }
        if (item.dueAtDate) {
          estimatedDate = item.dueAtDate;
        }
      }
    }

    // Vérifier l'historique : si le dernier entretien de ce type date de trop longtemps
    const lastLogForCategory = maintenanceLogs.find(log => 
      log.category === item.category || log.label.toLowerCase().includes(item.category.toLowerCase())
    );

    if (lastLogForCategory) {
      const lastLogDate = new Date(lastLogForCategory.date);
      const lastLogKm = lastLogForCategory.kmAtService || 0;
      const daysSinceLastLog = Math.ceil((today - lastLogDate) / (1000 * 60 * 60 * 24));
      const kmSinceLastLog = currentKm - lastLogKm;

      // Si l'intervalle recommandé est dépassé
      if (item.intervalMonths && daysSinceLastLog >= (item.intervalMonths * 30)) {
        shouldSuggest = true;
        reason = `Dernier entretien il y a ${Math.floor(daysSinceLastLog / 30)} mois`;
        priority = 'urgent';
        
        // Estimer la prochaine date/km
        if (item.intervalMonths) {
          estimatedDate = new Date(lastLogDate);
          estimatedDate.setMonth(estimatedDate.getMonth() + item.intervalMonths);
        }
        if (item.intervalKm) {
          estimatedKm = lastLogKm + item.intervalKm;
        }
      } else if (item.intervalKm && kmSinceLastLog >= item.intervalKm) {
        shouldSuggest = true;
        reason = `Dernier entretien à ${lastLogKm} km (${kmSinceLastLog} km parcourus)`;
        priority = 'urgent';
        
        if (item.intervalKm) {
          estimatedKm = lastLogKm + item.intervalKm;
        }
        if (item.intervalMonths) {
          estimatedDate = new Date(lastLogDate);
          estimatedDate.setMonth(estimatedDate.getMonth() + item.intervalMonths);
        }
      }
    } else {
      // Aucun historique pour ce type d'entretien
      // Suggérer si l'item est DUE ou UPCOMING
      if (item.status === 'DUE' || item.status === 'UPCOMING') {
        shouldSuggest = true;
        reason = 'Premier entretien de ce type recommandé';
        priority = item.status === 'DUE' ? 'urgent' : 'normal';
        
        if (item.dueAtKm) {
          estimatedKm = item.dueAtKm;
        }
        if (item.dueAtDate) {
          estimatedDate = item.dueAtDate;
        }
      }
    }

    // Estimer la progression du kilométrage basée sur l'historique
    if (odometerEntries.length >= 2) {
      const recentEntries = odometerEntries.slice(0, 2);
      const kmDiff = recentEntries[0].km - recentEntries[1].km;
      const daysDiff = Math.ceil((recentEntries[0].date - recentEntries[1].date) / (1000 * 60 * 60 * 24));
      const avgKmPerDay = daysDiff > 0 ? kmDiff / daysDiff : 0;

      // Si on a une estimation de km, calculer quand on l'atteindra
      if (estimatedKm && avgKmPerDay > 0) {
        const kmRemaining = estimatedKm - currentKm;
        const daysUntilKm = Math.ceil(kmRemaining / avgKmPerDay);
        if (daysUntilKm > 0 && daysUntilKm < 90) {
          // Si on atteindra le km dans moins de 90 jours, ajuster la date estimée
          const adjustedDate = new Date(today);
          adjustedDate.setDate(adjustedDate.getDate() + daysUntilKm);
          if (!estimatedDate || adjustedDate < estimatedDate) {
            estimatedDate = adjustedDate;
          }
        }
      }
    }

    if (shouldSuggest) {
      suggestions.push({
        maintenanceItemId: item._id,
        label: item.label,
        category: item.category,
        reason,
        priority,
        currentStatus: item.status,
        estimatedKm,
        estimatedDate,
        intervalKm: item.intervalKm,
        intervalMonths: item.intervalMonths,
        lastDoneAtKm: item.lastDoneAtKm,
        lastDoneAtDate: item.lastDoneAtDate,
        notes: item.notes
      });
    }
  }

  // Trier par priorité (urgent d'abord) puis par date/km estimé
  suggestions.sort((a, b) => {
    const priorityOrder = { urgent: 0, normal: 1, upcoming: 2 };
    const priorityDiff = priorityOrder[a.priority] - priorityOrder[b.priority];
    if (priorityDiff !== 0) return priorityDiff;

    // Si même priorité, trier par date/km estimé
    if (a.estimatedDate && b.estimatedDate) {
      return a.estimatedDate - b.estimatedDate;
    }
    if (a.estimatedKm && b.estimatedKm) {
      return a.estimatedKm - b.estimatedKm;
    }
    return 0;
  });

  return suggestions;
}

module.exports = {
  getMaintenanceSuggestions
};



