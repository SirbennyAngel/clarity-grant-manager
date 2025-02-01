;; Grant Manager Contract

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_GRANT_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_FUNDED (err u103))
(define-constant ERR_INVALID_MILESTONE (err u104))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u105))
(define-constant ERR_MILESTONE_ALREADY_FUNDED (err u106))

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

(define-private (create-milestones (grant-id uint) (amounts (list 10 uint)) (descriptions (list 10 (string-utf8 256))))
    (let
        ((milestone-id uint))
        (map create-milestone-entry 
            (map unwrap-panic 
                (map to-uint 
                    (range-step u0 (len amounts) u1)))
            amounts 
            descriptions)
    )
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

(define-public (complete-milestone (grant-id uint) (milestone-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
            (milestone (unwrap! (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
        )
        (if (is-eq tx-sender (var-get admin))
            (begin
                (map-set milestones
                    { grant-id: grant-id, milestone-id: milestone-id }
                    (merge milestone { completed: true })
                )
                (ok true)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

(define-public (fund-milestone (grant-id uint) (milestone-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
            (milestone (unwrap! (map-get? milestones { grant-id: grant-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
        )
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

(define-public (complete-grant (grant-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
        )
        (if (is-eq tx-sender (var-get admin))
            (if (check-all-milestones-complete grant-id (get milestone-count grant))
                (begin
                    (map-set grants
                        { grant-id: grant-id }
                        (merge grant { completed: true })
                    )
                    (ok true)
                )
                ERR_MILESTONE_NOT_COMPLETED
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

(define-private (check-all-milestones-complete (grant-id uint) (milestone-count uint))
    (fold check-milestone-complete-reducer 
        (map unwrap-panic 
            (map to-uint 
                (range-step u0 milestone-count u1)))
        true)
)

(define-private (check-milestone-complete-reducer (milestone-id uint) (prev-result bool))
    (let
        ((milestone (unwrap! (map-get? milestones { grant-id: (var-get grant-nonce), milestone-id: milestone-id }) false)))
        (and prev-result (get completed milestone))
    )
)

(define-public (transfer-admin (new-admin principal))
    (if (is-eq tx-sender (var-get admin))
        (begin
            (var-set admin new-admin)
            (ok true)
        )
        ERR_NOT_AUTHORIZED
    )
)
