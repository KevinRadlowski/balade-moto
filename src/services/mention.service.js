/**
 * Service pour gérer les mentions @pseudo dans les messages
 */

const User = require('../models/User');
const Group = require('../models/Group');

/**
 * Pattern pour détecter les mentions : @username
 * Format: @ suivi de 2-30 caractères alphanumériques, underscore, point ou tiret
 */
const MENTION_PATTERN = /@([a-zA-Z0-9_.-]{2,30})/g;

/**
 * Limite maximale de mentions par message
 */
const MAX_MENTIONS_PER_MESSAGE = 10;

/**
 * Extrait les mentions d'un texte
 * @param {string} text - Texte à analyser
 * @returns {string[]} Liste des usernames mentionnés (sans le @)
 */
function extractMentions(text) {
  if (!text || typeof text !== 'string') {
    return [];
  }

  const mentions = [];
  const matches = text.matchAll(MENTION_PATTERN);
  
  for (const match of matches) {
    const username = match[1].toLowerCase(); // Normaliser en minuscules
    if (!mentions.includes(username)) {
      mentions.push(username);
    }
  }

  // Limiter le nombre de mentions
  return mentions.slice(0, MAX_MENTIONS_PER_MESSAGE);
}

/**
 * Résout les usernames vers des userIds
 * @param {string[]} usernames - Liste des usernames (sans @)
 * @param {string} groupId - ID du groupe (optionnel, pour filtrer les membres)
 * @returns {Promise<Array<{userId: ObjectId, username: string}>>}
 */
async function resolveMentions(usernames, groupId = null) {
  if (!usernames || usernames.length === 0) {
    return [];
  }

  // Construire la requête pour trouver les utilisateurs
  const userQuery = {
    $or: usernames.map(username => ({
      $or: [
        { pseudo: { $regex: new RegExp(`^${username}$`, 'i') } },
        { email: { $regex: new RegExp(`^${username}$`, 'i') } }
      ]
    }))
  };

  // Si un groupId est fourni, filtrer par les membres du groupe
  let userIds = null;
  if (groupId) {
    const group = await Group.findById(groupId).select('membres');
    if (group && group.membres) {
      userIds = group.membres.map(m => m.userId);
      userQuery._id = { $in: userIds };
    }
  }

  const users = await User.find(userQuery)
    .select('_id pseudo email')
    .lean();

  // Mapper les résultats
  const resolved = [];
  for (const username of usernames) {
    const user = users.find(u => 
      (u.pseudo && u.pseudo.toLowerCase() === username) ||
      (u.email && u.email.toLowerCase() === username)
    );
    
    if (user) {
      resolved.push({
        userId: user._id,
        username: user.pseudo || user.email
      });
    }
  }

  return resolved;
}

/**
 * Parse et résout les mentions d'un message
 * @param {string} content - Contenu du message
 * @param {string} groupId - ID du groupe (optionnel)
 * @returns {Promise<Array<{userId: ObjectId, username: string}>>}
 */
async function parseAndResolveMentions(content, groupId = null) {
  const usernames = extractMentions(content);
  if (usernames.length === 0) {
    return [];
  }

  return await resolveMentions(usernames, groupId);
}

module.exports = {
  extractMentions,
  resolveMentions,
  parseAndResolveMentions,
  MENTION_PATTERN,
  MAX_MENTIONS_PER_MESSAGE
};

