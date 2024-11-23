;; Grant Manager Contract

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_GRANT_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_FUNDED (err u103))

;; Data variables
(define-data-var admin principal tx-sender)
(define-map grants 
    { grant-id: uint }
    {
        recipient: principal,
        amount: uint,
        description: (string-utf8 256),
        funded: bool,
        completed: bool
    }
)

(define-data-var grant-nonce uint u0)

;; Read only functions
(define-read-only (get-grant (grant-id uint))
    (ok (map-get? grants { grant-id: grant-id }))
)

(define-read-only (is-admin)
    (ok (is-eq tx-sender (var-get admin)))
)

;; Public functions
(define-public (create-grant (recipient principal) (amount uint) (description (string-utf8 256)))
    (let
        (
            (grant-id (var-get grant-nonce))
        )
        (if (is-eq tx-sender (var-get admin))
            (begin
                (map-set grants
                    { grant-id: grant-id }
                    {
                        recipient: recipient,
                        amount: amount,
                        description: description,
                        funded: false,
                        completed: false
                    }
                )
                (var-set grant-nonce (+ grant-id u1))
                (ok grant-id)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

(define-public (fund-grant (grant-id uint))
    (let
        (
            (grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
        )
        (if (is-eq tx-sender (var-get admin))
            (if (get funded grant)
                ERR_ALREADY_FUNDED
                (begin
                    (try! (stx-transfer? (get amount grant) tx-sender (get recipient grant)))
                    (map-set grants
                        { grant-id: grant-id }
                        (merge grant { funded: true })
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
            (begin
                (map-set grants
                    { grant-id: grant-id }
                    (merge grant { completed: true })
                )
                (ok true)
            )
            ERR_NOT_AUTHORIZED
        )
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
