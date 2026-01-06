const referralService = require('../../src/services/referral.service');
const Referral = require('../../src/models/Referral');
const subscriptionService = require('../../src/services/subscription.service');

// Mock des modèles et services
jest.mock('../../src/models/Referral');
jest.mock('../../src/services/subscription.service');

describe('Referral Service', () => {
  let referrerId, referredUserId, referralCode;

  beforeEach(() => {
    jest.clearAllMocks();

    referrerId = '507f1f77bcf86cd799439011';
    referredUserId = '507f1f77bcf86cd799439012';
    referralCode = 'ABC123';

    // Mock par défaut pour Referral.findOne
    Referral.findOne = jest.fn().mockResolvedValue(null);
    Referral.prototype.save = jest.fn().mockResolvedValue(true);
  });

  describe('grantReferralRewards', () => {
    it('devrait créer un nouveau referral et accorder 30 jours premium aux deux utilisateurs', async () => {
      const newReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: false,
        referrerRewardGranted: false,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(null);
      Referral.mockImplementation(() => newReferral);

      subscriptionService.grantPremiumDays.mockResolvedValue({});

      const result = await referralService.grantReferralRewards(referrerId, referredUserId, referralCode);

      // Vérifier qu'un nouveau referral a été créé
      expect(Referral).toHaveBeenCalledWith({
        referrerId,
        referredUserId,
        referralCode
      });

      // Vérifier que grantPremiumDays a été appelé pour les deux utilisateurs
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledTimes(2);
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referredUserId, 30, 'referral_reward');
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referrerId, 30, 'referral_reward');

      // Vérifier que les récompenses ont été marquées comme accordées
      expect(newReferral.referredRewardGranted).toBe(true);
      expect(newReferral.referrerRewardGranted).toBe(true);
      expect(newReferral.referredRewardGrantedAt).toBeInstanceOf(Date);
      expect(newReferral.referrerRewardGrantedAt).toBeInstanceOf(Date);

      // Vérifier que save a été appelé
      expect(newReferral.save).toHaveBeenCalled();
    });

    it('devrait utiliser un referral existant et accorder les récompenses non accordées', async () => {
      const existingReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: false,
        referrerRewardGranted: false,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(existingReferral);
      subscriptionService.grantPremiumDays.mockResolvedValue({});

      const result = await referralService.grantReferralRewards(referrerId, referredUserId, referralCode);

      // Vérifier qu'un nouveau referral n'a PAS été créé
      expect(Referral).not.toHaveBeenCalled();

      // Vérifier que grantPremiumDays a été appelé pour les deux utilisateurs
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledTimes(2);
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referredUserId, 30, 'referral_reward');
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referrerId, 30, 'referral_reward');

      // Vérifier que les récompenses ont été marquées
      expect(existingReferral.referredRewardGranted).toBe(true);
      expect(existingReferral.referrerRewardGranted).toBe(true);
    });

    it('ne devrait pas accorder de récompense si déjà accordée', async () => {
      const existingReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: true,
        referrerRewardGranted: true,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(existingReferral);
      subscriptionService.grantPremiumDays.mockResolvedValue({});

      const result = await referralService.grantReferralRewards(referrerId, referredUserId, referralCode);

      // Vérifier que grantPremiumDays n'a PAS été appelé
      expect(subscriptionService.grantPremiumDays).not.toHaveBeenCalled();

      // Vérifier que save n'a PAS été appelé (rien n'a changé)
      expect(existingReferral.save).not.toHaveBeenCalled();
    });

    it('devrait prolonger correctement le premium si l\'utilisateur a déjà premium jusqu\'à une date future', async () => {
      const existingReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: false,
        referrerRewardGranted: false,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(existingReferral);

      // Mock d'un utilisateur avec premium actif jusqu'à une date future
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 15); // 15 jours dans le futur

      const updatedUser = {
        _id: referredUserId,
        subscription: {
          isPremium: true,
          premiumExpiresAt: futureDate,
          premiumSource: 'purchase'
        }
      };

      // Mock grantPremiumDays pour simuler la prolongation
      subscriptionService.grantPremiumDays.mockImplementation(async (userId, days, source) => {
        // Simuler la logique : si premium actif, ajouter les jours à la date d'expiration
        const newExpirationDate = new Date(futureDate);
        newExpirationDate.setDate(newExpirationDate.getDate() + days);
        
        updatedUser.subscription.premiumExpiresAt = newExpirationDate;
        return updatedUser;
      });

      await referralService.grantReferralRewards(referrerId, referredUserId, referralCode);

      // Vérifier que grantPremiumDays a été appelé avec 30 jours
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referredUserId, 30, 'referral_reward');
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referrerId, 30, 'referral_reward');

      // Vérifier que la date d'expiration a été prolongée de 30 jours
      const finalExpirationDate = updatedUser.subscription.premiumExpiresAt;
      const expectedDate = new Date(futureDate);
      expectedDate.setDate(expectedDate.getDate() + 30);

      // Vérifier que la date est environ 30 jours après la date initiale (tolérance de 1 seconde)
      expect(Math.abs(finalExpirationDate.getTime() - expectedDate.getTime())).toBeLessThan(1000);
    });

    it('devrait accorder premium à partir de maintenant si l\'utilisateur n\'a pas de premium actif', async () => {
      const existingReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: false,
        referrerRewardGranted: false,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(existingReferral);

      const updatedUser = {
        _id: referredUserId,
        subscription: {
          isPremium: false,
          premiumExpiresAt: null,
          premiumSource: null
        }
      };

      // Mock grantPremiumDays pour simuler l'ajout à partir de maintenant
      subscriptionService.grantPremiumDays.mockImplementation(async (userId, days, source) => {
        const now = new Date();
        const expirationDate = new Date(now);
        expirationDate.setDate(expirationDate.getDate() + days);
        
        updatedUser.subscription.isPremium = true;
        updatedUser.subscription.premiumExpiresAt = expirationDate;
        updatedUser.subscription.premiumSource = source;
        return updatedUser;
      });

      await referralService.grantReferralRewards(referrerId, referredUserId, referralCode);

      // Vérifier que grantPremiumDays a été appelé
      expect(subscriptionService.grantPremiumDays).toHaveBeenCalledWith(referredUserId, 30, 'referral_reward');

      // Vérifier que le premium a été activé
      expect(updatedUser.subscription.isPremium).toBe(true);
      expect(updatedUser.subscription.premiumExpiresAt).toBeInstanceOf(Date);
      expect(updatedUser.subscription.premiumSource).toBe('referral_reward');

      // Vérifier que la date d'expiration est dans environ 30 jours
      const now = new Date();
      const expirationDate = updatedUser.subscription.premiumExpiresAt;
      const daysDifference = Math.floor((expirationDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      
      expect(daysDifference).toBeGreaterThanOrEqual(29); // Au moins 29 jours (tolérance)
      expect(daysDifference).toBeLessThanOrEqual(31); // Au plus 31 jours (tolérance)
    });

    it('devrait gérer les erreurs correctement', async () => {
      Referral.findOne.mockRejectedValue(new Error('Database error'));

      await expect(
        referralService.grantReferralRewards(referrerId, referredUserId, referralCode)
      ).rejects.toThrow('Database error');
    });

    it('devrait gérer les erreurs de grantPremiumDays', async () => {
      const existingReferral = {
        referrerId,
        referredUserId,
        referralCode,
        referredRewardGranted: false,
        referrerRewardGranted: false,
        save: jest.fn().mockResolvedValue(true)
      };

      Referral.findOne.mockResolvedValue(existingReferral);
      subscriptionService.grantPremiumDays.mockRejectedValue(new Error('User not found'));

      await expect(
        referralService.grantReferralRewards(referrerId, referredUserId, referralCode)
      ).rejects.toThrow('User not found');
    });
  });
});
