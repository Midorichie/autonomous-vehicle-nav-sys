;; Vehicle Registry Contract
;; Manages vehicle registration and authentication

(define-data-var admin principal tx-sender)

;; Constants for vehicle statuses
(define-constant STATUS_ACTIVE u"active")
(define-constant STATUS_INACTIVE u"inactive")
(define-constant STATUS_SUSPENDED u"suspended")

;; Define vehicle data structure
(define-map vehicles
    principal
    {
        vehicle-id: (string-utf8 36),
        status: (string-utf8 20),
        last-update: uint,
        route-permissions: (list 10 principal)
    }
)

;; Authorization check
(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

;; Vehicle existence check
(define-private (vehicle-exists (owner principal))
    (is-some (map-get? vehicles owner))
)

;; Initialize contract
(define-public (initialize-contract)
    (begin
        (asserts! (is-admin) (err u100))
        (ok true)
    )
)

;; Register new vehicle
(define-public (register-vehicle (vehicle-id (string-utf8 36)))
    (let
        (
            (vehicle-data {
                vehicle-id: vehicle-id,
                status: STATUS_ACTIVE,
                last-update: block-height,
                route-permissions: (list tx-sender tx-sender tx-sender tx-sender tx-sender 
                                       tx-sender tx-sender tx-sender tx-sender tx-sender)
            })
        )
        (asserts! (not (vehicle-exists tx-sender)) (err u101))
        (ok (map-set vehicles tx-sender vehicle-data))
    )
)

;; Get vehicle details
(define-read-only (get-vehicle-details (owner principal))
    (match (map-get? vehicles owner)
        vehicle (ok vehicle)
        (err u102)
    )
)

;; Validate status
(define-private (is-valid-status (status (string-utf8 20)))
    (or
        (is-eq status STATUS_ACTIVE)
        (is-eq status STATUS_INACTIVE)
        (is-eq status STATUS_SUSPENDED)
    )
)

;; Update vehicle status
(define-public (update-status (new-status (string-utf8 20)))
    (let
        (
            (vehicle (unwrap! (map-get? vehicles tx-sender) (err u102)))
        )
        (asserts! (is-valid-status new-status) (err u104))
        (ok (map-set vehicles 
            tx-sender
            (merge vehicle { 
                status: new-status,
                last-update: block-height
            })
        ))
    )
)

;; Clear route permissions
(define-public (clear-route-permissions (vehicle-owner principal))
    (begin
        ;; Check authorization
        (asserts! (is-admin) (err u100))
        ;; Check vehicle exists
        (asserts! (vehicle-exists vehicle-owner) (err u102))
        ;; Get existing vehicle data
        (match (map-get? vehicles vehicle-owner)
            vehicle (ok (map-set vehicles 
                vehicle-owner
                (merge vehicle {
                    route-permissions: (list tx-sender tx-sender tx-sender tx-sender tx-sender 
                                           tx-sender tx-sender tx-sender tx-sender tx-sender),
                    last-update: block-height
                })
            ))
            (err u102)
        )
    )
)

;; Error codes:
;; u100 - Not authorized
;; u101 - Vehicle already registered
;; u102 - Vehicle not found
;; u103 - Route permissions list full
;; u104 - Invalid status value
