(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-event-ended (err u105))
(define-constant err-ticket-locked (err u106))
(define-constant err-no-analytics-data (err u107))
(define-constant err-invalid-time-range (err u108))
(define-constant err-analytics-not-enabled (err u109))

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

;; Analytics data structures
(define-map event-analytics
    uint ;; event-id
    {
        total-revenue: uint,
        tickets-purchased: uint,
        tickets-checked-in: uint,
        no-shows: uint,
        refunds-claimed: uint,
        marketplace-sales: uint,
        average-sale-price: uint,
        first-purchase-block: uint,
        last-purchase-block: uint,
        peak-purchase-block: uint,
        scalping-attempts: uint,
    }
)

(define-map event-popularity
    uint ;; event-id
    {
        popularity-score: uint,
        ranking-position: uint,
        trending-factor: uint,
        social-engagement: uint,
    }
)

(define-map time-based-metrics
    { event-id: uint, time-period: (string-ascii 20) }
    {
        period-revenue: uint,
        period-sales: uint,
        period-attendance: uint,
        seasonal-factor: uint,
    }
)

(define-map ticket-utilization
    uint ;; ticket-id
    {
        purchase-block: uint,
        check-in-block: (optional uint),
        transfer-count: uint,
        marketplace-listed: bool,
        final-price: uint,
    }
)

;; Analytics helper functions
(define-private (initialize-event-analytics (event-id uint))
    (map-set event-analytics event-id {
        total-revenue: u0,
        tickets-purchased: u0,
        tickets-checked-in: u0,
        no-shows: u0,
        refunds-claimed: u0,
        marketplace-sales: u0,
        average-sale-price: u0,
        first-purchase-block: u0,
        last-purchase-block: u0,
        peak-purchase-block: u0,
        scalping-attempts: u0,
    })
)

(define-private (update-purchase-analytics (event-id uint) (price uint))
    (let ((analytics (default-to {
        total-revenue: u0,
        tickets-purchased: u0,
        tickets-checked-in: u0,
        no-shows: u0,
        refunds-claimed: u0,
        marketplace-sales: u0,
        average-sale-price: u0,
        first-purchase-block: u0,
        last-purchase-block: u0,
        peak-purchase-block: u0,
        scalping-attempts: u0,
    } (map-get? event-analytics event-id))))
        (map-set event-analytics event-id {
            total-revenue: (+ (get total-revenue analytics) price),
            tickets-purchased: (+ (get tickets-purchased analytics) u1),
            tickets-checked-in: (get tickets-checked-in analytics),
            no-shows: (get no-shows analytics),
            refunds-claimed: (get refunds-claimed analytics),
            marketplace-sales: (get marketplace-sales analytics),
            average-sale-price: (/ (+ (get total-revenue analytics) price) (+ (get tickets-purchased analytics) u1)),
            first-purchase-block: (if (is-eq (get first-purchase-block analytics) u0) burn-block-height (get first-purchase-block analytics)),
            last-purchase-block: burn-block-height,
            peak-purchase-block: burn-block-height,
            scalping-attempts: (get scalping-attempts analytics),
        })
    )
)

(define-private (initialize-ticket-utilization (ticket-id uint) (price uint))
    (map-set ticket-utilization ticket-id {
        purchase-block: burn-block-height,
        check-in-block: none,
        transfer-count: u0,
        marketplace-listed: false,
        final-price: price,
    })
)

(define-public (create-event
        (event-name (string-ascii 50))
        (event-date uint)
        (max-tickets uint)
        (price uint)
    )
    (let ((event-id (+ (var-get last-token-id) u1)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> event-date burn-block-height) err-invalid-price)
        (asserts! (> max-tickets u0) err-invalid-price)
        (asserts! (> price u0) err-invalid-price)
        (map-set events event-id {
            name: event-name,
            date: event-date,
            max-tickets: max-tickets,
            tickets-sold: u0,
        })
        (initialize-event-analytics event-id)
        (var-set ticket-price price)
        (var-set last-token-id event-id)
        (ok event-id)
    )
)

(define-public (purchase-ticket (event-id uint))
    (let (
            (event (unwrap! (map-get? events event-id) err-not-found))
            (new-id (+ (var-get last-token-id) u1))
            (current-price (var-get ticket-price))
        )
        (asserts! (< (get tickets-sold event) (get max-tickets event))
            err-not-found
        )
        (asserts! (> (get date event) burn-block-height) err-event-ended)
        (try! (stx-transfer? current-price tx-sender contract-owner))
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
        ;; Update analytics
        (update-purchase-analytics event-id current-price)
        (initialize-ticket-utilization new-id current-price)
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

;; Analytics read-only functions
(define-read-only (get-event-analytics (event-id uint))
    (let ((analytics (map-get? event-analytics event-id)))
        (match analytics
            some-analytics (ok some-analytics)
            err-no-analytics-data
        )
    )
)

(define-read-only (get-event-popularity-ranking (event-id uint))
    (let ((popularity (map-get? event-popularity event-id)))
        (match popularity
            some-popularity (ok some-popularity)
            (ok {
                popularity-score: u0,
                ranking-position: u0,
                trending-factor: u0,
                social-engagement: u0,
            })
        )
    )
)

(define-read-only (calculate-attendance-rate (event-id uint))
    (let (
            (analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data))
            (purchased (get tickets-purchased analytics))
            (checked-in (get tickets-checked-in analytics))
        )
        (ok {
            attendance-rate: (if (> purchased u0) (/ (* checked-in u100) purchased) u0),
            total-purchased: purchased,
            total-checked-in: checked-in,
            no-shows: (- purchased checked-in),
        })
    )
)

(define-read-only (get-revenue-report (event-id uint))
    (let ((analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data)))
        (ok {
            total-revenue: (get total-revenue analytics),
            average-price: (get average-sale-price analytics),
            tickets-sold: (get tickets-purchased analytics),
            marketplace-revenue: (get marketplace-sales analytics),
        })
    )
)

(define-read-only (get-no-show-statistics (event-id uint))
    (let (
            (analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data))
            (purchased (get tickets-purchased analytics))
            (checked-in (get tickets-checked-in analytics))
            (no-shows (- purchased checked-in))
        )
        (ok {
            no-show-count: no-shows,
            no-show-rate: (if (> purchased u0) (/ (* no-shows u100) purchased) u0),
            total-tickets: purchased,
            attended: checked-in,
        })
    )
)

(define-read-only (get-seasonal-trends (event-id uint) (time-period (string-ascii 20)))
    (let ((metrics (map-get? time-based-metrics { event-id: event-id, time-period: time-period })))
        (match metrics
            some-metrics (ok some-metrics)
            (ok {
                period-revenue: u0,
                period-sales: u0,
                period-attendance: u0,
                seasonal-factor: u100, ;; default factor
            })
        )
    )
)

(define-read-only (get-ticket-utilization-info (ticket-id uint))
    (let ((utilization (map-get? ticket-utilization ticket-id)))
        (match utilization
            some-util (ok some-util)
            err-not-found
        )
    )
)

;; Admin analytics functions
(define-public (export-event-report (event-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let (
                (event-info (unwrap! (map-get? events event-id) err-not-found))
                (analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data))
                (popularity (default-to {
                    popularity-score: u0,
                    ranking-position: u0,
                    trending-factor: u0,
                    social-engagement: u0,
                } (map-get? event-popularity event-id)))
            )
            (ok {
                event-details: event-info,
                analytics: analytics,
                popularity: popularity,
                report-generated-at: burn-block-height,
            })
        )
    )
)

(define-public (get-scalping-prevention-metrics (event-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data)))
            (ok {
                scalping-attempts: (get scalping-attempts analytics),
                prevention-rate: (if (> (get tickets-purchased analytics) u0)
                    (/ (* (- (get tickets-purchased analytics) (get scalping-attempts analytics)) u100) (get tickets-purchased analytics))
                    u100
                ),
                legitimate-purchases: (- (get tickets-purchased analytics) (get scalping-attempts analytics)),
                total-purchases: (get tickets-purchased analytics),
            })
        )
    )
)

(define-public (get-attendee-insights (event-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let (
                (analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data))
                (event-info (unwrap! (map-get? events event-id) err-not-found))
            )
            (ok {
                engagement-score: (if (> (get tickets-purchased analytics) u0)
                    (/ (* (get tickets-checked-in analytics) u100) (get tickets-purchased analytics))
                    u0
                ),
                purchase-pattern: {
                    first-purchase: (get first-purchase-block analytics),
                    last-purchase: (get last-purchase-block analytics),
                    peak-purchase: (get peak-purchase-block analytics),
                },
                conversion-metrics: {
                    purchase-to-attendance: (if (> (get tickets-purchased analytics) u0)
                        (/ (* (get tickets-checked-in analytics) u100) (get tickets-purchased analytics))
                        u0
                    ),
                    capacity-utilization: (if (> (get max-tickets event-info) u0)
                        (/ (* (get tickets-purchased analytics) u100) (get max-tickets event-info))
                        u0
                    ),
                },
            })
        )
    )
)

(define-public (get-pricing-effectiveness (event-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let (
                (analytics (unwrap! (map-get? event-analytics event-id) err-no-analytics-data))
                (event-info (unwrap! (map-get? events event-id) err-not-found))
            )
            (ok {
                revenue-per-ticket: (get average-sale-price analytics),
                total-revenue: (get total-revenue analytics),
                demand-indicator: (if (> (get max-tickets event-info) u0)
                    (/ (* (get tickets-purchased analytics) u100) (get max-tickets event-info))
                    u0
                ),
                pricing-score: (if (and (> (get tickets-purchased analytics) u0) (> (get max-tickets event-info) u0))
                    (/ (* (get tickets-purchased analytics) u100) (get max-tickets event-info))
                    u0
                ),
                marketplace-activity: (get marketplace-sales analytics),
            })
        )
    )
)

(define-public (update-event-popularity (event-id uint) (popularity-score uint) (social-engagement uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set event-popularity event-id {
            popularity-score: popularity-score,
            ranking-position: u0, ;; This would be calculated based on comparison with other events
            trending-factor: (if (> popularity-score u75) u3 (if (> popularity-score u50) u2 u1)),
            social-engagement: social-engagement,
        })
        (ok true)
    )
)

(define-public (record-seasonal-metrics
        (event-id uint)
        (time-period (string-ascii 20))
        (period-revenue uint)
        (period-sales uint)
        (period-attendance uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set time-based-metrics
            { event-id: event-id, time-period: time-period }
            {
                period-revenue: period-revenue,
                period-sales: period-sales,
                period-attendance: period-attendance,
                seasonal-factor: (if (> period-sales u100) u120 (if (> period-sales u50) u100 u80)),
            }
        )
        (ok true)
    )
)
