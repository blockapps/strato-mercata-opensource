import express from 'express';
import MetaMaskController from './metamask.controller.js';

const router = express.Router();

// Returns a web page that triggers the MetaMask extension
router.get(
    '/onboarding',
    MetaMaskController.onboarding
)

// A follow up to the user connecting their MetaMask wallet
// and stores the details in the database
router.post(
    '/onboarding',
    MetaMaskController.completeOnboarding
)

router.get(
    '/onboarding/status',
    MetaMaskController.onboardingStatus
)

router.get(
    '/checkout',
    MetaMaskController.checkout
)

router.post(
    '/checkout',
    MetaMaskController.completeCheckout
)

router.get(
    '/tx/params',
    MetaMaskController.getTxParams
)

router.get(
    '/order/info',
    MetaMaskController.orderInfo
)

router.get(
  '/order/status',
  MetaMaskController.orderStatus
)

router.put(
    '/wallet/change',
    MetaMaskController.changeUserWallet
)

export default router;