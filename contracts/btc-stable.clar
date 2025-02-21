;; Title: BTC-Stable - Bitcoin-Backed Stablecoin Protocol
;; Summary: A decentralized finance protocol enabling the creation of USD-pegged stablecoins collateralized by Bitcoin.
;; Description: BTC-Stable is a sophisticated DeFi protocol that allows users to mint stablecoins pegged to the US Dollar, backed by Bitcoin collateral.
;; The system ensures stability through dynamic collateralization ratios, liquidation mechanisms, and decentralized price oracles.
;;Designed for compliance with Stacks Layer 2 and Bitcoin, BTC-Stable offers a secure and efficient way to leverage Bitcoin's value while maintaining price stability.


;; Token Definitions 
;; Governance token reference for future DAO integration
(define-data-var governance-token principal 'SP000000000000000000002Q6VF78.governance-token)

;; Constants
(define-constant contract-owner tx-sender)

;; Error Codes
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-collateral (err u101))
(define-constant err-below-mcr (err u102))
(define-constant err-already-initialized (err u103))
(define-constant err-not-initialized (err u104))
(define-constant err-low-balance (err u105))
(define-constant err-invalid-price (err u106))
(define-constant err-emergency-shutdown (err u107))
(define-constant err-invalid-parameter (err u108))

;; Protocol Parameters
(define-constant maximum-price u1000000000) ;; $1B USD maximum price cap
(define-constant minimum-price u1) ;; $1 USD minimum price floor
(define-constant maximum-ratio u1000) ;; 1000% maximum collateral ratio
(define-constant minimum-ratio u101) ;; 101% minimum collateral ratio
(define-constant maximum-fee u100) ;; 100% maximum stability fee

;; Data Variables
(define-data-var minimum-collateral-ratio uint u150) ;; 150% collateralization ratio
(define-data-var liquidation-ratio uint u120) ;; 120% liquidation threshold
(define-data-var stability-fee uint u2) ;; 2% annual stability fee
(define-data-var initialized bool false)
(define-data-var emergency-shutdown bool false)
(define-data-var last-price uint u0)
(define-data-var price-valid bool false)

;; Data Maps
(define-map vaults
    principal
    {
        collateral: uint,
        debt: uint,
        last-fee-timestamp: uint
    }
)

(define-map liquidators principal bool)
(define-map price-oracles principal bool)

;; Private Functions
(define-private (is-valid-price (price uint))
    (and 
        (>= price minimum-price)
        (<= price maximum-price)
    )
)

(define-private (is-valid-ratio (ratio uint))
    (and 
        (>= ratio minimum-ratio)
        (<= ratio maximum-ratio)
    )
)

(define-private (is-valid-fee (fee uint))
    (<= fee maximum-fee)
)

;; Public Functions - Core Protocol
(define-public (initialize (btc-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (var-get initialized)) err-already-initialized)
        (asserts! (is-valid-price btc-price) err-invalid-parameter)
        (var-set last-price btc-price)
        (var-set price-valid true)
        (var-set initialized true)
        (ok true)
    )
)

(define-public (create-vault (collateral-amount uint))
    (let (
        (existing-vault (default-to 
            {
                collateral: u0,
                debt: u0,
                last-fee-timestamp: u0  ;; Use a default timestamp of 0
            }
            (map-get? vaults tx-sender)
        ))
    )
    (begin
        (asserts! (var-get initialized) err-not-initialized)
        (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        (map-set vaults tx-sender 
            (merge existing-vault {
                collateral: (+ collateral-amount (get collateral existing-vault))
            })
        )
        (ok true)
    ))
)

(define-public (mint-stablecoin (amount uint))
    (let (
        (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
        (current-collateral (get collateral vault))
        (current-debt (get debt vault))
        (new-debt (+ current-debt amount))
        (collateral-value (* current-collateral (var-get last-price)))
    )
    (begin
        (asserts! (var-get initialized) err-not-initialized)
        (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
        (asserts! (var-get price-valid) err-invalid-price)
        (asserts! (>= (* collateral-value u100) 
            (* new-debt (var-get minimum-collateral-ratio))) 
            err-below-mcr)
        (map-set vaults tx-sender
            (merge vault {
                debt: new-debt
            })
        )
        (ok true)
    ))
)

(define-public (repay-debt (amount uint))
    (let (
        (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
        (current-debt (get debt vault))
    )
    (begin
        (asserts! (var-get initialized) err-not-initialized)
        (asserts! (>= current-debt amount) err-low-balance)
        (map-set vaults tx-sender
            (merge vault {
                debt: (- current-debt amount)
            })
        )
        (ok true)
    ))
)

(define-public (withdraw-collateral (amount uint))
    (let (
        (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
        (current-collateral (get collateral vault))
        (current-debt (get debt vault))
        (new-collateral (- current-collateral amount))
        (collateral-value (* new-collateral (var-get last-price)))
    )
    (begin
        (asserts! (var-get initialized) err-not-initialized)
        (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
        (asserts! (var-get price-valid) err-invalid-price)
        (asserts! (>= current-collateral amount) err-low-balance)
        (asserts! (or
            (is-eq current-debt u0)
            (>= (* collateral-value u100)
                (* current-debt (var-get minimum-collateral-ratio))))
            err-below-mcr)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        (map-set vaults tx-sender
            (merge vault {
                collateral: new-collateral
            })
        )
        (ok true)
    ))
)

;; Public Functions - Liquidation
(define-public (liquidate (vault-owner principal))
    (let (
        (vault (unwrap! (map-get? vaults vault-owner) err-low-balance))
        (collateral (get collateral vault))
        (debt (get debt vault))
        (collateral-value (* collateral (var-get last-price)))
    )
    (begin
        (asserts! (var-get initialized) err-not-initialized)
        (asserts! (var-get price-valid) err-invalid-price)
        (asserts! (is-authorized-liquidator tx-sender) err-owner-only)
        (asserts! (> debt u0) err-invalid-parameter)
        (asserts! (< (* collateral-value u100)
            (* debt (var-get liquidation-ratio)))
            err-insufficient-collateral)
        
        ;; Additional check to prevent unauthorized vault deletion
        (asserts! (not (is-eq vault-owner contract-owner)) err-owner-only)
        
        (let (
            (collateral-to-transfer collateral)
        )
            (map-delete vaults vault-owner)
            (try! (as-contract (stx-transfer? collateral-to-transfer (as-contract tx-sender) tx-sender)))
            (ok true)
        )
    ))
)

;; Public Functions - Oracle Management
(define-public (update-price (new-price uint))
    (begin
        (asserts! (is-authorized-oracle tx-sender) err-owner-only)
        (asserts! (is-valid-price new-price) err-invalid-parameter)
        (var-set last-price new-price)
        (var-set price-valid true)
        (ok true)
    )
)

;; Public Functions - Governance
(define-public (set-minimum-collateral-ratio (new-ratio uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-ratio new-ratio) err-invalid-parameter)
        (asserts! (> new-ratio (var-get liquidation-ratio)) err-invalid-parameter)
        (var-set minimum-collateral-ratio new-ratio)
        (ok true)
    )
)

(define-public (set-liquidation-ratio (new-ratio uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-ratio new-ratio) err-invalid-parameter)
        (asserts! (< new-ratio (var-get minimum-collateral-ratio)) err-invalid-parameter)
        (var-set liquidation-ratio new-ratio)
        (ok true)
    )
)

(define-public (set-stability-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-fee new-fee) err-invalid-parameter)
        (var-set stability-fee new-fee)
        (ok true)
    )
)

;; Public Functions - Access Control
(define-public (add-liquidator (liquidator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (is-authorized-liquidator liquidator)) err-invalid-parameter)
        (map-set liquidators liquidator true)
        (ok true)
    )
)

(define-public (remove-liquidator (liquidator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-authorized-liquidator liquidator) err-invalid-parameter)
        (map-delete liquidators liquidator)
        (ok true)
    )
)

(define-public (add-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (is-authorized-oracle oracle)) err-invalid-parameter)
        (map-set price-oracles oracle true)
        (ok true)
    )
)

(define-public (remove-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-authorized-oracle oracle) err-invalid-parameter)
        (map-delete price-oracles oracle)
        (ok true)
    )
)

;; Public Functions - Emergency Controls
(define-public (trigger-emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-shutdown true)
        (ok true)
    )
)

;; Read-Only Functions
(define-read-only (get-vault (owner principal))
    (map-get? vaults owner)
)

(define-read-only (get-collateral-ratio (owner principal))
    (let (
        (vault (unwrap! (map-get? vaults owner) err-low-balance))
        (collateral (get collateral vault))
        (debt (get debt vault))
    )
    (if (is-eq debt u0)
        (ok u0)
        (ok (/ (* collateral (var-get last-price)) debt))
    ))
)

(define-read-only (is-authorized-liquidator (address principal))
    (default-to false (map-get? liquidators address))
)

(define-read-only (is-authorized-oracle (address principal))
    (default-to false (map-get? price-oracles address))
)

(define-read-only (get-stability-parameters)
    {
        minimum-collateral-ratio: (var-get minimum-collateral-ratio),
        liquidation-ratio: (var-get liquidation-ratio),
        stability-fee: (var-get stability-fee),
        price: (var-get last-price),
        price-valid: (var-get price-valid),
        emergency-shutdown: (var-get emergency-shutdown)
    }
)