;; Grant Manager Contract

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_GRANT_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_FUNDED (err u103))
(define-constant ERR_INVALID_MILESTONE (err u104))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u105))
(define-constant ERR_MILESTONE_ALREADY_FUNDED (err u106))
(define-constant ERR_INVALID_MILESTONE_AMOUNTS (err u107))
(define-constant ERR_GRANT_ALREADY_COMPLETED (err u108))

;; Data variables
(define-data-var admin principal tx-sender)

(define-map grants 
    { grant-id: uint }
    {
        recipient: principal,
        total-amount: uint,
        description: (string-utf8 256),
        funded: bool,
        completed: bool,
        milestone-count: uint
    }
)

(define-map milestones
    { grant-id: uint, milestone-id: uint }
    {
        amount: uint,
        description: (string-utf8 256),
        completed: bool,
        funded: bool
    }
)

(define-data-var grant-nonce uint u0)

;; Read only functions
(define-read-only (get-grant (grant-id uint))
    (ok (map-get? grants { grant-id: grant-id }))
)

(define-read-only (get-milestone (grant-id uint) (milestone-id uint))
    (ok (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }))
)

(define-read-only (is-admin)
    (ok (is-eq tx-sender (var-get admin)))
)

;; Private function to validate milestone amounts
(define-private (validate-milestone-amounts (amounts (list 10 uint)) (total-amount uint))
    (is-eq (fold + amounts u0) total-amount)
)

;; Public functions
(define-public (create-grant-with-milestones 
    (recipient principal) 
    (total-amount uint) 
    (description (string-utf8 256))
    (milestone-amounts (list 10 uint))
    (milestone-descriptions (list 10 (string-utf8 256)))
)
    (let
        (
            (grant-id (var-get grant-nonce))
            (milestone-count (len milestone-amounts))
        )
        (if (not (validate-milestone-amounts milestone-amounts total-amount))
            ERR_INVALID_MILESTONE_AMOUNTS
            (if (is-eq tx-sender (var-get admin))
                (begin
                    (map-set grants
                        { grant-id: grant-id }
                        {
                            recipient: recipient,
                            total-amount: total-amount,
                            description: description,
                            funded: false,
                            completed: false,
                            milestone-count: milestone-count
                        }
                    )
                    (create-milestones grant-id milestone-amounts milestone-descriptions)
                    (var-set grant-nonce (+ grant-id u1))
                    (ok grant-id)
                )
                ERR_NOT_AUTHORIZED
            )
        )
    )
)

(define-private (create-milestones (grant-id uint) (amounts (list 10 uint)) (descriptions (list 10 (string-utf8 256))))
    (map create-milestone-entry 
        (map unwrap-panic 
            (map to-uint 
                (range-step u0 (len amounts) u1)))
        amounts 
        descriptions)
)

(define-private (create-milestone-entry (milestone-id uint) (amount uint) (description (string-utf8 256)))
    (map-set milestones
        { grant-id: (var-get grant-nonce), milestone-id: milestone-id }
        {
            amount: amount,
            description: description,
            completed: false,
            funded: false
        }
    )
)

(define-public (fund-milestone (grant-id uint) (milestone-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
            (milestone (unwrap! (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
        )
        (if (get completed grant)
            ERR_GRANT_ALREADY_COMPLETED
            (if (and (is-eq tx-sender (var-get admin)) (get completed milestone))
                (if (get funded milestone)
                    ERR_MILESTONE_ALREADY_FUNDED
                    (begin
                        (try! (stx-transfer? (get amount milestone) tx-sender (get recipient grant)))
                        (map-set milestones
                            { grant-id: grant-id, milestone-id: milestone-id }
                            (merge milestone { funded: true })
                        )
                        (ok true)
                    )
                )
                ERR_NOT_AUTHORIZED
            )
        )
    )
)

[... rest of the contract remains unchanged ...]
