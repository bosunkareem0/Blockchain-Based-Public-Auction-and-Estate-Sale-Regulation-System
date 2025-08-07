;; Auction Advertising Compliance Contract
;; Ensures accurate advertising and prevents deceptive practices

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-INPUT (err u201))
(define-constant ERR-AD-NOT-FOUND (err u202))
(define-constant ERR-AD-ALREADY-EXISTS (err u203))
(define-constant ERR-NOT-LICENSED-AUCTIONEER (err u204))
(define-constant ERR-AD-REJECTED (err u205))

;; Data Variables
(define-data-var admin principal CONTRACT-OWNER)
(define-data-var next-ad-id uint u1)
(define-data-var review-fee uint u100000) ;; 0.1 STX in microSTX

;; Data Maps
(define-map advertisements
  { ad-id: uint }
  {
    auctioneer: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    auction-date: uint,
    location: (string-ascii 200),
    status: (string-ascii 20),
    submission-date: uint,
    review-date: (optional uint),
    reviewer: (optional principal),
    rejection-reason: (optional (string-ascii 500))
  }
)

(define-map auctioneer-ads
  { auctioneer: principal }
  { ad-ids: (list 50 uint) }
)

(define-map ad-violations
  { ad-id: uint }
  {
    violation-type: (string-ascii 100),
    description: (string-ascii 500),
    penalty-amount: uint,
    reported-date: uint,
    resolved: bool
  }
)

;; Private Functions
(define-private (is-admin (user principal))
  (is-eq user (var-get admin))
)

(define-private (is-valid-date (date uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (> date current-time)
  )
)

(define-private (add-ad-to-auctioneer (auctioneer principal) (ad-id uint))
  (let (
    (current-ads (default-to (list) (get ad-ids (map-get? auctioneer-ads { auctioneer: auctioneer }))))
  )
    (map-set auctioneer-ads
      { auctioneer: auctioneer }
      { ad-ids: (unwrap-panic (as-max-len? (append current-ads ad-id) u50)) }
    )
  )
)

;; Public Functions

;; Submit advertisement for review
(define-public (submit-advertisement
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (auction-date uint)
  (location (string-ascii 200))
)
  (let (
    (advertiser tx-sender)
    (current-ad-id (var-get next-ad-id))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (fee (var-get review-fee))
  )
    ;; Validate inputs
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len location) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-date auction-date) ERR-INVALID-INPUT)

    ;; Process review fee
    (try! (stx-transfer? fee advertiser (as-contract tx-sender)))

    ;; Create advertisement record
    (map-set advertisements
      { ad-id: current-ad-id }
      {
        auctioneer: advertiser,
        title: title,
        description: description,
        auction-date: auction-date,
        location: location,
        status: "pending",
        submission-date: current-time,
        review-date: none,
        reviewer: none,
        rejection-reason: none
      }
    )

    ;; Add to auctioneer's ad list
    (add-ad-to-auctioneer advertiser current-ad-id)

    ;; Increment ad ID
    (var-set next-ad-id (+ current-ad-id u1))

    (ok current-ad-id)
  )
)

;; Admin function to approve advertisement
(define-public (approve-advertisement (ad-id uint))
  (let (
    (ad-info (unwrap! (map-get? advertisements { ad-id: ad-id }) ERR-AD-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status ad-info) "pending") ERR-INVALID-INPUT)

    (map-set advertisements
      { ad-id: ad-id }
      (merge ad-info {
        status: "approved",
        review-date: (some current-time),
        reviewer: (some tx-sender)
      })
    )

    (ok true)
  )
)

;; Admin function to reject advertisement
(define-public (reject-advertisement (ad-id uint) (reason (string-ascii 500)))
  (let (
    (ad-info (unwrap! (map-get? advertisements { ad-id: ad-id }) ERR-AD-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status ad-info) "pending") ERR-INVALID-INPUT)
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)

    (map-set advertisements
      { ad-id: ad-id }
      (merge ad-info {
        status: "rejected",
        review-date: (some current-time),
        reviewer: (some tx-sender),
        rejection-reason: (some reason)
      })
    )

    (ok true)
  )
)

;; Report advertising violation
(define-public (report-violation
  (ad-id uint)
  (violation-type (string-ascii 100))
  (description (string-ascii 500))
  (penalty-amount uint)
)
  (let (
    (ad-info (unwrap! (map-get? advertisements { ad-id: ad-id }) ERR-AD-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len violation-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set ad-violations
      { ad-id: ad-id }
      {
        violation-type: violation-type,
        description: description,
        penalty-amount: penalty-amount,
        reported-date: current-time,
        resolved: false
      }
    )

    ;; Update ad status to violated
    (map-set advertisements
      { ad-id: ad-id }
      (merge ad-info { status: "violated" })
    )

    (ok true)
  )
)

;; Get advertisement details
(define-read-only (get-advertisement (ad-id uint))
  (map-get? advertisements { ad-id: ad-id })
)

;; Get advertisements by auctioneer
(define-read-only (get-auctioneer-ads (auctioneer principal))
  (map-get? auctioneer-ads { auctioneer: auctioneer })
)

;; Get violation details
(define-read-only (get-violation (ad-id uint))
  (map-get? ad-violations { ad-id: ad-id })
)

;; Check if advertisement is approved
(define-read-only (is-approved-ad (ad-id uint))
  (match (map-get? advertisements { ad-id: ad-id })
    ad-info (is-eq (get status ad-info) "approved")
    false
  )
)

;; Admin function to resolve violation
(define-public (resolve-violation (ad-id uint))
  (let (
    (violation-info (unwrap! (map-get? ad-violations { ad-id: ad-id }) ERR-AD-NOT-FOUND))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)

    (map-set ad-violations
      { ad-id: ad-id }
      (merge violation-info { resolved: true })
    )

    (ok true)
  )
)

;; Admin function to set review fee
(define-public (set-review-fee (new-fee uint))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (var-set review-fee new-fee)
    (ok new-fee)
  )
)

;; Get current review fee
(define-read-only (get-review-fee)
  (var-get review-fee)
)

;; Get pending advertisements count
(define-read-only (get-pending-ads-count)
  ;; This would require iterating through all ads in a real implementation
  ;; For now, return a placeholder
  (ok u0)
)
