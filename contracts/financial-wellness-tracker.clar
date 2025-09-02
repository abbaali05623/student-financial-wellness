;; Financial Wellness Tracker Smart Contract
;; This contract handles comprehensive financial wellness tracking including debt management, 
;; savings goals, scholarship tracking, career planning, and overall financial health scoring

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-unauthorized (err u203))
(define-constant err-invalid-data (err u204))
(define-constant err-insufficient-funds (err u205))
(define-constant err-goal-not-active (err u206))
(define-constant err-deadline-passed (err u207))

;; Financial health score thresholds
(define-constant excellent-score u800)
(define-constant good-score u600)
(define-constant fair-score u400)
(define-constant poor-score u200)

;; Data Variables
(define-data-var next-student-id uint u1)
(define-data-var next-goal-id uint u1)
(define-data-var next-debt-id uint u1)
(define-data-var next-scholarship-id uint u1)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee

;; Main student financial profile
(define-map student-profiles
  { student-address: principal }
  {
    student-id: uint,
    name: (string-ascii 50),
    major: (string-ascii 50),
    graduation-year: uint,
    registration-date: uint,
    total-debt: uint,
    total-savings: uint,
    monthly-income: uint,
    monthly-expenses: uint,
    financial-wellness-score: uint,
    last-updated: uint
  }
)

;; Debt management
(define-map student-debts
  { student-address: principal, debt-id: uint }
  {
    debt-type: (string-ascii 30), ;; "student-loan", "credit-card", "personal", etc.
    creditor-name: (string-ascii 50),
    principal-amount: uint,
    current-balance: uint,
    interest-rate: uint, ;; in basis points (100 = 1%)
    minimum-payment: uint,
    due-date: uint,
    status: (string-ascii 20), ;; "active", "paid-off", "delinquent"
    creation-date: uint
  }
)

(define-map debt-payments
  { student-address: principal, debt-id: uint, payment-id: uint }
  {
    payment-amount: uint,
    payment-date: uint,
    payment-type: (string-ascii 20), ;; "minimum", "extra", "full"
    remaining-balance: uint
  }
)

;; Savings goals
(define-map savings-goals
  { student-address: principal, goal-id: uint }
  {
    goal-name: (string-ascii 50),
    target-amount: uint,
    current-amount: uint,
    deadline: uint,
    category: (string-ascii 30), ;; "emergency", "education", "career", "personal"
    priority: uint, ;; 1-5 scale
    status: (string-ascii 15), ;; "active", "completed", "paused"
    creation-date: uint
  }
)

(define-map savings-contributions
  { student-address: principal, goal-id: uint, contribution-id: uint }
  {
    amount: uint,
    contribution-date: uint,
    source: (string-ascii 30) ;; "manual", "automatic", "windfall"
  }
)

;; Scholarship and financial aid tracking
(define-map scholarships
  { student-address: principal, scholarship-id: uint }
  {
    scholarship-name: (string-ascii 100),
    amount: uint,
    award-date: uint,
    disbursement-date: (optional uint),
    status: (string-ascii 20), ;; "applied", "awarded", "received", "rejected"
    renewable: bool,
    requirements: (string-ascii 200),
    provider: (string-ascii 50)
  }
)

;; Career planning and earning potential
(define-map career-plans
  { student-address: principal }
  {
    target-career: (string-ascii 50),
    expected-starting-salary: uint,
    target-salary-5yr: uint,
    skills-needed: (list 10 (string-ascii 30)),
    certifications-planned: (list 5 (string-ascii 50)),
    networking-events-attended: uint,
    internships-completed: uint,
    job-applications: uint,
    last-updated: uint
  }
)

;; Budget tracking
(define-map monthly-budgets
  { student-address: principal, month: uint, year: uint }
  {
    total-income: uint,
    fixed-expenses: uint,
    variable-expenses: uint,
    savings-allocation: uint,
    debt-payment-allocation: uint,
    discretionary-spending: uint,
    actual-vs-budget: int ;; positive means under budget, negative means over
  }
)

;; Financial education progress (linking to education contract)
(define-map education-progress
  { student-address: principal }
  {
    modules-completed: uint,
    certifications-earned: uint,
    financial-literacy-score: uint,
    last-assessment-date: uint
  }
)

;; Read-only functions

(define-read-only (get-student-profile (student-addr principal))
  (map-get? student-profiles { student-address: student-addr })
)

(define-read-only (get-student-debt (student-addr principal) (debt-id uint))
  (map-get? student-debts { student-address: student-addr, debt-id: debt-id })
)

(define-read-only (get-savings-goal (student-addr principal) (goal-id uint))
  (map-get? savings-goals { student-address: student-addr, goal-id: goal-id })
)

(define-read-only (get-scholarship-info (student-addr principal) (scholarship-id uint))
  (map-get? scholarships { student-address: student-addr, scholarship-id: scholarship-id })
)

(define-read-only (get-career-plan (student-addr principal))
  (map-get? career-plans { student-address: student-addr })
)

(define-read-only (get-monthly-budget (student-addr principal) (month uint) (year uint))
  (map-get? monthly-budgets { student-address: student-addr, month: month, year: year })
)

(define-read-only (calculate-debt-to-income-ratio (student-addr principal))
  (match (map-get? student-profiles { student-address: student-addr })
    profile
      (let ((monthly-income (get monthly-income profile))
            (total-debt (get total-debt profile)))
        (if (> monthly-income u0)
          (ok (/ (* total-debt u100) (* monthly-income u12))) ;; Annual ratio as percentage
          (ok u0)
        )
      )
    (err err-not-found)
  )
)

(define-read-only (calculate-savings-rate (student-addr principal))
  (match (map-get? student-profiles { student-address: student-addr })
    profile
      (let ((monthly-income (get monthly-income profile))
            (monthly-expenses (get monthly-expenses profile)))
        (if (> monthly-income monthly-expenses)
          (ok (/ (* (- monthly-income monthly-expenses) u100) monthly-income))
          (ok u0)
        )
      )
    (err err-not-found)
  )
)

(define-read-only (get-financial-wellness-score (student-addr principal))
  (match (map-get? student-profiles { student-address: student-addr })
    profile (ok (get financial-wellness-score profile))
    (err err-not-found)
  )
)

(define-read-only (get-wellness-score-category (score uint))
  (if (>= score excellent-score)
    (ok "Excellent")
    (if (>= score good-score)
      (ok "Good")
      (if (>= score fair-score)
        (ok "Fair")
        (ok "Poor")
      )
    )
  )
)

;; Private helper functions

(define-private (calculate-financial-wellness-score (student-addr principal))
  (match (map-get? student-profiles { student-address: student-addr })
    profile
      (let (
        (debt-ratio (unwrap-panic (calculate-debt-to-income-ratio student-addr)))
        (savings-rate (unwrap-panic (calculate-savings-rate student-addr)))
        (education-score (get-education-score student-addr))
        (base-score u1000)
      )
        (let (
          ;; Debt component (lower debt ratio = higher score)
          (debt-component (if (< debt-ratio u50) 
                            (- u250 (* debt-ratio u5)) 
                            u0))
          
          ;; Savings component (higher savings rate = higher score)
          (savings-component (* savings-rate u3))
          
          ;; Education component
          (education-component education-score)
          
          ;; Budget adherence component (simplified)
          (budget-component u100)
        )
          (ok (+ debt-component savings-component education-component budget-component))
        )
      )
    (err err-not-found)
  )
)

(define-private (get-education-score (student-addr principal))
  (match (map-get? education-progress { student-address: student-addr })
    progress (get financial-literacy-score progress)
    u50 ;; Default score if no education data
  )
)

(define-private (update-total-debt (student-addr principal))
  (match (map-get? student-profiles { student-address: student-addr })
    profile
      (let ((new-total (calculate-total-debt student-addr)))
        (map-set student-profiles
          { student-address: student-addr }
          (merge profile { total-debt: new-total })
        )
        (ok new-total)
      )
    (err err-not-found)
  )
)

(define-private (calculate-total-debt (student-addr principal))
  ;; Simplified calculation - would iterate through all debts in real implementation
  u0 ;; Placeholder
)

;; Public functions

(define-public (register-student 
  (name (string-ascii 50))
  (major (string-ascii 50))
  (graduation-year uint)
  (monthly-income uint)
  (monthly-expenses uint)
)
  (let ((student-id (var-get next-student-id))
        (current-block u1))
    (asserts! (is-none (map-get? student-profiles { student-address: tx-sender })) (err err-already-exists))
    (asserts! (and (> (len name) u0) (> graduation-year u2020)) (err err-invalid-data))
    
    (map-set student-profiles
      { student-address: tx-sender }
      {
        student-id: student-id,
        name: name,
        major: major,
        graduation-year: graduation-year,
        registration-date: current-block,
        total-debt: u0,
        total-savings: u0,
        monthly-income: monthly-income,
        monthly-expenses: monthly-expenses,
        financial-wellness-score: u0,
        last-updated: current-block
      }
    )
    
    ;; Initialize career plan
    (map-set career-plans
      { student-address: tx-sender }
      {
        target-career: "",
        expected-starting-salary: u0,
        target-salary-5yr: u0,
        skills-needed: (list),
        certifications-planned: (list),
        networking-events-attended: u0,
        internships-completed: u0,
        job-applications: u0,
        last-updated: current-block
      }
    )
    
    ;; Calculate initial wellness score
    (unwrap-panic (calculate-financial-wellness-score tx-sender))
    
    (var-set next-student-id (+ student-id u1))
    (ok student-id)
  )
)

(define-public (add-debt 
  (debt-type (string-ascii 30))
  (creditor-name (string-ascii 50))
  (principal-amount uint)
  (current-balance uint)
  (interest-rate uint)
  (minimum-payment uint)
  (due-date uint)
)
  (let ((debt-id (var-get next-debt-id))
        (current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (and (> principal-amount u0) (> current-balance u0)) (err err-invalid-data))
    
    (map-set student-debts
      { student-address: tx-sender, debt-id: debt-id }
      {
        debt-type: debt-type,
        creditor-name: creditor-name,
        principal-amount: principal-amount,
        current-balance: current-balance,
        interest-rate: interest-rate,
        minimum-payment: minimum-payment,
        due-date: due-date,
        status: "active",
        creation-date: current-block
      }
    )
    
    ;; Update total debt
    (try! (update-total-debt tx-sender))
    
    ;; Recalculate wellness score
    (try! (update-wellness-score tx-sender))
    
    (var-set next-debt-id (+ debt-id u1))
    (ok debt-id)
  )
)

(define-public (make-debt-payment (debt-id uint) (payment-amount uint) (payment-type (string-ascii 20)))
  (let ((current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (> payment-amount u0) (err err-invalid-data))
    
    (match (map-get? student-debts { student-address: tx-sender, debt-id: debt-id })
      debt-data
        (let ((current-balance (get current-balance debt-data))
              (new-balance (if (>= payment-amount current-balance) 
                              u0 
                              (- current-balance payment-amount)))
              (new-status (if (is-eq new-balance u0) "paid-off" "active")))
          
          ;; Update debt record
          (map-set student-debts
            { student-address: tx-sender, debt-id: debt-id }
            (merge debt-data 
              { 
                current-balance: new-balance,
                status: new-status
              }
            )
          )
          
          ;; Record payment
          ;; (Would implement payment tracking here)
          
          ;; Update total debt and wellness score
          (try! (update-total-debt tx-sender))
          (try! (update-wellness-score tx-sender))
          
          (ok new-balance)
        )
      (err err-not-found)
    )
  )
)

(define-public (create-savings-goal 
  (goal-name (string-ascii 50))
  (target-amount uint)
  (deadline uint)
  (category (string-ascii 30))
  (priority uint)
)
  (let ((goal-id (var-get next-goal-id))
        (current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (and (> target-amount u0) (<= priority u5)) (err err-invalid-data))
    
    (map-set savings-goals
      { student-address: tx-sender, goal-id: goal-id }
      {
        goal-name: goal-name,
        target-amount: target-amount,
        current-amount: u0,
        deadline: deadline,
        category: category,
        priority: priority,
        status: "active",
        creation-date: current-block
      }
    )
    
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (contribute-to-savings (goal-id uint) (amount uint) (source (string-ascii 30)))
  (let ((current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (> amount u0) (err err-invalid-data))
    
    (match (map-get? savings-goals { student-address: tx-sender, goal-id: goal-id })
      goal-data
        (let ((current-amount (get current-amount goal-data))
              (target-amount (get target-amount goal-data))
              (new-amount (+ current-amount amount))
              (new-status (if (>= new-amount target-amount) "completed" "active")))
          
          (asserts! (is-eq (get status goal-data) "active") (err err-goal-not-active))
          
          ;; Update goal
          (map-set savings-goals
            { student-address: tx-sender, goal-id: goal-id }
            (merge goal-data 
              { 
                current-amount: new-amount,
                status: new-status
              }
            )
          )
          
          ;; Update total savings in profile
          (match (map-get? student-profiles { student-address: tx-sender })
            profile
              (map-set student-profiles
                { student-address: tx-sender }
                (merge profile { total-savings: (+ (get total-savings profile) amount) })
              )
            false
          )
          
          ;; Update wellness score
          (try! (update-wellness-score tx-sender))
          
          (ok new-amount)
        )
      (err err-not-found)
    )
  )
)

(define-public (add-scholarship 
  (scholarship-name (string-ascii 100))
  (amount uint)
  (award-date uint)
  (renewable bool)
  (requirements (string-ascii 200))
  (provider (string-ascii 50))
)
  (let ((scholarship-id (var-get next-scholarship-id)))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (> amount u0) (err err-invalid-data))
    
    (map-set scholarships
      { student-address: tx-sender, scholarship-id: scholarship-id }
      {
        scholarship-name: scholarship-name,
        amount: amount,
        award-date: award-date,
        disbursement-date: none,
        status: "awarded",
        renewable: renewable,
        requirements: requirements,
        provider: provider
      }
    )
    
    (var-set next-scholarship-id (+ scholarship-id u1))
    (ok scholarship-id)
  )
)

(define-public (update-career-plan 
  (target-career (string-ascii 50))
  (expected-starting-salary uint)
  (target-salary-5yr uint)
)
  (let ((current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    
    (match (map-get? career-plans { student-address: tx-sender })
      current-plan
        (begin
          (map-set career-plans
            { student-address: tx-sender }
            (merge current-plan
              {
                target-career: target-career,
                expected-starting-salary: expected-starting-salary,
                target-salary-5yr: target-salary-5yr,
                last-updated: current-block
              }
            )
          )
          (ok true)
        )
      (err err-not-found)
    )
  )
)

(define-public (set-monthly-budget 
  (month uint) 
  (year uint)
  (total-income uint)
  (fixed-expenses uint)
  (variable-expenses uint)
  (savings-allocation uint)
  (debt-payment-allocation uint)
)
  (let ((discretionary (- total-income (+ fixed-expenses variable-expenses savings-allocation debt-payment-allocation))))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (and (> month u0) (<= month u12) (> year u2020)) (err err-invalid-data))
    
    (map-set monthly-budgets
      { student-address: tx-sender, month: month, year: year }
      {
        total-income: total-income,
        fixed-expenses: fixed-expenses,
        variable-expenses: variable-expenses,
        savings-allocation: savings-allocation,
        debt-payment-allocation: debt-payment-allocation,
        discretionary-spending: discretionary,
        actual-vs-budget: 0
      }
    )
    
    ;; Update profile with new monthly income/expenses if different
    (match (map-get? student-profiles { student-address: tx-sender })
      profile
        (if (or (not (is-eq (get monthly-income profile) total-income))
                (not (is-eq (get monthly-expenses profile) (+ fixed-expenses variable-expenses))))
          (begin
            (map-set student-profiles
              { student-address: tx-sender }
              (merge profile 
                { 
                  monthly-income: total-income,
                  monthly-expenses: (+ fixed-expenses variable-expenses)
                }
              )
            )
            (try! (update-wellness-score tx-sender))
            (ok true)
          )
          (ok true)
        )
      (err err-not-found)
    )
  )
)

(define-private (update-wellness-score (student-addr principal))
  (match (calculate-financial-wellness-score student-addr)
    new-score
      (match (map-get? student-profiles { student-address: student-addr })
        profile
          (begin
            (map-set student-profiles
              { student-address: student-addr }
              (merge profile 
                { 
                  financial-wellness-score: new-score,
                  last-updated: u1
                }
              )
            )
            (ok new-score)
          )
        (err err-not-found)
      )
    error (err error)
  )
)

(define-public (update-education-progress 
  (modules-completed uint)
  (certifications-earned uint)
  (financial-literacy-score uint)
)
  (let ((current-block u1))
    (asserts! (is-some (map-get? student-profiles { student-address: tx-sender })) (err err-unauthorized))
    (asserts! (<= financial-literacy-score u100) (err err-invalid-data))
    
    (map-set education-progress
      { student-address: tx-sender }
      {
        modules-completed: modules-completed,
        certifications-earned: certifications-earned,
        financial-literacy-score: financial-literacy-score,
        last-assessment-date: current-block
      }
    )
    
    ;; Update wellness score with new education data
    (try! (update-wellness-score tx-sender))
    
    (ok true)
  )
)

;; Administrative functions
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (<= new-fee u10) (err err-invalid-data)) ;; Max 10%
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    ;; Implementation for emergency pause functionality
    (ok true)
  )
)
