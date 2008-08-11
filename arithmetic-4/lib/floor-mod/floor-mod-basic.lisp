;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; floor-mod-basic.lisp
;;;
;;; This book contains the simpler rules about floor and mod.
;;; 
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(IN-PACKAGE "ACL2")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(table acl2-defaults-table :state-ok t)

;; I used to do the below include-book locally, but when I added the
;; set-defaults-hint this caused problems.  The set-defaults-hint
;; could not be done locally, and then this caused nonlinearp-default-hint
;; to be undefined.  I need to straighten all this out someday.

(include-book "../basic-ops/building-blocks")

(local
 (include-book "forcing-types"))

(local
 (include-book "../basic-ops/top"))

(local
 (include-book "floor-mod-basic-helper"))

;(set-default-hints '((nonlinearp-default-hint stable-under-simplificationp 
;                                              hist pspv)))

(SET-DEFAULT-HINTS
     '((NONLINEARP-DEFAULT-HINT++ ID STABLE-UNDER-SIMPLIFICATIONP
                                  HIST NIL)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Basic theorems about floor and mod

;;(defthm floor-integerp
;;  (integerp (floor x y)))

(defthm integerp-mod
  (implies (and (integerp x)
		(integerp y))
	   (integerp (mod x y)))
  :rule-classes (:rewrite :type-prescription))

(defthm integerp-mod-2
  (implies (and (integerp x)
		(integerp (/ y)))
	   (integerp (mod x y)))
  :hints (("Goal" :in-theory (enable mod floor)))
  :rule-classes (:rewrite :type-prescription))

(defthm integerp-mod-3
  (IMPLIES (INTEGERP X)
	   (INTEGERP (MOD X (EXPT 2 I))))
  :hints (("Goal" :cases ((equal i 0)
			  (< i 0)
			  (< 0 i))))
  :rule-classes (:rewrite :type-prescription))

(defthm rationalp-mod
  (implies (rationalp x)
           (rationalp (mod x y)))
  :rule-classes (:rewrite :type-prescription))

(defthm floor-mod-elim
  (implies (acl2-numberp x)
	   (equal (+ (mod x y)
		     (* y (floor x y)))
		  x))
  :rule-classes ((:rewrite)
		 (:elim)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Simple linear (and generalize) rules about floor and mod

;;; At one time I had tried theorems such as:
#|
(defthm linear-floor-bounds-1-negative-y
  (implies (and (rationalp (/ x y))
		(< y 0))
	   (and (< (* y (floor x y))
		   (+ x (- y)))
		(<= x
		    (* y (floor x y)))))
  :hints (("Goal" :in-theory (disable floor)))
  :rule-classes ((:linear :trigger-terms ((floor x y)))))
|#
;;; for both linear and generalization, which were supposedly better
;;; in that they didn't use division, but this turned out not to be
;;; true.  The linear rules caused excessive thrashing, adn the
;;; generalization rules caused justify-floor-recursion to fail
;;; with the subgoal:
#|
(thm
(IMPLIES (AND (RATIONALP R)
              (INTEGERP I)
              (< I -1)
              (< R Y)
              (< 0 R)
              (RATIONALP Y)
              (<= 2 Y))
         (< (+ R (* I Y)) I)))
|#
;;; Note that the original ``equivalent'' subgoal:
#|
(thm
(IMPLIES (AND (RATIONALP R)
              (INTEGERP I)
              (< I -1)
              (< R Y)
              (< 0 R)
              (< (* R (/ Y)) 1)
              (RATIONALP Y)
              (<= 2 Y))
         (< (+ R (* I Y)) I)))
|#
;;; succeeds.  I have not spent enough time to figure out why the
;;; second works.  I do not understand my own nonlinear arithemtic
;;; code it seems.  Math is hard.

;;; Update: The first thm above now gets proven.  I had a bug in
;;; the nonlinear routines.  This has been fixed in v3-4.  See
;;; the release notes and search for ``optimization''.

(defthm linear-floor-bounds-1
  (implies (rationalp (/ x y))
	   (and (< (+ (/ x y) -1)
		   (floor x y))
		(<= (floor x y)
		    (/ x y))))
  :rule-classes ((:generalize)
		 (:linear :trigger-terms ((floor x y)))))

(defthm linear-floor-bounds-2
  (implies (integerp (/ x y))
	   (equal (floor x y)
		  (/ x y)))
  :rule-classes ((:generalize)
		 (:linear :trigger-terms ((floor x y)))))

(defthm linear-floor-bounds-3
  (implies (and (rationalp (/ x y))
		(not (integerp (/ x y))))
	   (< (floor x y)
	      (/ x y)))
  :rule-classes ((:generalize)
		 (:linear :trigger-terms ((floor x y)))))

 (defthm mod-bounds-1
   (implies (and (rationalp (/ x y))
		 (< 0 y))
	    (and (<= 0 (mod x y))
		 (< (mod x y) y)))
   :rule-classes ((:generalize)
		  (:linear))
   :otf-flg t)

 (defthm mod-bounds-2
   (implies (and (rationalp (/ x y))
		 (< y 0))
	    (and (<= (mod x y) 0)
		 (< y (mod x y))))
   :rule-classes ((:generalize)
		  (:linear))
   :otf-flg t)

(defthm mod-bounds-3
  (implies (and (acl2-numberp y)
		(integerp (/ x y))
		(not (equal y 0)))
	   (equal 0 (mod x y)))
  :rule-classes ((:generalize)
		 (:linear)))

(deftheory floor-bounds
    '((:linear linear-floor-bounds-1)
      (:linear linear-floor-bounds-2)
      (:linear linear-floor-bounds-3)))

(deftheory mod-bounds
    '((:linear mod-bounds-1)
      (:linear mod-bounds-2)
      (:linear mod-bounds-3)))

(deftheory floor-mod-bounds
    '((:linear linear-floor-bounds-1)
      (:linear linear-floor-bounds-2)
      (:linear linear-floor-bounds-3)
      (:linear mod-bounds-1)
      (:linear mod-bounds-2)
      (:linear mod-bounds-3)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; A few more inequalities rules, and some type-prescriptions

;;; I have tried making the inequalities in this section :linear rules
;;; also; but, even with a :backchain-limit-lst 1, it was too
;;; expensive.  Perhaps if one could check whether the concl of a
;;; :linear rule was poly-weakerp than already known polys, we could
;;; avoid some of this expense.  That is, if a :type-prescription rule
;;; or an earlier :linear rule was successful, we wouldn't keep
;;; trying.  But even this might not be enough.

(in-theory (disable floor mod))

;;; What did I mean by the below comment?

;;; Note that floor-nonnegative-1, as an equality like floor-positive,
;;; is subsumed by floor-negative.  Also that floor-nonpositive-1, as
;;; an equality like floor-positive, is false.  Hence the lack of
;;; symmetry in the sets of rules.

(defthm floor-nonnegative
  (implies (and (rationalp (/ x y))
		(<= 0 (/ x y)))
	   (<= 0 (floor x y)))
  :rule-classes ((:rewrite :backchain-limit-lst (3 1))
		 (:rewrite 
		  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= 0 y)
				(<= 0 x))
			   (<= 0 (floor x y))))
		 (:rewrite 
		  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= y 0)
				(<= x 0))
			   (<= 0 (floor x y))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= 0 (/ x y)))
			   (and (integerp (floor x y))
				(<= 0 (floor x y)))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= 0 y)
				(<= 0 x))
			   (and (integerp (floor x y))
				(<= 0 (floor x y)))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= y 0)
				(<= x 0))
			   (and (integerp (floor x y))
				(<= 0 (floor x y))))))
  :hints (("Goal" :in-theory (disable |(< (* x (/ y)) 0) rationalp (* x (/ y))|
				      |(< 0 (* x (/ y))) rationalp (* x (/ y))|
				      |(< (* x y) 0) rationalp (* x y)|
				      |(< 0 (* x y)) rationalp (* x y)|)))
  :otf-flg t)

(defthm floor-nonpositive
  (implies (and (rationalp (/ x y))
		(<= (/ x y) 0))
	   (<= (floor x y) 0))
  :rule-classes ((:rewrite :backchain-limit-lst (3 1))
		 (:rewrite 
		  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				;(rationalp y)
				(<= 0 y)
				(<= x 0))
			   (<= (floor x y) 0)))
		 (:rewrite 
		  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				;(rationalp y)
				(<= y 0)
				(<= 0 x))
			   (<= (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= (/ x y) 0))
			   (and (integerp (floor x y))
				(<= (floor x y) 0))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				;(rationalp y)
				(<= 0 y)
				(<= x 0))
			   (and (integerp (floor x y))
				(<= (floor x y) 0))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				;(rationalp y)
				(<= y 0)
				(<= 0 x))
			   (and (integerp (floor x y))
				(<= (floor x y) 0))))))

(defthm floor-positive
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
                (rationalp (/ x y)))
           (equal (< 0 (floor x y))
                  (or (and (< 0 y)
                           (<= y x))
                      (and (< y 0)
                           (<= x y)))))
  :rule-classes ((:rewrite)
		 (:rewrite
                  :backchain-limit-lst (nil 3 1)
		  :corollary
		  (implies (and (syntaxp 
                                 (not (rewriting-goal-literal x mfc state)))
                                (rationalp (/ x y))
				(<= 1 (/ x y)))
                           (< 0 (floor x y))))
		 (:rewrite
                  :backchain-limit-lst (nil 3 1 1)
		  :corollary
		  (implies (and (syntaxp 
                                 (not (rewriting-goal-literal x mfc state)))
                                (rationalp (/ x y))
                                (< 0 y)
                                (<= y x))
                           (< 0 (floor x y))))
		 (:rewrite
                  :backchain-limit-lst (nil 3 1 1)
		  :corollary
		  (implies (and (syntaxp 
                                 (not (rewriting-goal-literal x mfc state)))
                                (rationalp (/ x y))
                                (< y 0)
                                (<= x y))
			   (< 0 (floor x y))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(<= 1 (/ x y)))
			   (and (integerp (floor x y))
				(< 0 (floor x y)))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (< 0 y)
                                (<= y x))
			   (and (integerp (floor x y))
				(< 0 (floor x y)))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (< y 0)
                                (<= x y))
			   (and (integerp (floor x y))
				(< 0 (floor x y))))))
  :otf-flg t)

(defthm floor-negative
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		(rationalp (/ x y)))
	   (equal (< (floor x y) 0)
		  (or (and (< 0 x)
			   (< y 0))
		      (and (< x 0)
			   (< 0 y)))))
  :rule-classes ((:rewrite)
		 (:rewrite
		  :backchain-limit-lst (nil 3 1)
		  :corollary
		  (implies (and (syntaxp 
				 (not (rewriting-goal-literal x mfc state)))
				(rationalp (/ x y))
				(< (/ x y) 0))
			   (< (floor x y) 0)))
		 (:rewrite
		  :backchain-limit-lst (nil 3 1 1)
		  :corollary
		  (implies (and (syntaxp 
				 (not (rewriting-goal-literal x mfc state)))
				(rationalp (/ x y))
				(< 0 x)
				(< y 0))
			   (< (floor x y) 0)))
		 (:rewrite
		  :backchain-limit-lst (nil 3 1 1)
		  :corollary
		  (implies (and (syntaxp 
				 (not (rewriting-goal-literal x mfc state)))
				(rationalp (/ x y))
				(< x 0)
				(< 0 y))
			   (< (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< (/ x y) 0))
			   (and (integerp (floor x y))
				(< (floor x y) 0))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< 0 x)
				(< y 0))
			   (and (integerp (floor x y))
				(< (floor x y) 0))))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< x 0)
				(< 0 y))
			   (and (integerp (floor x y))
				(< (floor x y) 0)))))
  :otf-flg t)

(defthm floor-zero
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		(acl2-numberp y)
                (rationalp (/ x y)))
           (equal (equal (floor x y) 0)
                  (or (equal y 0)
                      (and (<= 0 x)
                           (< x y))
                      (and (<= x 0)
                           (< y x)))))
  :rule-classes ((:rewrite)
		 (:rewrite
                  :backchain-limit-lst (3 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (equal y 0))
			   (equal (floor x y) 0)))
		 (:rewrite
                  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= 0 (/ x y))
				(< (/ x y) 1))
			   (equal (floor x y) 0)))
		 (:rewrite
                  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= 0 x)
				(< x y))
			   (equal (floor x y) 0)))
		 (:rewrite
		  :backchain-limit-lst (3 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= x 0)
				(< y x))
			   (equal (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (equal y 0))
			   (equal (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= 0 (/ x y))
				(< (/ x y) 1))
			   (equal (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= 0 x)
				(< x y))
			   (equal (floor x y) 0)))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp (/ x y))
                                (<= x 0)
				(< y x))
			   (equal (floor x y) 0))))
  :hints (("Goal" :cases ((< 0 (floor x y))
			  (< (floor x y) 0)))))

(defthm floor-x-y-=-1
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		(rationalp (/ x y)))
           (equal (equal (floor x y) 1)
		  (or (and (< 0 y)
			   (<= y x)
			   (< x (* 2 y)))
		      (and (< y 0)
			   (<= x y)
			   (< (* 2 y) x)))))
  :rule-classes ((:rewrite)
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< 0 y)
				(<= y x)
				(< x (* 2 y)))
			   (equal (floor x y) 1)))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< y 0)
				(<= x y)
				(< (* 2 y) x))
			   (equal (floor x y) 1))))
  :hints (("Goal" :cases ((< (floor x y) 1)
			  (< 1 (floor x y))))
	  ("Subgoal 3.6" :in-theory (enable floor)))
  :otf-flg t)

(defthm floor-x-y-=--1
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		(rationalp (/ x y)))
           (equal (equal (floor x y) -1)
		  (or (and (< 0 y)
			   (< x 0)
			   (<= (- x) y))
		      (and (< y 0)
			   (< 0 x)
			   (<= x (- y))))))
  :rule-classes ((:rewrite)
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< 0 y)
				(< x 0)
				(<= (- x) y))
			   (equal (floor x y) -1)))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
		  :corollary
		  (implies (and (rationalp (/ x y))
				(< y 0)
				(< 0 x)
				(<= x (- y)))
			   (equal (floor x y) -1))))
  :hints (("Goal" :cases ((< -1 (floor x y))
			  (< (floor x y) -1)))))


(defthm floor-=-x/y
  (equal (equal (floor x y) (* x (/ y)))
	 (integerp (/ x y)))
  :rule-classes ((:rewrite
		  :corollary
		  (implies (integerp (/ x y))
			   (equal (floor x y)
				  (/ x y))))
		 (:rewrite
		  :corollary
		  (implies (equal (* x (/ y)) z)
			   (equal (equal (floor x y) z)
				  (integerp z))))))

(defthm mod-nonnegative
  (implies (and (rationalp (/ x y))
		(< 0 y))
	   (<= 0 (mod x y)))
  :rule-classes ((:rewrite :backchain-limit-lst (3 1))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp x)
				(rationalp y)
				(< 0 y))
			   (and (rationalp (mod x y))
				(<= 0 (mod x y)))))))

(defthm mod-nonpositive
  (implies (and (rationalp (/ x y))
		(< y 0))
	   (<= (mod x y) 0))
  :rule-classes ((:rewrite :backchain-limit-lst (3 1))
		 (:type-prescription
		  :corollary
		  (implies (and (rationalp x)
				(rationalp y)
				(< y 0))
			   (and (rationalp (mod x y))
				(<= (mod x y) 0))))))

(defthm mod-positive
    (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		  (acl2-numberp y)
                  (rationalp (/ x y)))
             (equal (< 0 (mod x y))
                    (or (and (equal y 0)
                             (< 0 x))
                        (and (< 0 y)
                             (not (integerp (/ x y)))))))
  :rule-classes ((:rewrite)
                 (:rewrite
                  :backchain-limit-lst (nil 1 1)
		  :corollary
		   (implies (and (syntaxp 
                                  (not (rewriting-goal-literal x mfc state)))
                                 ;(rationalp (/ x y))
                                 (equal y 0)
                                 (< 0 x))
                            (< 0 (mod x y))))
                 (:rewrite
                  :backchain-limit-lst (nil 3 3 1)
		  :corollary
		   (implies (and (syntaxp 
                                  (not (rewriting-goal-literal x mfc state)))
                                 (rationalp (/ x y))
                                 (not (integerp (/ x y)))
                                 (< 0 y))
                            (< 0 (mod x y))))
                 (:type-prescription
		  :corollary
		   (implies (and ;(rationalp (/ x y))
				 ;(rationalp y)
			         (rationalp x)
                                 (equal y 0)
                                 (< 0 x))
			   (and (rationalp (mod x y))
				(< 0 (mod x y)))))
                 (:type-prescription
		  :corollary
		   (implies (and (rationalp x)
				 (rationalp y)
                                 (not (integerp (/ x y)))
                                 (< 0 y))
			   (and (rationalp (mod x y))
				(< 0 (mod x y)))))))

(defthm mod-negative
    (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		  (acl2-numberp y)
                  (rationalp (/ x y)))
             (equal (< (mod x y) 0)
                    (or (and (equal y 0)
                             (< x 0))
                        (and (< y 0)
                             (not (integerp (/ x y)))))))
  :rule-classes ((:rewrite)
                 (:rewrite
                  :backchain-limit-lst (nil 1 1)
		  :corollary
		   (implies (and (syntaxp 
                                  (not (rewriting-goal-literal x mfc state)))
                                 ;(rationalp (/ x y))
                                 (equal y 0)
                                 (< x 0))
                            (< (mod x y) 0)))
                 (:rewrite
                  :backchain-limit-lst (nil 3 3 1)
		  :corollary
		   (implies (and (syntaxp 
                                  (not (rewriting-goal-literal x mfc state)))
                                 (rationalp (/ x y))
                                 (not (integerp (/ x y)))
                                 (< y 0))
                            (< (mod x y) 0)))
                 (:type-prescription
		  :corollary
		   (implies (and ;(rationalp (/ x y))
				 ;(rationalp y)
			         (rationalp x)
                                 (equal y 0)
                                 (< x 0))
			   (and (rationalp (mod x y))
				(< (mod x y) 0))))
                 (:type-prescription
		  :corollary
		   (implies (and ;(rationalp (/ x y))
				 (rationalp y)
			         (rationalp x)
                                 (not (integerp (/ x y)))
                                 (< y 0))
			   (and (rationalp (mod x y))
				(< (mod x y) 0))))))

(defthm mod-x-y-=-x
    (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		  (acl2-numberp x)
		  (acl2-numberp y)
                  (rationalp (/ x y)))
             (equal (equal (mod x y) x)
                    (or (equal y 0)
                        (and (<= 0 x)
                             (< x y))
                        (and (<= x 0)
                             (< y x)))))
  :rule-classes ((:rewrite)
                 (:rewrite
                  :backchain-limit-lst (1 3 1)
                  :corollary
                  (implies (and (acl2-numberp x)
                                (rationalp (/ x y))
                                (equal y 0))
                           (equal (mod x y) x)))
                 (:rewrite
                  :backchain-limit-lst (1 3 1 1)
                  :corollary
                  (implies (and (acl2-numberp x)
                                 (rationalp (/ x y))
                                (<= 0 x)
                                (< x y))
                           (equal (mod x y) x)))
                 (:rewrite
                  :backchain-limit-lst (1 3 1 1)
                  :corollary
                  (implies (and (acl2-numberp x)
                                 (rationalp (/ x y))
                                (<= x 0)
                                (< y x))
                           (equal (mod x y) x)))))

;;; This is a bad rule, as a rewrite rule.  I should not
;;; move mods to integerp.

(defthm mod-zero
  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
		(acl2-numberp x)
		(acl2-numberp y)
                (rationalp (/ x y)))
           (equal (equal (mod x y) 0)
                  (or (equal x 0)
                      (and (not (equal y 0))
                           (integerp (/ x y))))))
  :rule-classes (;;;(:rewrite)   ;;; Bad part.
		 (:rewrite
                  :backchain-limit-lst (1 3 1)
                  :corollary
                  (implies (and (acl2-numberp x)
				(rationalp (/ x y))
				(equal y 0))
			   (equal (equal (mod x y) 0)
				  (equal x 0))))
                 (:rewrite
                  :backchain-limit-lst (1 3 1)
                  :corollary
                  (implies (and (acl2-numberp y)
                                (integerp (/ x y))
                                ;(rationalp (/ x y))
                                (not (equal y 0)))
                           (equal (mod x y) 0)))
                 (:rewrite
                  :backchain-limit-lst (3 1)
                  :corollary
                  (implies (and (rationalp (/ x y))
                                (equal x 0))
                           (equal (mod x y) 0)))
                 (:type-prescription
                  :corollary
                  (implies (and (acl2-numberp y)
                                (integerp (/ x y))
				;(rationalp (/ x y))
                                (not (equal y 0)))
                           (equal (mod x y) 0)))
                 (:type-prescription
                  :corollary
                  (implies (and (rationalp (/ x y))
                                (equal x 0))
                           (equal (mod x y) 0)))))

(defthm mod-zero-2
  (equal (mod x x) 0)
  :hints (("Goal" :cases ((equal x 0))))
  :rule-classes (:rewrite :type-prescription))

(defthm mod-x-y-=-x+y
  (implies (and ;(acl2-numberp x)
		(acl2-numberp y)
		(rationalp (/ x y)))
           (equal (equal (mod x y) (+ x y))
		  (or (equal y 0)
		      (and (< 0 y)
			   (< x 0)
			   (<= (- x) y))
		      (and (< y 0)
			   (< 0 x)
			   (<= x (- y))))))
  :rule-classes ((:rewrite
		  :corollary
		  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
				(acl2-numberp y)
				(rationalp (/ x y))
				(equal (+ x y) z))
			   (equal (equal (mod x y) z)
				  (or (equal y 0)
				      (and (< 0 y)
					   (< x 0)
					   (<= (- x) y))
				      (and (< y 0)
					   (< 0 x)
					   (<= x (- y)))))))
;;               same as mod-x-y-=-x
;		 (:rewrite
;                  :backchain-limit-lst 1
;                  :corollary
;		  (implies (and (rationalp (/ x y))
;				(equal y 0))
;			   (equal (mod x y) (+ x y))))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
                  :corollary
		  (implies (and (rationalp (/ x y))
				(< 0 y)
				(< x 0)
				(<= (- x) y))
			   (equal (mod x y) (+ x y))))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
                  :corollary
		  (implies (and (rationalp (/ x y))
				(< y 0)
				(< 0 x)
				(<= x (- y)))
			   (equal (mod x y) (+ x y)))))
  :hints (("Goal" :cases ((< (mod x y) (+ x y))
			  (< (+ x y) (mod x y))))))

(defthm mod-x-y-=-x-y
  (implies (and ;(acl2-numberp x)
		(acl2-numberp y)
		(rationalp (/ x y)))
           (equal (equal (mod x y) (+ x (- y)))
		  (or (equal y 0)
		      (and (< 0 y)
			   (<= y x)
			   (< x (* 2 y)))
		      (and (< y 0)
			   (<= x y)
			   (< (* 2 y) x)))))
  :rule-classes ((:rewrite
		  :corollary
		  (implies (and (syntaxp (rewriting-goal-literal x mfc state))
				(acl2-numberp y)
				(rationalp (/ x y))
				(equal (+ x (- y)) z))
			   (equal (equal (mod x y) z)
				  (or (equal y 0)
				      (and (< 0 y)
					   (<= y x)
					   (< x (* 2 y)))
				      (and (< y 0)
					   (<= x y)
					   (< (* 2 y) x))))))
;;               same as mod-x-y-=-x
;		 (:rewrite
;                  :backchain-limit-lst 1
;                  :corollary
;		  (implies (and (rationalp (/ x y))
;				(equal y 0))
;			   (equal (mod x y) (+ x y))))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
                  :corollary
		  (implies (and (rationalp (/ x y))
				(< 0 y)
				(<= y x)
				(< x (* 2 y)))
			   (equal (mod x y) (+ x (- y)))))
		 (:rewrite
                  :backchain-limit-lst (3 1 1 1)
                  :corollary
		  (implies (and (rationalp (/ x y))
				(< y 0)
				(<= x y)
				(< (* 2 y) x))
			   (equal (mod x y) (+ x (- y))))))
  :hints (("Goal" :cases ((< (mod x y) (+ x (- y)))
			  (< (+ x (- y)) (mod x y)))
	          :in-theory (enable mod))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; More simple reductions

(defthm |(mod x 2)|
  (implies (integerp x)
           (equal (mod x 2)
                  (if (integerp (* 1/2 x))
                      0
                    1)))
  :rule-classes ((:rewrite)
		 (:generalize
		  :corollary
		  (implies (integerp x)
			   (or (equal (mod x 2) 0)
			       (equal (mod x 2) 1))))))

;;; We want these rules to be seen first, so we include them last.

(defthm |(floor x 0)|
    (equal (floor x 0)
	   0))

(defthm |(floor 0 y)|
  (equal (floor 0 y)
	 0))

(defthm |(mod x 0)|
    (equal (mod x 0)
	   (if (acl2-numberp x)
	       x
	     0)))

(defthm |(mod 0 y)|
  (equal (mod 0 y)
	 0))

(defthm |(floor x 1)|
    (implies (integerp x)
             (equal (floor x 1)
                    x)))

(defthm |(mod x 1)|
    (implies (integerp x)
             (equal (mod x 1)
                    0)))
