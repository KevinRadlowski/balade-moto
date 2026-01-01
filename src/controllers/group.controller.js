const Group = require('../models/Group');
const User = require('../models/User');

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
exports.createGroup = async (req, res) => {
  try {
    const { nom, description, visibilite } = req.body;

    if (!nom) {
      return res.status(400).json({
        success: false,
        message: 'Le nom du groupe est requis'
      });
    }

    const group = new Group({
      nom,
      description,
      visibilite: visibilite || 'publique',
      createur: req.user._id
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
    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Erreur de validation',
        errors: Object.values(error.errors).map(err => err.message)
      });
    }
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la création du groupe',
      error: error.message
    });
  }
};

// Lister les groupes
exports.getGroups = async (req, res) => {
  try {
    const {
      visibilite,
      membre,
      search,
      page = 1,
      limit = 10
    } = req.query;

    const filter = {};

    // Filtre par visibilité
    if (visibilite && ['publique', 'privee'].includes(visibilite)) {
      filter.visibilite = visibilite;
    } else {
      // Montrer les groupes publics et les groupes privés où l'utilisateur est membre
      filter.$or = [
        { visibilite: 'publique' },
        { 'membres.userId': req.user._id }
      ];
    }

    // Filtre par membre
    if (membre) {
      filter['membres.userId'] = membre;
    }

    // Recherche par nom ou description
    if (search) {
      filter.$or = [
        ...(filter.$or || []),
        { nom: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const groups = await Group.find(filter)
      .populate('createur', 'pseudo email avatarUrl')
      .populate('membres.userId', 'pseudo email avatarUrl')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Group.countDocuments(filter);

    res.status(200).json({
      success: true,
      data: {
        groups,
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
      message: 'Erreur lors de la récupération des groupes',
      error: error.message
    });
  }
};

// Obtenir les détails d'un groupe
exports.getGroupById = async (req, res) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id)
      .populate('createur', 'pseudo email avatarUrl')
      .populate('membres.userId', 'pseudo email avatarUrl')
      .populate('bannedUsers.userId', 'pseudo email avatarUrl')
      .populate('bannedUsers.bannedBy', 'pseudo email');

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Construire les URLs complètes des avatars
    buildAvatarUrls(group);

    // Vérifier la visibilité (les groupes publics sont accessibles même sans être membre)
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

// Modifier un groupe (uniquement par les admins)
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

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour modifier ce groupe'
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

    // Vérifier que l'utilisateur est le créateur
    if (group.createur.toString() !== req.user._id.toString()) {
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

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour ajouter des membres'
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

    // Ajouter le membre
    group.membres.push({
      userId: user._id,
      role: role === 'admin' ? 'admin' : 'membre',
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

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour retirer des membres'
      });
    }

    // Vérifier si l'utilisateur est membre
    if (!group.isMember(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Cet utilisateur n\'est pas membre du groupe'
      });
    }

    // Ne pas permettre de retirer le créateur
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

// Modifier le rôle d'un membre
exports.updateMemberRole = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { role } = req.body;

    if (!role || !['admin', 'membre'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Le rôle doit être "admin" ou "membre"'
      });
    }

    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Groupe non trouvé'
      });
    }

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour modifier les rôles'
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

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour bannir un utilisateur'
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

    // Vérifier que l'utilisateur est admin
    if (!group.isAdmin(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Vous devez être administrateur pour débannir un utilisateur'
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

