; Update-Nth Lemmas
; Copyright (C) 2011-2014 Centaur Technology
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

(in-package "ACL2")
(include-book "list-defuns")
(local (include-book "equiv"))
(local (include-book "repeat"))
(local (include-book "append"))
(local (include-book "len"))
(local (include-book "take"))
(local (include-book "arithmetic/top" :dir :system))

(defsection std/lists/update-nth
  :parents (std/lists update-nth)
  :short "Lemmas about @(see update-nth) available in the @(see std/lists)
library."

(defthm update-nth-when-atom
  ;; BOZO may be too weird
  (implies (atom x)
           (equal (update-nth n v x)
                  (append (replicate n nil) (list v))))
  :hints(("Goal" :in-theory (enable replicate))))

(defthm update-nth-when-zp
  ;; BOZO may not always be wanted
  (implies (zp a)
	   (equal (update-nth a v xs)
		  (cons v (cdr xs)))))

(defthm update-nth-of-cons
  (equal (update-nth n x (cons a b))
	 (if (zp n)
	     (cons x b)
	   (cons a (update-nth (1- n) x b)))))



; Note: the :type-prescription rule for update-nth that is built into ACL2
; establishes consp universally, so we don't need any additional
; type-prescription rules.

(defthm true-listp-of-update-nth
  ;; ACL2 already has the type-prescription version of this built-in.  That
  ;; type-prescription rule may occasionally be expensive.  This is potentially
  ;; a problematic rule because of case-splitting.
  (equal (true-listp (update-nth n v x))
         (or (<= (len x) (nfix n))
             (true-listp x))))

(defthm len-of-update-nth
  ;; BOZO check compatibility with data-structures rules
  (equal (len (update-nth n v x))
         (max (len x) (+ 1 (nfix n)))))

(defthm car-of-update-nth
  ;; Possibly too aggressive with the case-splitting.
  (equal (car (update-nth n v x))
         (if (zp n)
             v
           (car x))))

(defthm cdr-of-update-nth
  ;; Possibly too aggressive with the case-splitting.
  (equal (cdr (update-nth n v x))
         (if (zp n)
             (cdr x)
           (update-nth (1- n) v (cdr x)))))


(defthm nth-update-nth
  ;; This is redundant with ACL2's built-in rule.  We put it here just so that
  ;; you can see that we have it.
  (equal (nth m (update-nth n val l))
         (if (equal (nfix m) (nfix n))
             val
           (nth m l))))

(defthm nth-of-update-nth-same
  ;; Useful in cases where nth-update-nth must be disabled due to case splits.
  (equal (nth n (update-nth n v x))
         v))

(defthm nth-of-update-nth-diff
  ;; Useful in cases where nth-update-nth must be disabled due to case splits.
  (implies (not (equal (nfix n1) (nfix n2)))
           (equal (nth n1 (update-nth n2 v x))
                  (nth n1 x))))

(defthm nth-of-update-nth-split-for-constants
  ;; Useful in cases when nth-update-nth must be disabled due to case splits;
  ;; it looks like it case-splits, but the syntaxp hyps ensure that we know
  ;; there will only be one case.
  (implies (and (syntaxp (quotep n1))
                (syntaxp (quotep n2)))
           (equal (nth n1 (update-nth n2 v x))
                  (if (equal (nfix n1) (nfix n2))
                      v
                    (nth n1 x)))))



(defthm update-nth-of-nth
  (implies (< (nfix n) (len x))
           (equal (update-nth n (nth n x) x)
                  x)))

(defthm update-nth-of-nth-free
  (implies (and (equal (nth n x) free)
                (< (nfix n) (len x)))
           (equal (update-nth n free x)
                  x)))

;; BOZO consider this rule from legacy-defrstobj/array-lemmas?
;; (defthm update-nth-of-nth-other
;;   (implies (not (equal (nfix n) (nfix m)))
;;            (equal (update-nth n (nth n arr) (update-nth m val arr))
;;                   (if (< (nfix n) (len arr))
;;                       (update-nth m val arr)
;;                     (update-nth n nil (update-nth m val arr))))))



(defthm update-nth-of-update-nth-same
  (equal (update-nth n v1 (update-nth n v2 x))
         (update-nth n v1 x)))

(defthm update-nth-of-update-nth-diff
  (implies (not (equal (nfix n1) (nfix n2)))
           (equal (update-nth n1 v1 (update-nth n2 v2 x))
                  (update-nth n2 v2 (update-nth n1 v1 x))))
  :rule-classes ((:rewrite :loop-stopper ((n1 n2 update-nth)))))

(defthm update-nth-diff-gather-constants
  ;; Special supplement to update-nth-of-update-nth-diff.  Here, we are willing
  ;; to reorder keys/vals in the wrong order, as long as the result will be a
  ;; completely constant update to a constant record.  This isn't really
  ;; enough.  It won't do the job for nests of updates.  But it is good enough
  ;; to solve "matt-example" in projects/legacy-defrstobj/basic-tests.  Without
  ;; the rule, we failed to prove to-leaves-bad-bad, because we put the keys
  ;; into the wrong order and don't get all the constants resolved.
  (implies (and (syntaxp (and (quotep x)
                              (quotep n)
                              (quotep val1)
                              (or (not (quotep m))
                                  (not (quotep val2)))))
                (not (equal (nfix n) (nfix m))))
           (equal (update-nth n val1 (update-nth m val2 x))
                  (update-nth m val2 (update-nth n val1 x))))
  :rule-classes ((:rewrite :loop-stopper nil)))



(defthm final-cdr-of-update-nth
  (equal (final-cdr (update-nth n v x))
	 (if (< (nfix n) (len x))
	     (final-cdr x)
	   nil))
  :hints(("Goal"
          :induct (update-nth n v x)
          :in-theory (enable final-cdr))))



(defthm nthcdr-past-update-nth
  ;; Useful when nthcdr-of-update-nth is disabled due to case-splits.
  (implies (and (< (nfix n2) (len x))
                (< (nfix n2) (nfix n1)))
           (equal (nthcdr n1 (update-nth n2 val x))
                  (nthcdr n1 x))))

(defthm nthcdr-before-update-nth
  ;; Useful when nthcdr-of-update-nth is disabled due to case-splits.
  (implies (and (< (nfix n2) (len x))
                (<= (nfix n1) (nfix n2)))
           (equal (nthcdr n1 (update-nth n2 val x))
                  (update-nth (- (nfix n2) (nfix n1)) val (nthcdr n1 x)))))

(defthm nthcdr-of-update-nth
  (equal (nthcdr n1 (update-nth n2 val x))
         (if (< (nfix n2) (nfix n1))
             (nthcdr n1 x)
           (update-nth (- (nfix n2) (nfix n1)) val (nthcdr n1 x)))))


(defthm take-before-update-nth
  ;; Useful when take-of-update-nth is disabled due to case-splits
  (implies (<= (nfix n1) (nfix n2))
           (equal (take n1 (update-nth n2 val x))
                  (take n1 x))))

(defthm take-after-update-nth
  ;; Useful when take-of-update-nth is disabled due to case-splits
  (implies (> (nfix n1) (nfix n2))
           (equal (take n1 (update-nth n2 val x))
                  (update-nth n2 val (take n1 x)))))

(defthm take-of-update-nth
  (equal (take n1 (update-nth n2 val x))
         (if (<= (nfix n1) (nfix n2))
             (take n1 x)
           (update-nth n2 val (take n1 x)))))


;; (defthm append-update-nth
;;
;; This is an improved rule from
;; workshops/2006/pike-shields-matthews/core_verifier/books/append-defthms-help.lisp
;; but it seems too weird, I don't think we want it.
;;
;;   (implies  (< (nfix n) (len x))
;;             (equal (cons (car (update-nth n a x))
;;                          (append (take n (cdr (update-nth n a x))) y))
;;                    (append (take n x) (cons a y)))))

(defthm member-equal-update-nth
  ;; Keep these names compatible with data-structures/list-defthms
  (member-equal x (update-nth n x l)))

(defthm update-nth-append
  ;; Keep these names compatible with data-structures/list-defthms
  (equal (update-nth n v (append a b))
         (if (< (nfix n) (len a))
             (append (update-nth n v a) b)
           (append a (update-nth (- n (len a)) v b)))))


;; BOZO eventually integrate centaur/misc/nth-equiv stuff here

)
