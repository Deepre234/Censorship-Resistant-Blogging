(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))

(define-data-var next-post-id uint u1)
(define-data-var next-user-id uint u1)
(define-data-var contract-balance uint u0)

(define-map users
  { user-id: uint }
  {
    address: principal,
    username: (string-ascii 50),
    bio: (string-utf8 500),
    post-count: uint,
    total-tips-received: uint,
    joined-at: uint
  }
)

(define-map user-addresses
  { address: principal }
  { user-id: uint }
)

(define-map posts
  { post-id: uint }
  {
    author-id: uint,
    title: (string-utf8 100),
    content: (string-utf8 2000),
    created-at: uint,
    tips-received: uint,
    likes: uint,
    dislikes: uint,
    is-active: bool
  }
)

(define-map post-tips
  { post-id: uint, tipper: principal }
  { amount: uint, tipped-at: uint }
)

(define-map post-reactions
  { post-id: uint, reactor: principal }
  { reaction: (string-ascii 10) }
)

(define-map user-followers
  { follower: uint, following: uint }
  { followed-at: uint }
)

(define-public (register-user (username (string-ascii 50)) (bio (string-utf8 500)))
  (let (
    (user-id (var-get next-user-id))
    (existing-user (map-get? user-addresses { address: tx-sender }))
  )
    (asserts! (is-none existing-user) ERR-ALREADY-EXISTS)
    (map-set users
      { user-id: user-id }
      {
        address: tx-sender,
        username: username,
        bio: bio,
        post-count: u0,
        total-tips-received: u0,
        joined-at: stacks-block-height
      }
    )
    (map-set user-addresses { address: tx-sender } { user-id: user-id })
    (var-set next-user-id (+ user-id u1))
    (ok user-id)
  )
)

(define-public (create-post (title (string-utf8 100)) (content (string-utf8 2000)))
  (let (
    (post-id (var-get next-post-id))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (user-id (get user-id user-data))
    (user-info (unwrap! (map-get? users { user-id: user-id }) ERR-NOT-FOUND))
  )
    (map-set posts
      { post-id: post-id }
      {
        author-id: user-id,
        title: title,
        content: content,
        created-at: stacks-block-height,
        tips-received: u0,
        likes: u0,
        dislikes: u0,
        is-active: true
      }
    )
    (map-set users
      { user-id: user-id }
      (merge user-info { post-count: (+ (get post-count user-info) u1) })
    )
    (var-set next-post-id (+ post-id u1))
    (ok post-id)
  )
)

(define-public (tip-post (post-id uint))
  (let (
    (tip-amount (stx-get-balance tx-sender))
    (post-data (unwrap! (map-get? posts { post-id: post-id }) ERR-NOT-FOUND))
    (author-id (get author-id post-data))
    (author-data (unwrap! (map-get? users { user-id: author-id }) ERR-NOT-FOUND))
    (author-address (get address author-data))
  )
    (asserts! (> tip-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get is-active post-data) ERR-NOT-FOUND)
    (try! (stx-transfer? tip-amount tx-sender author-address))
    (map-set post-tips
      { post-id: post-id, tipper: tx-sender }
      { amount: tip-amount, tipped-at: stacks-block-height }
    )
    (map-set posts
      { post-id: post-id }
      (merge post-data { tips-received: (+ (get tips-received post-data) tip-amount) })
    )
    (map-set users
      { user-id: author-id }
      (merge author-data { total-tips-received: (+ (get total-tips-received author-data) tip-amount) })
    )
    (ok true)
  )
)

(define-public (react-to-post (post-id uint) (reaction (string-ascii 10)))
  (let (
    (post-data (unwrap! (map-get? posts { post-id: post-id }) ERR-NOT-FOUND))
    (existing-reaction (map-get? post-reactions { post-id: post-id, reactor: tx-sender }))
  )
    (asserts! (get is-active post-data) ERR-NOT-FOUND)
    (asserts! (or (is-eq reaction "like") (is-eq reaction "dislike")) ERR-INVALID-AMOUNT)
    (match existing-reaction
      prev-reaction
      (begin
        (if (is-eq (get reaction prev-reaction) "like")
          (map-set posts { post-id: post-id }
            (merge post-data { likes: (- (get likes post-data) u1) }))
          (map-set posts { post-id: post-id }
            (merge post-data { dislikes: (- (get dislikes post-data) u1) })))
        (if (is-eq reaction "like")
          (map-set posts { post-id: post-id }
            (merge post-data { likes: (+ (get likes post-data) u1) }))
          (map-set posts { post-id: post-id }
            (merge post-data { dislikes: (+ (get dislikes post-data) u1) })))
      )
      (begin
        (if (is-eq reaction "like")
          (map-set posts { post-id: post-id }
            (merge post-data { likes: (+ (get likes post-data) u1) }))
          (map-set posts { post-id: post-id }
            (merge post-data { dislikes: (+ (get dislikes post-data) u1) })))
      )
    )
    (map-set post-reactions
      { post-id: post-id, reactor: tx-sender }
      { reaction: reaction }
    )
    (ok true)
  )
)

(define-public (follow-user (user-id uint))
  (let (
    (follower-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (follower-id (get user-id follower-data))
    (target-user (unwrap! (map-get? users { user-id: user-id }) ERR-NOT-FOUND))
  )
    (asserts! (not (is-eq follower-id user-id)) ERR-INVALID-AMOUNT)
    (map-set user-followers
      { follower: follower-id, following: user-id }
      { followed-at: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (unfollow-user (user-id uint))
  (let (
    (follower-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (follower-id (get user-id follower-data))
  )
    (map-delete user-followers { follower: follower-id, following: user-id })
    (ok true)
  )
)

(define-public (deactivate-post (post-id uint))
  (let (
    (post-data (unwrap! (map-get? posts { post-id: post-id }) ERR-NOT-FOUND))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (user-id (get user-id user-data))
  )
    (asserts! (is-eq (get author-id post-data) user-id) ERR-UNAUTHORIZED)
    (map-set posts
      { post-id: post-id }
      (merge post-data { is-active: false })
    )
    (ok true)
  )
)

(define-read-only (get-user (user-id uint))
  (map-get? users { user-id: user-id })
)

(define-read-only (get-user-by-address (address principal))
  (match (map-get? user-addresses { address: address })
    user-data (map-get? users { user-id: (get user-id user-data) })
    none
  )
)

(define-read-only (get-post (post-id uint))
  (map-get? posts { post-id: post-id })
)

(define-read-only (get-post-tip (post-id uint) (tipper principal))
  (map-get? post-tips { post-id: post-id, tipper: tipper })
)

(define-read-only (get-user-reaction (post-id uint) (reactor principal))
  (map-get? post-reactions { post-id: post-id, reactor: reactor })
)

(define-read-only (is-following (follower-id uint) (following-id uint))
  (is-some (map-get? user-followers { follower: follower-id, following: following-id }))
)

(define-read-only (get-next-post-id)
  (var-get next-post-id)
)

(define-read-only (get-next-user-id)
  (var-get next-user-id)
)

(define-read-only (get-contract-stats)
  {
    total-users: (- (var-get next-user-id) u1),
    total-posts: (- (var-get next-post-id) u1),
    current-block: stacks-block-height
  }
)
