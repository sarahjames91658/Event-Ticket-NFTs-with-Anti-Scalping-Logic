(define-data-var contract-owner principal tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-event-ended (err u105))
(define-constant err-ticket-locked (err u106))
(define-constant err-invalid-quantity (err u107))
(define-constant err-already-used (err u108))
(define-constant err-event-not-started (err u109))
(define-constant err-not-listed (err u110))
(define-constant err-price-cap-exceeded (err u111))
(define-constant err-self-purchase (err u112))

(define-data-var last-token-id uint u0)
(define-data-var ticket-price uint u0)

(define-map tickets
    uint
    {
        owner: principal,
        locked: bool,
        event-date: uint,
        transfer-allowed: bool,
        used: bool,
        check-in-time: (optional uint),
    }
)

(define-map events
    uint
    {
        name: (string-ascii 50),
        date: uint,
        max-tickets: uint,
        tickets-sold: uint,
        check-in-start: uint,
        attendees-count: uint,
    }
)

(define-map event-staff
    {
        event-id: uint,
        staff: principal,
    }
    bool
)

(define-map marketplace-listings
    uint
    {
        seller: principal,
        price: uint,
        listed-block: uint,
    }
)

(define-non-fungible-token event-ticket uint)

(define-private (mint-ticket-internal
        (event-id uint)
        (recipient principal)
    )
    (let (
            (event (unwrap! (map-get? events event-id) err-not-found))
            (new-id (+ (var-get last-token-id) u1))
        )
        (asserts! (< (get tickets-sold event) (get max-tickets event))
            err-not-found
        )
        (try! (nft-mint? event-ticket new-id recipient))
        (map-set tickets new-id {
            owner: recipient,
            locked: true,
            event-date: (get date event),
            transfer-allowed: false,
            used: false,
            check-in-time: none,
        })
        (map-set events event-id
            (merge event { tickets-sold: (+ (get tickets-sold event) u1) })
        )
        (var-set last-token-id new-id)
        (ok new-id)
    )
)

(define-public (create-event-with-checkin
        (event-name (string-ascii 50))
        (event-date uint)
        (max-tickets uint)
        (price uint)
        (check-in-start uint)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (asserts! (> event-date burn-block-height) err-invalid-price)
        (asserts! (> max-tickets u0) err-invalid-price)
        (asserts! (> price u0) err-invalid-price)
        (asserts! (< check-in-start event-date) err-invalid-price)
        (let ((event-id (+ (var-get last-token-id) u1)))
            (map-set events event-id {
                name: event-name,
                date: event-date,
                max-tickets: max-tickets,
                tickets-sold: u0,
                check-in-start: check-in-start,
                attendees-count: u0,
            })
            (var-set ticket-price price)
            (var-set last-token-id event-id)
            (ok event-id)
        )
    )
)

(define-public (create-event
        (event-name (string-ascii 50))
        (event-date uint)
        (max-tickets uint)
        (price uint)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (asserts! (> event-date burn-block-height) err-invalid-price)
        (asserts! (> max-tickets u0) err-invalid-price)
        (asserts! (> price u0) err-invalid-price)
        (let ((event-id (+ (var-get last-token-id) u1)))
            (map-set events event-id {
                name: event-name,
                date: event-date,
                max-tickets: max-tickets,
                tickets-sold: u0,
                check-in-start: (- event-date u144),
                attendees-count: u0,
            })
            (var-set ticket-price price)
            (var-set last-token-id event-id)
            (ok event-id)
        )
    )
)

(define-public (batch-purchase-tickets
        (event-id uint)
        (quantity uint)
    )
    (let (
            (event (unwrap! (map-get? events event-id) err-not-found))
            (total-cost (* (var-get ticket-price) quantity))
        )
        (asserts! (> quantity u0) err-invalid-quantity)
        (asserts! (<= quantity u10) err-invalid-quantity)
        (asserts!
            (<= (+ (get tickets-sold event) quantity) (get max-tickets event))
            err-not-found
        )
        (asserts! (> (get date event) burn-block-height) err-event-ended)
        (try! (stx-transfer? total-cost tx-sender (var-get contract-owner)))
        (fold batch-mint-helper (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) {
            event-id: event-id,
            recipient: tx-sender,
            remaining: quantity,
            results: (list),
        })
        (ok quantity)
    )
)

(define-private (batch-mint-helper
        (index uint)
        (data {
            event-id: uint,
            recipient: principal,
            remaining: uint,
            results: (list 10 uint),
        })
    )
    (if (> (get remaining data) u0)
        (match (mint-ticket-internal (get event-id data) (get recipient data))
            success (merge data {
                remaining: (- (get remaining data) u1),
                results: (unwrap-panic (as-max-len? (append (get results data) success) u10)),
            })
            error
            data
        )
        data
    )
)

(define-public (owner-batch-mint
        (event-id uint)
        (recipients (list 5 principal))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (let ((event (unwrap! (map-get? events event-id) err-not-found)))
            (asserts! (> (get date event) burn-block-height) err-event-ended)
            (asserts!
                (<= (+ (get tickets-sold event) (len recipients))
                    (get max-tickets event)
                )
                err-not-found
            )
            (fold owner-mint-helper recipients {
                event-id: event-id,
                results: (list),
            })
            (ok (len recipients))
        )
    )
)

(define-private (owner-mint-helper
        (recipient principal)
        (data {
            event-id: uint,
            results: (list 5 uint),
        })
    )
    (match (mint-ticket-internal (get event-id data) recipient)
        success (merge data { results: (unwrap-panic (as-max-len? (append (get results data) success) u5)) })
        error
        data
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
        (try! (stx-transfer? (var-get ticket-price) tx-sender (var-get contract-owner)))
        (try! (nft-mint? event-ticket new-id tx-sender))
        (map-set tickets new-id {
            owner: tx-sender,
            locked: true,
            event-date: (get date event),
            transfer-allowed: false,
            used: false,
            check-in-time: none,
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

(define-public (add-event-staff
        (event-id uint)
        (staff-member principal)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-set event-staff {
            event-id: event-id,
            staff: staff-member,
        }
            true
        )
        (ok true)
    )
)

(define-public (remove-event-staff
        (event-id uint)
        (staff-member principal)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-delete event-staff {
            event-id: event-id,
            staff: staff-member,
        })
        (ok true)
    )
)

(define-public (check-in-ticket
        (token-id uint)
        (event-id uint)
    )
    (let (
            (ticket (unwrap! (map-get? tickets token-id) err-not-found))
            (event (unwrap! (map-get? events event-id) err-not-found))
            (is-staff (default-to false
                (map-get? event-staff {
                    event-id: event-id,
                    staff: tx-sender,
                })
            ))
            (is-owner (is-eq tx-sender (var-get contract-owner)))
        )
        (asserts! (or is-staff is-owner) err-not-authorized)
        (asserts! (not (get used ticket)) err-already-used)
        (asserts! (>= burn-block-height (get check-in-start event))
            err-event-not-started
        )
        (asserts! (<= burn-block-height (get date event)) err-event-ended)
        (map-set tickets token-id
            (merge ticket {
                used: true,
                check-in-time: (some burn-block-height),
            })
        )
        (map-set events event-id
            (merge event { attendees-count: (+ (get attendees-count event) u1) })
        )
        (ok true)
    )
)

(define-public (verify-ticket (token-id uint))
    (let ((ticket (unwrap! (map-get? tickets token-id) err-not-found)))
        (ok {
            valid: (and
                (not (get used ticket))
                (> (get event-date ticket) burn-block-height)
            ),
            owner: (get owner ticket),
            used: (get used ticket),
            event-date: (get event-date ticket),
            check-in-time: (get check-in-time ticket),
        })
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

(define-public (list-ticket-for-sale
        (token-id uint)
        (asking-price uint)
    )
    (let (
            (ticket (unwrap! (map-get? tickets token-id) err-not-found))
            (original-price (var-get ticket-price))
            (max-allowed-price (* original-price u2))
        )
        (asserts! (is-eq (get owner ticket) tx-sender) err-not-authorized)
        (asserts! (not (get used ticket)) err-already-used)
        (asserts! (> (get event-date ticket) burn-block-height) err-event-ended)
        (asserts! (get transfer-allowed ticket) err-ticket-locked)
        (asserts! (<= asking-price max-allowed-price) err-price-cap-exceeded)
        (asserts! (is-none (map-get? marketplace-listings token-id))
            err-already-listed
        )
        (map-set marketplace-listings token-id {
            seller: tx-sender,
            price: asking-price,
            listed-block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (remove-listing (token-id uint))
    (let ((listing (unwrap! (map-get? marketplace-listings token-id) err-not-listed)))
        (asserts! (is-eq (get seller listing) tx-sender) err-not-authorized)
        (map-delete marketplace-listings token-id)
        (ok true)
    )
)

(define-public (purchase-listed-ticket (token-id uint))
    (let (
            (listing (unwrap! (map-get? marketplace-listings token-id) err-not-listed))
            (ticket (unwrap! (map-get? tickets token-id) err-not-found))
            (seller (get seller listing))
            (sale-price (get price listing))
            (owner-fee (/ (* sale-price u5) u100))
            (seller-payment (- sale-price owner-fee))
        )
        (asserts! (not (is-eq tx-sender seller)) err-self-purchase)
        (asserts! (is-eq (get owner ticket) seller) err-not-authorized)
        (asserts! (not (get used ticket)) err-already-used)
        (asserts! (> (get event-date ticket) burn-block-height) err-event-ended)
        (try! (stx-transfer? seller-payment tx-sender seller))
        (try! (stx-transfer? owner-fee tx-sender (var-get contract-owner)))
        (try! (nft-transfer? event-ticket token-id seller tx-sender))
        (map-set tickets token-id (merge ticket { owner: tx-sender }))
        (map-delete marketplace-listings token-id)
        (ok true)
    )
)

(define-read-only (get-listing (token-id uint))
    (map-get? marketplace-listings token-id)
)
