import request from 'supertest';
import express from 'express';
import MetaMaskController from '../MetaMask/metamask.controller.js';
import client from '../db/index.js';

// Mock the database client
jest.mock('../db/index.js', () => ({
  query: jest.fn()
}));

// Mock the utils functions
jest.mock('../helpers/utils.js', () => ({
  completeOrder: jest.fn(),
  getCheckoutEvent: jest.fn(),
  emitOnboardSeller: jest.fn(),
  validateAndGetOrderDetails: jest.fn()
}));

// Mock ethers
jest.mock('ethers', () => ({
  Interface: jest.fn(),
  parseEther: jest.fn(),
  parseUnits: jest.fn()
}));

describe('MetaMask Controller', () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.use(express.urlencoded({ extended: true }));
    
    // Reset all mocks
    jest.clearAllMocks();
  });

  describe('onboarding', () => {
    it('should serve the onboarding page', async () => {
      const mockSendFile = jest.fn();
      const mockStatus = jest.fn().mockReturnValue({ sendFile: mockSendFile });
      
      const req = {};
      const res = { status: mockStatus };
      const next = jest.fn();

      await MetaMaskController.onboarding(req, res, next);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockSendFile).toHaveBeenCalledWith(expect.stringContaining('onboarding.html'));
    });
  });

  describe('completeOnboarding', () => {
    it('should complete onboarding successfully', async () => {
      const mockQuery = jest.fn().mockResolvedValue({ rows: [] });
      client.query.mockImplementation(mockQuery);

      const { emitOnboardSeller } = require('../helpers/utils.js');
      emitOnboardSeller.mockResolvedValue({ success: true });

      const req = {
        query: { username: 'testuser', address: '0x1234567890123456789012345678901234567890' },
        body: { supported_tokens: ['ETH', 'USDC'] }
      };
      const res = { status: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.completeOnboarding(req, res, next);

      expect(emitOnboardSeller).toHaveBeenCalledWith(expect.any(String), {
        sellersCommonName: 'testuser',
        isActive: true
      });
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO metamask'),
        ['testuser', '0x1234567890123456789012345678901234567890', ['ETH', 'USDC']]
      );
      expect(res.status).toHaveBeenCalledWith(204);
    });

    it('should handle missing parameters', async () => {
      const req = {
        query: { username: 'testuser' }, // Missing address
        body: { supported_tokens: ['ETH'] }
      };
      const res = {};
      const next = jest.fn();

      await MetaMaskController.completeOnboarding(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(Error));
    });

    it('should handle missing supported tokens', async () => {
      const req = {
        query: { username: 'testuser', address: '0x1234567890123456789012345678901234567890' },
        body: {} // Missing supported_tokens
      };
      const res = {};
      const next = jest.fn();

      await MetaMaskController.completeOnboarding(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(Error));
    });
  });

  describe('onboardingStatus', () => {
    it('should return onboarded status when user exists', async () => {
      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{
          username: 'testuser',
          eth_address: '0x1234567890123456789012345678901234567890',
          supported_tokens: ['ETH', 'USDC']
        }]
      });
      client.query.mockImplementation(mockQuery);

      const req = { query: { username: 'testuser' } };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.onboardingStatus(req, res, next);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        onboarded: true,
        eth_address: '0x1234567890123456789012345678901234567890',
        supported_tokens: ['ETH', 'USDC']
      });
    });

    it('should return not onboarded status when user does not exist', async () => {
      const mockQuery = jest.fn().mockResolvedValue({ rows: [] });
      client.query.mockImplementation(mockQuery);

      const req = { query: { username: 'nonexistent' } };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.onboardingStatus(req, res, next);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        onboarded: false
      });
    });
  });

  describe('getTxParams', () => {
    it('should return ETH transaction parameters', async () => {
      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{ eth_address: '0x1234567890123456789012345678901234567890' }]
      });
      client.query.mockImplementation(mockQuery);

      // Mock fetch for CoinGecko API
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: jest.fn().mockResolvedValue({ ethereum: { usd: 2000 } })
      });

      const { parseEther } = require('ethers');
      parseEther.mockReturnValue({ toString: jest.fn().mockReturnValue('0x1234567890abcdef') });

      const req = { 
        query: { 
          checkout_total: '100', 
          currency: 'ETH', 
          username: 'testuser' 
        } 
      };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.getTxParams(req, res, next);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        to: '0x1234567890123456789012345678901234567890',
        value: '0x1234567890abcdef',
        networkId: expect.any(String)
      });
    });

    it('should return USDC transaction parameters', async () => {
      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{ eth_address: '0x1234567890123456789012345678901234567890' }]
      });
      client.query.mockImplementation(mockQuery);

      const { Interface, parseUnits } = require('ethers');
      const mockInterface = {
        encodeFunctionData: jest.fn().mockReturnValue('0xencodeddata')
      };
      Interface.mockReturnValue(mockInterface);
      parseUnits.mockReturnValue({ toString: jest.fn().mockReturnValue('100000000') });

      const req = { 
        query: { 
          checkout_total: '100', 
          currency: 'USDC', 
          username: 'testuser' 
        } 
      };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.getTxParams(req, res, next);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        to: '0xA0b86991c6218b36c1d19D4a2e9EB0cE3606EB48',
        data: '0xencodeddata',
        networkId: expect.any(String)
      });
    });

    it('should handle unsupported currency', async () => {
      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{ eth_address: '0x1234567890123456789012345678901234567890' }]
      });
      client.query.mockImplementation(mockQuery);

      const req = { 
        query: { 
          checkout_total: '100', 
          currency: 'UNSUPPORTED', 
          username: 'testuser' 
        } 
      };
      const res = {};
      const next = jest.fn();

      await MetaMaskController.getTxParams(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(Error));
    });
  });

  describe('completeCheckout', () => {
    it('should complete checkout successfully', async () => {
      const { getCheckoutEvent, completeOrder } = require('../helpers/utils.js');
      
      getCheckoutEvent.mockResolvedValue([{
        checkoutHash: 'hash123',
        orderId: 'order123',
        purchaser: '0xbuyer',
        saleAddresses: ['0xasset1'],
        quantities: [1],
        createdDate: 1234567890
      }]);
      
      completeOrder.mockResolvedValue(['asset1', 'asset2']);

      const req = {
        body: {
          checkout_total: '100',
          currency: 'ETH',
          checkoutHash: 'hash123'
        }
      };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.completeCheckout(req, res, next);

      expect(completeOrder).toHaveBeenCalledWith(expect.any(String), {
        orderHash: 'hash123',
        orderId: 'order123',
        purchaser: '0xbuyer',
        saleAddresses: ['0xasset1'],
        quantities: [1],
        currency: 'ETH',
        createdDate: 1234567890,
        comments: expect.any(String)
      });
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        assets: ['asset1', 'asset2']
      });
    });
  });

  describe('changeUserWallet', () => {
    it('should update wallet address successfully', async () => {
      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{
          username: 'testuser',
          eth_address: '0xnewaddress1234567890123456789012345678901234567890'
        }]
      });
      client.query.mockImplementation(mockQuery);

      const req = {
        body: {
          username: 'testuser',
          newAddress: '0xnewaddress1234567890123456789012345678901234567890'
        }
      };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.changeUserWallet(req, res, next);

      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE metamask'),
        ['0xnewaddress1234567890123456789012345678901234567890', 'testuser']
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        message: "Wallet address updated successfully",
        eth_address: '0xnewaddress1234567890123456789012345678901234567890'
      });
    });
  });

  describe('orderInfo', () => {
    it('should return order information', async () => {
      const { getCheckoutEvent, validateAndGetOrderDetails } = require('../helpers/utils.js');
      
      getCheckoutEvent.mockResolvedValue([{
        saleAddresses: ['0xasset1'],
        quantities: [1]
      }]);
      
      validateAndGetOrderDetails.mockResolvedValue({
        sellerCommonName: 'testuser',
        orderDetails: [{ productName: 'Test Product', unitPrice: 100, quantity: 1 }]
      });

      const mockQuery = jest.fn().mockResolvedValue({
        rows: [{ supported_tokens: ['ETH', 'USDC'] }]
      });
      client.query.mockImplementation(mockQuery);

      const req = { query: { orderHash: 'hash123' } };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.orderInfo(req, res, next);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        sellerCommonName: 'testuser',
        orderDetails: [{ productName: 'Test Product', unitPrice: 100, quantity: 1 }],
        checkoutEvent: { saleAddresses: ['0xasset1'], quantities: [1] },
        supported_tokens: ['ETH', 'USDC']
      });
    });
  });

  describe('orderStatus', () => {
    it('should return order status', async () => {
      const { getCheckoutEvent } = require('../helpers/utils.js');
      
      getCheckoutEvent.mockResolvedValue([{
        createdDate: 1234567890
      }]);

      const req = { query: { orderHash: 'hash123' } };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await MetaMaskController.orderStatus(req, res, next);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        orderHash: 'hash123',
        status: "completed",
        timestamp: 1234567890
      });
    });
  });
}); 