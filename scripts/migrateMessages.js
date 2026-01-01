const mongoose = require('mongoose');
require('dotenv').config();

const Message = require('../src/models/Message');

const migrateMessages = async () => {
  try {
    // Connexion à MongoDB
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connecté à MongoDB');

    // Trouver tous les messages
    const messages = await Message.find({});
    console.log(`📝 ${messages.length} message(s) trouvé(s)`);

    let updated = 0;
    let errors = 0;

    for (const message of messages) {
      try {
        let needsUpdate = false;

        // S'assurer que reactions est un array
        if (!Array.isArray(message.reactions)) {
          message.reactions = [];
          needsUpdate = true;
        }

        // S'assurer que deletedForUserIds est un array
        if (!Array.isArray(message.deletedForUserIds)) {
          message.deletedForUserIds = [];
          needsUpdate = true;
        }

        // S'assurer que mentions est un array
        if (!Array.isArray(message.mentions)) {
          message.mentions = [];
          needsUpdate = true;
        }

        // S'assurer que replyPreview a la bonne structure
        if (message.replyPreview && typeof message.replyPreview === 'object') {
          if (!message.replyPreview.senderPseudo) {
            message.replyPreview.senderPseudo = null;
            needsUpdate = true;
          }
          if (!message.replyPreview.content) {
            message.replyPreview.content = null;
            needsUpdate = true;
          }
          if (!message.replyPreview.type) {
            message.replyPreview.type = 'text';
            needsUpdate = true;
          }
        }

        // S'assurer que type existe
        if (!message.type) {
          message.type = 'text';
          needsUpdate = true;
        }

        // S'assurer que edited existe
        if (message.edited === undefined) {
          message.edited = false;
          needsUpdate = true;
        }

        // S'assurer que deletedForAll existe
        if (message.deletedForAll === undefined) {
          message.deletedForAll = false;
          needsUpdate = true;
        }

        if (needsUpdate) {
          message.markModified('reactions');
          message.markModified('deletedForUserIds');
          message.markModified('mentions');
          if (message.replyPreview) {
            message.markModified('replyPreview');
          }
          await message.save();
          updated++;
          console.log(`  ✅ Message ${message._id} mis à jour`);
        }
      } catch (error) {
        errors++;
        console.error(`  ❌ Erreur pour le message ${message._id}:`, error.message);
      }
    }

    console.log(`\n✅ Migration terminée:`);
    console.log(`   - ${updated} message(s) mis à jour`);
    console.log(`   - ${errors} erreur(s)`);

    await mongoose.disconnect();
    console.log('✅ Déconnecté de MongoDB');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors de la migration:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
};

migrateMessages();



