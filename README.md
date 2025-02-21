# BTC-Stable Protocol

A sophisticated decentralized finance protocol enabling the creation of USD-pegged stablecoins collateralized by Bitcoin on the Stacks blockchain.

## Overview

BTC-Stable is a decentralized protocol that allows users to mint USD-pegged stablecoins using Bitcoin as collateral. The system maintains price stability through:

- Dynamic collateralization ratios
- Automated liquidation mechanisms
- Decentralized price oracles
- Risk management parameters

## Key Features

- **Vault System**: Users can create vaults to deposit Bitcoin collateral and mint stablecoins
- **Over-collateralization**: Maintains system stability with minimum 150% collateralization ratio
- **Liquidation Protection**: Automated liquidation at 120% ratio to protect the system
- **Oracle Network**: Decentralized price feeds for accurate Bitcoin pricing
- **Governance Controls**: Protocol parameters adjustable through governance
- **Emergency Controls**: Safety mechanisms to protect user funds

## Core Components

### Vault Management

Users can perform the following operations with vaults:

1. **Create Vault**

```clarity
(create-vault (collateral-amount uint))
```

- Deposit Bitcoin as collateral
- Multiple deposits supported
- Requires protocol initialization

2. **Mint Stablecoins**

```clarity
(mint-stablecoin (amount uint))
```

- Mint stablecoins against deposited collateral
- Must maintain minimum collateralization ratio
- Requires valid price feed

3. **Repay Debt**

```clarity
(repay-debt (amount uint))
```

- Repay outstanding stablecoin debt
- Reduces vault risk
- Enables collateral withdrawal

4. **Withdraw Collateral**

```clarity
(withdraw-collateral (amount uint))
```

- Remove excess collateral
- Must maintain minimum collateralization ratio
- Blocked during emergency shutdown

### Risk Parameters

The protocol maintains stability through key risk parameters:

- **Minimum Collateral Ratio**: 150%

  - Minimum required collateral-to-debt ratio
  - Prevents undercollateralized positions

- **Liquidation Ratio**: 120%

  - Threshold for vault liquidation
  - Protects system solvency

- **Stability Fee**: 2% annual
  - Fee charged on outstanding debt
  - Helps maintain peg stability

### Price Oracle System

Decentralized price feed mechanism:

- Multiple authorized oracles
- Price validation checks
- Emergency price feed controls
- Minimum and maximum price bounds

### Liquidation Mechanism

Automated liquidation process:

- Triggered below 120% collateralization
- Authorized liquidators only
- Full collateral distribution
- Debt clearance mechanism

### Access Control

Role-based permissions system:

1. **Contract Owner**

   - Protocol parameter updates
   - Access control management
   - Emergency controls

2. **Liquidators**

   - Perform vault liquidations
   - Added/removed by owner
   - Authorization checks

3. **Price Oracles**
   - Update price feeds
   - Added/removed by owner
   - Price validation enforcement

### Emergency Controls

Safety mechanisms include:

- Emergency shutdown capability
- Price feed validation
- Parameter bounds checking
- Owner-only critical operations

## Query Functions

Read-only functions for protocol interaction:

```clarity
;; Get vault information
(get-vault (owner principal))

;; Calculate collateral ratio
(get-collateral-ratio (owner principal))

;; Check liquidator authorization
(is-authorized-liquidator (address principal))

;; Check oracle authorization
(is-authorized-oracle (address principal))

;; Get protocol parameters
(get-stability-parameters)
```

## Error Codes

| Code | Description                    |
| ---- | ------------------------------ |
| u100 | Owner-only operation           |
| u101 | Insufficient collateral        |
| u102 | Below minimum collateral ratio |
| u103 | Already initialized            |
| u104 | Not initialized                |
| u105 | Low balance                    |
| u106 | Invalid price                  |
| u107 | Emergency shutdown active      |
| u108 | Invalid parameter              |

## Security Considerations

1. **Collateral Safety**

   - Over-collateralization requirement
   - Liquidation protection
   - Emergency shutdown capability

2. **Access Control**

   - Role-based permissions
   - Owner-only critical functions
   - Authorized liquidators and oracles

3. **Price Security**

   - Multiple oracle support
   - Price validation checks
   - Valid price bounds

4. **Parameter Safety**
   - Bounded parameters
   - Relationship checks
   - Owner-only updates

## Future Governance Integration

The protocol is designed for future DAO governance with:

- Governance token support
- Parameter adjustment capability
- Access control management
- Emergency control mechanisms

## Development and Testing

To interact with the contract:

1. Deploy the contract to Stacks blockchain
2. Initialize with valid Bitcoin price
3. Add authorized oracles and liquidators
4. Create vaults and mint stablecoins
5. Monitor collateral ratios
6. Implement liquidation monitoring

## Security Warnings

- This code is provided as-is
- Audit recommended before mainnet deployment
- Test thoroughly on testnet first
- Monitor oracle feeds and liquidation events
- Maintain adequate collateralization
