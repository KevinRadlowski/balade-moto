/**
 * Tests unitaires pour ride.service.js
 * Teste la logique métier sans dépendances DB réelles
 */

const rideService = require('../../src/services/ride.service');
const rideRepository = require('../../src/repositories/ride.repository');
const { NotFoundError, ForbiddenError, BadRequestError, ConflictError } = require('../../src/utils/errors');
const { enrichRidesWithLikes } = require('../../src/utils/rideStats');
const subscriptionService = require('../../src/services/subscription.service');
const premiumConfig = require('../../src/config/premium.config');

// Mock des dépendances
jest.mock('../../src/repositories/ride.repository');
jest.mock('../../src/utils/rideStats');
jest.mock('../../src/services/subscription.service');
jest.mock('../../src/config/premium.config');

describe('Ride Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getRideById', () => {
    const mockRideId = '507f1f77bcf86cd799439011';
    const mockUser = {
      _id: '507f1f77bcf86cd799439012',
      email: 'test@example.com'
    };

    it('devrait retourner une balade existante et accessible', async () => {
      const mockRide = {
        _id: mockRideId,
        titre: 'Balade test',
        visibilite: 'publique',
        organisateur: {
          _id: mockUser._id,
          firstName: 'John',
          lastName: 'Doe'
        },
        participants: [],
        invitations: [],
        toObject: function() {
          return { ...this };
        }
      };

      rideRepository.findById.mockResolvedValue(mockRide);
      enrichRidesWithLikes.mockResolvedValue([{
        ...mockRide,
        totalLikes: 5,
        hasUserLiked: true
      }]);
      subscriptionService.isPremiumActive.mockReturnValue(false);

      const result = await rideService.getRideById(mockRideId, mockUser);

      expect(result).toBeDefined();
      expect(result.titre).toBe('Balade test');
      expect(result.totalLikes).toBe(5);
      expect(result.hasUserLiked).toBe(true);
      expect(rideRepository.findById).toHaveBeenCalledWith(mockRideId, expect.any(Object));
    });

    it('devrait lancer NotFoundError si la balade n\'existe pas', async () => {
      rideRepository.findById.mockResolvedValue(null);

      await expect(
        rideService.getRideById(mockRideId, mockUser)
      ).rejects.toThrow(NotFoundError);

      expect(rideRepository.findById).toHaveBeenCalled();
    });

    it('devrait lancer ForbiddenError pour une balade privée non accessible', async () => {
      const mockRide = {
        _id: mockRideId,
        titre: 'Balade privée',
        visibilite: 'privee',
        organisateur: {
          _id: '507f1f77bcf86cd799439013', // Autre utilisateur
          firstName: 'Jane',
          lastName: 'Doe'
        },
        participants: [],
        invitations: [],
        toObject: function() {
          return { ...this };
        }
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      await expect(
        rideService.getRideById(mockRideId, mockUser)
      ).rejects.toThrow(ForbiddenError);
    });
  });

  describe('createRide', () => {
    const mockUser = {
      _id: '507f1f77bcf86cd799439012',
      email: 'test@example.com'
    };

    const mockRideData = {
      titre: 'Nouvelle balade',
      description: 'Description test',
      typeVehicule: 'moto',
      date: new Date(Date.now() + 86400000), // Demain
      heure: '10:00',
      lieuDepart: 'Paris',
      lieuArrivee: 'Lyon',
      visibilite: 'publique'
    };

    it('devrait créer une balade publique avec succès', async () => {
      premiumConfig.getUserPlan.mockReturnValue('FREE');
      premiumConfig.getPlanLimits.mockReturnValue({
        maxPrivateRidesCreatedPerMonth: 5
      });
      rideRepository.count.mockResolvedValue(0);
      
      const mockCreatedRide = {
        _id: '507f1f77bcf86cd799439011',
        ...mockRideData,
        organisateur: mockUser._id,
        participants: [{ userId: mockUser._id }],
        status: 'scheduled'
      };

      rideRepository.create.mockResolvedValue(mockCreatedRide);

      const result = await rideService.createRide(mockRideData, mockUser);

      expect(result).toBeDefined();
      expect(result.titre).toBe('Nouvelle balade');
      expect(rideRepository.create).toHaveBeenCalled();
    });

    it('devrait lancer BadRequestError si la date est dans le passé', async () => {
      const pastRideData = {
        ...mockRideData,
        date: new Date(Date.now() - 86400000) // Hier
      };

      await expect(
        rideService.createRide(pastRideData, mockUser)
      ).rejects.toThrow(BadRequestError);
    });

    it('devrait lancer BadRequestError si waypoints et lieuDepart/Arrivee manquants', async () => {
      const invalidRideData = {
        ...mockRideData,
        lieuDepart: null,
        lieuArrivee: null
      };

      await expect(
        rideService.createRide(invalidRideData, mockUser)
      ).rejects.toThrow(BadRequestError);
    });
  });

  describe('joinRide', () => {
    const mockRideId = '507f1f77bcf86cd799439011';
    const mockUser = {
      _id: '507f1f77bcf86cd799439012',
      email: 'test@example.com'
    };

    it('devrait permettre de rejoindre une balade publique', async () => {
      const mockRide = {
        _id: mockRideId,
        titre: 'Balade publique',
        visibilite: 'publique',
        date: new Date(Date.now() + 86400000),
        organisateur: {
          _id: '507f1f77bcf86cd799439013',
          toString: () => '507f1f77bcf86cd799439013'
        },
        participants: [],
        maxParticipants: null,
        requiresApproval: false,
        enableWaitlist: false,
        save: jest.fn().mockResolvedValue(true),
        populate: jest.fn().mockResolvedValue(true)
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      const result = await rideService.joinRide(mockRideId, mockUser);

      expect(result).toBeDefined();
      expect(result.status).toBe('joined');
      expect(mockRide.save).toHaveBeenCalled();
    });

    it('devrait lancer NotFoundError si la balade n\'existe pas', async () => {
      rideRepository.findById.mockResolvedValue(null);

      await expect(
        rideService.joinRide(mockRideId, mockUser)
      ).rejects.toThrow(NotFoundError);
    });

    it('devrait lancer BadRequestError si la balade est passée', async () => {
      const mockRide = {
        _id: mockRideId,
        date: new Date(Date.now() - 86400000), // Hier
        organisateur: { _id: '507f1f77bcf86cd799439013' },
        participants: []
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      await expect(
        rideService.joinRide(mockRideId, mockUser)
      ).rejects.toThrow(BadRequestError);
    });

    it('devrait lancer ConflictError si l\'utilisateur est déjà participant', async () => {
      const mockRide = {
        _id: mockRideId,
        date: new Date(Date.now() + 86400000),
        organisateur: { _id: '507f1f77bcf86cd799439013' },
        participants: [{
          userId: {
            toString: () => mockUser._id.toString()
          }
        }]
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      await expect(
        rideService.joinRide(mockRideId, mockUser)
      ).rejects.toThrow(ConflictError);
    });
  });

  describe('leaveRide', () => {
    const mockRideId = '507f1f77bcf86cd799439011';
    const mockUser = {
      _id: '507f1f77bcf86cd799439012',
      email: 'test@example.com'
    };

    it('devrait permettre de quitter une balade', async () => {
      const mockRide = {
        _id: mockRideId,
        organisateur: {
          _id: '507f1f77bcf86cd799439013',
          toString: () => '507f1f77bcf86cd799439013'
        },
        participants: [{
          userId: {
            toString: () => mockUser._id.toString()
          }
        }],
        rideEvents: [],
        save: jest.fn().mockResolvedValue(true),
        populate: jest.fn().mockResolvedValue(true)
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      const result = await rideService.leaveRide(mockRideId, mockUser);

      expect(result).toBeDefined();
      expect(mockRide.save).toHaveBeenCalled();
      expect(mockRide.participants.length).toBe(0);
    });

    it('devrait lancer BadRequestError si l\'organisateur essaie de quitter', async () => {
      const mockRide = {
        _id: mockRideId,
        organisateur: {
          _id: mockUser._id,
          toString: () => mockUser._id.toString()
        },
        participants: [{
          userId: {
            toString: () => mockUser._id.toString()
          }
        }]
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      await expect(
        rideService.leaveRide(mockRideId, mockUser)
      ).rejects.toThrow(BadRequestError);
    });
  });

  describe('likeRide', () => {
    const mockRideId = '507f1f77bcf86cd799439011';
    const mockUser = {
      _id: '507f1f77bcf86cd799439012',
      email: 'test@example.com'
    };

    it('devrait lancer NotFoundError si la balade n\'existe pas', async () => {
      rideRepository.findById.mockResolvedValue(null);

      await expect(
        rideService.likeRide(mockRideId, mockUser)
      ).rejects.toThrow(NotFoundError);
    });

    it('devrait vérifier que la balade existe avant de liker', async () => {
      const mockRide = {
        _id: mockRideId,
        titre: 'Balade test',
        likes: []
      };

      rideRepository.findById.mockResolvedValue(mockRide);

      // Mock Like model
      const Like = jest.fn().mockImplementation(() => ({
        save: jest.fn().mockResolvedValue(true)
      }));
      Like.findOne = jest.fn().mockResolvedValue(null);

      // Mock le require de Like dans le service
      jest.doMock('../../src/models/Like', () => Like, { virtual: true });

      // Le test vérifie que findById est appelé
      await rideService.likeRide(mockRideId, mockUser).catch(() => {});

      expect(rideRepository.findById).toHaveBeenCalledWith(mockRideId);
    });
  });

  describe('buildRideFilters', () => {
    it('devrait construire des filtres corrects pour un utilisateur authentifié', () => {
      const user = {
        _id: '507f1f77bcf86cd799439012'
      };

      const queryParams = {
        typeVehicule: 'moto',
        search: 'test'
      };

      const filters = rideService.buildRideFilters(queryParams, user);

      expect(filters.typeVehicule).toBe('moto');
      expect(filters.$or).toBeDefined();
    });

    it('devrait construire des filtres pour un utilisateur non authentifié', () => {
      const queryParams = {
        typeVehicule: 'moto'
      };

      const filters = rideService.buildRideFilters(queryParams, null);

      expect(filters.visibilite).toBe('publique');
    });
  });
});

