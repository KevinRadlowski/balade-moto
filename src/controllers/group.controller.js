const Group = require('../models/Group');
const User = require('../models/User');
const { createPlanLimitError } = require('../utils/errors');

// Helper pour normaliser un créateur supprimé ou introuvable
function normalizeCreator(createur) {
  if (!createur || createur.isDeleted) {
    return {
      _id: createur?._id || null,
      id: createur?._id?.toString() || null,
      firstName: null,
      lastName: null,
      pseudo: 'Utilisateur supprimé',
      email: null,
      avatarUrl: null,
      isDeleted: true
    };
  }
  return createur;
}

// Helper pour construire les URLs complètes des avatars
const buildAvatarUrls = (data) => {
  const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
  
  if (data.createur && data.createur.avatarUrl && !data.createur.avatarUrl.startsWith('http')) {
    data.createur.avatarUrl = `${baseUrl}${data.createur.avatarUrl}`;
  }
  
  if (data.membres && Array.isArray(data.membres)) {
    data.membres.forEach(membre => {
      if (membre.userId && membre.userId.avatarUrl && !membre.userId.avatarUrl.startsWith('http')) {
        membre.userId.avatarUrl = `${baseUrl}${membre.userId.avatarUrl}`;
      }
    });
  }
  
  return data;
};

// Créer un groupe
exports.createGroup = async (req, res, next) => {
  try {
    // Vérifier les limites du plan (FREE vs PREMIUM) pour les groupes privés
    const premiumConfig = require('../config/premium.config');
    const userPlan = premiumConfig.getUserPlan(req.user);
    const limits = premiumConfig.getPlanLimits(userPlan);
    
    const { nom, description, visibilite, location } = req.body;

    if (!nom) {
      return res.status(400).json({
        success: false,
        message: 'Le nom du groupe est requis'
      });
    }
    
    const finalVisibilite = visibilite || 'publique';
    
    // Vérifier la limite de groupes privés créés (Standard seulement)
    if (finalVisibilite === 'privee' && !premiumConfig.isPremium(userPlan)) {
      // Compter les groupes privés dont l'utilisateur est propriétaire (createur)
      const privateGroupsOwnedCount = await Group.countDocuments({
        createur: req.user._id,
        visibilite: 'privee'
      });
      
      // Vérifier la limite (Standard = 1 groupe privé max)
      if (limits.maxPrivateGroupsCreated !== null && privateGroupsOwnedCount >= limits.maxPrivateGroupsCreated) {
        throw createPlanLimitError(
          'maxPrivateGroupsCreated',
          limits.maxPrivateGroupsCreated,
          privateGroupsOwnedCount,
          userPlan,
          'groupe(s) privé(s)'
        );
      }
    }

    // Construire l'objet location si fourni
    let groupLocation = null;
    if (location) {
      groupLocation = {};
      
      // Champs texte
      if (location.city) groupLocation.city = location.city;
      if (location.departmentCode) groupLocation.departmentCode = location.departmentCode;
      if (location.departmentName) groupLocation.departmentName = location.departmentName;
      if (location.regionName) groupLocation.regionName = location.regionName;
      if (location.countryCode) groupLocation.countryCode = location.countryCode;
      
      // Geo (Point avec coordinates)
      if (location.geo && location.geo.coordinates && Array.isArray(location.geo.coordinates) && location.geo.coordinates.length >= 2) {
        groupLocation.geo = {
          type: 'Point',
          coordinates: location.geo.coordinates // [lng, lat]
        };
      }
      
      // Ne créer location que s'il y a au moins un champ
      if (Object.keys(groupLocation).length === 0) {
        groupLocation = null;
      }
    }

    const group = new Group({
      nom,
      description,
      visibilite: finalVisibilite,
      createur: req.user._id,
      ...(groupLocation ? { location: groupLocation } : {})
    });

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'pseudo email avatarUrl');
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    if (group.createur && group.createur.avatarUrl && !group.createur.avatarUrl.startsWith('http')) {
      group.createur.avatarUrl = `${baseUrl}${group.createur.avatarUrl}`;
    }
    if (group.membres) {
      group.membres.forEach(membre => {
        if (membre.userId && membre.userId.avatarUrl && !membre.userId.avatarUrl.startsWith('http')) {
          membre.userId.avatarUrl = `${baseUrl}${membre.userId.avatarUrl}`;
        }
      });
    }

    res.status(201).json({
      success: true,
      message: 'Groupe créé avec succès',
      data: { group }
    });
  } catch (error) {
    // Laisser passer les erreurs AppError (comme ForbiddenError avec PLAN_LIMIT) au middleware global
    const { AppError } = require('../utils/errors');
    if (error instanceof AppError) {
      return next(error); // Passer au middleware d'erreur global
    }
    
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Erreur de validation',
        errors: Object.values(error.errors).map(err => err.message)
      });
    }
    
    // Pour les autres erreurs, passer au middleware global aussi
    return next(error);
  }
};

// Toggle favoris d'un groupe
exports.toggleFavorite = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    // Vérifier que le groupe existe
    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Charger l'utilisateur avec favoriteGroups
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Initialiser favoriteGroups si undefined (compatibilité avec anciens users)
    if (!user.favoriteGroups) {
      user.favoriteGroups = [];
    }

    // Toggle le groupe dans les favoris
    const groupIdStr = id.toString();
    const isFavorite = user.favoriteGroups.some(
      favId => favId.toString() === groupIdStr
    );

    if (isFavorite) {
      // Retirer des favoris
      user.favoriteGroups = user.favoriteGroups.filter(
        favId => favId.toString() !== groupIdStr
      );
    } else {
      // Ajouter aux favoris
      user.favoriteGroups.push(id);
    }

    await user.save();

    res.status(200).json({
      success: true,
      data: {
        isFavorite: !isFavorite
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de groupe invalide'
      });
    }
    return next(error);
  }
};

// Lister les groupes (version refondue avec aggregation)
exports.getGroups = async (req, res, next) => {
  try {
    const {
      scope = 'all', // 'discover' | 'joined' | 'favorites' | 'all'
      q, // Recherche nom/description
      owner, // Recherche pseudo du créateur
      visibilite, // 'publique' | 'privee'
      region,
      departmentCode,
      city,
      nearLat,
      nearLng,
      nearKm,
      page = 1,
      limit = 20
    } = req.query;

    const userId = req.user._id;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(50, Math.max(1, parseInt(limit))); // Max 50

    // Charger l'utilisateur pour avoir favoriteGroups
    const user = await User.findById(userId).select('favoriteGroups');
    const favoriteGroupIds = (user?.favoriteGroups || []).map(id => id.toString());

    // Pipeline d'aggregation
    const pipeline = [];

    // Étape 1: $match - Filtres de base
    let matchStage = {};

    // Filtre par scope
    // NOTE: Si un filtre géospatial (nearLat/nearLng) est actif, on assouplit le scope "discover"
    // pour permettre de voir tous les groupes dans le rayon, y compris ceux où l'utilisateur est membre
    const hasGeoSpatialFilter = nearLat && nearLng;
    
    if (scope === 'joined') {
      matchStage['membres.userId'] = userId;
    } else if (scope === 'favorites') {
      matchStage._id = { $in: user?.favoriteGroups || [] };
    } else if (scope === 'discover') {
      // Découvrir = groupes publics où l'utilisateur n'est pas membre
      // SAUF si un filtre géospatial est actif : dans ce cas, on montre tous les groupes publics
      // dans le rayon (y compris ceux où l'utilisateur est membre) pour permettre la découverte géographique
      matchStage.visibilite = 'publique';
      if (!hasGeoSpatialFilter) {
        // Sans filtre géospatial, exclure les groupes où l'utilisateur est membre
        matchStage['membres.userId'] = { $ne: userId };
      }
      // Avec filtre géospatial, on garde tous les groupes publics (le filtre géospatial fera le tri)
    }
    // scope === 'all' : pas de filtre supplémentaire

    // Filtre par visibilité
    if (visibilite && ['publique', 'privee'].includes(visibilite)) {
      matchStage.visibilite = visibilite;
    } else if (scope !== 'discover') {
      // Pour 'all', montrer publics + privés où l'utilisateur est membre
      if (!matchStage.$or) {
        matchStage.$or = [];
      }
      matchStage.$or.push(
        { visibilite: 'publique' },
        { 'membres.userId': userId }
      );
    }

    // Recherche par nom/description
    if (q) {
      const searchRegex = { $regex: q, $options: 'i' };
      if (!matchStage.$or) {
        matchStage.$or = [];
      }
      matchStage.$or.push(
        { nom: searchRegex },
        { description: searchRegex }
      );
    }

    // Filtres géographiques textuels (seulement si pas de filtre géospatial)
    // Si un filtre géospatial est actif, on ignore les filtres textuels car le filtre géospatial est plus précis
    if (!hasGeoSpatialFilter) {
      if (region) {
        matchStage['location.regionName'] = { $regex: region, $options: 'i' };
      }
      if (departmentCode) {
        matchStage['location.departmentCode'] = departmentCode;
      }
      if (city) {
        matchStage['location.city'] = { $regex: city, $options: 'i' };
      }
    }

    // Filtre géospatial "près de moi" - sera traité séparément avec $geoNear
    let geoNearStage = null;
    if (nearLat && nearLng) {
      const lat = parseFloat(nearLat);
      const lng = parseFloat(nearLng);
      const maxDistance = nearKm ? parseFloat(nearKm) * 1000 : 50000; // Par défaut 50km, en mètres

      if (!isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        // Créer un matchStage pour geoNear qui inclut uniquement les groupes avec location.geo valide
        // $geoNear nécessite que location.geo existe et soit de type Point avec coordinates [lng, lat]
        const geoMatchStage = {
          ...matchStage,
          'location.geo': {
            $exists: true,
            $ne: null
          },
          'location.geo.type': 'Point',
          'location.geo.coordinates': {
            $exists: true,
            $ne: null,
            $type: 'array',
            $size: 2
          }
        };

        geoNearStage = {
          $geoNear: {
            near: {
              type: 'Point',
              coordinates: [lng, lat] // MongoDB utilise [lng, lat]
            },
            distanceField: 'distance',
            maxDistance: maxDistance,
            spherical: true,
            query: geoMatchStage // Appliquer les autres filtres dans geoNear + filtre pour avoir location.geo
          }
        };
        // Réinitialiser matchStage car il sera dans geoNear
        matchStage = {};
        
        // Debug: logger les paramètres de recherche (uniquement en développement)
        if (process.env.NODE_ENV === 'development') {
          console.log('[DEBUG] Recherche géospatiale:', {
            near: { lat, lng },
            maxDistance: `${maxDistance}m (${nearKm}km)`,
            query: JSON.stringify(geoMatchStage, null, 2)
          });
        }
      }
    }

    // Ajouter $geoNear en premier si nécessaire, sinon $match
    if (geoNearStage) {
      pipeline.push(geoNearStage);
    } else if (Object.keys(matchStage).length > 0) {
      pipeline.push({ $match: matchStage });
    }

    // Étape 2: $lookup - Joindre avec User pour filtrer par owner (pseudo)
    if (owner) {
      pipeline.push({
        $lookup: {
          from: 'users',
          localField: 'createur',
          foreignField: '_id',
          as: 'creatorInfo'
        }
      });
      pipeline.push({
        $match: {
          'creatorInfo.pseudo': { $regex: owner, $options: 'i' }
        }
      });
    }

    // Étape 3: $addFields - Ajouter isMember et isFavorite
    pipeline.push({
      $addFields: {
        isMember: {
          $cond: {
            if: {
              $gt: [
                {
                  $size: {
                    $filter: {
                      input: '$membres',
                      as: 'membre',
                      cond: {
                        $eq: [
                          { $toString: '$$membre.userId' },
                          userId.toString()
                        ]
                      }
                    }
                  }
                },
                0
              ]
            },
            then: true,
            else: false
          }
        },
        isFavorite: {
          $in: [{ $toString: '$_id' }, favoriteGroupIds]
        }
      }
    });

    // Étape 4: Filtrer les groupes privés non accessibles
    // Un groupe privé n'est listé que si l'utilisateur est membre
    // NOTE: Pour le scope "discover", ce filtre est déjà appliqué dans matchStage/geoMatchStage
    // mais on le garde ici pour les autres scopes
    if (scope !== 'discover') {
      pipeline.push({
        $match: {
          $or: [
            { visibilite: 'publique' },
            { isMember: true }
          ]
        }
      });
    }

    // Étape 5: $sort - Tri recommandé
    pipeline.push({
      $sort: {
        isFavorite: -1, // Favoris d'abord
        isMember: -1, // Puis groupes rejoints
        updatedAt: -1, // Puis activité récente
        createdAt: -1 // Puis date de création
      }
    });

    // Debug: logger le pipeline complet (uniquement en développement)
    if (process.env.NODE_ENV === 'development' && nearLat && nearLng) {
      console.log('[DEBUG] Pipeline complet pour recherche géospatiale:', JSON.stringify(pipeline, null, 2));
    }

    // Étape 6: $facet - Pagination
    pipeline.push({
      $facet: {
        data: [
          { $skip: (pageNum - 1) * limitNum },
          { $limit: limitNum },
          {
            $lookup: {
              from: 'users',
              localField: 'createur',
              foreignField: '_id',
              as: 'createurInfo'
            }
          },
          {
            $unwind: {
              path: '$createurInfo',
              preserveNullAndEmptyArrays: true
            }
          },
          {
            $addFields: {
              createur: {
                $cond: {
                  if: { $or: [{ $not: '$createurInfo' }, '$createurInfo.isDeleted'] },
                  then: {
                    _id: '$createur',
                    pseudo: 'Utilisateur supprimé',
                    email: null,
                    avatarUrl: null,
                    isDeleted: true
                  },
                  else: {
                    _id: '$createurInfo._id',
                    pseudo: '$createurInfo.pseudo',
                    email: '$createurInfo.email',
                    avatarUrl: '$createurInfo.avatarUrl',
                    isDeleted: false
                  }
                }
              }
            }
          },
          {
            $lookup: {
              from: 'users',
              localField: 'membres.userId',
              foreignField: '_id',
              as: 'membresInfo'
            }
          },
          {
            $addFields: {
              membres: {
                $map: {
                  input: '$membres',
                  as: 'membre',
                  in: {
                    $let: {
                      vars: {
                        userInfo: {
                          $arrayElemAt: [
                            {
                              $filter: {
                                input: '$membresInfo',
                                as: 'info',
                                cond: { $eq: ['$$info._id', '$$membre.userId'] }
                              }
                            },
                            0
                          ]
                        }
                      },
                      in: {
                        userId: {
                          $cond: {
                            if: { $or: [{ $not: '$$userInfo' }, '$$userInfo.isDeleted'] },
                            then: {
                              _id: '$$membre.userId',
                              pseudo: 'Utilisateur supprimé',
                              email: null,
                              avatarUrl: null,
                              isDeleted: true
                            },
                            else: {
                              _id: '$$userInfo._id',
                              pseudo: '$$userInfo.pseudo',
                              email: '$$userInfo.email',
                              avatarUrl: '$$userInfo.avatarUrl',
                              isDeleted: false
                            }
                          }
                        },
                        role: '$$membre.role',
                        dateAjout: '$$membre.dateAjout'
                      }
                    }
                  }
                }
              }
            }
          },
          {
            $project: {
              createurInfo: 0,
              membresInfo: 0
            }
          }
        ],
        total: [{ $count: 'count' }]
      }
    });

    // Exécuter l'aggregation
    const result = await Group.aggregate(pipeline);

    const groups = result[0]?.data || [];
    const total = result[0]?.total[0]?.count || 0;

    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    groups.forEach(group => {
      if (group.createur && group.createur.avatarUrl && !group.createur.avatarUrl.startsWith('http')) {
        group.createur.avatarUrl = `${baseUrl}${group.createur.avatarUrl}`;
      }
      if (group.membres && Array.isArray(group.membres)) {
        group.membres.forEach(membre => {
          if (membre.userId && membre.userId.avatarUrl && !membre.userId.avatarUrl.startsWith('http')) {
            membre.userId.avatarUrl = `${baseUrl}${membre.userId.avatarUrl}`;
          }
        });
      }
    });

    res.status(200).json({
      success: true,
      data: {
        groups,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });
  } catch (error) {
    return next(error);
  }
};

// Obtenir les détails d'un groupe
exports.getGroupById = async (req, res) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id)
      .populate('createur', 'pseudo email avatarUrl isDeleted')
      .populate('membres.userId', 'pseudo email avatarUrl isDeleted')
      .populate('bannedUsers.userId', 'pseudo email avatarUrl')
      .populate('bannedUsers.bannedBy', 'pseudo email');

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Normaliser le créateur si supprimé
    group.createur = normalizeCreator(group.createur);

    // Construire les URLs complètes des avatars
    buildAvatarUrls(group);

    // Vérifier la visibilité (les groupes publics sont accessibles même sans être membre)
    // Pour les groupes privés, vérifier si l'utilisateur est membre OU créateur
    // Le createur peut être un ObjectId ou un objet peuplé, donc on vérifie les deux cas
    const createurId = group.createur && group.createur._id ? group.createur._id.toString() : (group.createur ? group.createur.toString() : null);
    const userId = req.user._id.toString();
    const isCreator = createurId === userId;
    const isMember = group.isMember(req.user._id);
    
    // Vérification manuelle supplémentaire au cas où isMember ne fonctionnerait pas correctement
    let isMemberManual = false;
    if (group.membres && group.membres.length > 0) {
      isMemberManual = group.membres.some(m => {
        const membreUserId = m.userId._id ? m.userId._id.toString() : m.userId.toString();
        return membreUserId === userId;
      });
    }
    
    const finalIsMember = isMember || isMemberManual;
    
    console.log('🔍 Vérification accès groupe:', {
      groupId: group._id,
      visibilite: group.visibilite,
      createurId,
      userId,
      isCreator,
      isMember,
      isMemberManual,
      finalIsMember,
      membresCount: group.membres.length,
      membresIds: group.membres.map(m => {
        const id = m.userId._id ? m.userId._id.toString() : m.userId.toString();
        return id;
      })
    });
    
    if (group.visibilite === 'privee' && !finalIsMember && !isCreator) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'avez pas accès à ce groupe privé'
      });
    }

    // Utiliser finalIsMember pour la réponse

    // Convertir en objet JSON et normaliser les IDs
    const groupObj = group.toObject ? group.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(group));
    
    // Normaliser les IDs des utilisateurs bannis
    if (groupObj.bannedUsers && Array.isArray(groupObj.bannedUsers)) {
      groupObj.bannedUsers = groupObj.bannedUsers.map(banned => ({
        ...banned,
        userId: banned.userId?._id?.toString() || banned.userId?._id || banned.userId?.id?.toString() || banned.userId?.toString() || banned.userId,
        bannedBy: banned.bannedBy?._id?.toString() || banned.bannedBy?._id || banned.bannedBy?.id?.toString() || banned.bannedBy?.toString() || banned.bannedBy,
        bannedAt: banned.bannedAt ? (banned.bannedAt instanceof Date ? banned.bannedAt.toISOString() : banned.bannedAt) : new Date().toISOString()
      }));
    }

    res.status(200).json({
      success: true,
      data: { 
        group: groupObj,
        isMember: finalIsMember
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de groupe invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération du groupe',
      error: error.message
    });
  }
};

// Modifier un groupe (uniquement par le créateur ou les admins)
exports.updateGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const { nom, description, visibilite } = req.body;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier les permissions
    const permissions = group.getUserPermissions(req.user._id);
    
    // Pour modifier le titre et la description, il faut être créateur ou admin
    if ((nom !== undefined || description !== undefined) && !permissions.canEditGroupInfo) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être créateur ou administrateur pour modifier le titre et la description du groupe'
      });
    }

    // Pour modifier la visibilité, seul le créateur peut le faire
    if (visibilite !== undefined && !group.isCreator(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Seul le créateur peut modifier la visibilité du groupe'
      });
    }

    // Mettre à jour les champs
    if (nom !== undefined) group.nom = nom;
    if (description !== undefined) group.description = description;
    if (visibilite !== undefined) group.visibilite = visibilite;

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'pseudo email avatarUrl');
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    if (group.createur && group.createur.avatarUrl && !group.createur.avatarUrl.startsWith('http')) {
      group.createur.avatarUrl = `${baseUrl}${group.createur.avatarUrl}`;
    }
    if (group.membres) {
      group.membres.forEach(membre => {
        if (membre.userId && membre.userId.avatarUrl && !membre.userId.avatarUrl.startsWith('http')) {
          membre.userId.avatarUrl = `${baseUrl}${membre.userId.avatarUrl}`;
        }
      });
    }

    res.status(200).json({
      success: true,
      message: 'Groupe modifié avec succès',
      data: { group }
    });
  } catch (error) {
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Erreur de validation',
        errors: Object.values(error.errors).map(err => err.message)
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification du groupe',
      error: error.message
    });
  }
};

// Supprimer un groupe (uniquement par le créateur)
exports.deleteGroup = async (req, res) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    await group.populate('createur', 'pseudo email avatarUrl isDeleted');
    // Normaliser le créateur si supprimé
    group.createur = normalizeCreator(group.createur);

    // Vérifier que l'utilisateur est le créateur
    const isCreator = group.createur && group.createur._id && 
      group.createur._id.toString() === req.user._id.toString();
    
    if (!isCreator) {
      return res.status(403).json({
        success: false,
        message: 'Seul le créateur peut supprimer ce groupe'
      });
    }

    await Group.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'Groupe supprimé avec succès'
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de groupe invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la suppression du groupe',
      error: error.message
    });
  }
};

// Rejoindre un groupe (pour les groupes publics)
exports.joinGroup = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier que le groupe est public
    if (group.visibilite !== 'publique') {
      return res.status(403).json({
        success: false,
        message: 'Ce groupe est privé. Vous devez être invité pour le rejoindre.'
      });
    }

    // Vérifier si l'utilisateur est banni
    if (group.isBanned(userId)) {
      return res.status(403).json({
        success: false,
        message: 'Vous avez été banni de ce groupe et ne pouvez pas le rejoindre.'
      });
    }

    // Vérifier si l'utilisateur est déjà membre
    if (group.isMember(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Vous êtes déjà membre de ce groupe'
      });
    }

    // Ajouter l'utilisateur comme membre
    group.membres.push({
      userId: userId,
      role: 'membre',
      dateAjout: new Date()
    });

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'pseudo email avatarUrl');
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    if (group.createur && group.createur.avatarUrl && !group.createur.avatarUrl.startsWith('http')) {
      group.createur.avatarUrl = `${baseUrl}${group.createur.avatarUrl}`;
    }
    if (group.membres) {
      group.membres.forEach(membre => {
        if (membre.userId && membre.userId.avatarUrl && !membre.userId.avatarUrl.startsWith('http')) {
          membre.userId.avatarUrl = `${baseUrl}${membre.userId.avatarUrl}`;
        }
      });
    }

    res.status(200).json({
      success: true,
      message: 'Vous avez rejoint le groupe avec succès',
      data: { group }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID de groupe invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la jonction au groupe',
      error: error.message
    });
  }
};

// Ajouter un membre au groupe (uniquement par un admin)
exports.addMember = async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, pseudo, email, role = 'membre' } = req.body;

    // Vérifier qu'au moins un identifiant est fourni
    if (!userId && !pseudo && !email) {
      return res.status(400).json({
        success: false,
        message: 'Vous devez fournir un ID, un pseudo ou un email'
      });
    }

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier les permissions
    const permissions = group.getUserPermissions(req.user._id);
    if (!permissions.canAddMembers) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être créateur ou administrateur pour ajouter des membres'
      });
    }

    // Trouver l'utilisateur par userId, pseudo ou email
    let user;
    if (userId) {
      user = await User.findById(userId);
    } else if (pseudo) {
      user = await User.findOne({ pseudo: pseudo.trim() });
    } else if (email) {
      user = await User.findOne({ email: email.toLowerCase().trim() });
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier si l'utilisateur est déjà membre
    if (group.isMember(user._id)) {
      return res.status(400).json({
        success: false,
        message: 'Cet utilisateur est déjà membre du groupe'
      });
    }

    // Ajouter le membre (seul le créateur peut ajouter directement en admin/modérateur)
    let finalRole = 'membre';
    if (group.isCreator(req.user._id)) {
      // Le créateur peut définir n'importe quel rôle
      if (['admin', 'moderateur', 'membre'].includes(role)) {
        finalRole = role;
      }
    } else if (role === 'admin' || role === 'moderateur') {
      // Les admins ne peuvent ajouter que des membres normaux
      finalRole = 'membre';
    }
    
    group.membres.push({
      userId: user._id,
      role: finalRole,
      dateAjout: new Date()
    });

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'firstName lastName pseudo email avatarUrl');

    buildAvatarUrls(group);

    res.status(200).json({
      success: true,
      message: 'Membre ajouté avec succès',
      data: { group }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de l\'ajout du membre',
      error: error.message
    });
  }
};

// Retirer un membre du groupe
exports.removeMember = async (req, res) => {
  try {
    const { id, userId } = req.params;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier si l'utilisateur est membre
    if (!group.isMember(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Cet utilisateur n\'est pas membre du groupe'
      });
    }

    // Permettre à un utilisateur de se retirer lui-même, sinon vérifier les permissions
    const isSelfRemoval = userId === req.user._id.toString();
    if (!isSelfRemoval) {
      const permissions = group.getUserPermissions(req.user._id);
      if (!permissions.canRemoveMembers) {
        return res.status(403).json({
          success: false,
          message: 'Vous devez être créateur, administrateur ou modérateur pour retirer des membres'
        });
      }
    }

    // Ne pas permettre de retirer le créateur (même si c'est lui-même)
    if (group.createur.toString() === userId) {
      return res.status(400).json({
        success: false,
        message: 'Le créateur ne peut pas être retiré du groupe'
      });
    }

    // Retirer le membre
    group.membres = group.membres.filter(
      m => m.userId.toString() !== userId
    );

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'firstName lastName pseudo email avatarUrl');

    buildAvatarUrls(group);

    res.status(200).json({
      success: true,
      message: 'Membre retiré avec succès',
      data: { group }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du retrait du membre',
      error: error.message
    });
  }
};

// Modifier le rôle d'un membre (uniquement par le créateur)
exports.updateMemberRole = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { role } = req.body;

    if (!role || !['admin', 'moderateur', 'membre'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Le rôle doit être "admin", "moderateur" ou "membre"'
      });
    }

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le créateur (seul le créateur peut promouvoir)
    if (!group.isCreator(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Seul le créateur peut modifier les rôles des membres'
      });
    }

    // Ne pas permettre de modifier le rôle du créateur
    if (group.createur.toString() === userId) {
      return res.status(400).json({
        success: false,
        message: 'Le rôle du créateur ne peut pas être modifié'
      });
    }

    // Trouver et mettre à jour le membre
    const membre = group.membres.find(
      m => m.userId.toString() === userId
    );

    if (!membre) {
      return res.status(404).json({
        success: false,
        message: 'Membre non trouvé dans le groupe'
      });
    }

    membre.role = role;
    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'firstName lastName pseudo email avatarUrl');

    buildAvatarUrls(group);

    res.status(200).json({
      success: true,
      message: 'Rôle modifié avec succès',
      data: { group }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la modification du rôle',
      error: error.message
    });
  }
};

// Bannir un utilisateur du groupe
exports.banUser = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { reason } = req.body;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier les permissions
    const permissions = group.getUserPermissions(req.user._id);
    if (!permissions.canBanUsers) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être créateur, administrateur ou modérateur pour bannir un utilisateur'
      });
    }

    // Ne pas permettre de bannir le créateur
    if (group.createur.toString() === userId) {
      return res.status(400).json({
        success: false,
        message: 'Le créateur ne peut pas être banni'
      });
    }

    // Vérifier si l'utilisateur est déjà banni
    if (group.isBanned(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Cet utilisateur est déjà banni'
      });
    }

    // Vérifier que l'utilisateur existe
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Retirer l'utilisateur des membres s'il est membre
    if (group.isMember(userId)) {
      group.membres = group.membres.filter(
        m => m.userId.toString() !== userId
      );
    }

    // Ajouter l'utilisateur à la liste des bannis
    group.bannedUsers.push({
      userId: userId,
      bannedBy: req.user._id,
      reason: reason || null,
      bannedAt: new Date()
    });

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'pseudo email avatarUrl');
    await group.populate('bannedUsers.userId', 'pseudo email avatarUrl');
    await group.populate('bannedUsers.bannedBy', 'pseudo email');

    buildAvatarUrls(group);

    // Convertir en objet JSON et normaliser les IDs
    const groupObj = group.toObject ? group.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(group));
    
    // Normaliser les IDs des utilisateurs bannis
    if (groupObj.bannedUsers && Array.isArray(groupObj.bannedUsers)) {
      groupObj.bannedUsers = groupObj.bannedUsers.map(banned => ({
        ...banned,
        userId: banned.userId?._id?.toString() || banned.userId?._id || banned.userId?.id?.toString() || banned.userId?.toString() || banned.userId,
        bannedBy: banned.bannedBy?._id?.toString() || banned.bannedBy?._id || banned.bannedBy?.id?.toString() || banned.bannedBy?.toString() || banned.bannedBy,
        bannedAt: banned.bannedAt ? (banned.bannedAt instanceof Date ? banned.bannedAt.toISOString() : banned.bannedAt) : new Date().toISOString()
      }));
    }
    
    res.status(200).json({
      success: true,
      message: 'Utilisateur banni avec succès',
      data: { group: groupObj }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du bannissement',
      error: error.message
    });
  }
};

// Débannir un utilisateur du groupe
exports.unbanUser = async (req, res) => {
  try {
    const { id, userId } = req.params;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier les permissions
    const permissions = group.getUserPermissions(req.user._id);
    if (!permissions.canUnbanUsers) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être créateur, administrateur ou modérateur pour débannir un utilisateur'
      });
    }

    // Vérifier si l'utilisateur est banni
    if (!group.isBanned(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Cet utilisateur n\'est pas banni'
      });
    }

    // Retirer l'utilisateur de la liste des bannis
    group.bannedUsers = group.bannedUsers.filter(
      b => b.userId.toString() !== userId
    );

    await group.save();
    await group.populate('createur', 'pseudo email avatarUrl');
    await group.populate('membres.userId', 'pseudo email avatarUrl');
    await group.populate('bannedUsers.userId', 'pseudo email avatarUrl');
    await group.populate('bannedUsers.bannedBy', 'pseudo email');

    buildAvatarUrls(group);

    // Convertir en objet JSON et normaliser les IDs
    const groupObj = group.toObject ? group.toObject({ virtuals: true }) : JSON.parse(JSON.stringify(group));
    
    // Normaliser les IDs des utilisateurs bannis
    if (groupObj.bannedUsers && Array.isArray(groupObj.bannedUsers)) {
      groupObj.bannedUsers = groupObj.bannedUsers.map(banned => ({
        ...banned,
        userId: banned.userId?._id?.toString() || banned.userId?._id || banned.userId?.id?.toString() || banned.userId?.toString() || banned.userId,
        bannedBy: banned.bannedBy?._id?.toString() || banned.bannedBy?._id || banned.bannedBy?.id?.toString() || banned.bannedBy?.toString() || banned.bannedBy,
        bannedAt: banned.bannedAt ? (banned.bannedAt instanceof Date ? banned.bannedAt.toISOString() : banned.bannedAt) : new Date().toISOString()
      }));
    }

    res.status(200).json({
      success: true,
      message: 'Utilisateur débanni avec succès',
      data: { group: groupObj }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors du débannissement',
      error: error.message
    });
  }
};

// Obtenir les messages d'un groupe
exports.getGroupMessages = async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 50 } = req.query;

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier la visibilité
    // Pour les groupes privés, vérifier si l'utilisateur est membre OU créateur
    // Le createur peut être un ObjectId ou un objet peuplé, donc on vérifie les deux cas
    const createurId = group.createur._id ? group.createur._id.toString() : group.createur.toString();
    const userId = req.user._id.toString();
    const isCreator = createurId === userId;
    const isMember = group.isMember(req.user._id);
    
    // Vérification manuelle supplémentaire au cas où isMember ne fonctionnerait pas correctement
    let isMemberManual = false;
    if (group.membres && group.membres.length > 0) {
      isMemberManual = group.membres.some(m => {
        const membreUserId = m.userId._id ? m.userId._id.toString() : m.userId.toString();
        return membreUserId === userId;
      });
    }
    
    const finalIsMember = isMember || isMemberManual;
    
    if (group.visibilite === 'privee' && !finalIsMember && !isCreator) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'avez pas accès à ce groupe privé'
      });
    }

    const Message = require('../models/Message');
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find({ idGroupe: id })
      .populate('auteur', 'pseudo email avatarUrl')
      .sort({ date: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    messages.forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
    });

    const total = await Message.countDocuments({ idGroupe: id });

    res.status(200).json({
      success: true,
      data: {
        messages: messages.reverse(),
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des messages',
      error: error.message
    });
  }
};

// Reprendre l'administration d'un groupe si le créateur est supprimé ou s'il n'y a plus d'admin actif
exports.claimAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    // Vérifier que l'utilisateur n'est pas supprimé
    if (req.user.isDeleted) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez pas reprendre l\'administration d\'un groupe avec un compte supprimé'
      });
    }

    // Récupérer le groupe
    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier que l'utilisateur est membre
    const isMember = group.isMember(userId);
    if (!isMember) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être membre de ce groupe pour reprendre l\'administration'
      });
    }

    // Vérifier le créateur
    const creator = await User.findById(group.createur);
    const isCreatorDeleted = !creator || creator.isDeleted;

    // Vérifier s'il existe des admins actifs dans les membres
    let hasActiveAdmin = false;
    if (group.membres && group.membres.length > 0) {
      // Récupérer tous les userId des membres avec rôle admin
      const adminUserIds = group.membres
        .filter(m => m.role === 'admin')
        .map(m => m.userId._id ? m.userId._id : m.userId);

      // Vérifier si au moins un admin existe et n'est pas supprimé
      if (adminUserIds.length > 0) {
        const adminUsers = await User.find({
          _id: { $in: adminUserIds },
          isDeleted: false
        });
        hasActiveAdmin = adminUsers.length > 0;
      }
    }

    // Condition d'éligibilité : créateur supprimé OU aucun admin actif
    const canClaim = isCreatorDeleted || !hasActiveAdmin;

    if (!canClaim) {
      return res.status(409).json({
        success: false,
        message: 'Il existe encore des administrateurs actifs. Vous ne pouvez pas reprendre l\'administration'
      });
    }

    // Update atomique : promouvoir l'utilisateur en admin et optionnellement remplacer le créateur
    const updateData = {
      $set: {
        'membres.$[elem].role': 'admin'
      }
    };

    // Si le créateur est supprimé, le remplacer aussi
    if (isCreatorDeleted) {
      updateData.$set.createur = userId;
    }

    const updatedGroup = await Group.findOneAndUpdate(
      {
        _id: id,
        // Double vérification : l'utilisateur doit être membre
        'membres.userId': userId
      },
      updateData,
      {
        arrayFilters: [{ 'elem.userId': userId }],
        new: true,
        runValidators: true
      }
    );

    if (!updatedGroup) {
      // Cas de concurrence : le groupe a changé entre temps
      return res.status(409).json({
        success: false,
        message: 'Le groupe a été modifié. Veuillez réessayer'
      });
    }

    // Populate pour la réponse
    await updatedGroup.populate('createur', 'firstName lastName pseudo email');
    await updatedGroup.populate('membres.userId', 'firstName lastName pseudo email');

    res.status(200).json({
      success: true,
      message: isCreatorDeleted 
        ? 'Vous avez repris l\'administration de ce groupe'
        : 'Vous avez été promu administrateur de ce groupe',
      data: {
        group: updatedGroup
      }
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(400).json({
        success: false,
        message: 'ID invalide'
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la reprise de l\'administration',
      error: error.message
    });
  }
};

// Obtenir les messages d'une balade
exports.getRideMessages = async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 50 } = req.query;

    const Ride = require('../models/Ride');
    const ride = await Ride.findById(id);

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Balade non trouvée'
      });
    }

    // Vérifier que l'utilisateur est participant ou organisateur
    const isParticipant = ride.participants.some(
      p => p.toString() === req.user._id.toString()
    );
    const isOrganizer = ride.organisateur.toString() === req.user._id.toString();

    if (!isParticipant && !isOrganizer) {
      return res.status(403).json({
        success: false,
        message: 'Vous n\'avez pas accès à cette discussion'
      });
    }

    const Message = require('../models/Message');
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find({ idBalade: id })
      .populate('auteur', 'pseudo email avatarUrl')
      .sort({ date: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();
    
    // Construire les URLs complètes des avatars
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    messages.forEach(msg => {
      if (msg.auteur && msg.auteur.avatarUrl && !msg.auteur.avatarUrl.startsWith('http')) {
        msg.auteur.avatarUrl = `${baseUrl}${msg.auteur.avatarUrl}`;
      }
    });

    const total = await Message.countDocuments({ idBalade: id });

    res.status(200).json({
      success: true,
      data: {
        messages: messages.reverse(),
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / parseInt(limit))
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la récupération des messages',
      error: error.message
    });
  }
};

