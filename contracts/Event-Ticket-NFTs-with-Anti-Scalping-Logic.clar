(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-event-ended (err u105))
(define-constant err-ticket-locked (err u106))

(define-data-var last-token-id uint u0)
(define-data-var ticket-price uint u0)

(define-map tickets
    uint
    {
        owner: principal,
        locked: bool,
        event-date: uint,
        transfer-allowed: bool,
    }
)

(define-map events
    uint
    {
        name: (string-ascii 50),
        date: uint,
        max-tickets: uint,
        tickets-sold: uint,
    }
)

(define-non-fungible-token event-ticket uint)

(define-public (create-event
        (event-name (string-ascii 50))
        (event-date uint)
        (max-tickets uint)
        (price uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> event-date burn-block-height) err-invalid-price)
        (asserts! (> max-tickets u0) err-invalid-price)
        (asserts! (> price u0) err-invalid-price)
        (map-set events (var-get last-token-id) {
            name: event-name,
            date: event-date,
            max-tickets: max-tickets,
            tickets-sold: u0,
        })
        (var-set ticket-price price)
        (ok true)
    )
)

(define-public (purchase-ticket (event-id uint))
    (let (
            (event (unwrap! (map-get? events event-id) err-not-found))
            (new-id (+ (var-get last-token-id) u1))
        )
        (asserts! (< (get tickets-sold event) (get max-tickets event))
            err-not-found
        )
        (asserts! (> (get date event) burn-block-height) err-event-ended)
        (try! (stx-transfer? (var-get ticket-price) tx-sender contract-owner))
        (try! (nft-mint? event-ticket new-id tx-sender))
        (map-set tickets new-id {
            owner: tx-sender,
            locked: true,
            event-date: (get date event),
            transfer-allowed: false,
        })
        (map-set events event-id
            (merge event { tickets-sold: (+ (get tickets-sold event) u1) })
        )
        (var-set last-token-id new-id)
        (ok new-id)
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (let ((ticket (unwrap! (map-get? tickets token-id) err-not-found)))
        (asserts! (is-eq tx-sender sender) err-not-authorized)
        (asserts! (is-eq (get owner ticket) sender) err-not-authorized)
        (asserts! (get transfer-allowed ticket) err-ticket-locked)
        (asserts! (> (get event-date ticket) burn-block-height) err-event-ended)
        (try! (nft-transfer? event-ticket token-id sender recipient))
        (map-set tickets token-id (merge ticket { owner: recipient }))
        (ok true)
    )
)

(define-public (unlock-ticket (token-id uint))
    (let ((ticket (unwrap! (map-get? tickets token-id) err-not-found)))
        (asserts! (is-eq (get owner ticket) tx-sender) err-not-authorized)
        (asserts! (> (get event-date ticket) burn-block-height) err-event-ended)
        (map-set tickets token-id (merge ticket { transfer-allowed: true }))
        (ok true)
    )
)

(define-read-only (get-ticket-info (token-id uint))
    (map-get? tickets token-id)
)

(define-read-only (get-event-info (event-id uint))
    (map-get? events event-id)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? event-ticket token-id))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)
