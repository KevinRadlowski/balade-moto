const subscriptionService = require('../src/services/subscription.service');
const User = require('../src/models/User');

// Mock du modèle User
jest.mock('../src/models/User', () => {
  return jest.fn();
});

describe('Subscription Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('isPremiumActive', () => {
    it('devrait retourner true si premiumExpiresAt est une date future', () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30); // 30 jours dans le futur

      const user = {
        subscription: {
          isPremium: true,
          premiumExpiresAt: futureDate,
          premiumSource: 'referral_reward'
        }
      };

      expect(subscriptionService.isPremiumActive(user)).toBe(true);
    });

    it('devrait retourner true si premiumExpiresAt est exactement maintenant', () => {
      const now = new Date();

      const user = {
        subscription: {
          isPremium: true,
          premiumExpiresAt: now,
          premiumSource: 'referral_reward'
        }
      };

      expect(subscriptionService.isPremiumActive(user)).toBe(true);
    });

    it('devrait retourner false si premiumExpiresAt est une date passée', () => {
      const pastDate = new Date();
      pastDate.setDate(pastDate.getDate() - 1); // Hier

      const user = {
        subscription: {
          isPremium: true,
          premiumExpiresAt: pastDate,
          premiumSource: 'referral_reward'
        }
      };

      expect(subscriptionService.isPremiumActive(user)).toBe(false);
    });

    it('devrait retourner false si premiumExpiresAt est null', () => {
      const user = {
        subscription: {
          isPremium: false,
          premiumExpiresAt: null,
          premiumSource: null
        }
      };

      expect(subscriptionService.isPremiumActive(user)).toBe(false);
    });

    it('devrait retourner false si subscription est null', () => {
      const user = {
        subscription: null
      };

      expect(subscriptionService.isPremiumActive(user)).toBe(false);
    });

    it('devrait retourner false si user est null', () => {
      expect(subscriptionService.isPremiumActive(null)).toBe(false);
    });
  });

  describe('normalizeSubscription', () => {
    it('devrait mettre isPremium=false et premiumSource=null si premiumExpiresAt est passé', async () => {
      const pastDate = new Date();
      pastDate.setDate(pastDate.getDate() - 1); // Hier

      const user = {
        _id: 'user123',
        subscription: {
          isPremium: true,
          premiumExpiresAt: pastDate,
          premiumSource: 'referral_reward'
        },
        save: jest.fn().mockResolvedValue(true)
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result.subscription.isPremium).toBe(false);
      expect(result.subscription.premiumSource).toBe(null);
      expect(user.save).toHaveBeenCalled();
    });

    it('devrait mettre isPremium=true si premiumExpiresAt est futur', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30); // 30 jours dans le futur

      const user = {
        _id: 'user123',
        subscription: {
          isPremium: false,
          premiumExpiresAt: futureDate,
          premiumSource: 'referral_reward'
        },
        save: jest.fn().mockResolvedValue(true)
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result.subscription.isPremium).toBe(true);
      expect(user.save).toHaveBeenCalled();
    });

    it('ne devrait pas sauvegarder si l\'état est déjà correct (premium actif)', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30);

      const user = {
        _id: 'user123',
        subscription: {
          isPremium: true,
          premiumExpiresAt: futureDate,
          premiumSource: 'referral_reward'
        },
        save: jest.fn().mockResolvedValue(true)
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result.subscription.isPremium).toBe(true);
      expect(user.save).not.toHaveBeenCalled();
    });

    it('ne devrait pas sauvegarder si l\'état est déjà correct (premium expiré)', async () => {
      const pastDate = new Date();
      pastDate.setDate(pastDate.getDate() - 1);

      const user = {
        _id: 'user123',
        subscription: {
          isPremium: false,
          premiumExpiresAt: pastDate,
          premiumSource: null
        },
        save: jest.fn().mockResolvedValue(true)
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result.subscription.isPremium).toBe(false);
      expect(result.subscription.premiumSource).toBe(null);
      expect(user.save).not.toHaveBeenCalled();
    });

    it('devrait gérer un utilisateur sans subscription', async () => {
      const user = {
        _id: 'user123',
        subscription: null
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result).toBe(user);
    });

    it('devrait gérer un utilisateur sans premiumExpiresAt', async () => {
      const user = {
        _id: 'user123',
        subscription: {
          isPremium: true,
          premiumExpiresAt: null,
          premiumSource: 'referral_reward'
        },
        save: jest.fn().mockResolvedValue(true)
      };

      const result = await subscriptionService.normalizeSubscription(user);

      expect(result.subscription.isPremium).toBe(false);
      expect(result.subscription.premiumSource).toBe(null);
      expect(user.save).toHaveBeenCalled();
    });
  });

  describe('grantPremiumDays', () => {
    it('devrait ajouter des jours à maintenant si l\'utilisateur n\'a pas de premium actif', async () => {
      const userId = 'user123';
      const user = {
        _id: userId,
        subscription: {
          isPremium: false,
          premiumExpiresAt: null,
          premiumSource: null
        },
        save: jest.fn().mockResolvedValue(true)
      };

      User.findById.mockResolvedValue(user);

      const beforeDate = new Date();
      const result = await subscriptionService.grantPremiumDays(userId, 30, 'referral_reward');
      const afterDate = new Date();

      expect(result.subscription.isPremium).toBe(true);
      expect(result.subscription.premiumSource).toBe('referral_reward');
      expect(result.subscription.premiumExpiresAt).toBeInstanceOf(Date);
      
      const expirationDate = new Date(result.subscription.premiumExpiresAt);
      const expectedMinDate = new Date(beforeDate);
      expectedMinDate.setDate(expectedMinDate.getDate() + 30);
      const expectedMaxDate = new Date(afterDate);
      expectedMaxDate.setDate(expectedMaxDate.getDate() + 30);

      expect(expirationDate.getTime()).toBeGreaterThanOrEqual(expectedMinDate.getTime());
      expect(expirationDate.getTime()).toBeLessThanOrEqual(expectedMaxDate.getTime());
      
      expect(user.save).toHaveBeenCalled();
    });

    it('devrait ajouter des jours à la date d\'expiration actuelle si premium est déjà actif', async () => {
      const userId = 'user123';
      const existingExpiration = new Date();
      existingExpiration.setDate(existingExpiration.getDate() + 15); // 15 jours dans le futur

      const user = {
        _id: userId,
        subscription: {
          isPremium: true,
          premiumExpiresAt: existingExpiration,
          premiumSource: 'purchase'
        },
        save: jest.fn().mockResolvedValue(true)
      };

      User.findById.mockResolvedValue(user);

      const result = await subscriptionService.grantPremiumDays(userId, 30, 'referral_reward');

      expect(result.subscription.isPremium).toBe(true);
      expect(result.subscription.premiumSource).toBe('referral_reward');
      
      const newExpirationDate = new Date(result.subscription.premiumExpiresAt);
      const expectedDate = new Date(existingExpiration);
      expectedDate.setDate(expectedDate.getDate() + 30);

      // Vérifier que la nouvelle date est environ 30 jours après l'ancienne (tolérance de 1 seconde)
      expect(Math.abs(newExpirationDate.getTime() - expectedDate.getTime())).toBeLessThan(1000);
      
      expect(user.save).toHaveBeenCalled();
    });

    it('devrait ajouter des jours à maintenant si premium est expiré', async () => {
      const userId = 'user123';
      const pastExpiration = new Date();
      pastExpiration.setDate(pastExpiration.getDate() - 5); // 5 jours dans le passé

      const user = {
        _id: userId,
        subscription: {
          isPremium: false,
          premiumExpiresAt: pastExpiration,
          premiumSource: null
        },
        save: jest.fn().mockResolvedValue(true)
      };

      User.findById.mockResolvedValue(user);

      const beforeDate = new Date();
      const result = await subscriptionService.grantPremiumDays(userId, 30, 'admin_grant');
      const afterDate = new Date();

      expect(result.subscription.isPremium).toBe(true);
      expect(result.subscription.premiumSource).toBe('admin_grant');
      
      const expirationDate = new Date(result.subscription.premiumExpiresAt);
      const expectedMinDate = new Date(beforeDate);
      expectedMinDate.setDate(expectedMinDate.getDate() + 30);
      const expectedMaxDate = new Date(afterDate);
      expectedMaxDate.setDate(expectedMaxDate.getDate() + 30);

      expect(expirationDate.getTime()).toBeGreaterThanOrEqual(expectedMinDate.getTime());
      expect(expirationDate.getTime()).toBeLessThanOrEqual(expectedMaxDate.getTime());
      
      expect(user.save).toHaveBeenCalled();
    });

    it('devrait initialiser subscription si elle n\'existe pas', async () => {
      const userId = 'user123';
      const user = {
        _id: userId,
        subscription: null,
        save: jest.fn().mockResolvedValue(true)
      };

      User.findById.mockResolvedValue(user);

      const result = await subscriptionService.grantPremiumDays(userId, 30, 'purchase');

      expect(result.subscription).toBeDefined();
      expect(result.subscription.isPremium).toBe(true);
      expect(result.subscription.premiumExpiresAt).toBeInstanceOf(Date);
      expect(result.subscription.premiumSource).toBe('purchase');
      
      expect(user.save).toHaveBeenCalled();
    });

    it('devrait lancer une erreur si userId est null', async () => {
      await expect(
        subscriptionService.grantPremiumDays(null, 30, 'referral_reward')
      ).rejects.toThrow('userId est requis');
    });

    it('devrait lancer une erreur si days est invalide', async () => {
      await expect(
        subscriptionService.grantPremiumDays('user123', 0, 'referral_reward')
      ).rejects.toThrow('days doit être un nombre positif');

      await expect(
        subscriptionService.grantPremiumDays('user123', -5, 'referral_reward')
      ).rejects.toThrow('days doit être un nombre positif');
    });

    it('devrait lancer une erreur si source est invalide', async () => {
      await expect(
        subscriptionService.grantPremiumDays('user123', 30, 'invalid_source')
      ).rejects.toThrow('source doit être l\'un de: purchase, referral_reward, admin_grant');
    });

    it('devrait lancer une erreur si l\'utilisateur n\'existe pas', async () => {
      User.findById.mockResolvedValue(null);

      await expect(
        subscriptionService.grantPremiumDays('user123', 30, 'referral_reward')
      ).rejects.toThrow('Utilisateur non trouvé');
    });
  });
});
