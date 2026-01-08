const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contact.controller');

// Route publique pour envoyer un email de contact
router.post('/', contactController.sendContactEmail);

module.exports = router;






