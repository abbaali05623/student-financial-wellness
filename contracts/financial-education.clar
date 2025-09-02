;; Financial Education Smart Contract
;; This contract manages financial literacy education modules, progress tracking, and certification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-data (err u104))
(define-constant err-already-completed (err u105))
(define-constant err-prerequisites-not-met (err u106))

;; Data Variables
(define-data-var next-module-id uint u1)
(define-data-var next-student-id uint u1)
(define-data-var certification-threshold uint u80) ;; 80% completion required for certification

;; Data Maps
(define-map students 
  { student-address: principal }
  {
    student-id: uint,
    name: (string-ascii 50),
    registration-date: uint,
    total-modules-completed: uint,
    certification-earned: bool,
    wellness-score: uint
  }
)

(define-map education-modules
  { module-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 30),
    difficulty-level: uint, ;; 1-5 scale
    completion-reward: uint,
    prerequisites: (list 10 uint),
    is-active: bool,
    created-by: principal,
    creation-date: uint
  }
)

(define-map student-progress
  { student-address: principal, module-id: uint }
  {
    completion-status: (string-ascii 20), ;; "not-started", "in-progress", "completed"
    start-date: uint,
    completion-date: (optional uint),
    quiz-score: uint,
    time-spent: uint, ;; in minutes
    attempts: uint
  }
)

(define-map certifications
  { student-address: principal }
  {
    certification-id: (string-ascii 50),
    issue-date: uint,
    modules-completed: (list 50 uint),
    overall-score: uint,
    valid-until: uint,
    issuer: principal
  }
)

(define-map quiz-results
  { student-address: principal, module-id: uint, attempt: uint }
  {
    score: uint,
    total-questions: uint,
    correct-answers: uint,
    completion-time: uint,
    date-taken: uint
  }
)

;; Achievement system
(define-map achievements
  { achievement-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    criteria: (string-ascii 100),
    reward-points: uint,
    badge-icon: (string-ascii 100)
  }
)

(define-map student-achievements
  { student-address: principal, achievement-id: uint }
  {
    earned-date: uint,
    progress: uint
  }
)

;; Read-only functions

(define-read-only (get-student-info (student-addr principal))
  (map-get? students { student-address: student-addr })
)

(define-read-only (get-module-info (module-id uint))
  (map-get? education-modules { module-id: module-id })
)

(define-read-only (get-student-progress (student-addr principal) (module-id uint))
  (map-get? student-progress { student-address: student-addr, module-id: module-id })
)

(define-read-only (get-certification (student-addr principal))
  (map-get? certifications { student-address: student-addr })
)

(define-read-only (get-quiz-result (student-addr principal) (module-id uint) (attempt uint))
  (map-get? quiz-results { student-address: student-addr, module-id: module-id, attempt: attempt })
)

(define-read-only (check-prerequisites (student-addr principal) (module-id uint))
  (match (map-get? education-modules { module-id: module-id })
    module-data 
      (let ((prerequisites (get prerequisites module-data)))
        (if (is-eq (len prerequisites) u0)
          (ok true)
          (ok (is-all-completed student-addr prerequisites))
        )
      )
    (err err-not-found)
  )
)

(define-read-only (calculate-overall-progress (student-addr principal))
  (match (map-get? students { student-address: student-addr })
    student-data
      (let ((completed-modules (get total-modules-completed student-data))
            (total-modules (get-total-active-modules)))
        (if (> total-modules u0)
          (ok (/ (* completed-modules u100) total-modules))
          (ok u0)
        )
      )
    (err err-not-found)
  )
)

(define-read-only (get-student-wellness-score (student-addr principal))
  (match (map-get? students { student-address: student-addr })
    student-data (ok (get wellness-score student-data))
    (err err-not-found)
  )
)

;; Private helper functions

(define-private (is-all-completed (student-addr principal) (module-list (list 10 uint)))
  (fold check-module-completion module-list true)
)

(define-private (check-module-completion (module-id uint) (acc bool))
  (if acc
    (match (map-get? student-progress { student-address: tx-sender, module-id: module-id })
      progress-data (is-eq (get completion-status progress-data) "completed")
      false
    )
    false
  )
)

(define-private (get-total-active-modules)
  (var-get next-module-id)
)

(define-private (update-wellness-score (student-addr principal))
  (match (calculate-overall-progress student-addr)
    progress-percentage
      (begin
        (map-set students
          { student-address: student-addr }
          (merge (unwrap-panic (map-get? students { student-address: student-addr }))
                 { wellness-score: progress-percentage })
        )
        (ok progress-percentage)
      )
    error (err error)
  )
)

;; Public functions

(define-public (register-student (name (string-ascii 50)))
  (let ((student-id (var-get next-student-id))
        (current-block u1))
    (asserts! (is-none (map-get? students { student-address: tx-sender })) (err err-already-exists))
    (asserts! (> (len name) u0) (err err-invalid-data))
    
    (map-set students
      { student-address: tx-sender }
      {
        student-id: student-id,
        name: name,
        registration-date: current-block,
        total-modules-completed: u0,
        certification-earned: false,
        wellness-score: u0
      }
    )
    
    (var-set next-student-id (+ student-id u1))
    (ok student-id)
  )
)

(define-public (create-education-module 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 30))
  (difficulty-level uint)
  (completion-reward uint)
  (prerequisites (list 10 uint))
)
  (let ((module-id (var-get next-module-id))
        (current-block u1))
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (and (> (len title) u0) (<= difficulty-level u5)) (err err-invalid-data))
    
    (map-set education-modules
      { module-id: module-id }
      {
        title: title,
        description: description,
        category: category,
        difficulty-level: difficulty-level,
        completion-reward: completion-reward,
        prerequisites: prerequisites,
        is-active: true,
        created-by: tx-sender,
        creation-date: current-block
      }
    )
    
    (var-set next-module-id (+ module-id u1))
    (ok module-id)
  )
)

(define-public (start-module (module-id uint))
  (let ((current-block u1))
    (asserts! (is-some (map-get? students { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (is-some (map-get? education-modules { module-id: module-id })) (err err-not-found))
    
    ;; Check if prerequisites are met
    (asserts! (unwrap! (check-prerequisites tx-sender module-id) (err err-prerequisites-not-met)) 
              (err err-prerequisites-not-met))
    
    ;; Check if already completed
    (match (map-get? student-progress { student-address: tx-sender, module-id: module-id })
      existing-progress 
        (asserts! (not (is-eq (get completion-status existing-progress) "completed")) 
                  (err err-already-completed))
      true ;; Not started yet, continue
    )
    
    (map-set student-progress
      { student-address: tx-sender, module-id: module-id }
      {
        completion-status: "in-progress",
        start-date: current-block,
        completion-date: none,
        quiz-score: u0,
        time-spent: u0,
        attempts: u0
      }
    )
    
    (ok true)
  )
)

(define-public (complete-module (module-id uint) (quiz-score uint) (time-spent uint))
  (let ((current-block u1))
    (asserts! (is-some (map-get? students { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (is-some (map-get? education-modules { module-id: module-id })) (err err-not-found))
    (asserts! (<= quiz-score u100) (err err-invalid-data))
    
    ;; Get current progress
    (match (map-get? student-progress { student-address: tx-sender, module-id: module-id })
      current-progress
        (begin
          ;; Update progress to completed
          (map-set student-progress
            { student-address: tx-sender, module-id: module-id }
            (merge current-progress
              {
                completion-status: "completed",
                completion-date: (some current-block),
                quiz-score: quiz-score,
                time-spent: (+ (get time-spent current-progress) time-spent),
                attempts: (+ (get attempts current-progress) u1)
              }
            )
          )
          
          ;; Record quiz result
          (map-set quiz-results
            { student-address: tx-sender, module-id: module-id, attempt: (+ (get attempts current-progress) u1) }
            {
              score: quiz-score,
              total-questions: u10, ;; Assume 10 questions per quiz
              correct-answers: (/ (* quiz-score u10) u100),
              completion-time: time-spent,
              date-taken: current-block
            }
          )
          
          ;; Update student's completed modules count
          (match (map-get? students { student-address: tx-sender })
            student-data
              (map-set students
                { student-address: tx-sender }
                (merge student-data
                  { total-modules-completed: (+ (get total-modules-completed student-data) u1) }
                )
              )
            false
          )
          
          ;; Update wellness score
          (unwrap-panic (update-wellness-score tx-sender))
          
          ;; Check if eligible for certification
          (try! (check-and-issue-certification tx-sender))
          
          (ok true)
        )
      (err err-not-found)
    )
  )
)

(define-public (issue-certification (student-addr principal))
  (let ((current-block u1)
        (cert-id (int-to-ascii (to-int (+ current-block u1)))))
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    
    (match (map-get? students { student-address: student-addr })
      student-data
        (let ((completion-percentage (unwrap! (calculate-overall-progress student-addr) (err err-invalid-data))))
          (asserts! (>= completion-percentage (var-get certification-threshold)) (err err-invalid-data))
          
          (map-set certifications
            { student-address: student-addr }
            {
              certification-id: cert-id,
              issue-date: current-block,
              modules-completed: (list),
              overall-score: completion-percentage,
              valid-until: (+ current-block u52560), ;; Valid for ~1 year
              issuer: tx-sender
            }
          )
          
          ;; Mark student as certified
          (map-set students
            { student-address: student-addr }
            (merge student-data { certification-earned: true })
          )
          
          (ok cert-id)
        )
      (err err-not-found)
    )
  )
)

(define-private (check-and-issue-certification (student-addr principal))
  (match (calculate-overall-progress student-addr)
    completion-percentage
      (if (>= completion-percentage (var-get certification-threshold))
        (issue-certification student-addr)
        (ok "not-eligible")
      )
    error (err error)
  )
)

(define-public (update-certification-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (<= new-threshold u100) (err err-invalid-data))
    (var-set certification-threshold new-threshold)
    (ok true)
  )
)

(define-public (deactivate-module (module-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (match (map-get? education-modules { module-id: module-id })
      module-data
        (begin
          (map-set education-modules
            { module-id: module-id }
            (merge module-data { is-active: false })
          )
          (ok true)
        )
      (err err-not-found)
    )
  )
)

;; Achievement system functions
(define-public (create-achievement 
  (name (string-ascii 50))
  (description (string-ascii 200))
  (criteria (string-ascii 100))
  (reward-points uint)
  (badge-icon (string-ascii 100))
)
  (let ((achievement-id (var-get next-module-id))) ;; Reusing for simplicity
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    
    (map-set achievements
      { achievement-id: achievement-id }
      {
        name: name,
        description: description,
        criteria: criteria,
        reward-points: reward-points,
        badge-icon: badge-icon
      }
    )
    
    (ok achievement-id)
  )
)

(define-public (award-achievement (student-addr principal) (achievement-id uint))
  (let ((current-block u1))
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (is-some (map-get? achievements { achievement-id: achievement-id })) (err err-not-found))
    
    (map-set student-achievements
      { student-address: student-addr, achievement-id: achievement-id }
      {
        earned-date: current-block,
        progress: u100
      }
    )
    
    (ok true)
  )
)

;; Emergency functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    ;; Implementation for pausing contract operations
    (ok true)
  )
)
