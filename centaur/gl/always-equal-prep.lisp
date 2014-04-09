; GL - A Symbolic Simulation Framework for ACL2
; Copyright (C) 2008-2013 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original author: Sol Swords <sswords@centtech.com>

(in-package "GL")
(include-book "symbolic-arithmetic")
(include-book "g-if")
(include-book "eval-g-base")
(include-book "gl-mbe")
(local (include-book "hyp-fix"))
(local (include-book "eval-g-base-help"))
(local (include-book "clause-processors/find-subterms" :dir :system))
(local (include-book "clause-processors/just-expand" :dir :system))
(local (include-book "centaur/bitops/ihsext-basics" :dir :system))

;; This introduces a symbolic counterpart function for EQUAL (more
;; specifically, for ALWAYS-EQUAL, which is defined as EQUAL) that takes a
;; shortcut.  In many cases, it's easy to tell that two symbolic objects are
;; always equal, or that they're sometimes unequal, but it may be very
;; expensive to determine exactly when they're equal or unequal, which the
;; original symbolic counterpart of EQUAL tries to do in all cases.  This
;; function will instead try to cheaply determine whether the objects are
;; always equal, and if not, it will try to cheaply come up with a
;; counterexample or else produce an APPLY object.  In the counterexample case,
;; the object it produces looks something like this:
;; (g-ite (g-boolean <counterexample-bdd>) nil (g-apply 'equal (list a b))).
;; That is, in some particular case (when <counterexample-bdd> is true) the
;; equality is known to be untrue, and in all other cases it's unknown.
;; In odd cases such as numbers wherein the denominators are nontrivial, we'll
;; just punt and produce an apply object.



;; X and Y should be unequal BDDs.  This produces an environment under which x
;; and y evaluate to opposite values.
(defun ctrex-for-always-equal (x y)
  (declare (xargs :guard t :measure (+ (acl2-count x) (acl2-count y))))
  (if (and (atom x) (atom y))
      nil
    (b* (((mv xa xd) (if (consp x) (mv (car x) (cdr x)) (mv x x)))
         ((mv ya yd) (if (consp y) (mv (car y) (cdr y)) (mv y y))))
      (if (hqual xa ya)
          (cons nil (ctrex-for-always-equal xd yd))
        (cons t (ctrex-for-always-equal xa ya))))))


(defthmd ctrex-for-always-equal-correct
  (implies (and (acl2::ubddp x) (acl2::ubddp y) (not (equal x y)))
           (equal (acl2::eval-bdd x (ctrex-for-always-equal x y))
                  (not (acl2::eval-bdd y (ctrex-for-always-equal x y)))))
  :hints (("goal" :induct (ctrex-for-always-equal x y)
           :in-theory (enable acl2::ubddp acl2::eval-bdd))))


;; This produces an environment under which x and y differ and hyp is true, if
;; one exists.  The first return value is a flag saying whether we succeeded or not.

;; This is used as a helper function for the top-level
;; ctrex-for-always-equal-under-hyp, but it is actually complete; the top-level
;; function just tries to find an easier answer first.
(defun ctrex-for-always-equal-under-hyp1 (x y hypbdd)
  (declare (xargs :guard t))
  (cond ((hqual x y) (mv nil nil))
        ((eq hypbdd nil) (mv nil nil))
        ((atom hypbdd) (mv (not (hqual x y))
                        (ctrex-for-always-equal x y)))
        ((and (atom x) (atom y))
         (mv (not (eq hypbdd nil))
             (ctrex-for-always-equal hypbdd nil)))
        ((eq (cdr hypbdd) nil)
         (mv-let (ok env)
           (ctrex-for-always-equal-under-hyp1
            (if (consp x) (car x) x)
            (if (consp y) (car y) y)
            (car hypbdd))
           (mv ok (cons t env))))
        ((eq (car hypbdd) nil)
         (mv-let (ok env)
           (ctrex-for-always-equal-under-hyp1
            (if (consp x) (cdr x) x)
            (if (consp y) (cdr y) y)
            (cdr hypbdd))
           (mv ok (cons nil env))))
        (t (let ((x1 (acl2::q-and hypbdd x))
                 (y1 (acl2::q-and hypbdd y)))
             (mv (not (hqual x1 y1))
                 (ctrex-for-always-equal x1 y1))))))

(defun ctrex-for-always-equal-under-hyp1-ind (x y hypbdd env)
  (cond ((hqual x y) env)
        ((eq hypbdd nil) env)
        ((atom hypbdd) env)
        ((and (atom x) (atom y))
         env)
        ((eq (cdr hypbdd) nil)
         (ctrex-for-always-equal-under-hyp1-ind
          (if (consp x) (car x) x)
          (if (consp y) (car y) y)
          (car hypbdd)
          (cdr env)))
        ((eq (car hypbdd) nil)
         (ctrex-for-always-equal-under-hyp1-ind
          (if (consp x) (cdr x) x)
          (if (consp y) (cdr y) y)
          (cdr hypbdd)
          (cdr env)))
        (t env)))

(local (in-theory (disable ctrex-for-always-equal-under-hyp1
                           ctrex-for-always-equal
                           acl2::qs-subset-when-booleans
                           acl2::eval-bdd-when-qs-subset
                           equal-of-booleans-rewrite)))

(defthm ctrex-for-always-equal-under-hyp1-correct
  (implies (and (acl2::ubddp x) (acl2::ubddp y) (acl2::ubddp hypbdd)
                  (not (equal (acl2::eval-bdd x env)
                              (acl2::eval-bdd y env)))
                  (acl2::eval-bdd hypbdd env))
             (let ((env (mv-nth 1 (ctrex-for-always-equal-under-hyp1 x y hypbdd))))
               (and (not (equal (acl2::eval-bdd x env)
                                (acl2::eval-bdd y env)))
                    (acl2::eval-bdd hypbdd env))))
    :hints ((acl2::just-induct-and-expand
             (ctrex-for-always-equal-under-hyp1-ind x y hypbdd env)
             :expand-others ((ctrex-for-always-equal-under-hyp1 x y hypbdd)))
            (and stable-under-simplificationp
                 (let ((call (acl2::find-call-lst 'ctrex-for-always-equal
                                                  clause)))
                   (and call
                        `(:use ((:instance ctrex-for-always-equal-correct
                                 (x ,(second call)) (y ,(third call))))
                          :in-theory (disable
                                      ctrex-for-always-equal-correct)))))
            (and (equal (car clause)
                        '(not (equal (acl2::q-binary-and hypbdd x)
                                     (acl2::q-binary-and hypbdd y))))
                 (acl2::bdd-reasoning))
            (and stable-under-simplificationp
                 '(;; :in-theory (e/d (acl2::eval-bdd acl2::ubddp)
                   ;;                 (ctrex-for-always-equal-correct))
                   :expand ((:free (x a b)
                             (acl2::eval-bdd x (cons a b)))
                            (acl2::eval-bdd x env)
                            (acl2::eval-bdd x nil)
                            (acl2::eval-bdd y env)
                            (acl2::eval-bdd y nil)
                            (acl2::eval-bdd hypbdd env)
                            (acl2::eval-bdd hypbdd nil))))))

(defthm ctrex-for-always-equal-under-hyp1-flag-correct
  (implies (and (acl2::ubddp x) (acl2::ubddp y) (acl2::ubddp hypbdd))
           (iff (mv-nth 0 (ctrex-for-always-equal-under-hyp1 x y hypbdd))
                (let ((env (mv-nth 1 (ctrex-for-always-equal-under-hyp1 x y hypbdd))))
                  (and (not (equal (acl2::eval-bdd x env)
                                   (acl2::eval-bdd y env)))
                       (acl2::eval-bdd hypbdd env)))))
    :hints ((acl2::just-induct-and-expand
             (ctrex-for-always-equal-under-hyp1-ind x y hypbdd env)
             :expand-others ((ctrex-for-always-equal-under-hyp1 x y hypbdd)))
            (and stable-under-simplificationp
                 (let ((call (acl2::find-call-lst 'ctrex-for-always-equal
                                                  clause)))
                   (and call
                        `(:use ((:instance ctrex-for-always-equal-correct
                                 (x ,(second call)) (y ,(third call))))
                          :in-theory (disable
                                      ctrex-for-always-equal-correct)))))
            (and stable-under-simplificationp
                 (member-equal '(not (equal (acl2::q-binary-and hypbdd x)
                                            (acl2::q-binary-and hypbdd y)))
                               clause)
                 (acl2::bdd-reasoning))
            (and stable-under-simplificationp
                 '(;; :in-theory (e/d (acl2::eval-bdd acl2::ubddp)
                   ;;                 (ctrex-for-always-equal-correct))
                   :expand ((:free (x a b)
                             (acl2::eval-bdd x (cons a b))))))))


(defun ctrex-for-always-equal-under-hyp (x y hypbdd)
  (declare (xargs :guard t :measure (acl2-count hypbdd)))
  (cond ((hqual x y) (mv nil nil))
        ((eq hypbdd nil) (mv nil nil))
        ((atom hypbdd) (mv (not (hqual x y))
                        (ctrex-for-always-equal x y)))
        ((eq (cdr hypbdd) nil)
         (mv-let (ok env)
           (ctrex-for-always-equal-under-hyp
            (if (consp x) (car x) x)
            (if (consp y) (car y) y)
            (car hypbdd))
           (mv ok (cons t env))))
        ((eq (car hypbdd) nil)
         (mv-let (ok env)
           (ctrex-for-always-equal-under-hyp
            (if (consp x) (cdr x) x)
            (if (consp y) (cdr y) y)
            (cdr hypbdd))
           (mv ok (cons nil env))))
        ;; The bad case here is when x and y are equal wherever the hyp holds
        ;; and unequal everywhere else.
        ;; Possible ways to deal with this: Q-AND the hyp with each arg and
        ;; compare equality, or else recur on the car and then the cdr.
        ;; We take a hybrid approch: recur down the car in hopes of finding an
        ;; easy counterexample, then at each level, use the Q-AND approch on
        ;; the cdr.
        (t (b* (((mv ok env)
                 (ctrex-for-always-equal-under-hyp
                  (if (consp x) (car x) x)
                  (if (consp y) (car y) y)
                  (car hypbdd)))
                ((when ok) (mv t (cons t env)))
                ((mv ok env)
                 (ctrex-for-always-equal-under-hyp1
                  (if (consp x) (cdr x) x)
                  (if (consp y) (cdr y) y)
                  (cdr hypbdd))))
             (mv ok (cons nil env))))))

(defun ctrex-for-always-equal-under-hyp-ind (x y hypbdd env)
  (declare (xargs :measure (acl2-count hypbdd)))
  (cond ((hqual x y) env)
        ((eq hypbdd nil) env)
        ((atom hypbdd) env)
        ((eq (cdr hypbdd) nil)
         (ctrex-for-always-equal-under-hyp-ind
            (if (consp x) (car x) x)
            (if (consp y) (car y) y)
            (car hypbdd)
            (cdr env)))
        ((eq (car hypbdd) nil)
         (ctrex-for-always-equal-under-hyp-ind
            (if (consp x) (cdr x) x)
            (if (consp y) (cdr y) y)
            (cdr hypbdd)
            (cdr env)))
        ;; The bad case here is when x and y are equal wherever the hyp holds
        ;; and unequal everywhere else.
        ;; Possible ways to deal with this: Q-AND the hyp with each arg and
        ;; compare equality, or else recur on the car and then the cdr.
        ;; We take a hybrid approch: recur down the car in hopes of finding an
        ;; easy counterexample, then at each level, use the Q-AND approch on
        ;; the cdr.
        (t (ctrex-for-always-equal-under-hyp-ind
            (if (consp x) (car x) x)
            (if (consp y) (car y) y)
            (car hypbdd) (cdr env)))))


(local (in-theory (disable ctrex-for-always-equal-under-hyp
                           set::double-containment)))

(defthm ctrex-for-always-equal-under-hyp-flag-correct
  (implies (and (acl2::ubddp x) (acl2::ubddp y) (acl2::ubddp hyp))
           (iff (mv-nth 0 (ctrex-for-always-equal-under-hyp x y hyp))
                (let ((env (mv-nth 1 (ctrex-for-always-equal-under-hyp x y hyp))))
                  (and (not (equal (acl2::eval-bdd x env)
                                   (acl2::eval-bdd y env)))
                       (acl2::eval-bdd hyp env)))))
  :hints ((acl2::just-induct-and-expand
           (ctrex-for-always-equal-under-hyp-ind x y hyp env)
           :expand-others ((ctrex-for-always-equal-under-hyp x y hyp)))
          (and stable-under-simplificationp
               (b* ((call (acl2::find-call-lst 'ctrex-for-always-equal
                                               clause))
                    ((when call)
                     `(:use ((:instance ctrex-for-always-equal-correct
                              (x ,(second call)) (y ,(third call))))
                       :in-theory (disable
                                   ctrex-for-always-equal-correct))))
                 nil))
          ;; (and (equal (car clause)
          ;;             '(not (equal (acl2::q-binary-and hyp x)
          ;;                          (acl2::q-binary-and hyp y))))
          ;;      (acl2::bdd-reasoning))
          (and stable-under-simplificationp
               '(;; :in-theory (e/d (acl2::eval-bdd acl2::ubddp)
                 ;;                 (ctrex-for-always-equal-correct))
                 :expand ((:free (x a b)
                           (acl2::eval-bdd x (cons a b)))
                          (acl2::eval-bdd x env)
                          (acl2::eval-bdd x nil)
                          (acl2::eval-bdd y env)
                          (acl2::eval-bdd y nil)
                          (acl2::eval-bdd hyp env)
                          (acl2::eval-bdd hyp nil))))))

(defthm ctrex-for-always-equal-under-hyp-correct
  (implies (and (acl2::ubddp x) (acl2::ubddp y) (acl2::ubddp hyp)
                (not (equal (acl2::eval-bdd x env)
                            (acl2::eval-bdd y env)))
                (acl2::eval-bdd hyp env))
           (let ((env (mv-nth 1 (ctrex-for-always-equal-under-hyp x y hyp))))
             (and (not (equal (acl2::eval-bdd x env)
                              (acl2::eval-bdd y env)))
                  (acl2::eval-bdd hyp env))))
  :hints ((acl2::just-induct-and-expand
           (ctrex-for-always-equal-under-hyp-ind x y hyp env)
           :expand-others ((ctrex-for-always-equal-under-hyp x y hyp)))
          (and stable-under-simplificationp
               (b* ((call (acl2::find-call-lst 'ctrex-for-always-equal
                                               clause))
                    ((when call)
                     `(:use ((:instance ctrex-for-always-equal-correct
                              (x ,(second call)) (y ,(third call))))
                       :in-theory (disable
                                   ctrex-for-always-equal-correct)))
                    (call (acl2::find-call-lst 'ctrex-for-always-equal-under-hyp1
                                               clause))
                    ((when call)
                     `(:use ((:instance ctrex-for-always-equal-under-hyp1-correct
                              (x ,(second call)) (y ,(third call))
                              (hypbdd ,(fourth call)) (env (cdr env))))
                       :in-theory (disable
                                   ctrex-for-always-equal-under-hyp1-correct))))
                 nil))
          ;; (and (equal (car clause)
          ;;             '(not (equal (acl2::q-binary-and hyp x)
          ;;                          (acl2::q-binary-and hyp y))))
          ;;      (acl2::bdd-reasoning))
          (and stable-under-simplificationp
               '(;; :in-theory (e/d (acl2::eval-bdd acl2::ubddp)
                 ;;                 (ctrex-for-always-equal-correct))
                 :expand ((:free (x a b)
                           (acl2::eval-bdd x (cons a b)))
                          (acl2::eval-bdd x env)
                          (acl2::eval-bdd x nil)
                          (acl2::eval-bdd y env)
                          (acl2::eval-bdd y nil)
                          (acl2::eval-bdd hyp env)
                          (acl2::eval-bdd hyp nil))
                 :do-not-induct t))))





;; (defun always-equal-uu (x y)
;;   (declare (xargs :guard t :measure (+ (acl2-count x) (acl2-count y))))
;;   (if (and (atom x) (atom y))
;;       (mv t nil)
;;     (b* (((mv xa xd) (if (consp x) (mv (car x) (cdr x)) (mv nil nil)))
;;          ((mv ya yd) (if (consp y) (mv (car y) (cdr y)) (mv nil nil)))
;;          ((when (hqual xa ya)) (always-equal-uu xd yd))
;;          (xa (acl2::ubdd-fix xa))
;;          (ya (acl2::ubdd-fix ya))
;;          ((when (hqual xa ya)) (always-equal-uu xd yd)))
;;       (mv nil (ctrex-for-always-equal xa ya)))))

(defun always-equal-ss-under-hyp (x y hypbdd)
  (declare (xargs :guard t :measure (+ (acl2-count x) (acl2-count y))))
  (b* (((mv xa xd xend) (first/rest/end x))
       ((mv ya yd yend) (first/rest/end y))
       ((when (hqual xa ya))
        (if (and xend yend)
            (mv t nil)
          (always-equal-ss-under-hyp xd yd hypbdd)))
       (xa (acl2::ubdd-fix xa))
       (ya (acl2::ubdd-fix ya))
       ((mv diffp res) (ctrex-for-always-equal-under-hyp xa ya hypbdd)))
    (if diffp
        (mv nil res)
      (if (and xend yend)
          (mv t nil)
        (always-equal-ss-under-hyp xd yd hypbdd)))))




(local
 (encapsulate nil

   (local
    (progn

      (defthm equal-of-bool->bit
        (equal (equal (acl2::bool->bit x) (acl2::bool->bit y))
               (iff x y)))

      ;; (defthm even-not-equal-odd
      ;;   (implies (and (evenp x) (evenp y))
      ;;            (not (equal x (+ 1 y)))))

      ;; (defthm *-2-not-minus-1
      ;;   (implies (integerp n)
      ;;            (not (equal (* 2 n) -1)))
      ;;   :hints (("goal" :use ((:instance even-not-equal-odd
      ;;                          (x (* 2 n)) (y -2))))))

      ;; (defthm evenp-ash-1
      ;;   (implies (integerp x)
      ;;            (evenp (ash x 1)))
      ;;   :hints(("Goal" :in-theory (enable ash))))

      ;; (defthm natp-ash-1
      ;;   (implies (natp x)
      ;;            (natp (ash x 1)))
      ;;   :hints(("Goal" :in-theory (enable ash)))
      ;;   :rule-classes :type-prescription)

      ;; (defthm equal-ash-n
      ;;   (implies (and (integerp x) (integerp n))
      ;;            (equal (equal (ash x 1) n)
      ;;                   (equal x (* 1/2 n))))
      ;;   :hints(("Goal" :in-theory (enable ash))))

      ;; (defthm half-of-ash
      ;;   (implies (integerp x)
      ;;            (equal (* 1/2 (ash x 1)) x))
      ;;   :hints(("Goal" :in-theory (enable ash))))
      ))



   ;; (defthm always-equal-uu-correct
   ;;   (mv-let (always-equal ctrex-bdd)
   ;;     (always-equal-uu x y)
   ;;     (implies (and (not (bfr-mode)))
   ;;              (and (implies always-equal
   ;;                            (equal (bfr-list->u x env)
   ;;                                   (bfr-list->u y env)))
   ;;                   (implies (and (not always-equal)
   ;;                                 (bfr-eval ctrex-bdd env))
   ;;                            (not (equal (bfr-list->u x env)
   ;;                                        (bfr-list->u y env)))))))
   ;;   :hints(("Goal"
   ;;           :induct (always-equal-uu x y))
   ;;          '(:use ((:instance ctrex-for-always-equal-correct
   ;;                             (x (and (consp x) (acl2::ubdd-fix (car x))))
   ;;                             (y (and (consp y) (acl2::ubdd-fix (car y)))))
   ;;                  (:instance acl2::eval-bdd-ubdd-fix
   ;;                   (x (car x)))
   ;;                  (:instance acl2::eval-bdd-ubdd-fix
   ;;                   (x (car y))))
   ;;            :in-theory (e/d (bfr-eval bfr-eval-list)
   ;;                            (acl2::eval-bdd-ubdd-fix)))))

   (defthm always-equal-ss-under-hyp-correct
     (mv-let (always-equal ctrex)
       (always-equal-ss-under-hyp x y hyp)
       (and (implies (and always-equal
                          (not (bfr-mode))
                          (acl2::ubddp hyp)
                          (bfr-eval hyp env))
                     (equal (bfr-list->s x env)
                            (bfr-list->s y env)))
            (implies (and (not (bfr-mode))
                          (bfr-eval ctrex-bdd env)
                          (acl2::ubddp hyp)
                          (not always-equal))
                     (and (bfr-eval hyp ctrex)
                          (not (equal (bfr-list->s x ctrex)
                                      (bfr-list->s y ctrex)))))))
     :hints(("Goal" :in-theory (e/d* (ACL2::EQUAL-LOGCONS-STRONG
                                      bfr-list->s bfr-eval scdr s-endp)
                                     (ctrex-for-always-equal-under-hyp
                                      logcons
                                      ctrex-for-always-equal-under-hyp-correct
                                      ctrex-for-always-equal-under-hyp-flag-correct
                                      default-cdr default-car
                                      default-+-1 default-+-2
                                      (:definition always-equal-ss-under-hyp)
                                      (:rules-of-class :type-prescription
                                                       :here))
                                     ((:type-prescription bfr-eval)
                                      (:type-prescription ash)
                                      (:type-prescription bfr-list->s)
                                      (:type-prescription acl2::eval-bdd)))
             :induct (always-equal-ss-under-hyp x y hyp)
             :expand ((always-equal-ss-under-hyp x y hyp)
                      (always-equal-ss-under-hyp x nil hyp)
                      (always-equal-ss-under-hyp nil y hyp)
                      (always-equal-ss-under-hyp nil nil hyp)))
            (and stable-under-simplificationp
                 (b* ((call (acl2::find-call-lst 'ctrex-for-always-equal-under-hyp
                                                 clause))
                      ((when call)
                       `(:use ((:instance ctrex-for-always-equal-under-hyp-correct
                                (x ,(second call)) (y ,(third call)) (hyp ,(fourth call)))
                               (:instance ctrex-for-always-equal-under-hyp-flag-correct
                                (x ,(second call)) (y ,(third call)) (hyp ,(fourth call)))))))
                   nil)))
     :rule-classes ((:rewrite :match-free :all)))))



;; (local
;;  (progn



;;    (defthm bfr-p-always-equal-uu
;;      (implies (not (bfr-mode))
;;               (bfr-p (mv-nth 1 (always-equal-uu a b)))))

;;    (defthm bfr-p-always-equal-ss-under-hyp
;;      (implies (and (not (bfr-mode))
;;                    (bfr-p hyp) (bfr-listp a) (bfr-listp b))
;;               (bfr-p (mv-nth 1 (always-equal-ss-under-hyp a b hyp))))
;;      :hints (("goal" :induct (always-equal-ss-under-hyp a b hyp)
;;               :in-theory (disable (:definition always-equal-ss-under-hyp)))
;;              (and stable-under-simplificationp
;;                   (flag::expand-calls-computed-hint
;;                    clause '(always-equal-ss-under-hyp)))))))



(include-book "ctrex-utils")

(defun always-equal-of-numbers (a b hyp config bvar-db state)
  (declare (xargs :guard (and (not (bfr-mode))
                              (glcp-config-p config)
                              (general-numberp a)
                              (general-numberp b))
                  :stobjs (hyp bvar-db state)))
  (b* (((mv arn ard ain aid)
        (general-number-components a))
       ((mv brn brd bin bid)
        (general-number-components b))
       ((unless (and (equal ard '(T))
                     (equal aid '(T))
                     (equal brd '(T))
                     (equal bid '(T))))
        (prog2$ (cw "Bad denominators: ~x0~%"
                    (list (equal ard '(T))
                          (equal aid '(T))
                          (equal brd '(T))
                          (equal bid '(T))))
                (g-apply 'equal (gl-list a b))))
       (uhyp (acl2::ubdd-fix (bfr-hyp->bfr hyp)))
       ((mv requal rctrex)
        (always-equal-ss-under-hyp arn brn uhyp))
       ((unless requal)
        (ec-call
         (glcp-print-single-ctrex rctrex
                                  "Error:"
                                  "ALWAYS-EQUAL violation"
                                  config bvar-db state))
        (g-apply 'equal (gl-list a b)))
       ((mv iequal ictrex)
        (always-equal-ss-under-hyp ain bin uhyp))
       ((unless iequal)
        (ec-call
         (glcp-print-single-ctrex ictrex
                                  "Error:"
                                  "ALWAYS-EQUAL violation"
                                  config bvar-db state))
        (g-apply 'equal (gl-list a b))))
    t))

(defthm deps-of-always-equal-of-numbers
  (implies (and (not (gobj-depends-on k p a))
                (not (gobj-depends-on k p b))
                (general-numberp a)
                (general-numberp b))
           (not (gobj-depends-on
                 k p (always-equal-of-numbers a b hyp config bvar-db state))))
  :hints(("Goal" :in-theory (enable always-equal-of-numbers))))

;; (local (defthm always-equal-of-numbers-gobjectp
;;          (implies (and (not (bfr-mode))
;;                        (gobjectp a)
;;                        (general-numberp a)
;;                        (gobjectp b)
;;                        (general-numberp b)
;;                        (bfr-p hyp))
;;                   (gobjectp (always-equal-of-numbers a b hyp)))))



(local (defthm eval-g-base-apply-of-equal
         (equal (eval-g-base-ev (list 'equal
                                      (list 'quote x)
                                      (list 'quote y))
                                a)
                (equal x y))))

(local (defthm eval-g-base-apply-of-equal-kwote-lst
         (equal (eval-g-base-ev (cons 'equal
                                      (kwote-lst (list x y)))
                                a)
                (equal x y))))

(local (defthm equal-of-components-to-number-fn
         (implies (and (integerp arn) (integerp ain)
                       (integerp brn) (integerp bin))
                  (equal (equal (components-to-number-fn
                                 arn 1 ain 1)
                                (components-to-number-fn
                                 brn 1 bin 1))
                         (and (equal arn brn)
                              (equal ain bin))))))

(local (defthm bfr-eval-of-ubdd-fix
         (implies (not (bfr-mode))
                  (equal (bfr-eval (acl2::ubdd-fix x) env)
                         (bfr-eval x env)))
         :hints(("Goal" :in-theory (enable bfr-eval)))))

(local (defthm always-equal-of-numbers-correct
         (implies (and (not (bfr-mode))
                       (general-numberp a)
                       (general-numberp b)
                       (bfr-hyp-eval hyp (car env)))
                  (equal (eval-g-base (always-equal-of-numbers
                                       a b hyp config bvar-db state) env)
                         (equal (eval-g-base a env)
                                (eval-g-base b env))))
         :hints(("Goal" :in-theory (e/d* ((:ruleset general-object-possibilities)
                                          ctrex-for-always-equal-correct
                                          boolean-list-bfr-eval-list)
                                         (bfr-sat-bdd-unsat bfr-list->s))))))

(in-theory (disable always-equal-of-numbers))


(defun always-equal-of-booleans (a b hyp config bvar-db state)
  (declare (xargs :guard (and (not (bfr-mode))
                              (glcp-config-p config)
                              (general-booleanp a)
                              (general-booleanp b))
                  :stobjs (hyp bvar-db state)))
  (b* ((av (general-boolean-value a))
       (bv (general-boolean-value b))
       ((when (hqual av bv)) t)
       (av (acl2::ubdd-fix av))
       (bv (acl2::ubdd-fix bv))
       ((when (hqual av bv)) t)
       ((mv unequal ctrex) (ctrex-for-always-equal-under-hyp
                          av bv (acl2::ubdd-fix (bfr-hyp->bfr hyp))))
       ((unless unequal) t))
    (ec-call
     (glcp-print-single-ctrex ctrex
                              "Error:"
                              "ALWAYS-EQUAL violation"
                              config bvar-db state))
    (g-apply 'equal (gl-list a b))))

(defthm deps-of-always-equal-of-booleans
  (implies (and (not (gobj-depends-on k p a))
                (not (gobj-depends-on k p b))
                (general-booleanp a)
                (general-booleanp b))
           (not (gobj-depends-on
                 k p (always-equal-of-booleans a b hyp config bvar-db state))))
  :hints(("Goal" :in-theory (enable always-equal-of-booleans))))

;; (local (defthm always-equal-of-booleans-gobjectp
;;          (implies (and (not (bfr-mode))
;;                        (gobjectp a)
;;                        (general-booleanp a)
;;                        (gobjectp b)
;;                        (general-booleanp b)
;;                        (bfr-p hyp))
;;                   (gobjectp (always-equal-of-booleans a b hyp)))))

(local (defthm ubdd-fixes-unequal
         (implies (not (equal (acl2::eval-bdd a env) (acl2::eval-bdd b env)))
                  (not (equal (acl2::ubdd-fix a) (acl2::ubdd-fix b))))
         :hints (("goal" :in-theory (disable ACL2::EVAL-BDD-UBDD-FIX)
                  :use ((:instance ACL2::EVAL-BDD-UBDD-FIX (x a)
                                   (acl2::env gl::env))
                        (:instance ACL2::EVAL-BDD-UBDD-FIX (x b)
                                   (acl2::env gl::env)))))))

(local (defthm eval-bdd-of-bfr-constr->bfr
         (implies (not (bfr-mode))
                  (equal (acl2::eval-bdd (bfr-constr->bfr hyp) env)
                         (bfr-hyp-eval hyp env)))
         :hints(("Goal" :in-theory (enable bfr-hyp-eval bfr-eval
                                           bfr-constr->bfr)))))

(local (defthm always-equal-of-booleans-correct
         (implies (and (not (bfr-mode))
                       (general-booleanp a)
                       (general-booleanp b)
                       (bfr-hyp-eval hyp (car env)))
                  (equal (eval-g-base (always-equal-of-booleans a b hyp config bvar-db state) env)
                         (equal (eval-g-base a env)
                                (eval-g-base b env))))
         :hints(("Goal" :in-theory (e/d (bfr-eval)
                                        (ctrex-for-always-equal-under-hyp-correct
                                         ctrex-for-always-equal-under-hyp-flag-correct)))
                (and stable-under-simplificationp
                     (b* ((call (acl2::find-call-lst 'ctrex-for-always-equal-under-hyp
                                                     clause))
                          ((when call)
                           `(:use ((:instance ctrex-for-always-equal-under-hyp-correct
                                    (x ,(second call)) (y ,(third call))
                                    (hyp ,(fourth call)) (env (car env)))
                                   (:instance ctrex-for-always-equal-under-hyp-flag-correct
                                    (x ,(second call)) (y ,(third call))
                                    (hyp ,(fourth call)))))))
                       nil)))))

(in-theory (disable always-equal-of-booleans))




(define g-always-equal-core (a b hyp clk config bvar-db state)
  :measure (+ (acl2-count a) (Acl2-count b))
  :guard (and (not (bfr-mode))
              (natp clk)
              (glcp-config-p config))
  :verify-guards nil
  (let* ((hyp (lbfr-hyp-fix hyp)))
    (cond ((hqual a b) (gret t))
          ((and (general-concretep a) (general-concretep b))
           (gret (hons-equal (general-concrete-obj a) (general-concrete-obj b))))
          ((zp clk)
           (gret (g-apply 'equal (gl-list a b))))
          ((or (atom a)
               (not (member-eq (tag a) '(:g-ite :g-var :g-apply))))
           (cond ((or (atom b)
                      (not (member-eq (tag b) '(:g-ite :g-var :g-apply))))
                  (cond
                   ((general-booleanp a)
                    (gret (and (general-booleanp b)
                               (always-equal-of-booleans a b hyp config bvar-db state))))
                   ((general-booleanp b) (gret nil))
                   ((general-numberp a)
                    (gret (and
                           (general-numberp b)
                           (always-equal-of-numbers a b hyp config bvar-db state))))
                   ((general-numberp b) (gret nil))
                   ((general-consp a)
                    (if (general-consp b)
                        (b* (((gret car-equal)
                              (g-always-equal-core
                               (general-consp-car a)
                               (general-consp-car b)
                               hyp clk config bvar-db state)))
                          (if (eq car-equal t)
                              (g-always-equal-core
                               (general-consp-cdr a)
                               (general-consp-cdr b)
                               hyp clk config bvar-db state)
                            (g-if-mbe (gret car-equal)
                                      (gret (g-apply 'equal (gl-list a b)))
                                      (gret nil))))
                      (gret nil)))
                   (t (gret nil))))
                 ((eq (tag b) :g-ite)
                  (if (zp clk)
                      (gret (g-apply 'equal (gl-list a b)))
                    (let* ((test (g-ite->test b))
                           (then (g-ite->then b))
                           (else (g-ite->else b)))
                      (g-if-mbe (gret test)
                                (g-always-equal-core a then hyp clk config bvar-db state)
                                (g-always-equal-core a else hyp clk config bvar-db state)))))
                 (t (gret (g-apply 'equal (gl-list a b))))))
          ((eq (tag a) :g-ite)
           (if (zp clk)
               (gret (g-apply 'equal (gl-list a b)))
             (let* ((test (g-ite->test a))
                    (then (g-ite->then a))
                    (else (g-ite->else a)))
               (g-if-mbe (gret test)
                         (g-always-equal-core then b hyp clk config bvar-db state)
                         (g-always-equal-core else b hyp clk config bvar-db state)))))
          (t (gret (g-apply 'equal (gl-list a b))))))
  ///
  (def-hyp-congruence g-always-equal-core
    :hints(("Goal" :in-theory (disable always-equal-of-numbers
                                       always-equal-of-booleans
                                       (:d g-always-equal-core))
            :induct (g-always-equal-core a b hyp clk config bvar-db state)
            :expand ((:free (hyp) (g-always-equal-core a b hyp clk config bvar-db state))
                     (:free (hyp) (g-always-equal-core a a hyp clk config bvar-db state)))))))
    



(encapsulate nil
  (local (in-theory (e/d* (g-if-fn g-or-fn)
                          (g-always-equal-core
                           equal-of-booleans-rewrite
                           iff-implies-equal-not
                           (:type-prescription true-under-hyp)
                           (:type-prescription false-under-hyp)
                           (:type-prescription general-booleanp)
                           (:type-prescription general-numberp)
                           (:type-prescription acl2::ubddp)
                           (:type-prescription general-concretep)
                           (:type-prescription bfr-=-uu)
                           ;; (:type-prescription assume-true-under-hyp2)
                           ;; (:type-prescription assume-false-under-hyp2)
;(:type-prescription assume-true-under-hyp)
;(:type-prescription assume-false-under-hyp)
                           (:meta mv-nth-cons-meta)
                           zp-open default-<-2 default-<-1
                           (:type-prescription zp)
                           (:type-prescription hyp-fix)
                           default-car default-cdr
                           general-concretep-def
                           ctrex-for-always-equal
                           hyp-fix
                           (:rules-of-class :type-prescription :here)
                           not)
                          ((:type-prescription general-number-components)))))
  (verify-guards g-always-equal-core))


(defthm deps-of-g-always-equal-core
  (implies (and (not (gobj-depends-on k p x))
                (not (gobj-depends-on k p y)))
           (not (gobj-depends-on
                 k p (mv-nth 0 (g-always-equal-core x y hyp clk config bvar-db state)))))
  :hints('(:in-theory (e/d ((:i g-always-equal-core))
                           (gobj-depends-on
                            general-concrete-obj-when-consp-for-eval-g-base)))
         (acl2::just-induct-and-expand
          (g-always-equal-core x y hyp clk config bvar-db state))))

(encapsulate nil

  (local (include-book "clause-processors/just-expand" :dir :system))
  (local
   (in-theory (e/d* (possibilities-for-x-1
                      possibilities-for-x-2
                      possibilities-for-x-3
                      possibilities-for-x-4
                      possibilities-for-x-5
                      possibilities-for-x-6
                      possibilities-for-x-7
                      ;; possibilities-for-x-8
                      possibilities-for-x-9
                      (:i g-always-equal-core)
                      eval-g-base-non-cons
                      general-concretep-atom
                      (:rules-of-class :executable-counterpart :here))
                     ((general-concrete-obj)
                      (general-concretep)
                      (kwote-lst)
                      kwote kwote-lst
                      acl2::member-of-cons
                      always-equal-of-numbers
                      always-equal-of-booleans
                      eval-g-base-alt-def
                      member-equal
                      eval-g-base-ev-of-equal-call
                      eval-g-base-ev-of-variable
                      eval-g-base-list
                      bfr-list->s
                      bfr-list->u
                      bfr-eval-booleanp
                      acl2::subsetp-member
                      components-to-number-alt-def
                      general-concretep-def))))

  (defthm g-always-equal-core-correct
    (implies (and (not (bfr-mode))
                  (bfr-hyp-eval hyp (car env)))
             (equal (eval-g-base (mv-nth 0 (g-always-equal-core x y hyp clk config bvar-db state)) env)
                    (acl2::always-equal (eval-g-base x env)
                                        (eval-g-base y env))))
    :hints ((acl2::just-induct-and-expand
             (g-always-equal-core x y hyp clk config bvar-db state))
            (and stable-under-simplificationp
                 '(:expand ((g-always-equal-core x y hyp clk config bvar-db state)
                            (g-always-equal-core x x hyp clk config bvar-db state)
                            (g-always-equal-core x y hyp clk config bvar-db state)
                            (g-always-equal-core x x hyp clk config bvar-db state)
                            (eval-g-base x env)
                            (eval-g-base y env)
                            (eval-g-base nil env)
                            (eval-g-base t env)
                            (eval-g-base-list nil env))
                   :do-not-induct t)))))

(in-theory (disable g-always-equal-core))
