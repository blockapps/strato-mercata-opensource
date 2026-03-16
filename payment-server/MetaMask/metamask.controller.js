import client from '../db/index.js';
import { completeOrder, getCheckoutEvent, emitOnboardSeller, validateAndGetOrderDetails } from '../helpers/utils.js';
import { METAMASK_CONTRACT_ADDRESS, PAYMENT_RECEIVED_MESSAGE } from '../helpers/constants.js';
import { Interface, parseEther, parseUnits } from 'ethers';

class MetaMaskController {
    static async onboarding(req, res, next) {
        try {
            res.status(200)
            res.sendFile(process.cwd() + '/MetaMask/onboarding.html')
        } catch (error) {
            console.log(error)
            next(error);
        }
    }

    static async completeOnboarding(req, res, next) {
        try {
            const { username, address, redirectUrl } = req.query;

            if (!username || !address) {
                throw new Error('Missing username OR eth_address in GET request')
            }

            const { supported_tokens } = req.body;

            if (!supported_tokens || !Array.isArray(supported_tokens) || supported_tokens.length === 0) {
                throw new Error('Supported tokens array is required and must not be empty')
            }

            // Call onboardSeller
            const callArgs = {
              sellersCommonName: username,
              isActive: true,
            }
            const onboardSellerStatus = await emitOnboardSeller(METAMASK_CONTRACT_ADDRESS, callArgs);
            console.log("onboardSellerStatus", onboardSellerStatus);

            const query = `INSERT INTO metamask (
                username,
                eth_address,
                supported_tokens
            ) VALUES ($1, $2, $3) ON CONFLICT (username) DO UPDATE SET 
                eth_address = EXCLUDED.eth_address,
                supported_tokens = EXCLUDED.supported_tokens;`

            await client.query(query, [username, address, supported_tokens])

            res.status(204); // Success without content

            next();
        } catch (error) {
            console.log(error)
            next(error);
        }
    }
    
    static async onboardingStatus(req, res, next) {
        try {
            if (!req.query.username) {
                throw new Error('Missing username in GET request')
            }

            const query = 'SELECT * FROM metamask WHERE username = $1;'
            const query_result = await client.query(query, [req.query.username])
            
            if (query_result.rows.length === 1) {
                res.status(200).json({
                    onboarded: true,
                    eth_address: query_result.rows[0].eth_address,
                    supported_tokens: query_result.rows[0].supported_tokens
                });
            } else {
                res.status(404).json({
                    onboarded: false,
                })
            }

            next();
        } catch (error) {
            console.error('DB Error:', error.message);
            next(error);
        }    
    }

    static async checkout(req, res, next) {
        try {
            res.status(200)
            res.sendFile(process.cwd() + '/MetaMask/checkout.html')
        } catch (error) {
            console.log(error)
            next(error);
        }
    }

    static async getTxParams(req, res, next) {
        try {            
            const { checkout_total, currency, username } = req.query; 
            
            if (!checkout_total || !currency || !username) {
                throw new Error('Missing required parameters: checkout_total, currency, or username')
            }

            const query = 'SELECT eth_address FROM metamask WHERE username = $1';
            const query_result = await client.query(query, [username])
            
            if (query_result.rows.length === 0) {
                res.status(500).json({
                    error: "This user has not been onboarded through MetaMask yet."
                });
                return next();
            }

            const seller_address = query_result.rows[0].eth_address;
            const networkId = process.env.NODE_ENV === 'production' ? '0x1' : '0xaa36a7' // Sepolia network ID
            
            switch (currency) {
                case 'ETH':
                    const url = 'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd';
                    const response = await fetch(url);

                    if (!response.ok) {
                        throw new Error('Network response was not ok ' + response.statusText);
                    }

                    const coin_gecko_response = await response.json();
                    const eth_usd_price = coin_gecko_response.ethereum.usd;
                    console.log(`checkout_total: ${checkout_total}`)
                    console.log(`eth_usd_price: ${eth_usd_price}`)
                    const eth_amount = (Math.round((checkout_total * 100000000) / eth_usd_price)/100000000).toString() // amount in ether
                    console.log(`eth_amount: ${eth_amount}`)
                    const amount_in_wei = parseEther(eth_amount).toString(16) // amount in wei, hex-encoded
                    console.log(`amount_in_wei: ${amount_in_wei}`)
                    
                    res.status(200).json({
                        to: seller_address,
                        value: amount_in_wei,
                        networkId
                    });
                    break;
                case 'USDC':
                    const to = '0xA0b86991c6218b36c1d19D4a2e9EB0cE3606EB48'; // USDC contract address (mainnet)
                    const usdc_abi = [ "function transfer(address to, uint amount) public returns (bool)" ];
                    const amount = parseUnits(checkout_total.toString(), 6);
                    const iface = new Interface(usdc_abi)
                    const data = iface.encodeFunctionData('transfer', [seller_address, amount.toString()])

                    res.status(200).json({
                        to: to,
                        data: data,
                        networkId
                    })
                    break;
                default:
                    throw new Error(`Unsupported currency: ${currency}`)
            }
        } catch (error) {
            console.log(error);
            next(error);
        }
    }

    static async completeCheckout(req, res, next) {
        try {
            const { checkout_total, currency, checkoutHash } = req.body; 
            
            if (!checkoutHash) {
                throw new Error('Missing checkoutHash in request body')
            }

            const checkoutEvent = await getCheckoutEvent(checkoutHash);

            if (!checkoutEvent || checkoutEvent.length === 0) {
                throw new Error(`Checkout event not found for hash: ${checkoutHash}`)
            }

            // Call completeOrder
            const callArgs = {
              orderHash: checkoutEvent[0].checkoutHash,
              orderId: checkoutEvent[0].orderId,
              purchaser: checkoutEvent[0].purchaser,
              saleAddresses: checkoutEvent[0].saleAddresses,
              quantities: checkoutEvent[0].quantities,
              currency: currency,
              createdDate: checkoutEvent[0].createdDate,
              comments: PAYMENT_RECEIVED_MESSAGE,
            } 
            const returnStatus = await completeOrder(METAMASK_CONTRACT_ADDRESS, callArgs);
            res.status(200).json({
                assets: returnStatus,
            })
        } catch (error) {
            console.log(error);
            next(error);
        }
    }

    static async changeUserWallet(req, res, next) {
        try {
            const { username, newAddress } = req.body;
            
            if (!username || !newAddress) {
                throw new Error('Missing username or newAddress in request body')
            }

            const query = 'UPDATE metamask SET eth_address = $1 WHERE username = $2 RETURNING *;'
            const query_result = await client.query(query, [newAddress, username])
            
            if (query_result.rows.length === 0) {
                res.status(404).json({
                    error: "User not found or not onboarded"
                });
            } else {
                res.status(200).json({
                    message: "Wallet address updated successfully",
                    eth_address: query_result.rows[0].eth_address
                });
            }
        } catch (error) {
            console.log(error);
            next(error);
        }
    }

    // TODO: Handle MetaMask

    static async orderInfo(req, res, next) {
        try {
            // Validation
            const { orderHash } = req.query;
            
            if (!orderHash) {
                throw new Error('Missing orderHash in query parameters')
            }

            const checkoutEvent = await getCheckoutEvent(orderHash);

            if (!checkoutEvent || checkoutEvent.length === 0) {
                throw new Error(`Checkout event not found for hash: ${orderHash}`)
            }

            // Get and validate the order details
            const saleAddresses = checkoutEvent[0].saleAddresses;
            const quantities = checkoutEvent[0].quantities;
            const { sellerCommonName, orderDetails } = await validateAndGetOrderDetails(quantities, saleAddresses);
            
            const query = 'SELECT supported_tokens FROM metamask WHERE username = $1';
            const query_result = await client.query(query, [sellerCommonName])
            
            if (query_result.rows.length === 0) {
                throw new Error(`Seller ${sellerCommonName} not found in MetaMask database`)
            }

            res.status(200).json({
                sellerCommonName,
                orderDetails,
                checkoutEvent: checkoutEvent[0],
                supported_tokens: query_result.rows[0].supported_tokens
            });
        } catch (error) {
            console.log(error);
            next(error);
        }
    }

    static async orderStatus(req, res, next) {
        try {
            const { orderHash } = req.query;
            
            if (!orderHash) {
                throw new Error('Missing orderHash in query parameters')
            }

            // Get checkout event to check status
            const checkoutEvent = await getCheckoutEvent(orderHash);
            
            if (!checkoutEvent || checkoutEvent.length === 0) {
                res.status(404).json({
                    error: "Order not found"
                });
                return next();
            }

            // For MetaMask payments, we assume the order is completed if the checkout event exists
            // In a real implementation, you might want to check the blockchain for transaction confirmation
            res.status(200).json({
                orderHash: orderHash,
                status: "completed",
                timestamp: checkoutEvent[0].createdDate
            });
        } catch (error) {
            console.log(error);
            next(error);
        }
    }
}

export default MetaMaskController;