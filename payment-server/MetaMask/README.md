# MetaMask Integration

This module provides MetaMask wallet integration for the payment server, allowing users to pay with cryptocurrencies (ETH and USDC) directly through their MetaMask wallet.

## Features

- **Seller Onboarding**: Sellers can connect their MetaMask wallet and specify supported tokens
- **Crypto Payments**: Support for ETH and USDC payments
- **Real-time Price Conversion**: ETH prices are fetched from CoinGecko API
- **Transaction Management**: Complete checkout flow with blockchain transaction handling
- **Wallet Management**: Ability to update wallet addresses

## API Endpoints

### Seller Onboarding

#### GET `/metamask/onboarding`
Serves the MetaMask onboarding page where sellers can connect their wallet.

#### POST `/metamask/onboarding`
Completes the onboarding process by storing seller's wallet address and supported tokens.

**Query Parameters:**
- `username` (required): Seller's username
- `address` (required): Ethereum wallet address
- `redirectUrl` (optional): URL to redirect after onboarding

**Request Body:**
```json
{
  "supported_tokens": ["ETH", "USDC"]
}
```

#### GET `/metamask/onboarding/status`
Checks if a seller has completed MetaMask onboarding.

**Query Parameters:**
- `username` (required): Seller's username

**Response:**
```json
{
  "onboarded": true,
  "eth_address": "0x1234567890123456789012345678901234567890",
  "supported_tokens": ["ETH", "USDC"]
}
```

### Payment Processing

#### GET `/metamask/checkout`
Serves the checkout page where buyers can select payment method and complete transaction.

#### GET `/metamask/tx/params`
Generates transaction parameters for MetaMask payment.

**Query Parameters:**
- `checkout_total` (required): Total amount in USD
- `currency` (required): Payment currency (ETH or USDC)
- `username` (required): Seller's username

**Response for ETH:**
```json
{
  "to": "0x1234567890123456789012345678901234567890",
  "value": "0x1234567890abcdef",
  "networkId": "0xaa36a7"
}
```

**Response for USDC:**
```json
{
  "to": "0xA0b86991c6218b36c1d19D4a2e9EB0cE3606EB48",
  "data": "0xa9059cbb000000000000000000000000...",
  "networkId": "0xaa36a7"
}
```

#### POST `/metamask/checkout`
Completes the checkout process after successful blockchain transaction.

**Request Body:**
```json
{
  "checkout_total": "100",
  "currency": "ETH",
  "checkoutHash": "hash123"
}
```

**Response:**
```json
{
  "assets": ["asset1", "asset2"]
}
```

### Order Management

#### GET `/metamask/order/info`
Retrieves order information for checkout.

**Query Parameters:**
- `orderHash` (required): Order hash

**Response:**
```json
{
  "sellerCommonName": "testuser",
  "orderDetails": [
    {
      "productName": "Test Product",
      "unitPrice": 100,
      "quantity": 1
    }
  ],
  "checkoutEvent": {
    "saleAddresses": ["0xasset1"],
    "quantities": [1]
  },
  "supported_tokens": ["ETH", "USDC"]
}
```

#### GET `/metamask/order/status`
Checks the status of an order.

**Query Parameters:**
- `orderHash` (required): Order hash

**Response:**
```json
{
  "orderHash": "hash123",
  "status": "completed",
  "timestamp": 1234567890
}
```

### Wallet Management

#### PUT `/metamask/wallet/change`
Updates a seller's wallet address.

**Request Body:**
```json
{
  "username": "testuser",
  "newAddress": "0xnewaddress1234567890123456789012345678901234567890"
}
```

**Response:**
```json
{
  "message": "Wallet address updated successfully",
  "eth_address": "0xnewaddress1234567890123456789012345678901234567890"
}
```

## Database Schema

The MetaMask integration uses the following database table:

```sql
CREATE TABLE IF NOT EXISTS metamask (
    username TEXT PRIMARY KEY,
    eth_address TEXT,
    supported_tokens TEXT[]
);
```

## Configuration

The MetaMask integration is configured through environment variables:

- `METAMASK_SERVICE_NAME_VALUE`: Service name (default: 'MetaMask')
- `METAMASK_ONBOARDING_ROUTE_VALUE`: Onboarding route (default: '/metamask/onboarding')
- `METAMASK_CHECKOUT_ROUTE_VALUE`: Checkout route (default: '/metamask/checkout')
- `METAMASK_ORDER_STATUS_ROUTE_VALUE`: Order status route (default: '/metamask/order/status')
- `METAMASK_IMAGE_URL_VALUE`: Service icon URL
- `METAMASK_PRIMARY_SALE_FEE_PERCENTAGE_VALUE`: Primary sale fee percentage (default: 10.0)
- `METAMASK_SECONDARY_SALE_FEE_PERCENTAGE_VALUE`: Secondary sale fee percentage (default: 3.0)

## Supported Networks

- **Development**: Sepolia testnet (chainId: 0xaa36a7)
- **Production**: Ethereum mainnet (chainId: 0x1)

## Supported Tokens

### ETH (Ethereum)
- Direct ETH transfers to seller's wallet
- Real-time price conversion using CoinGecko API
- Automatic conversion from USD to ETH amount

### USDC (USD Coin)
- ERC-20 token transfers using USDC contract
- Fixed 6 decimal places
- Direct USD amount (no conversion needed)

## Error Handling

The integration includes comprehensive error handling for:

- Missing required parameters
- Invalid wallet addresses
- Unsupported currencies
- Database connection issues
- Blockchain transaction failures
- API rate limiting (CoinGecko)

## Testing

Run the MetaMask integration tests:

```bash
npm test -- tests/metamask.test.js
```

## Security Considerations

1. **Input Validation**: All user inputs are validated before processing
2. **SQL Injection Prevention**: Uses parameterized queries
3. **Rate Limiting**: CoinGecko API calls are handled gracefully
4. **Error Logging**: Comprehensive error logging for debugging
5. **Transaction Verification**: Blockchain transactions are verified before order completion

## Dependencies

- `ethers`: Ethereum library for transaction handling
- `node-fetch`: HTTP client for API calls
- `pg`: PostgreSQL client for database operations

## Integration with Marketplace

The MetaMask integration works seamlessly with the existing marketplace backend:

1. **Payment Service Registration**: MetaMask is registered as a payment service
2. **Order Flow**: Integrates with existing order management system
3. **Asset Transfer**: Uses existing asset transfer mechanisms
4. **User Management**: Leverages existing user authentication and authorization

## Future Enhancements

- Support for additional ERC-20 tokens
- Multi-chain support (Polygon, BSC, etc.)
- Gas fee optimization
- Transaction batching
- Advanced wallet features (multi-sig, hardware wallets) 