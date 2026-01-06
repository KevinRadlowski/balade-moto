const vpicService = require('../../src/services/vpic.service');
const VpicCache = require('../../src/models/VpicCache');

// Mock axios
jest.mock('axios');
const axios = require('axios');

// Mock VpicCache
jest.mock('../../src/models/VpicCache');

describe('VpicService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getVpicTypesForAppType', () => {
    it('devrait retourner les types vPIC pour "moto"', () => {
      const result = vpicService.getVpicTypesForAppType('moto');
      expect(result).toEqual(['Motorcycle']);
    });

    it('devrait retourner les types vPIC pour "voiture"', () => {
      const result = vpicService.getVpicTypesForAppType('voiture');
      expect(result).toEqual(['Passenger Car', 'Truck', 'Van', 'SUV']);
    });

    it('devrait retourner un tableau vide pour un type inconnu', () => {
      const result = vpicService.getVpicTypesForAppType('unknown');
      expect(result).toEqual([]);
    });
  });

  describe('getMakesForVehicleType', () => {
    it('devrait normaliser les résultats vPIC pour les marques', async () => {
      const mockVpicResponse = {
        Results: [
          { Make_ID: 1, Make_Name: 'Yamaha' },
          { Make_ID: 2, Make_Name: 'Honda' },
          { Make_ID: 1, Make_Name: 'Yamaha' }, // Duplicate
          { Make_ID: null, Make_Name: 'Invalid' }, // Invalid
        ]
      };

      axios.get.mockResolvedValueOnce({ data: mockVpicResponse });

      // Mock cache miss
      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getMakesForVehicleType('moto');

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({ makeId: 1, makeName: 'Yamaha' });
      expect(result[1]).toEqual({ makeId: 2, makeName: 'Honda' });
      expect(result).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ makeId: expect.any(Number), makeName: expect.any(String) })
        ])
      );
    });

    it('devrait trier les marques par nom', async () => {
      const mockVpicResponse = {
        Results: [
          { Make_ID: 2, Make_Name: 'Zebra' },
          { Make_ID: 1, Make_Name: 'Alpha' },
        ]
      };

      axios.get.mockResolvedValueOnce({ data: mockVpicResponse });

      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getMakesForVehicleType('moto');

      expect(result[0].makeName).toBe('Alpha');
      expect(result[1].makeName).toBe('Zebra');
    });

    it('devrait utiliser le cache si disponible', async () => {
      const cachedData = [
        { makeId: 1, makeName: 'Cached Make' }
      ];

      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockResolvedValue(cachedData);

      const result = await vpicService.getMakesForVehicleType('moto');

      expect(result).toEqual(cachedData);
      expect(axios.get).not.toHaveBeenCalled();
    });

    it('devrait lancer une erreur pour un type non supporté', async () => {
      await expect(vpicService.getMakesForVehicleType('invalid')).rejects.toThrow(
        'Type de véhicule non supporté'
      );
    });
  });

  describe('getModelsForMakeYearAndType', () => {
    it('devrait normaliser les résultats vPIC pour les modèles', async () => {
      const mockVpicResponse = {
        Results: [
          {
            Model_ID: 1,
            Model_Name: 'MT-07',
            Make_ID: 1,
            Make_Name: 'Yamaha'
          },
          {
            Model_ID: 2,
            Model_Name: 'CBR600',
            Make_ID: 2,
            Make_Name: 'Honda'
          },
          {
            Model_ID: 1,
            Model_Name: 'MT-07',
            Make_ID: 1,
            Make_Name: 'Yamaha'
          }, // Duplicate
        ]
      };

      axios.get.mockResolvedValueOnce({ data: mockVpicResponse });

      VpicCache.generateKey.mockReturnValue('models:Yamaha:2020:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getModelsForMakeYearAndType('Yamaha', 2020, 'moto');

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({
        modelId: 1,
        modelName: 'MT-07',
        makeId: 1,
        makeName: 'Yamaha'
      });
      expect(result[1]).toEqual({
        modelId: 2,
        modelName: 'CBR600',
        makeId: 2,
        makeName: 'Honda'
      });
    });

    it('devrait trier les modèles par nom', async () => {
      const mockVpicResponse = {
        Results: [
          { Model_ID: 2, Model_Name: 'Zebra', Make_ID: 1, Make_Name: 'Make' },
          { Model_ID: 1, Model_Name: 'Alpha', Make_ID: 1, Make_Name: 'Make' },
        ]
      };

      axios.get.mockResolvedValueOnce({ data: mockVpicResponse });

      VpicCache.generateKey.mockReturnValue('models:Make:2020:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getModelsForMakeYearAndType('Make', 2020, 'moto');

      expect(result[0].modelName).toBe('Alpha');
      expect(result[1].modelName).toBe('Zebra');
    });

    it('devrait utiliser le cache si disponible', async () => {
      const cachedData = [
        { modelId: 1, modelName: 'Cached Model', makeId: 1, makeName: 'Make' }
      ];

      VpicCache.generateKey.mockReturnValue('models:Make:2020:moto');
      VpicCache.getOrSet.mockResolvedValue(cachedData);

      const result = await vpicService.getModelsForMakeYearAndType('Make', 2020, 'moto');

      expect(result).toEqual(cachedData);
      expect(axios.get).not.toHaveBeenCalled();
    });

    it('devrait lancer une erreur pour un type non supporté', async () => {
      await expect(
        vpicService.getModelsForMakeYearAndType('Make', 2020, 'invalid')
      ).rejects.toThrow('Type de véhicule non supporté');
    });
  });

  describe('Cache behavior', () => {
    it('devrait générer des clés de cache correctes pour makes', async () => {
      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockResolvedValue([]);

      await vpicService.getMakesForVehicleType('moto');

      expect(VpicCache.generateKey).toHaveBeenCalledWith('makes', 'moto');
    });

    it('devrait générer des clés de cache correctes pour models', async () => {
      VpicCache.generateKey.mockReturnValue('models:Yamaha:2020:moto');
      VpicCache.getOrSet.mockResolvedValue([]);

      await vpicService.getModelsForMakeYearAndType('Yamaha', 2020, 'moto');

      expect(VpicCache.generateKey).toHaveBeenCalledWith('models', 'Yamaha', '2020', 'moto');
    });

    it('devrait utiliser TTL de 7 jours pour makes', async () => {
      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn, ttlHours) => {
        expect(ttlHours).toBe(24 * 7); // 7 jours
        return await fetchFn();
      });

      axios.get.mockResolvedValue({ data: { Results: [] } });

      await vpicService.getMakesForVehicleType('moto');
    });

    it('devrait utiliser TTL de 7 jours pour models', async () => {
      VpicCache.generateKey.mockReturnValue('models:Make:2020:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn, ttlHours) => {
        expect(ttlHours).toBe(24 * 7); // 7 jours
        return await fetchFn();
      });

      axios.get.mockResolvedValue({ data: { Results: [] } });

      await vpicService.getModelsForMakeYearAndType('Make', 2020, 'moto');
    });
  });

  describe('Error handling', () => {
    it('devrait gérer les erreurs réseau avec retry', async () => {
      const networkError = new Error('Network error');
      networkError.code = 'ETIMEDOUT';
      networkError.response = undefined;

      axios.get
        .mockRejectedValueOnce(networkError)
        .mockResolvedValueOnce({ data: { Results: [] } });

      VpicCache.generateKey.mockReturnValue('makes:moto');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getMakesForVehicleType('moto');

      expect(axios.get).toHaveBeenCalledTimes(2); // Retry
      expect(result).toEqual([]);
    });

    it('devrait continuer avec les autres types si un type échoue', async () => {
      const error = new Error('API error');
      axios.get
        .mockRejectedValueOnce(error)
        .mockResolvedValueOnce({ data: { Results: [{ Make_ID: 1, Make_Name: 'Success' }] } });

      VpicCache.generateKey.mockReturnValue('makes:voiture');
      VpicCache.getOrSet.mockImplementation(async (key, fetchFn) => {
        return await fetchFn();
      });

      const result = await vpicService.getMakesForVehicleType('voiture');

      // Devrait avoir au moins un résultat malgré l'erreur sur un type
      expect(result.length).toBeGreaterThan(0);
    });
  });
});







