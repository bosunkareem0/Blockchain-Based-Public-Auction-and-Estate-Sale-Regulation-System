;; Antique and Collectible Authentication Contract
;; Regulates authentication services for valuable items

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-AUTHENTICATOR-NOT-FOUND (err u502))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u503))
(define-constant ERR-ALREADY-AUTHENTICATED (err u504))
(define-constant ERR-CERTIFICATE-EXPIRED (err u505))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u506))

;; Data Variables
(define-data-var admin principal CONTRACT-OWNER)
(define-data-var next-authenticator-id uint u1)
(define-data-var next-certificate-id uint u1)
(define-data-var authenticator-license-fee uint u2000000) ;; 2 STX in microSTX
(define-data-var authentication-fee uint u500000) ;; 0.5 STX in microSTX

;; Data Maps
(define-map authenticators
  { authenticator-id: uint }
  {
    authenticator: principal,
    name: (string-ascii 200),
    specialization: (string-ascii 200),
    credentials: (string-ascii 500),
    license-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    certifications-issued: uint,
    violations: uint
  }
)

(define-map authenticator-registry
  { authenticator: principal }
  { authenticator-id: uint }
)

(define-map authentication-certificates
  { certificate-id: uint }
  {
    item-owner: principal,
    authenticator: principal,
    item-name: (string-ascii 200),
    item-description: (string-ascii 1000),
    category: (string-ascii 100),
    estimated-value: uint,
    authentication-date: uint,
    certificate-expiry: uint,
    authenticity-status: (string-ascii 50),
    certificate-hash: (string-ascii 64),
    notes: (optional (string-ascii 500))
  }
)

(define-map item-certificates
  { item-hash: (string-ascii 64) }
  { certificate-ids: (list 10 uint) }
)

(define-map owner-certificates
  { owner: principal }
  { certificate-ids: (list 100 uint) }
)

(define-map certificate-disputes
  { certificate-id: uint }
  {
    disputer: principal,
    reason: (string-ascii 500),
    dispute-date: uint,
    resolved: bool,
    resolution: (optional (string-ascii 500)),
    resolver: (optional principal)
  }
)

;; Private Functions
(define-private (is-admin (user principal))
  (is-eq user (var-get admin))
)

(define-private (is-licensed-authenticator (authenticator principal))
  (match (map-get? authenticator-registry { authenticator: authenticator })
    registry-data
    (match (map-get? authenticators { authenticator-id: (get authenticator-id registry-data) })
      auth-data
      (let (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (expiry-date (get expiry-date auth-data))
        (status (get status auth-data))
      )
        (and (is-eq status "active") (> expiry-date current-time))
      )
      false
    )
    false
  )
)

(define-private (calculate-certificate-expiry (auth-date uint))
  (+ auth-date u31536000) ;; Add 1 year in seconds
)

(define-private (add-to-item-list (item-hash (string-ascii 64)) (certificate-id uint))
  (let (
    (current-list (default-to (list) (get certificate-ids (map-get? item-certificates { item-hash: item-hash }))))
  )
    (map-set item-certificates
      { item-hash: item-hash }
      { certificate-ids: (unwrap-panic (as-max-len? (append current-list certificate-id) u10)) }
    )
  )
)

(define-private (add-to-owner-list (owner principal) (certificate-id uint))
  (let (
    (current-list (default-to (list) (get certificate-ids (map-get? owner-certificates { owner: owner }))))
  )
    (map-set owner-certificates
      { owner: owner }
      { certificate-ids: (unwrap-panic (as-max-len? (append current-list certificate-id) u100)) }
    )
  )
)

;; Public Functions

;; Apply for authenticator license
(define-public (apply-for-authenticator-license
  (name (string-ascii 200))
  (specialization (string-ascii 200))
  (credentials (string-ascii 500))
)
  (let (
    (applicant tx-sender)
    (current-auth-id (var-get next-authenticator-id))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (expiry-date (+ current-time u31536000)) ;; 1 year
    (fee (var-get authenticator-license-fee))
  )
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len specialization) u0) ERR-INVALID-INPUT)
    (asserts! (> (len credentials) u0) ERR-INVALID-INPUT)

    ;; Check if already licensed
    (asserts! (is-none (map-get? authenticator-registry { authenticator: applicant })) ERR-INVALID-INPUT)

    ;; Process license fee
    (try! (stx-transfer? fee applicant (as-contract tx-sender)))

    ;; Create authenticator record
    (map-set authenticators
      { authenticator-id: current-auth-id }
      {
        authenticator: applicant,
        name: name,
        specialization: specialization,
        credentials: credentials,
        license-date: current-time,
        expiry-date: expiry-date,
        status: "pending",
        certifications-issued: u0,
        violations: u0
      }
    )

    ;; Add to registry
    (map-set authenticator-registry
      { authenticator: applicant }
      { authenticator-id: current-auth-id }
    )

    ;; Increment authenticator ID
    (var-set next-authenticator-id (+ current-auth-id u1))

    (ok current-auth-id)
  )
)

;; Admin function to approve authenticator
(define-public (approve-authenticator (authenticator-id uint))
  (let (
    (auth-info (unwrap! (map-get? authenticators { authenticator-id: authenticator-id }) ERR-AUTHENTICATOR-NOT-FOUND))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status auth-info) "pending") ERR-INVALID-INPUT)

    (map-set authenticators
      { authenticator-id: authenticator-id }
      (merge auth-info { status: "active" })
    )

    (ok true)
  )
)

;; Issue authentication certificate
(define-public (issue-certificate
  (item-owner principal)
  (item-name (string-ascii 200))
  (item-description (string-ascii 1000))
  (category (string-ascii 100))
  (estimated-value uint)
  (authenticity-status (string-ascii 50))
  (certificate-hash (string-ascii 64))
  (notes (optional (string-ascii 500)))
)
  (let (
    (authenticator tx-sender)
    (current-cert-id (var-get next-certificate-id))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (cert-expiry (calculate-certificate-expiry current-time))
    (fee (var-get authentication-fee))
  )
    ;; Validate authenticator license
    (asserts! (is-licensed-authenticator authenticator) ERR-NOT-AUTHORIZED)

    ;; Validate inputs
    (asserts! (> (len item-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len item-description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len category) u0) ERR-INVALID-INPUT)
    (asserts! (> (len authenticity-status) u0) ERR-INVALID-INPUT)
    (asserts! (> (len certificate-hash) u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-value u0) ERR-INVALID-INPUT)

    ;; Process authentication fee (paid by item owner)
    (try! (stx-transfer? fee item-owner (as-contract tx-sender)))

    ;; Create certificate
    (map-set authentication-certificates
      { certificate-id: current-cert-id }
      {
        item-owner: item-owner,
        authenticator: authenticator,
        item-name: item-name,
        item-description: item-description,
        category: category,
        estimated-value: estimated-value,
        authentication-date: current-time,
        certificate-expiry: cert-expiry,
        authenticity-status: authenticity-status,
        certificate-hash: certificate-hash,
        notes: notes
      }
    )

    ;; Add to tracking lists
    (add-to-item-list certificate-hash current-cert-id)
    (add-to-owner-list item-owner current-cert-id)

    ;; Update authenticator stats
    (let (
      (auth-registry (unwrap! (map-get? authenticator-registry { authenticator: authenticator }) ERR-AUTHENTICATOR-NOT-FOUND))
      (auth-id (get authenticator-id auth-registry))
      (auth-info (unwrap! (map-get? authenticators { authenticator-id: auth-id }) ERR-AUTHENTICATOR-NOT-FOUND))
    )
      (map-set authenticators
        { authenticator-id: auth-id }
        (merge auth-info { certifications-issued: (+ (get certifications-issued auth-info) u1) })
      )
    )

    ;; Increment certificate ID
    (var-set next-certificate-id (+ current-cert-id u1))

    (ok current-cert-id)
  )
)

;; File certificate dispute
(define-public (file-certificate-dispute (certificate-id uint) (reason (string-ascii 500)))
  (let (
    (cert-info (unwrap! (map-get? authentication-certificates { certificate-id: certificate-id }) ERR-CERTIFICATE-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)

    (map-set certificate-disputes
      { certificate-id: certificate-id }
      {
        disputer: tx-sender,
        reason: reason,
        dispute-date: current-time,
        resolved: false,
        resolution: none,
        resolver: none
      }
    )

    (ok true)
  )
)

;; Admin function to resolve dispute
(define-public (resolve-certificate-dispute
  (certificate-id uint)
  (resolution (string-ascii 500))
)
  (let (
    (dispute-info (unwrap! (map-get? certificate-disputes { certificate-id: certificate-id }) ERR-CERTIFICATE-NOT-FOUND))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len resolution) u0) ERR-INVALID-INPUT)

    (map-set certificate-disputes
      { certificate-id: certificate-id }
      (merge dispute-info {
        resolved: true,
        resolution: (some resolution),
        resolver: (some tx-sender)
      })
    )

    (ok true)
  )
)

;; Read-only functions

;; Get authenticator details
(define-read-only (get-authenticator (authenticator-id uint))
  (map-get? authenticators { authenticator-id: authenticator-id })
)

;; Get certificate details
(define-read-only (get-certificate (certificate-id uint))
  (map-get? authentication-certificates { certificate-id: certificate-id })
)

;; Get certificates for item
(define-read-only (get-item-certificates (item-hash (string-ascii 64)))
  (map-get? item-certificates { item-hash: item-hash })
)

;; Get owner's certificates
(define-read-only (get-owner-certificates (owner principal))
  (map-get? owner-certificates { owner: owner })
)

;; Get dispute details
(define-read-only (get-certificate-dispute (certificate-id uint))
  (map-get? certificate-disputes { certificate-id: certificate-id })
)

;; Verify certificate validity
(define-read-only (is-valid-certificate (certificate-id uint))
  (match (map-get? authentication-certificates { certificate-id: certificate-id })
    cert-info
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expiry-date (get certificate-expiry cert-info))
      (authenticator (get authenticator cert-info))
    )
      (and
        (> expiry-date current-time)
        (is-licensed-authenticator authenticator)
      )
    )
    false
  )
)

;; Admin functions

;; Revoke authenticator license
(define-public (revoke-authenticator (authenticator-id uint))
  (let (
    (auth-info (unwrap! (map-get? authenticators { authenticator-id: authenticator-id }) ERR-AUTHENTICATOR-NOT-FOUND))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)

    (map-set authenticators
      { authenticator-id: authenticator-id }
      (merge auth-info { status: "revoked" })
    )

    (ok true)
  )
)

;; Add violation to authenticator
(define-public (add-authenticator-violation (authenticator-id uint))
  (let (
    (auth-info (unwrap! (map-get? authenticators { authenticator-id: authenticator-id }) ERR-AUTHENTICATOR-NOT-FOUND))
    (current-violations (get violations auth-info))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)

    (map-set authenticators
      { authenticator-id: authenticator-id }
      (merge auth-info { violations: (+ current-violations u1) })
    )

    (ok (+ current-violations u1))
  )
)

;; Set authenticator license fee
(define-public (set-authenticator-license-fee (new-fee uint))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set authenticator-license-fee new-fee)
    (ok new-fee)
  )
)

;; Set authentication fee
(define-public (set-authentication-fee (new-fee uint))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set authentication-fee new-fee)
    (ok new-fee)
  )
)

;; Get current fees
(define-read-only (get-authenticator-license-fee)
  (var-get authenticator-license-fee)
)

(define-read-only (get-authentication-fee)
  (var-get authentication-fee)
)

;; Check authenticator status
(define-read-only (get-authenticator-status (authenticator principal))
  (match (map-get? authenticator-registry { authenticator: authenticator })
    registry-data
    (match (map-get? authenticators { authenticator-id: (get authenticator-id registry-data) })
      auth-data
      (let (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (expiry-date (get expiry-date auth-data))
        (status (get status auth-data))
      )
        (ok {
          status: status,
          valid: (and (is-eq status "active") (> expiry-date current-time)),
          expiry-date: expiry-date,
          violations: (get violations auth-data)
        })
      )
      ERR-AUTHENTICATOR-NOT-FOUND
    )
    ERR-AUTHENTICATOR-NOT-FOUND
  )
)
