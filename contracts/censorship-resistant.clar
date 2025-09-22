(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-BOUNTY-ALREADY-CLAIMED (err u403))
(define-constant ERR-CANNOT-CLAIM-OWN-BOUNTY (err u405))
(define-constant ERR-VOTING-ENDED (err u406))
(define-constant ERR-ALREADY-VOTED (err u407))
(define-constant ERR-INSUFFICIENT-STAKE (err u408))
(define-constant ERR-INVALID-VOTE (err u409))

(define-data-var next-post-id uint u1)
(define-data-var next-user-id uint u1)
(define-data-var contract-balance uint u0)
(define-data-var next-bounty-id uint u1)
(define-data-var next-vote-id uint u1)
(define-data-var min-stake-to-vote uint u100)

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

(define-map post-bounties
  { bounty-id: uint }
  {
    post-id: uint,
    creator-id: uint,
    amount: uint,
    created-at: uint,
    claimed-by: (optional uint),
    claimed-at: (optional uint),
    is-active: bool
  }
)

(define-map post-bounty-lookup
  { post-id: uint }
  { bounty-id: uint }
)

(define-map moderation-votes
  { vote-id: uint }
  {
    post-id: uint,
    flagged-by: uint,
    reason: (string-ascii 100),
    votes-for: uint,
    votes-against: uint,
    total-stake-for: uint,
    total-stake-against: uint,
    voting-ends: uint,
    is-active: bool,
    final-decision: (optional bool)
  }
)

(define-map vote-participation
  { vote-id: uint, voter: uint }
  {
    vote-choice: bool,
    stake-weight: uint,
    voted-at: uint
  }
)

(define-map post-moderation-lookup
  { post-id: uint }
  { vote-id: uint }
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

(define-public (place-bounty (post-id uint) (amount uint))
  (let (
    (bounty-id (var-get next-bounty-id))
    (post-data (unwrap! (map-get? posts { post-id: post-id }) ERR-NOT-FOUND))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (user-id (get user-id user-data))
    (existing-bounty (map-get? post-bounty-lookup { post-id: post-id }))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get is-active post-data) ERR-NOT-FOUND)
    (asserts! (is-none existing-bounty) ERR-ALREADY-EXISTS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set post-bounties
      { bounty-id: bounty-id }
      {
        post-id: post-id,
        creator-id: user-id,
        amount: amount,
        created-at: stacks-block-height,
        claimed-by: none,
        claimed-at: none,
        is-active: true
      }
    )
    (map-set post-bounty-lookup { post-id: post-id } { bounty-id: bounty-id })
    (var-set next-bounty-id (+ bounty-id u1))
    (ok bounty-id)
  )
)

(define-public (claim-bounty (post-id uint))
  (let (
    (bounty-lookup (unwrap! (map-get? post-bounty-lookup { post-id: post-id }) ERR-NOT-FOUND))
    (bounty-id (get bounty-id bounty-lookup))
    (bounty-data (unwrap! (map-get? post-bounties { bounty-id: bounty-id }) ERR-NOT-FOUND))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (claimer-id (get user-id user-data))
    (claimer-info (unwrap! (map-get? users { user-id: claimer-id }) ERR-NOT-FOUND))
    (amount (get amount bounty-data))
  )
    (asserts! (get is-active bounty-data) ERR-BOUNTY-ALREADY-CLAIMED)
    (asserts! (not (is-eq (get creator-id bounty-data) claimer-id)) ERR-CANNOT-CLAIM-OWN-BOUNTY)
    (asserts! (is-none (get claimed-by bounty-data)) ERR-BOUNTY-ALREADY-CLAIMED)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set post-bounties
      { bounty-id: bounty-id }
      (merge bounty-data {
        claimed-by: (some claimer-id),
        claimed-at: (some stacks-block-height),
        is-active: false
      })
    )
    (map-set users
      { user-id: claimer-id }
      (merge claimer-info { total-tips-received: (+ (get total-tips-received claimer-info) amount) })
    )
    (ok true)
  )
)

(define-read-only (get-bounty (bounty-id uint))
  (map-get? post-bounties { bounty-id: bounty-id })
)

(define-read-only (get-post-bounty (post-id uint))
  (match (map-get? post-bounty-lookup { post-id: post-id })
    bounty-lookup (map-get? post-bounties { bounty-id: (get bounty-id bounty-lookup) })
    none
  )
)

(define-read-only (get-contract-stats)
  {
    total-users: (- (var-get next-user-id) u1),
    total-posts: (- (var-get next-post-id) u1),
    total-bounties: (- (var-get next-bounty-id) u1),
    total-votes: (- (var-get next-vote-id) u1),
    current-block: stacks-block-height
  }
)

(define-public (flag-content (post-id uint) (reason (string-ascii 100)))
  (let (
    (vote-id (var-get next-vote-id))
    (post-data (unwrap! (map-get? posts { post-id: post-id }) ERR-NOT-FOUND))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (flagger-id (get user-id user-data))
    (flagger-info (unwrap! (map-get? users { user-id: flagger-id }) ERR-NOT-FOUND))
    (existing-vote (map-get? post-moderation-lookup { post-id: post-id }))
    (voting-period u1008)
  )
    (asserts! (get is-active post-data) ERR-NOT-FOUND)
    (asserts! (is-none existing-vote) ERR-ALREADY-EXISTS)
    (asserts! (>= (get total-tips-received flagger-info) (var-get min-stake-to-vote)) ERR-INSUFFICIENT-STAKE)
    
    (map-set moderation-votes
      { vote-id: vote-id }
      {
        post-id: post-id,
        flagged-by: flagger-id,
        reason: reason,
        votes-for: u0,
        votes-against: u0,
        total-stake-for: u0,
        total-stake-against: u0,
        voting-ends: (+ stacks-block-height voting-period),
        is-active: true,
        final-decision: none
      }
    )
    
    (map-set post-moderation-lookup { post-id: post-id } { vote-id: vote-id })
    (var-set next-vote-id (+ vote-id u1))
    (ok vote-id)
  )
)

(define-public (vote-on-moderation (vote-id uint) (vote-for bool))
  (let (
    (vote-data (unwrap! (map-get? moderation-votes { vote-id: vote-id }) ERR-NOT-FOUND))
    (user-data (unwrap! (map-get? user-addresses { address: tx-sender }) ERR-UNAUTHORIZED))
    (voter-id (get user-id user-data))
    (voter-info (unwrap! (map-get? users { user-id: voter-id }) ERR-NOT-FOUND))
    (existing-participation (map-get? vote-participation { vote-id: vote-id, voter: voter-id }))
    (stake-weight (+ (get total-tips-received voter-info) (get post-count voter-info)))
  )
    (asserts! (get is-active vote-data) ERR-VOTING-ENDED)
    (asserts! (< stacks-block-height (get voting-ends vote-data)) ERR-VOTING-ENDED)
    (asserts! (is-none existing-participation) ERR-ALREADY-VOTED)
    (asserts! (>= stake-weight (var-get min-stake-to-vote)) ERR-INSUFFICIENT-STAKE)
    
    (map-set vote-participation
      { vote-id: vote-id, voter: voter-id }
      {
        vote-choice: vote-for,
        stake-weight: stake-weight,
        voted-at: stacks-block-height
      }
    )
    
    (if vote-for
      (map-set moderation-votes
        { vote-id: vote-id }
        (merge vote-data {
          votes-for: (+ (get votes-for vote-data) u1),
          total-stake-for: (+ (get total-stake-for vote-data) stake-weight)
        })
      )
      (map-set moderation-votes
        { vote-id: vote-id }
        (merge vote-data {
          votes-against: (+ (get votes-against vote-data) u1),
          total-stake-against: (+ (get total-stake-against vote-data) stake-weight)
        })
      )
    )
    
    (ok true)
  )
)

(define-public (finalize-moderation-vote (vote-id uint))
  (let (
    (vote-data (unwrap! (map-get? moderation-votes { vote-id: vote-id }) ERR-NOT-FOUND))
    (post-data (unwrap! (map-get? posts { post-id: (get post-id vote-data) }) ERR-NOT-FOUND))
    (decision (> (get total-stake-for vote-data) (get total-stake-against vote-data)))
  )
    (asserts! (get is-active vote-data) ERR-VOTING-ENDED)
    (asserts! (>= stacks-block-height (get voting-ends vote-data)) ERR-INVALID-VOTE)
    
    (map-set moderation-votes
      { vote-id: vote-id }
      (merge vote-data {
        is-active: false,
        final-decision: (some decision)
      })
    )
    
    (if decision
      (map-set posts
        { post-id: (get post-id vote-data) }
        (merge post-data { is-active: false })
      )
      true
    )
    
    (ok decision)
  )
)

(define-public (set-min-stake-to-vote (new-min-stake uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set min-stake-to-vote new-min-stake)
    (ok new-min-stake)
  )
)

(define-read-only (get-moderation-vote (vote-id uint))
  (map-get? moderation-votes { vote-id: vote-id })
)

(define-read-only (get-post-moderation-vote (post-id uint))
  (match (map-get? post-moderation-lookup { post-id: post-id })
    vote-lookup (map-get? moderation-votes { vote-id: (get vote-id vote-lookup) })
    none
  )
)

(define-read-only (get-user-vote (vote-id uint) (voter-id uint))
  (map-get? vote-participation { vote-id: vote-id, voter: voter-id })
)

(define-read-only (calculate-user-stake (user-id uint))
  (match (map-get? users { user-id: user-id })
    user-data (+ (get total-tips-received user-data) (get post-count user-data))
    u0
  )
)

(define-read-only (get-min-stake-to-vote)
  (var-get min-stake-to-vote)
)
