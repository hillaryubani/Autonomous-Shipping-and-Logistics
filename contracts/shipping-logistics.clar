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

