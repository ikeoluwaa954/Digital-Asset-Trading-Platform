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
