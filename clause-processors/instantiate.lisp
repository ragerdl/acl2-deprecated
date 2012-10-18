; Copyright (C) 2012 Centaur Technology
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

(in-package "ACL2")




(include-book "unify-subst")
(include-book "tools/flag" :dir :system)
(include-book "tools/bstar" :dir :system)


(mutual-recursion
 (defun find-matching-terms (pattern x)
   (declare (xargs :guard (and (pseudo-termp pattern)
                               (pseudo-termp x))
                   :verify-guards nil))
   (b* (((when (or (mbe :logic (atom x) :exec (symbolp x))
                   (eq (car x) 'quote)))
         nil)
        ((mv succ1 alist1)
         (simple-one-way-unify pattern x nil))
        (alists (find-matching-terms-list pattern (cdr x))))
     (if (and succ1 (not (member-equal alist1 alists)))
         (cons alist1 alists)
       alists)))

 (defun find-matching-terms-list (pattern x)
   (declare (xargs :guard (and (pseudo-termp pattern)
                               (pseudo-term-listp x))))
   (if (endp x)
       nil
     (union-equal (find-matching-terms pattern (car x))
                  (find-matching-terms-list pattern (cdr x))))))

(make-flag find-matching-terms-flg find-matching-terms)

(defthm-find-matching-terms-flg
  (defthm true-listp-find-matching-terms
    (true-listp (find-matching-terms pattern x))
    :rule-classes (:rewrite :type-prescription)
    :flag find-matching-terms)
  (defthm true-listp-find-matching-terms-list
    (true-listp (find-matching-terms-list pattern x))
    :rule-classes (:rewrite :type-prescription)
    :flag find-matching-terms-list))

(verify-guards find-matching-terms)

(program)
(set-state-ok t)

(defun make-subst-for-match (subst match)
  (if (atom subst)
      nil
    (cons (list (caar subst) (substitute-into-term (cadar subst) match))
          (make-subst-for-match (cdr subst) match))))

(defun make-insts-for-matches (thm subst matches)
  (if (atom matches)
      nil
    (cons `(:instance ,thm . ,(make-subst-for-match subst (car matches)))
          (make-insts-for-matches thm subst (cdr matches)))))

(defun translate-subst-for-instantiate (subst state)
  (b* (((when (atom subst))
        (value-cmp nil))
       ((when (or (atom (car subst))
                  (atom (cdar subst))))
        (cw "skipping malformed substitution pair: ~x0~%" (car subst))
        (translate-subst-for-instantiate (cdr subst) state))
       ((cmp tterm)
        (translate-cmp (cadar subst) t t t 'instantiate-thm-for-matching-terms
                       (w state)
                       (default-state-vars t)))
       ((cmp rest)
        (translate-subst-for-instantiate (cdr subst) state)))
    (value-cmp (cons (list (caar subst) tterm) rest))))
            

(defun instantiate-thm-for-matching-terms-fn (thm subst pattern clause state)
  (b* (((mv ctx pattern)
        (translate-cmp pattern t t t
                       'instantiate-thm-for-matching-terms
                       (w state) (default-state-vars t)))
       ((when ctx)
        (if pattern
            (er hard? ctx "~@0" pattern)
          nil))
       ((mv ctx subst)
        (translate-subst-for-instantiate subst state))
       ((when ctx)
        (if pattern
            (er hard? ctx "~@0" pattern)
          nil))
       (matches (find-matching-terms-list pattern clause))
       ;; matches is the list of unifying substitutions
       ((unless matches) nil))
    `(:use ,(make-insts-for-matches thm subst matches))))


(defmacro instantiate-thm-for-matching-terms (thm subst pattern)
  ":doc-section computed-hints
A computed hint which produces :use hints of the given theorem based on
occurences of a pattern in the current goal clause.~/

Arguments: THM is a theorem/definition name or rune,
SUBST is a list of pairs such as
~bv[]
 ((var1 sub1)
  (var2 sub2) ... )
~ev[]
where each vari is a variable name and each sub1 is a term, usually containing
free variables that are also free in PATTERN,
and PATTERN is a pattern (pseudo-term) to be matched against the clause.

We translate the PATTERN and each term in the SUBST, so it's ok to use macros
etc. within them.

For each subterm of CLAUSE that matches PATTERN, the unifying
substitution is computed and applied to each of the subi terms
in the SUBST.~/

For example, if I have some theorem FOO-BOUND, such as:
~bv[]
 (defthm foo-bound
  (< (foo a b) (max (g a) (g b))))
~ev[]

and I'm proving the goal:
~bv[]
 (implies (and (p (foo (bar z) (baz q)))
               (q (bar z) (buz y)))
          (r (foo (baz q) (bar y))))
~ev[]

and I provide the computed hint
~bv[]
 (instantiate-thm-for-matching-terms
   foo-bound
   ((a c) (b d))
   (foo c d))
~ev[]
this produces the hint:
~bv[]
 :use ((:instance foo-bound
        (a (bar z)) (b (baz q)))
       (:instance foo-bound
        (a (baz q)) (b (bar y))))
~ev[]

The process by which this happens:  The provided pattern
 ~c[(foo c d)] is matched against the clause, which contains
two unifying instances,
~bv[]
  c -> (bar z), d -> (baz q)
~ev[]
and
~bv[]
  c -> (baz q), d -> (bar y).
~ev[]
These two unifying substitutions are applied to the user-provided substitution
 ~c[((a c) (b d))] to obtain the two instantiations.

Note: you may want to qualify this computed hint with
STABLE-UNDER-SIMPLIFICATIONP or other conditions, and perhaps disable the
theorem used.  For example:
~bv[]
 :hints ((and stable-under-simplificationp
              (let ((res (instantiate-thm-for-matching-terms
                          foo-bound ((a c) (b d)) (foo c d))))
                (and res (append res '(:in-theory (disable foo-bound)))))))
~ev[]
~/"
  `(instantiate-thm-for-matching-terms-fn
    ',thm ',subst ',pattern clause state))
