const User = require('../models/User');
const bcrypt = require('bcryptjs');
const { BadRequestError, NotFoundError } = require('../utils/errors');

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: Liste des utilisateurs (admin)
 *     tags: [Admin Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: query
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste des utilisateurs
 */
exports.getUsers = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 50;
    const skip = (page - 1) * limit;
    const { query } = req.query;

    const filter = {};
    if (query && query.trim().length > 0) {
      // Recherche par email (regex safe)
      filter.email = { $regex: query.trim(), $options: 'i' };
    }

    const users = await User.find(filter)
      .select('-password -refreshToken -twoFactorSecret')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await User.countDocuments(filter);

    res.json({
      success: true,
      data: {
        users,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/users:
 *   post:
 *     summary: Créer un utilisateur (admin)
 *     tags: [Admin Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - role
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [MEMBER, ADMIN]
 *     responses:
 *       201:
 *         description: Utilisateur créé
 */
exports.createUser = async (req, res, next) => {
  try {
    const { email, password, role } = req.body;

    if (!email || !password || !role) {
      throw new BadRequestError('email, password et role sont requis');
    }

    if (!['MEMBER', 'ADMIN'].includes(role)) {
      throw new BadRequestError('role doit être MEMBER ou ADMIN');
    }

    // Vérifier si l'email existe déjà
    const existingUser = await User.findOne({ email: email.toLowerCase().trim() });
    if (existingUser) {
      throw new BadRequestError('Cet email est déjà utilisé');
    }

    // Créer l'utilisateur
    const user = new User({
      email: email.toLowerCase().trim(),
      password,
      role,
      emailVerified: true, // Admin crée directement vérifié
    });

    await user.save();

    // Retourner sans le mot de passe
    const userObj = user.toObject();
    delete userObj.password;
    delete userObj.refreshToken;
    delete userObj.twoFactorSecret;

    res.status(201).json({
      success: true,
      data: { user: userObj },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/users/:id:
 *   patch:
 *     summary: Mettre à jour un utilisateur (admin)
 *     tags: [Admin Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [MEMBER, ADMIN]
 *               password:
 *                 type: string
 *               banned:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Utilisateur mis à jour
 */
exports.updateUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { email, role, password, banned } = req.body;

    const user = await User.findById(id);
    if (!user) {
      throw new NotFoundError('Utilisateur');
    }

    // Empêcher de se supprimer soi-même
    if (id === req.user._id.toString() && (banned === true || role === 'MEMBER')) {
      throw new BadRequestError('Vous ne pouvez pas vous bannir ou retirer vos droits admin');
    }

    if (email) {
      const existingUser = await User.findOne({ email: email.toLowerCase().trim() });
      if (existingUser && existingUser._id.toString() !== id) {
        throw new BadRequestError('Cet email est déjà utilisé');
      }
      user.email = email.toLowerCase().trim();
    }

    if (role && ['MEMBER', 'ADMIN'].includes(role)) {
      user.role = role;
    }

    if (password) {
      const salt = await bcrypt.genSalt(10);
      user.password = await bcrypt.hash(password, salt);
    }

    if (banned !== undefined) {
      user.banned = banned === true;
    }

    await user.save();

    const userObj = user.toObject();
    delete userObj.password;
    delete userObj.refreshToken;
    delete userObj.twoFactorSecret;

    res.json({
      success: true,
      data: { user: userObj },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @swagger
 * /api/admin/users/:id:
 *   delete:
 *     summary: Supprimer un utilisateur (admin)
 *     tags: [Admin Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Utilisateur supprimé
 */
exports.deleteUser = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Empêcher de se supprimer soi-même
    if (id === req.user._id.toString()) {
      throw new BadRequestError('Vous ne pouvez pas supprimer votre propre compte');
    }

    const user = await User.findById(id);
    if (!user) {
      throw new NotFoundError('Utilisateur');
    }

    await User.findByIdAndDelete(id);

    res.json({
      success: true,
      message: 'Utilisateur supprimé',
    });
  } catch (error) {
    next(error);
  }
};

