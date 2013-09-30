; SATLINK - Link from ACL2 to SAT Solvers
; Copyright (C) 2013 Centaur Technology
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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

; cnf.lisp -- Semantics of CNF formulas and basic CNF functions like gathering
; indices, determining maximum indices, etc.

(in-package "SATLINK")
(include-book "varp")
(include-book "litp")
(include-book "tools/clone-stobj" :dir :system)
(include-book "centaur/misc/bitarr" :dir :system)
(local (include-book "data-structures/list-defthms" :dir :system))


(defsection env$
  :parents (cnf)
  :short "A bit array that serves as the environment for @(see eval-formula)."

  (defstobj-clone env$ bitarr
    :exports (env$-length env$-get env$-set env$-resize)))

(local (defthm equal-1-when-bitp
         (implies (bitp x)
                  (equal (equal x 1)
                         (not (equal x 0))))))


(defxdoc cnf
  :parents (satlink)
  :short "Our representation (syntax and semantics) for <a
href='http://en.wikipedia.org/wiki/Conjunctive_normal_form'>conjunctive normal
form</a> formulas."

  :long "<p>To express what it means to call a SAT solver, we need a
representation and a semantics for Boolean formulas in conjunctive normal form.
Our syntax is as follows:</p>

<ul>

<li>A <b>variable</b> is a natural number.  To help keep variables separate
from literals, we represent them @(see varp)s, instead of @(see natp)s.</li>

<li>A <b>literal</b> represents either a variable or a negated variable.  We
represent these using a typical numeric encoding: the least significant bit is
the negated bit, and the remaining bits are the variable.  See @(see
litp).</li>

<li>A <b>clause</b> is a disjunction of literals.  We represent these as
ordinary lists of literals.  See @(see lit-listp).</li>

<li>A <b>formula</b> is a conjunction of clauses.  We represent these using
@(see lit-list-listp).</li>

</ul>

<p>The semantics of these formulas are given by @(see eval-formula).</p>")

(defsection eval-formula
  :parents (cnf)
  :short "Semantics of CNF formulas."

  :long "<p>We define a simple evaluator for CNF formulas that uses an
environment to assign values to the identifiers.</p>

<p>The environment, @(see env$), is an abstract stobj that implements a simple
bit array.  Our evaluators produce a <b>BIT</b> (i.e., 0 or 1) instead of a
BOOL (i.e., T or NIL) to make it directly compatible with the bitarr
stobj.</p>"

  (define eval-var ((var varp) env$)
    :returns (bit bitp)
    :inline t
    (mbe :logic (get-bit (var->index var) env$)
         ;; We'll pay the price of a bounds check just to make the guards
         ;; here much easier to satisfy.
         :exec (if (< (the (integer 0 *) (var->index var))
                      (the (integer 0 *) (bits-length env$)))
                   (get-bit (var->index var) env$)
                 0)))

  (define eval-lit ((lit litp) env$)
    :returns (bit bitp)
    (b-xor (lit->neg lit)
           (eval-var (lit->var lit) env$)))

  (define eval-clause ((clause lit-listp) env$)
    :returns (bit bitp)
    (if (atom clause)
        0
      (b-ior (eval-lit (car clause) env$)
             (eval-clause (cdr clause) env$))))

  (define eval-formula ((formula lit-list-listp) env$)
    :returns (bit bitp)
    (if (atom formula)
        1
      (b-and (eval-clause (car formula) env$)
             (eval-formula (cdr formula) env$)))))



(define fast-max-index-clause ((clause lit-listp) (max natp))
  :parents (max-index-clause)
  :short "Tail-recursive version of @(see max-index-clause)."
  (b* (((when (atom clause))
        max)
       (id1 (var->index (lit->var (car clause))))
       (max (max max id1)))
    (fast-max-index-clause (cdr clause) max)))

(define max-index-clause ((clause lit-listp))
  :returns (max natp :rule-classes :type-prescription)
  :parents (cnf)
  :short "Maximum index of any identifier used anywhere in a clause."
  :verify-guards nil
  (mbe :logic
       (if (atom clause)
           0
         (max (var->index (lit->var (car clause)))
              (max-index-clause (cdr clause))))
       :exec
       (fast-max-index-clause clause 0))
  ///
  (defthm fast-max-index-clause-removal
    (implies (natp max)
             (equal (fast-max-index-clause clause max)
                    (max max (max-index-clause clause))))
    :hints(("Goal" :in-theory (enable fast-max-index-clause))))

  (verify-guards max-index-clause))



(define fast-max-index-formula ((formula lit-list-listp) (max natp))
  :parents (max-index-formula)
  :short "Tail recursive version of @(see max-index-formula)."
  (b* (((when (atom formula))
        max)
       (max (fast-max-index-clause (car formula) max)))
    (fast-max-index-formula (cdr formula) max)))

(define max-index-formula ((formula lit-list-listp))
  :returns (max natp :rule-classes :type-prescription)
  :parents (cnf)
  :short "Maximum index of any identifier used anywhere in a formula."
  :verify-guards nil
  (mbe :logic
       (if (atom formula)
           0
         (max (max-index-clause (car formula))
              (max-index-formula (cdr formula))))
       :exec (fast-max-index-formula formula 0))
  ///
  (defthm fast-max-index-formula-removal
    (implies (natp max)
             (equal (fast-max-index-formula formula max)
                    (max max (max-index-formula formula))))
    :hints(("Goal" :in-theory (enable fast-max-index-formula))))

  (verify-guards max-index-formula))



(define clause-indices ((clause lit-listp))
  :parents (cnf)
  :short "Collect indices of all identifiers used throughout a clause."

  (if (atom clause)
      nil
    (cons (var->index (lit->var (car clause)))
          (clause-indices (cdr clause))))

  ///
  (defthm clause-indices-when-atom
    (implies (atom clause)
             (equal (clause-indices clause)
                    nil)))

  (defthm clause-indices-of-cons
    (equal (clause-indices (cons lit clause))
           (cons (var->index (lit->var lit))
                 (clause-indices clause)))))



(define formula-indices ((formula lit-list-listp))
  :parents (cnf)
  :short "Collect indices of all identifiers used throughout a formula."

  (if (atom formula)
      nil
    (append (clause-indices (car formula))
            (formula-indices (cdr formula))))

  ///
  (defthm formula-indices-when-atom
    (implies (atom formula)
             (equal (formula-indices formula)
                    nil)))

  (defthm formula-indices-of-cons
    (equal (formula-indices (cons clause formula))
           (append (clause-indices clause)
                   (formula-indices formula)))))


