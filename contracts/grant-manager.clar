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
(define-constant ERR_EMPTY_MILESTONE_LIST (err u109))
(define-constant ERR_ZERO_MILESTONE_AMOUNT (err u110))
(define-constant ERR_INVALID_MILESTONE_SEQUENCE (err u111))

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
        milestone-count: uint,
        current-milestone: uint
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

;; Enhanced milestone amount validation
(define-private (validate-milestone-amounts (amounts (list 10 uint)) (total-amount uint))
    (let
        ((list-length (len amounts)))
        (if (is-eq list-length u0)
            false
            (and
                (is-eq (fold + amounts u0) total-amount)
                (fold and (map check-non-zero amounts) true)
            )
        )
    )
)

;; Helper function to check for non-zero amounts
(define-private (check-non-zero (amount uint))
    (> amount u0)
)

;; Modified fund-milestone function with sequence validation
(define-public (fund-milestone (grant-id uint) (milestone-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
            (milestone (unwrap! (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
        )
        (if (get completed grant)
            ERR_GRANT_ALREADY_COMPLETED
            (if (not (is-eq milestone-id (get current-milestone grant)))
                ERR_INVALID_MILESTONE_SEQUENCE
                (if (and (is-eq tx-sender (var-get admin)) (get completed milestone))
                    (if (get funded milestone)
                        ERR_MILESTONE_ALREADY_FUNDED
                        (begin
                            (try! (stx-transfer? (get amount milestone) tx-sender (get recipient grant)))
                            (map-set milestones
                                { grant-id: grant-id, milestone-id: milestone-id }
                                (merge milestone { funded: true })
                            )
                            (map-set grants
                                { grant-id: grant-id }
                                (merge grant { current-milestone: (+ milestone-id u1) })
                            )
                            (ok true)
                        )
                    )
                    ERR_NOT_AUTHORIZED
                )
            )
        )
    )
)

[... rest of the contract remains unchanged ...]
