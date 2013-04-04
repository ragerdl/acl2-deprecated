; Trivial-ancestors-check: replace the ACL2 ancestors check heuristic with a
; simpler one

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
; Original author: Sol Swords <sswords@centtech.com>

; Very lightly modified April 2013 by Matt K. to accommodate introduction of
; defrec for ancestors.

(in-package "ACL2")

; Sometimes the ACL2 ancestors-check heuristic prevents rules from applying
; when you think they should.  Fortunately it's an attachable function, so we
; can make it into a simple loop check without too much trouble.

; The constraint it needs to satisfy:

;; (defthmd ancestors-check-constraint
;;    (implies (and (pseudo-termp lit)
;;                  (ancestor-listp ancestors)
;;                  (true-listp tokens))
;;             (mv-let (on-ancestors assumed-true)
;;                     (ancestors-check lit ancestors tokens)
;;                     (implies (and on-ancestors
;;                                   assumed-true)
;;                              (member-equal-mod-commuting
;;                               lit
;;                               (strip-ancestor-literals ancestors)
;;                               nil))))
;;    :hints (("Goal" :use ancestors-check-builtin-property)))

(local (in-theory (disable mv-nth equal-mod-commuting)))

(defun check-assumed-true-or-false (lit lit-atm ancestors)
  (declare (xargs :guard (and (pseudo-termp lit)
                              (pseudo-termp lit-atm)
                              (ancestor-listp ancestors))))
  (cond ((endp ancestors) (mv nil nil))
        ((ancestor-binding-hyp-p (car ancestors))
         (check-assumed-true-or-false lit lit-atm (cdr ancestors)))
        ((equal-mod-commuting lit
                              (access ancestor (car ancestors) :lit) ;; first lit
                              nil)
         (mv t t))
        ((equal-mod-commuting lit-atm
                              (access ancestor (car ancestors) :atm) ;; atom of first lit
                              nil)
         (mv t nil))
        (t (check-assumed-true-or-false lit lit-atm (cdr ancestors)))))

(defthmd check-assumed-true-or-false-ok
  (mv-let (present true)
    (check-assumed-true-or-false lit lit-atm ancestors)
    (implies (and present true)
             (member-equal-mod-commuting
              lit (strip-ancestor-literals ancestors) nil))))

(in-theory (disable check-assumed-true-or-false))

(defun trivial-ancestors-check (lit ancestors tokens)
  (declare (xargs :guard (and (pseudo-termp lit)
                              (ancestor-listp ancestors)
                              (true-listp tokens)))
           (ignorable tokens))
  (cond ((endp ancestors)
         (mv nil nil))
        (t (mv-let (not-flg lit-atm)
             (strip-not lit)
             (declare (ignore not-flg))
             (check-assumed-true-or-false lit lit-atm ancestors)))))

(defthmd trivial-ancestors-check-ok
  (mv-let (present true)
    (trivial-ancestors-check lit ancestors tokens)
    (implies (and present true)
             (member-equal-mod-commuting
              lit (strip-ancestor-literals ancestors) nil)))
  :hints(("Goal" :in-theory (enable check-assumed-true-or-false-ok))))

(in-theory (disable trivial-ancestors-check))

;; test
(local (defattach (ancestors-check trivial-ancestors-check)
         :hints (("goal" :in-theory '(trivial-ancestors-check-ok)))))

;; This macro makes a local event, but you can also do
;; (local (include-book "centaur/misc/defeat-ancestors" :dir :system))
;; (local (use-trivial-ancestors-check))
;; if you want this book to be included only locally.
(defmacro use-trivial-ancestors-check ()
  '(local (defattach (ancestors-check trivial-ancestors-check)
            :hints (("goal" :in-theory '(trivial-ancestors-check-ok))))))
