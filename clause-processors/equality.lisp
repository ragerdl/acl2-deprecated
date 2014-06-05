; Equality Substitution Clause Processor
; Copyright (c) 2007-2010 Jared Davis <jared@cs.utexas.edu>
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
; USA.
;
; Modified for v3-4 by Matt K.: or-list and and-list are now defined in ACL2.
;
; Modified for v4-2 by Jared: this book was initially intended to be an
; pedagogical example of a simple, verified clause processor.  Because of this,
; it formerly did "bad" things like defining "evl" and "evl-list" (which isn't
; very nice to the namespace) and theorems like "lemma".  I've now cleaned this
; up by renaming things and more appropriately using local, and added some
; documentation.

(in-package "ACL2")
(local (include-book "tools/flag" :dir :system))

; We introduce EQUALITY-SUBSTITUTE-CLAUSE, which allows you to manually apply
; equality substitutions through a clause.
;
; Given an alist of the form ((lhs_1 . rhs_1) ... (lhs_N . rhs_N)), where each
; lhs_i and rhs_i is a "translated" term, i.e., a pseudo-termp, this clause
; processor allows you to simplify the goal clause by replacing every instance
; of lhs_i with rhs_i.
;
; For example, suppose our goal is:
;
;   (implies (equal a b)
;            (baz a c))
;
; Then, given the alist ((A . B) (C . D)), our clause processor will produce
; three new subgoals.
;
; The "main" subgoal is the reduction you would expect, where everywhere we
; have replaced A with B and C with D:
;
;   (implies (equal b b)
;            (baz b d))
;
; The other, "justifying" subgoals try to show that the substitutions we've
; made are valid, and have the form:
;
;   (implies (not (equal lhs_i rhs_i))
;            original-clause)
;
; There is one such subgoal for each substitution we applied.  For the first
; substitution, this justifying subgoal is:
;
;   (implies (not (equal a b))
;            (implies (equal a b) (baz a c)))
;
; Which is easily reduced to T.  For the second substitution, the justifying
; subgoal is:
;
;   (implies (not (equal b d))
;            (implies (equal a b) (baz a c)))
;
; Which may not be any easier to prove than the original clause.  In general,
; you should typically only substitute terms that are actually equal.

(defconst *esc-disables*
  '(disjoin disjoin2 conjoin conjoin2))

(make-event
 (prog2$ (cw "Note (from clause-processors/equality): disabling ~&0.~%~%"
             *esc-disables*)
         '(value-triple :invisible))
 :check-expansion t)

(in-theory (set-difference-theories (current-theory :here)
                                    *esc-disables*))

(defund iff-list (x y)
  (if (and (consp x)
           (consp y))
      (and (iff (car x) (car y))
           (iff-list (cdr x) (cdr y)))
    (and (not (consp x))
         (not (consp y)))))

(local (in-theory (enable iff-list)))

(encapsulate
 ()
 (defthm iff-list-reflexive
   (iff-list x x))

 (defthm iff-list-symmetric
   (implies (iff-list x y)
            (iff-list y x)))

 (defthm iff-list-transitive
   (implies (and (iff-list x y)
                 (iff-list y z))
            (iff-list x z)))

 (defequiv iff-list))

(defcong iff-list equal (or-list x) 1)

(defcong iff-list equal (and-list x) 1)



; The prefix "esc-", short for "equality substitute clause", is just to avoid
; namespace clashes with other evaluators.

(defevaluator esc-eval esc-eval-list
  ((if x y z) (equal x y) (not x)))

(local (defthm esc-eval-of-arbitrary-function
         (implies
          (and (symbolp fn)
               (not (equal fn 'quote))
               (equal (esc-eval-list args1 env)
                      (esc-eval-list args2 env)))
          (equal (esc-eval (cons fn args1) env)
                 (esc-eval (cons fn args2) env)))
         :hints (("goal" :use ((:instance esc-eval-constraint-0
                                          (x (cons fn args1))
                                          (a env))
                               (:instance esc-eval-constraint-0
                                          (x (cons fn args2))
                                          (a env)))))))

(defthm esc-eval-of-disjoin2
  (iff (esc-eval (disjoin2 t1 t2) env)
       (or (esc-eval t1 env)
           (esc-eval t2 env)))
  :hints(("Goal" :in-theory (enable disjoin2))))

(defthm esc-eval-of-disjoin
  (iff (esc-eval (disjoin x) env)
       (or-list (esc-eval-list x env)))
  :hints(("Goal" :in-theory (enable disjoin))))

(defthm esc-eval-of-conjoin2
  (iff (esc-eval (conjoin2 t1 t2) env)
       (and (esc-eval t1 env)
            (esc-eval t2 env)))
  :hints(("Goal" :in-theory (enable conjoin2))))

(defthm esc-eval-of-conjoin
  (iff (esc-eval (conjoin x) env)
       (and-list (esc-eval-list x env)))
  :hints(("Goal" :in-theory (enable conjoin))))



(defund esc-alist-p (x)
  "Recognizes an alist whose keys and values are all pseudo-terms."
  (declare (xargs :guard t))
  (if (atom x)
      (not x)
    (and (consp (car x))
         (pseudo-termp (car (car x)))
         (pseudo-termp (cdr (car x)))
         (esc-alist-p (cdr x)))))

(defthm esc-alist-p-when-atom
  (implies (atom x)
           (equal (esc-alist-p x)
                  (not x)))
  :hints(("Goal" :in-theory (enable esc-alist-p))))

(defthm esc-alist-p-of-cons
  (equal (esc-alist-p (cons a x))
         (and (consp a)
              (pseudo-termp (car a))
              (pseudo-termp (cdr a))
              (esc-alist-p x)))
  :hints(("Goal" :in-theory (enable esc-alist-p))))

(defthm alistp-when-esc-alist-p
  (implies (esc-alist-p x)
           (alistp x))
  :hints(("Goal" :induct (len x))))



(defund esc-alist-to-equalities (x)
  "Convert an esc-alist-p into a list of (equal key val) terms."
  (declare (xargs :guard (esc-alist-p x)))
  (if (atom x)
      nil
    (cons `(equal ,(car (car x)) ,(cdr (car x)))
          (esc-alist-to-equalities (cdr x)))))

(defthm esc-alist-to-equalities-when-atom
  (implies (atom x)
           (equal (esc-alist-to-equalities x)
                  nil))
  :hints(("Goal" :in-theory (enable esc-alist-to-equalities))))

(defthm esc-alist-to-equalities-of-cons
  (equal (esc-alist-to-equalities (cons a x))
         (cons `(equal ,(car a) ,(cdr a))
               (esc-alist-to-equalities x)))
  :hints(("Goal" :in-theory (enable esc-alist-to-equalities))))

(defthm pseudo-term-listp-of-esc-alist-to-equalities
  (implies (force (esc-alist-p x))
           (equal (pseudo-term-listp (esc-alist-to-equalities x))
                  t))
  :hints(("Goal" :induct (len x))))

(encapsulate
  ()
  (local (defthm lemma1
           (implies (consp (assoc-equal a x))
                    (member `(equal ,a ,(cdr (assoc-equal a x)))
                            (esc-alist-to-equalities x)))
           :hints(("Goal" :induct (len x)))))

  (local (defthm lemma2
           (implies (and (and-list (esc-eval-list x env))
                         (member a x))
                    (iff (esc-eval a env)
                         t))
           :hints(("Goal" :induct (len x)))))

  (local (defthm lemma3
           (implies (and (and-list (esc-eval-list (esc-alist-to-equalities x) env))
                         (consp (assoc-equal a x)))
                    (iff (esc-eval `(equal ,a ,(cdr (assoc-equal a x))) env)
                         t))))

  (defthm esc-eval-of-binding
    (implies (and (and-list (esc-eval-list (esc-alist-to-equalities x) env))
                  (consp (assoc-equal a x)))
             (equal (esc-eval (cdr (assoc-equal a x)) env)
                    (esc-eval a env)))))



(mutual-recursion

 (defund esc-substitute (x alist)
   "Substitute an esc-alist-p into a pseudo-term-p."
   (declare (xargs :guard (and (pseudo-termp x)
                               (esc-alist-p alist))))
   (let ((binding (assoc-equal x alist)))
     (cond ((consp binding)
            (cdr binding))
           ((atom x)
            x)
           ((eq (car x) 'quote)
            x)
           (t
            ;; We've arbitrarily chosen not to descend into lambda bodies.
            (cons (car x) (esc-substitute-list (cdr x) alist))))))

 (defund esc-substitute-list (x alist)
   (declare (xargs :guard (and (pseudo-term-listp x)
                               (esc-alist-p alist))))
   (if (atom x)
       nil
     (cons (esc-substitute (car x) alist)
           (esc-substitute-list (cdr x) alist)))))

(defthm esc-substitute-list-when-atom
  (implies (atom x)
           (equal (esc-substitute-list x alist)
                  nil))
  :hints(("Goal" :in-theory (enable esc-substitute-list))))

(defthm esc-substitute-list-of-cons
  (equal (esc-substitute-list (cons a x) alist)
         (cons (esc-substitute a alist)
               (esc-substitute-list x alist)))
  :hints(("Goal" :in-theory (enable esc-substitute-list))))

(encapsulate
  ()
  ;; Kind of bulky, but this way we don't have to export flag-pseudo-termp.
  (local (flag::make-flag flag-pseudo-termp
                          pseudo-termp
                          :flag-mapping ((pseudo-termp . term)
                                         (pseudo-term-listp . list))))

  (local (defthm-flag-pseudo-termp lemma
           (term (implies (and (pseudo-termp x)
                               (esc-alist-p alist)
                               (and-list (esc-eval-list (esc-alist-to-equalities alist) env)))
                          (equal (esc-eval (esc-substitute x alist) env)
                                 (esc-eval x env))))
           (list (implies (and (pseudo-term-listp lst)
                               (esc-alist-p alist)
                               (and-list (esc-eval-list (esc-alist-to-equalities alist) env)))
                          (equal (esc-eval-list (esc-substitute-list lst alist) env)
                                 (esc-eval-list lst env))))
           :hints(("goal"
                   :induct (flag-pseudo-termp flag x lst)
                   :expand ((esc-substitute x alist))
                   :do-not '(generalize fertilize)
                   :do-not-induct t))))

  (defthm esc-eval-of-esc-substitute
    (implies (and (pseudo-termp x)
                  (esc-alist-p alist)
                  (and-list (esc-eval-list (esc-alist-to-equalities alist) env)))
             (equal (esc-eval (esc-substitute x alist) env)
                    (esc-eval x env))))

  (defthm esc-eval-list-of-esc-substitute-list
    (implies (and (pseudo-term-listp lst)
                  (esc-alist-p alist)
                  (and-list (esc-eval-list (esc-alist-to-equalities alist) env)))
             (equal (esc-eval-list (esc-substitute-list lst alist) env)
                    (esc-eval-list lst env)))))



(defund weaken-clause-with-each-term (terms clause)
  ;; Terms are a list of pseudo-terms, [t1, ..., tn]
  ;; We create the list of clauses, [t1::clause, ..., tn::clause]
  (declare (xargs :guard (and (pseudo-term-listp terms)
                              (pseudo-term-listp clause))))
  (if (atom terms)
      nil
    (cons (cons (car terms) clause)
          (weaken-clause-with-each-term (cdr terms) clause))))

(defthm pseudo-term-list-listp-of-weaken-clause-with-each-term
  (implies (and (force (pseudo-term-listp terms))
                (force (pseudo-term-listp clause)))
           (pseudo-term-list-listp (weaken-clause-with-each-term terms clause)))
  :hints(("Goal" :in-theory (enable weaken-clause-with-each-term))))

(defthm soundness-of-weaken-clause-with-each-term
  (implies (not (or-list (esc-eval-list clause env)))
           (iff-list (esc-eval-list (disjoin-lst (weaken-clause-with-each-term terms clause)) env)
                     (esc-eval-list terms env)))
  :hints(("Goal" :in-theory (enable weaken-clause-with-each-term))))



(defund equality-substitute-clause (clause alist state)
  (declare (xargs :guard (and (state-p state)
                              (pseudo-term-listp clause))
                  :stobjs state))
  (cond
   ((not (esc-alist-p alist))
    (ACL2::prog2$
     (ACL2::cw "equality-substitute-clause invoked with bad alist: ~x0~%" alist)
     (mv t nil state)))
   (t
    (value (cons
            ;; The clause resulting from the substitution.
            (esc-substitute-list clause alist)
            ;; You also have to prove the clause resulting from the substitution.
            (weaken-clause-with-each-term
             (esc-alist-to-equalities alist)
             clause))))))

(defthm correctness-of-equality-substitute-clause
  (implies (and (pseudo-term-listp clause)
                (alistp env)
                (esc-eval (conjoin-clauses (clauses-result (equality-substitute-clause clause alist state))) env))
           (esc-eval (disjoin clause) env))
  :rule-classes :clause-processor
  :hints(("Goal" :in-theory (enable equality-substitute-clause))))



; Here is an application contributed by Erik Reeber (which we make local so
; that it's not exported).

(local
 (progn

   (encapsulate
    (((f *) => *)
     ((g *) => *)
     ((p * *) => *))
    (local (defun f (x) x))
    (local (defun g (x) x))
    (local (defun p (x y) (declare (ignore x y)) t))
    (defthm p-axiom (p (g x) (g y))))

; Define must-succeed and must-fail macros.
   (local (include-book "misc/eval" :dir :system))

   (must-fail ; illustrates why we need a hint
    (defthm p-thm-fail
      (implies (and (equal (f x) (g x))
                    (equal (f y) (g y)))
               (p (f x) (f y)))))

   (defthm p-thm
     (implies (and (equal (f x) (g x))
                   (equal (f y) (g y)))
              (p (f x) (f y)))
     :hints (("Goal"
              :clause-processor
              (:function
               equality-substitute-clause
               :hint
; The following is an alist with entries (old . new), where new is to be
; substituted for old.
               '(((f x) . (g x))
                 ((f y) . (g y)))))))
   ))
