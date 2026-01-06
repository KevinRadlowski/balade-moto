const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const Vehicle = require('../src/models/Vehicle');
const Group = require('../src/models/Group');
const Ride = require('../src/models/Ride');
const jwt = require('jsonwebtoken');
const planQuotaService = require('../src/services/planQuota.service');
const subscriptionService = require('../src/services/subscription.service');
const premiumConfig = require('../src/config/premium.config');

// Mock des services
jest.mock('../src/services/planQuota.service');
jest.mock('../src/services/subscription.service');
jest.mock('../src/config/premium.config');

// Helper pour créer un token JWT
function createToken(userId, role = 'MEMBER') {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET || 'test-secret', { expiresIn: '1h' });
}

describe('GET /api/users/me/plan', () => {
  let user;
  let token;

  beforeEach(() => {
    jest.clearAllMocks();

    // Mock utilisateur
    user = {
      _id: '507f1f77bcf86cd799439011',
      email: 'test@example.com',
      pseudo: 'testuser',
      subscription: {
        isPremium: false,
        premiumExpiresAt: null,
        premiumSource: null
      }
    };

    token = createToken(user._id);

    // Mock User.findById
    User.findById = jest.fn().mockResolvedValue(user);

    // Mock des services
    planQuotaService.countVehiclesByUser = jest.fn().mockResolvedValue({
      total: 1,
      byType: { moto: 1, voiture: 0 },
      photosTotal: 5
    });

    planQuotaService.countPrivateGroupsCreated = jest.fn().mockResolvedValue(0);
    planQuotaService.countPrivateRidesCreatedThisMonth = jest.fn().mockResolvedValue(1);

    subscriptionService.isPremiumActive = jest.fn().mockReturnValue(false);
    premiumConfig.getUserPlan = jest.fn().mockReturnValue('FREE');
    premiumConfig.getPlanLimits = jest.fn().mockReturnValue({
      maxVehiclesTotal: 2,
      maxVehiclesByType: { moto: 1, voiture: 1 },
      maxPrivateGroupsCreated: 1,
      maxPrivateRidesCreatedPerMonth: 2,
      maxPhotosTotal: 12
    });
  });

  it('devrait retourner les informations du plan pour un utilisateur FREE', async () => {
    const response = await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body).toHaveProperty('success', true);
    expect(response.body).toHaveProperty('data');

    const { data } = response.body;

    // Vérifier la structure de base
    expect(data).toHaveProperty('plan');
    expect(data).toHaveProperty('isPremium');
    expect(data).toHaveProperty('premiumExpiresAt');
    expect(data).toHaveProperty('limits');
    expect(data).toHaveProperty('usage');

    // Vérifier les valeurs
    expect(data.plan).toBe('FREE');
    expect(data.isPremium).toBe(false);
    expect(data.premiumExpiresAt).toBeNull();

    // Vérifier les limites
    expect(data.limits).toHaveProperty('maxVehiclesTotal');
    expect(data.limits).toHaveProperty('maxVehiclesByType');
    expect(data.limits).toHaveProperty('maxPrivateGroupsCreated');
    expect(data.limits).toHaveProperty('maxPrivateRidesCreatedPerMonth');
    expect(data.limits).toHaveProperty('maxPhotosTotal');

    // Vérifier l'usage
    expect(data.usage).toHaveProperty('vehiclesTotal');
    expect(data.usage).toHaveProperty('vehiclesByType');
    expect(data.usage).toHaveProperty('photosTotal');
    expect(data.usage).toHaveProperty('privateGroupsCreated');
    expect(data.usage).toHaveProperty('privateRidesCreatedThisMonth');

    expect(data.usage.vehiclesTotal).toBe(1);
    expect(data.usage.vehiclesByType).toEqual({ moto: 1, voiture: 0 });
    expect(data.usage.photosTotal).toBe(5);
    expect(data.usage.privateGroupsCreated).toBe(0);
    expect(data.usage.privateRidesCreatedThisMonth).toBe(1);
  });

  it('devrait retourner les informations du plan pour un utilisateur PREMIUM', async () => {
    // Mock utilisateur premium
    user.subscription = {
      isPremium: true,
      premiumExpiresAt: new Date('2025-12-31'),
      premiumSource: 'purchase'
    };

    subscriptionService.isPremiumActive.mockReturnValue(true);
    premiumConfig.getUserPlan.mockReturnValue('PREMIUM');
    premiumConfig.getPlanLimits.mockReturnValue({ unlimited: true });

    const response = await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body.data.plan).toBe('PREMIUM');
    expect(response.body.data.isPremium).toBe(true);
    expect(response.body.data.premiumExpiresAt).toBeTruthy();
    expect(response.body.data.limits).toEqual({ unlimited: true });
  });

  it('devrait retourner une erreur 401 si non authentifié', async () => {
    const response = await request(app)
      .get('/api/users/me/plan')
      .expect(401);

    expect(response.body).toHaveProperty('success', false);
  });

  it('devrait appeler les services de quota correctement', async () => {
    await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(planQuotaService.countVehiclesByUser).toHaveBeenCalledWith(user._id);
    expect(planQuotaService.countPrivateGroupsCreated).toHaveBeenCalledWith(user._id);
    expect(planQuotaService.countPrivateRidesCreatedThisMonth).toHaveBeenCalledWith(user._id);
  });

  it('devrait retourner les limites FREE correctes', async () => {
    const response = await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const { limits } = response.body.data;
    expect(limits.maxVehiclesTotal).toBe(2);
    expect(limits.maxVehiclesByType).toEqual({ moto: 1, voiture: 1 });
    expect(limits.maxPrivateGroupsCreated).toBe(1);
    expect(limits.maxPrivateRidesCreatedPerMonth).toBe(2);
    expect(limits.maxPhotosTotal).toBe(12);
  });

  it('devrait gérer les erreurs de service correctement', async () => {
    planQuotaService.countVehiclesByUser.mockRejectedValue(new Error('Database error'));

    const response = await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(500);

    expect(response.body).toHaveProperty('success', false);
    expect(response.body).toHaveProperty('message');
  });

  it('devrait retourner la structure complète de vehiclesByType', async () => {
    planQuotaService.countVehiclesByUser.mockResolvedValue({
      total: 2,
      byType: { moto: 1, voiture: 1 },
      photosTotal: 10
    });

    const response = await request(app)
      .get('/api/users/me/plan')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body.data.usage.vehiclesByType).toHaveProperty('moto');
    expect(response.body.data.usage.vehiclesByType).toHaveProperty('voiture');
    expect(response.body.data.usage.vehiclesByType.moto).toBe(1);
    expect(response.body.data.usage.vehiclesByType.voiture).toBe(1);
  });
});
