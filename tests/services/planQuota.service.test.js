const planQuotaService = require('../../src/services/planQuota.service');
const Vehicle = require('../../src/models/Vehicle');
const Group = require('../../src/models/Group');
const Ride = require('../../src/models/Ride');

// Mock des modèles Mongoose
jest.mock('../../src/models/Vehicle');
jest.mock('../../src/models/Group');
jest.mock('../../src/models/Ride');

describe('Plan Quota Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('countVehiclesByUser', () => {
    it('devrait retourner les compteurs corrects pour un utilisateur avec plusieurs véhicules', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      // Mock de l'aggregation
      Vehicle.aggregate.mockResolvedValue([
        {
          _id: 'moto',
          count: 1,
          photosCount: 5,
          hasMainPhoto: 1
        },
        {
          _id: 'voiture',
          count: 1,
          photosCount: 3,
          hasMainPhoto: 1
        }
      ]);

      const result = await planQuotaService.countVehiclesByUser(userId);

      expect(result).toEqual({
        total: 2,
        byType: {
          moto: 1,
          voiture: 1
        },
        photosTotal: 10 // 5 + 1 (moto) + 3 + 1 (voiture)
      });

      expect(Vehicle.aggregate).toHaveBeenCalledWith([
        {
          $match: {
            ownerUserId: expect.anything(),
            active: true
          }
        },
        {
          $group: {
            _id: '$type',
            count: { $sum: 1 },
            photosCount: expect.anything(),
            hasMainPhoto: expect.anything()
          }
        }
      ]);
    });

    it('devrait retourner zéro si l\'utilisateur n\'a pas de véhicules', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      Vehicle.aggregate.mockResolvedValue([]);

      const result = await planQuotaService.countVehiclesByUser(userId);

      expect(result).toEqual({
        total: 0,
        byType: {
          moto: 0,
          voiture: 0
        },
        photosTotal: 0
      });
    });

    it('devrait compter correctement les photos même sans photo principale', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      Vehicle.aggregate.mockResolvedValue([
        {
          _id: 'moto',
          count: 2,
          photosCount: 8,
          hasMainPhoto: 0
        }
      ]);

      const result = await planQuotaService.countVehiclesByUser(userId);

      expect(result.total).toBe(2);
      expect(result.byType.moto).toBe(2);
      expect(result.photosTotal).toBe(8);
    });

    it('devrait lancer une erreur si userId est null', async () => {
      await expect(planQuotaService.countVehiclesByUser(null)).rejects.toThrow('userId est requis');
      await expect(planQuotaService.countVehiclesByUser(undefined)).rejects.toThrow('userId est requis');
    });
  });

  describe('countPrivateGroupsCreated', () => {
    it('devrait retourner le nombre de groupes privés créés', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      Group.countDocuments.mockResolvedValue(2);

      const result = await planQuotaService.countPrivateGroupsCreated(userId);

      expect(result).toBe(2);
      expect(Group.countDocuments).toHaveBeenCalledWith({
        createur: userId,
        visibilite: 'privee'
      });
    });

    it('devrait retourner 0 si l\'utilisateur n\'a pas créé de groupes privés', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      Group.countDocuments.mockResolvedValue(0);

      const result = await planQuotaService.countPrivateGroupsCreated(userId);

      expect(result).toBe(0);
    });

    it('devrait lancer une erreur si userId est null', async () => {
      await expect(planQuotaService.countPrivateGroupsCreated(null)).rejects.toThrow('userId est requis');
    });
  });

  describe('countPrivateRidesCreatedThisMonth', () => {
    it('devrait retourner le nombre de balades privées créées ce mois', async () => {
      const userId = '507f1f77bcf86cd799439011';
      const nowDate = new Date('2024-01-15T10:00:00Z');
      
      Ride.countDocuments.mockResolvedValue(2);

      const result = await planQuotaService.countPrivateRidesCreatedThisMonth(userId, nowDate);

      expect(result).toBe(2);
      expect(Ride.countDocuments).toHaveBeenCalledWith({
        organisateur: userId,
        visibilite: 'privee',
        createdAt: {
          $gte: expect.any(Date),
          $lt: expect.any(Date)
        }
      });

      // Vérifier que les dates sont correctes (début du mois)
      const callArgs = Ride.countDocuments.mock.calls[0][0];
      expect(callArgs.createdAt.$gte.getFullYear()).toBe(2024);
      expect(callArgs.createdAt.$gte.getMonth()).toBe(0); // Janvier = 0
      expect(callArgs.createdAt.$gte.getDate()).toBe(1);
    });

    it('devrait utiliser la date actuelle par défaut si nowDate n\'est pas fourni', async () => {
      const userId = '507f1f77bcf86cd799439011';
      const beforeCall = new Date();
      
      Ride.countDocuments.mockResolvedValue(0);

      await planQuotaService.countPrivateRidesCreatedThisMonth(userId);
      const afterCall = new Date();

      expect(Ride.countDocuments).toHaveBeenCalled();
      const callArgs = Ride.countDocuments.mock.calls[0][0];
      
      // Vérifier que la date de début du mois est dans la plage attendue
      const startOfMonth = callArgs.createdAt.$gte;
      expect(startOfMonth.getTime()).toBeGreaterThanOrEqual(
        new Date(beforeCall.getFullYear(), beforeCall.getMonth(), 1).getTime()
      );
      expect(startOfMonth.getTime()).toBeLessThanOrEqual(
        new Date(afterCall.getFullYear(), afterCall.getMonth(), 1).getTime()
      );
    });

    it('devrait retourner 0 si aucune balade privée n\'a été créée ce mois', async () => {
      const userId = '507f1f77bcf86cd799439011';
      const nowDate = new Date('2024-01-15T10:00:00Z');
      
      Ride.countDocuments.mockResolvedValue(0);

      const result = await planQuotaService.countPrivateRidesCreatedThisMonth(userId, nowDate);

      expect(result).toBe(0);
    });

    it('devrait lancer une erreur si userId est null', async () => {
      await expect(planQuotaService.countPrivateRidesCreatedThisMonth(null)).rejects.toThrow('userId est requis');
    });

    it('devrait gérer correctement les mois avec différentes dates', async () => {
      const userId = '507f1f77bcf86cd799439011';
      
      // Test avec février (mois avec 28/29 jours)
      const febDate = new Date('2024-02-15T10:00:00Z');
      Ride.countDocuments.mockResolvedValue(1);

      await planQuotaService.countPrivateRidesCreatedThisMonth(userId, febDate);

      const callArgs = Ride.countDocuments.mock.calls[0][0];
      expect(callArgs.createdAt.$gte.getMonth()).toBe(1); // Février = 1
      expect(callArgs.createdAt.$lt.getMonth()).toBe(2); // Mars = 2
    });
  });
});
