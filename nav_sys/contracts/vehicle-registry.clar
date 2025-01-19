;; Vehicle Registry Contract v2
;; Enhanced security and functionality for autonomous vehicle management

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-PERMISSIONS-FULL (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INVALID-OPERATION (err u105))
(define-constant ERR-PERMISSION-DENIED (err u106))
(define-constant ERR-ALREADY-DEACTIVATED (err u107))

(define-constant STATUS_ACTIVE u"active")
(define-constant STATUS_INACTIVE u"inactive")
(define-constant STATUS_SUSPENDED u"suspended")
(define-constant STATUS_EMERGENCY u"emergency")

;; Data Variables
(define-data-var admin principal tx-sender)
(define-data-var emergency-mode bool false)

;; Data Maps
(define-map vehicles
    principal
    {
        vehicle-id: (string-utf8 36),
        status: (string-utf8 20),
        last-update: uint,
        route-permissions: (list 10 principal),
        security-score: uint
    }
)

(define-map vehicle-operators
    principal
    {
        is-active: bool,
        clearance-level: uint,
        last-access: uint
    }
)

;; Authorization checks
(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

(define-private (is-authorized-operator (operator principal))
    (match (map-get? vehicle-operators operator)
        operator-data (and 
            (get is-active operator-data)
            (>= (get clearance-level operator-data) u2)
        )
        false
    )
)

;; Validation helpers
(define-private (vehicle-exists (owner principal))
    (is-some (map-get? vehicles owner))
)

(define-private (is-valid-status (status (string-utf8 20)))
    (or
        (is-eq status STATUS_ACTIVE)
        (is-eq status STATUS_INACTIVE)
        (is-eq status STATUS_SUSPENDED)
        (is-eq status STATUS_EMERGENCY)
    )
)

(define-private (is-valid-operator (operator principal))
    (and
        (not (is-eq operator tx-sender))  
        (not (is-eq operator (var-get admin)))  
        (not (vehicle-exists operator))  
        (is-none (map-get? vehicle-operators operator))  
    )
)

;; Vehicle management
(define-public (register-vehicle (vehicle-id (string-utf8 36)))
    (let
        (
            (vehicle-data {
                vehicle-id: vehicle-id,
                status: STATUS_ACTIVE,
                last-update: block-height,
                route-permissions: (list tx-sender tx-sender tx-sender tx-sender tx-sender 
                                       tx-sender tx-sender tx-sender tx-sender tx-sender),
                security-score: u100
            })
        )
        (asserts! (or (is-admin) (is-authorized-operator tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (not (vehicle-exists tx-sender)) ERR-ALREADY-REGISTERED)
        (print { event-type: u"register", data: vehicle-id, timestamp: block-height })
        (ok (map-set vehicles tx-sender vehicle-data))
    )
)

;; Update vehicle status
(define-public (update-status (new-status (string-utf8 20)))
    (let
        (
            (vehicle (unwrap! (map-get? vehicles tx-sender) ERR-NOT-FOUND))
        )
        (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
        (asserts! (or (is-admin) (is-authorized-operator tx-sender)) ERR-NOT-AUTHORIZED)
        (print { 
            event-type: u"status-update", 
            vehicle: tx-sender,
            old-status: (get status vehicle),
            new-status: new-status,
            timestamp: block-height 
        })
        (ok (map-set vehicles 
            tx-sender
            (merge vehicle { 
                status: new-status,
                last-update: block-height
            })
        ))
    )
)

;; Emergency protocols
(define-public (trigger-emergency-mode)
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (var-set emergency-mode true)
        (print { event-type: u"emergency", data: u"Emergency mode activated", timestamp: block-height })
        (ok true)
    )
)

(define-public (clear-emergency-mode)
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (var-set emergency-mode false)
        (print { event-type: u"emergency", data: u"Emergency mode cleared", timestamp: block-height })
        (ok true)
    )
)

;; Operator management
(define-public (register-operator (operator principal) (clearance-level uint))
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (asserts! (<= clearance-level u5) ERR-INVALID-OPERATION)
        (asserts! (is-valid-operator operator) ERR-INVALID-OPERATION)
        (print { 
            event-type: u"operator", 
            data: u"New operator registered",
            operator: operator,
            clearance: clearance-level,
            timestamp: block-height 
        })
        (ok (map-set vehicle-operators operator {
            is-active: true,
            clearance-level: clearance-level,
            last-access: block-height
        }))
    )
)

;; Operator status management with improved security
(define-public (deactivate-operator (operator principal))
    (begin
        ;; First verify admin authorization
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        
        ;; Additional safety checks
        (asserts! (not (is-eq operator (var-get admin))) ERR-INVALID-OPERATION)
        
        ;; Verify operator exists and get their data
        (let 
            (
                (operator-data (unwrap! (map-get? vehicle-operators operator) ERR-NOT-FOUND))
            )
            ;; Check if operator is already deactivated
            (asserts! (get is-active operator-data) ERR-ALREADY-DEACTIVATED)
            
            ;; Log the deactivation event
            (print {
                event-type: u"operator",
                data: u"Operator deactivated",
                operator: operator,
                timestamp: block-height
            })
            
            ;; Update the operator's status with validated data
            (ok (map-set vehicle-operators 
                operator
                (merge operator-data {
                    is-active: false,
                    last-access: block-height
                })
            ))
        )
    )
)

;; Read-only functions
(define-read-only (get-vehicle-details (owner principal))
    (match (map-get? vehicles owner)
        vehicle (ok vehicle)
        ERR-NOT-FOUND
    )
)

(define-read-only (get-operator-details (operator principal))
    (match (map-get? vehicle-operators operator)
        operator-data (ok operator-data)
        ERR-NOT-FOUND
    )
)

(define-read-only (is-emergency-active)
    (ok (var-get emergency-mode))
)

;; Contract initialization
(define-public (initialize-contract)
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (ok true)
    )
)
