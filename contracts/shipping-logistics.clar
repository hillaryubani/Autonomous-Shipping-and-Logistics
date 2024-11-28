;; Decentralized Autonomous Shipping and Logistics

;; Constants
(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))

;; Data vars
(define-data-var shipment-counter uint u0)
(define-data-var container-counter uint u0)
(define-data-var vessel-counter uint u0)

;; Maps
(define-map shipments
  { id: uint }
  { sender: principal, receiver: principal, status: (string-ascii 20), customs-cleared: bool, insurance: uint })

(define-map containers
  { id: uint }
  { owner: principal, location: (string-ascii 50), status: (string-ascii 20) })

(define-map vessels
  { id: uint }
  { name: (string-ascii 100), owner: principal, location: (string-ascii 50), status: (string-ascii 20) })

(define-map tracking-data
  { shipment-id: uint, timestamp: uint }
  { location: (string-ascii 50), status: (string-ascii 20) })

(define-map disputes
  { shipment-id: uint }
  { claimant: principal, amount: uint, status: (string-ascii 20) })

(define-map fractional-ownership
  { asset-type: (string-ascii 10), asset-id: uint, owner: principal }
  { shares: uint })

;; Functions
(define-public (create-shipment (receiver principal) (insurance uint))
  (let ((shipment-id (+ (var-get shipment-counter) u1)))
    (map-set shipments
      { id: shipment-id }
      { sender: tx-sender, receiver: receiver, status: "created", customs-cleared: false, insurance: insurance })
    (var-set shipment-counter shipment-id)
    (ok shipment-id)))

(define-public (update-shipment-status (shipment-id uint) (new-status (string-ascii 20)))
  (let ((shipment (unwrap! (map-get? shipments { id: shipment-id }) ERR_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get sender shipment)) (is-eq tx-sender (get receiver shipment))) ERR_UNAUTHORIZED)
    (map-set shipments
      { id: shipment-id }
      (merge shipment { status: new-status }))
    (ok true)))

(define-public (clear-customs (shipment-id uint))
  (let ((shipment (unwrap! (map-get? shipments { id: shipment-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get sender shipment)) ERR_UNAUTHORIZED)
    (map-set shipments
      { id: shipment-id }
      (merge shipment { customs-cleared: true }))
    (ok true)))

(define-public (add-tracking-data (shipment-id uint) (location (string-ascii 50)) (status (string-ascii 20)))
  (let ((timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
    (map-set tracking-data
      { shipment-id: shipment-id, timestamp: timestamp }
      { location: location, status: status })
    (ok true)))

(define-public (file-dispute (shipment-id uint) (amount uint))
  (let ((shipment (unwrap! (map-get? shipments { id: shipment-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get receiver shipment)) ERR_UNAUTHORIZED)
    (map-set disputes
      { shipment-id: shipment-id }
      { claimant: tx-sender, amount: amount, status: "filed" })
    (ok true)))

(define-public (resolve-dispute (shipment-id uint) (approved bool))
  (let ((dispute (unwrap! (map-get? disputes { shipment-id: shipment-id }) ERR_NOT_FOUND))
        (shipment (unwrap! (map-get? shipments { id: shipment-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get sender shipment)) ERR_UNAUTHORIZED)
    (if approved
      (begin
        (try! (stx-transfer? (get amount dispute) tx-sender (get claimant dispute)))
        (map-set disputes
          { shipment-id: shipment-id }
          (merge dispute { status: "approved" }))
        (ok true))
      (begin
        (map-set disputes
          { shipment-id: shipment-id }
          (merge dispute { status: "rejected" }))
        (ok true)))))

(define-public (create-container)
  (let ((container-id (+ (var-get container-counter) u1)))
    (map-set containers
      { id: container-id }
      { owner: tx-sender, location: "warehouse", status: "available" })
    (var-set container-counter container-id)
    (ok container-id)))

(define-public (create-vessel (name (string-ascii 100)))
  (let ((vessel-id (+ (var-get vessel-counter) u1)))
    (map-set vessels
      { id: vessel-id }
      { name: name, owner: tx-sender, location: "port", status: "docked" })
    (var-set vessel-counter vessel-id)
    (ok vessel-id)))

(define-public (buy-fractional-ownership (asset-type (string-ascii 10)) (asset-id uint) (shares uint))
  (let ((current-ownership (default-to { shares: u0 } (map-get? fractional-ownership { asset-type: asset-type, asset-id: asset-id, owner: tx-sender }))))
    (map-set fractional-ownership
      { asset-type: asset-type, asset-id: asset-id, owner: tx-sender }
      { shares: (+ (get shares current-ownership) shares) })
    (ok true)))

;; Read-only functions
(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { id: shipment-id }))

(define-read-only (get-tracking-data (shipment-id uint))
  (map-get? tracking-data { shipment-id: shipment-id, timestamp: (unwrap-panic (get-block-info? time (- block-height u1))) }))

(define-read-only (get-dispute (shipment-id uint))
  (map-get? disputes { shipment-id: shipment-id }))

(define-read-only (get-container (container-id uint))
  (map-get? containers { id: container-id }))

(define-read-only (get-vessel (vessel-id uint))
  (map-get? vessels { id: vessel-id }))

(define-read-only (get-fractional-ownership (asset-type (string-ascii 10)) (asset-id uint) (owner principal))
  (map-get? fractional-ownership { asset-type: asset-type, asset-id: asset-id, owner: owner }))
