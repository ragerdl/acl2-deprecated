; Do-Not Hint
; Copyright (C) 2010 Centaur Technology
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
; Original author: Jared Davis <jared@centtech.com>
;
; Additional Copyright Notice.
;
; This file is an extension of the "no-fertilize" hint developed for the Milawa
; theorem prover, and also released under the GPL.  See the Milawa source code
; file Sources/ACL2/acl2-hacks/no-fertilize.lisp for details.

(in-package "ACL2")
(include-book "bstar")

(defun strip-quotes-for-do-not (x)
  ;; Turn any quoted arguments into unquoted args, so that
  ;;   (do-not 'induct 'generalize)
  ;; and
  ;;   (do-not induct generalize)
  ;; are both permitted.
  (declare (xargs :guard t))
  (cond ((atom x)
         nil)
        ((and (quotep (car x))
              (consp (cdr (car x))))
         (cons (unquote (car x))
               (strip-quotes-for-do-not (cdr x))))
        (t
         (cons (car x)
               (strip-quotes-for-do-not (cdr x))))))


(defconst *allowed-for-do-not*
  '(induct preprocess simplify eliminate-destructors
           fertilize generalize eliminate-irrelevance))

(defun check-allowed-for-do-not (x)
  (declare (xargs :guard t))
  (cond ((atom x)
         t)
        ((member-equal (car x) *allowed-for-do-not*)
         (check-allowed-for-do-not (cdr x)))
        (t
         (er hard? 'do-not
             "~x0 is not allowed.  The allowed symbols are ~x1."
             (car x) *allowed-for-do-not*))))


(table do-not-table 'things-not-to-be-done nil)
(table do-not-table 'do-not-inductp nil)

(defmacro do-not (&rest things)
  (declare (xargs :guard t))
  (b* ((things (strip-quotes-for-do-not things))
       (-      (check-allowed-for-do-not things))
       (induct (if (member-eq 'induct things) t nil))
       (others (remove-eq 'induct things)))
      `(with-output
        :off (event summary)
        (progn
          (table do-not-table 'do-not-inductp ',induct)
          (table do-not-table 'things-not-to-be-done ',others)))))



(defun do-not-hint (world stable-under-simplificationp state)
  ":Doc-Section Miscellaneous
Give :do-not hints automatically.~/

~c[Do-not-hint] is a computed hint (~l[computed-hints]) that gives ~c[:do-not]
and perhaps ~c[:do-not-induct] hints automatically.  For instance:

~bv[]
 (encapsulate
  ()
  (local (do-not generalize fertilize))
  (defthm thm1 ...)
  (defthm thm2 ...)
  ...)
~ev[]

is roughly equivalent to:

~bv[]
 (encapsulate
  ()
  (defthm thm1 ... :hints((\"Goal\" :do-not '(generalize fertilize))))
  (defthm thm2 ... :hints((\"Goal\" :do-not '(generalize fertilize))))
  ...)
~ev[]

Except that the ~c[:do-not] hints are actually given at
stable-under-simplificationp checkpoints.  This is kind of useful: the hints
will apply to forced subgoals in addition to regular subgoals, and won't
clutter proofs that never hit a stable-under-simplification checkpoint.

The ~c[do-not] macro expands to some ~ilc[table] events that update the
~c[do-not-table].  It should typically be made local to a book or encapsulate
since globally disabling these proof engines is likely to be particularly
disruptive to other proofs.

The arguments to ~c[do-not] can be any of the keywords used for ~c[:do-not]
hints, and may also include ~c[induct] which results in ~c[:do-not-induct t]
hints.~/~/"

  (declare (xargs :mode :program :stobjs state))

  (b* (((unless stable-under-simplificationp)
        ;; No reason to give a hint until stable-under-simplificationp.
        nil)

       (tbl     (table-alist 'do-not-table world))
       (things  (cdr (assoc 'things-not-to-be-done tbl)))
       (inductp (cdr (assoc 'do-not-inductp tbl)))

       ((when (and (atom things)
                   (not inductp)))
        ;; Nothing is prohibited, so give no hint.
        nil)

       (- (or (gag-mode)
              (cw "~%;; do-not-hint: prohibiting ~x0.~|"
                  (if inductp
                      (cons 'induct things)
                    things))))

       (hint (if inductp
                 '(:do-not-induct t)
               nil))
       (hint (if (consp things)
                 (append `(:do-not ',things) hint)
               hint)))
      hint))

(add-default-hints!
 '((do-not-hint world stable-under-simplificationp state)))


(defdoc do-not
  ":doc-section Miscellaneous
hints keyword ~c[:do-not]~/

~l[hints] for documentation about the ~c[:do-not] keyword for theorem
hints.

~l[do-not-hint] for documentation about the ~c[do-not] macro that controls the
behavior of the ~c[do-not-hint].~/~/")