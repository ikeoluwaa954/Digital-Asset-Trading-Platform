# Digital Asset Trading Platform

A comprehensive blockchain-based platform for tokenizing, trading, and managing digital assets built on the Stacks blockchain using Clarity smart contracts.

## System Overview

The platform consists of five interconnected smart contracts that work together to provide a complete digital asset trading ecosystem:

### 1. Asset Tokenization Contract (`asset-tokenization.clar`)
- Converts physical assets into digital tokens
- Manages asset metadata and ownership records
- Handles token minting and burning operations
- Tracks asset provenance and authenticity

### 2. Trading Order Matching Contract (`trading-order-matching.clar`)
- Facilitates buy and sell order creation
- Implements automated order matching logic
- Manages order book and execution queue
- Handles partial and complete order fulfillment

### 3. Price Discovery Contract (`price-discovery.clar`)
- Establishes fair market values through trading activity
- Maintains price history and market data
- Calculates volume-weighted average prices
- Provides price feeds for other contracts

### 4. Custody and Settlement Contract (`custody-settlement.clar`)
- Secures asset transfers between parties
- Manages escrow and settlement processes
- Handles payment processing and verification
- Ensures atomic swap execution

### 5. Regulatory Compliance Contract (`regulatory-compliance.clar`)
- Enforces trading rules and regulations
- Manages KYC/AML compliance checks
- Implements trading limits and restrictions
- Maintains audit trails for regulatory reporting

## Key Features

- **Decentralized Trading**: Peer-to-peer asset trading without intermediaries
- **Asset Tokenization**: Convert any asset into tradeable digital tokens
- **Price Discovery**: Market-driven price determination
- **Secure Settlement**: Guaranteed asset and payment transfers
- **Regulatory Compliance**: Built-in compliance and audit capabilities

## Technical Architecture

### Data Types
- Assets represented as unique token IDs with metadata
- Orders stored with price, quantity, and execution status
- Price data maintained with timestamps and volume information
- Compliance records linked to user addresses and trading activity

### Security Features
- Multi-signature requirements for high-value transactions
- Time-locked settlements for dispute resolution
- Role-based access control for administrative functions
- Comprehensive error handling and validation

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for interaction

### Installation
\`\`\`bash
git clone <repository-url>
cd digital-asset-trading-platform
npm install
clarinet check
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Contract Interactions

### Tokenizing an Asset
1. Call `tokenize-asset` with asset details
2. Asset is minted as NFT with unique ID
3. Metadata stored on-chain for verification

### Creating a Trade Order
1. Call `create-order` with asset ID, price, and quantity
2. Order added to matching engine
3. Automatic matching attempted with existing orders

### Price Discovery
1. Completed trades update price feeds
2. VWAP calculated based on recent trading activity
3. Price history maintained for analysis

### Settlement Process
1. Matched orders trigger settlement
2. Assets and payments held in escrow
3. Atomic swap executed upon verification

## Error Codes

- `ERR-NOT-AUTHORIZED` (u100): Caller lacks required permissions
- `ERR-INVALID-ASSET` (u101): Asset does not exist or invalid
- `ERR-INSUFFICIENT-BALANCE` (u102): Insufficient funds or assets
- `ERR-ORDER-NOT-FOUND` (u103): Trading order does not exist
- `ERR-COMPLIANCE-VIOLATION` (u104): Regulatory compliance check failed
- `ERR-SETTLEMENT-FAILED` (u105): Settlement process encountered error

## License

MIT License - see LICENSE file for details
\`\`\`

Now let me create the Asset Tokenization contract:

```clarity file="contracts/asset-tokenization.clar"
;; Asset Tokenization Contract
;; Converts physical assets into digital tokens

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ASSET (err u101))
(define-constant ERR-ASSET-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))

;; Data Variables
(define-data-var next-asset-id uint u1)
(define-data-var total-assets uint u0)

;; Data Maps
(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    value: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map asset-balances
  { owner: principal, asset-id: uint }
  { balance: uint }
)

(define-map authorized-minters
  { minter: principal }
  { authorized: bool }
)

;; Private Functions
(define-private (is-authorized-minter (minter principal))
  (default-to false (get authorized (map-get? authorized-minters { minter: minter })))
)

;; Public Functions

;; Authorize a minter
(define-public (authorize-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-minters { minter: minter } { authorized: true }))
  )
)

;; Tokenize a new asset
(define-public (tokenize-asset (name (string-ascii 50)) (description (string-ascii 200)) (value uint) (quantity uint))
  (let
    (
      (asset-id (var-get next-asset-id))
      (current-block (stacks-block-height))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-authorized-minter tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> quantity u0) ERR-INVALID-ASSET)
    (asserts! (> value u0) ERR-INVALID-ASSET)
    
    ;; Create asset record
    (map-set assets
      { asset-id: asset-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        value: value,
        created-at: current-block,
        is-active: true
      }
    )
    
    ;; Set initial balance
    (map-set asset-balances
      { owner: tx-sender, asset-id: asset-id }
      { balance: quantity }
    )
    
    ;; Update counters
    (var-set next-asset-id (+ asset-id u1))
    (var-set total-assets (+ (var-get total-assets) u1))
    
    (ok asset-id)
  )
)

;; Transfer asset tokens
(define-public (transfer-asset (asset-id uint) (amount uint) (recipient principal))
  (let
    (
      (sender-balance (default-to u0 (get balance (map-get? asset-balances { owner: tx-sender, asset-id: asset-id }))))
      (recipient-balance (default-to u0 (get balance (map-get? asset-balances { owner: recipient, asset-id: asset-id }))))
    )
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (is-some (map-get? assets { asset-id: asset-id })) ERR-INVALID-ASSET)
    
    ;; Update sender balance
    (map-set asset-balances
      { owner: tx-sender, asset-id: asset-id }
      { balance: (- sender-balance amount) }
    )
    
    ;; Update recipient balance
    (map-set asset-balances
      { owner: recipient, asset-id: asset-id }
      { balance: (+ recipient-balance amount) }
    )
    
    (ok true)
  )
)

;; Burn asset tokens
(define-public (burn-asset (asset-id uint) (amount uint))
  (let
    (
      (current-balance (default-to u0 (get balance (map-get? asset-balances { owner: tx-sender, asset-id: asset-id }))))
    )
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (is-some (map-get? assets { asset-id: asset-id })) ERR-INVALID-ASSET)
    
    ;; Update balance
    (map-set asset-balances
      { owner: tx-sender, asset-id: asset-id }
      { balance: (- current-balance amount) }
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get asset details
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

;; Get asset balance
(define-read-only (get-balance (owner principal) (asset-id uint))
  (default-to u0 (get balance (map-get? asset-balances { owner: owner, asset-id: asset-id })))
)

;; Get total assets
(define-read-only (get-total-assets)
  (var-get total-assets)
)

;; Get next asset ID
(define-read-only (get-next-asset-id)
  (var-get next-asset-id)
)
