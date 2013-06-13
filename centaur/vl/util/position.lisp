; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
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

(in-package "VL")
(include-book "defs")
(local (include-book "arithmetic"))


; Lemmas about the POSITION function.  Ugly stuff.  We should probably redo
; all of this based on a simpler-position function that is accumulator-free.


(defthm natp-of-position-equal-ac-when-natp
  (implies (natp acc)
           (or (not (position-equal-ac item lst acc))
               (natp (position-equal-ac item lst acc))))
  :rule-classes :type-prescription)

(defthm type-of-position-equal
  (or (not (position-equal item lst))
      (natp (position-equal item lst)))
  :rule-classes :type-prescription
  :hints(("Goal" :in-theory (enable position-equal))))

; [Removed by Matt K. to handle changes to member, assoc, etc. after ACL2 4.2.]
; (defthm position-ac-removal
;   (equal (position-ac item lst acc)
;          (position-equal-ac item lst acc)))

(defthm position-equal-ac-under-iff
  (implies (acl2-numberp acc)
           (iff (position-equal-ac item lst acc)
                (member-equal item lst))))

(defthm position-equal-under-iff-when-stringp
  (implies (stringp string)
           (iff (position-equal char string)
                (member-equal char (explode string))))
  :hints(("Goal" :in-theory (enable position-equal))))

(encapsulate
  ()
  (local (defun my-induct (x acc)
           (if (atom x)
               acc
             (my-induct (cdr x) (+ 1 acc)))))

  (defthm position-equal-ac-of-append
    (implies (force (acl2-numberp acc))
             (equal (position-equal-ac a (append x y) acc)
                    (if (member-equal a x)
                        (position-equal-ac a x acc)
                      (position-equal-ac a y (+ (len x) acc)))))
    :hints(("Goal" :induct (my-induct x acc)))))

(defthm position-equal-ac-upper-bound-weak
  (implies (natp acc)
           (<= (position-equal-ac item lst acc)
               (+ (len lst) acc)))
  :rule-classes ((:rewrite) (:linear)))

(defthm position-equal-ac-upper-bound-strong
  (implies (and (case-split (position-equal-ac item lst acc))
                (natp acc))
           (< (position-equal-ac item lst acc)
              (+ (len lst) acc)))
  :rule-classes ((:rewrite) (:linear)))

(defthm position-equal-upper-bound-weak-when-stringp
  (implies (stringp string)
           (<= (position-equal char string)
               (length string)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal" :in-theory (enable position-equal))))

(defthm position-equal-upper-bound-strong-when-stringp
  (implies (and (case-split (position-equal char string))
                (stringp string))
           (< (position-equal char string)
              (length string)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal" :in-theory (enable position-equal))))

(defthm position-equal-ac-monotonic
  (implies (and (position-equal-ac item lst acc)
                (natp acc))
           (<= acc (position-equal-ac item lst acc)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal" :in-theory (enable position-equal-ac))))

(defthm nth-of-position-equal-ac
  (implies (and (position-equal-ac item lst acc)
                (natp acc))
           (equal (nth (- (position-equal-ac item lst acc) acc)
                       lst)
                  item))
  :hints(("Goal"
          :in-theory (enable position-equal-ac)
          :do-not '(generalize fertilize)
          :induct (position-equal-ac item lst acc))))

(defthm nth-of-position-equal-of-explode-when-stringp
  (implies (and (position-equal char string)
                (stringp string))
           (equal (nth (position-equal char string)
                       (explode string))
                  char))
  :hints(("Goal"
          :in-theory (e/d (position-equal)
                          (nth-of-position-equal-ac))
          :use ((:instance nth-of-position-equal-ac
                           (item char)
                           (lst (explode string))
                           (acc 0))))))

(defthm acl2-numberp-of-position-equal
  ;; Why the hell doesn't type reasoning get these?
  (equal (acl2-numberp (position-equal a x))
         (if (position-equal a x)
             t
           nil)))

(defthm integerp-of-position-equal
  ;; Why the hell doesn't type reasoning get these?
  (equal (integerp (position-equal a x))
         (if (position-equal a x)
             t
           nil)))

(defthm natp-of-position-equal-ac
  ;; Why the hell doesn't type reasoning get these?
  (implies (natp acc)
           (equal (natp (position-equal-ac item lst acc))
                  (if (position-equal-ac item lst acc)
                      t
                    nil))))



(encapsulate
  ()
  (local (defun my-induct (item n lst acc)
           (cond ((atom lst)
                  (list n lst acc))
                 ((equal item (car lst))
                  (list n lst acc))
                 (t
                  (my-induct item (- n 1) (cdr lst) (+ 1 acc))))))

  (local (defthm l0
           (implies (and (position-equal-ac item lst acc)
                         (natp n)
                         (natp acc)
                         (<= n (- (position-equal-ac item lst acc) acc)))
                    (not (member-equal item (take n lst))))
           :hints(("Goal"
                   :in-theory (enable position-equal-ac)
                   :induct (my-induct item n lst acc)))))

  (local (defthm l1
           (implies (and (<= n (position-equal-ac item lst 0))
                         (position-equal-ac item lst 0)
                         (natp n))
                    (not (member-equal item (take n lst))))
           :hints(("Goal"
                   :in-theory (disable l0)
                   :use ((:instance l0 (acc 0)))))))

  (local (in-theory (enable subseq subseq-list position-equal)))

  (defthm member-equal-of-subseq-chars-impossible-1
    (implies (and (not (position-equal a x))
                  (<= (nfix end) (length x)))
             (not (member-equal a (explode (subseq x 0 end))))))

  (defthm member-equal-of-subseq-chars-impossible-2
    (implies (and (<= end (position-equal a x))
                  (position-equal a x)
                  (natp end))
             (not (member-equal a (explode (subseq x 0 end)))))
    :hints(("Goal"
            :in-theory (disable member-equal-of-subseq-chars-impossible-1 l1)
            :use ((:instance member-equal-of-subseq-chars-impossible-1)
                  (:instance l1 (item a) (lst (explode x)) (n end)))))))



(defthm position-equal-of-implode
  (implies (character-listp x)
           (equal (position-equal a (implode x))
                  (position-equal a x)))
  :hints(("Goal" :in-theory (enable position-equal))))

(defthm position-equal-of-explode
  (implies (stringp x)
           (equal (position-equal a (explode x))
                  (position-equal a x)))
  :hints(("Goal" :in-theory (enable position-equal))))


(encapsulate
  ()
  (local
   (defun simpler-position-equal-ac (item lst)
     (declare (xargs :guard t))
     (cond ((atom lst)
            nil)
           ((equal item (car lst))
            0)
           (t
            (let ((tail (simpler-position-equal-ac item (cdr lst))))
              (and tail
                   (+ 1 tail)))))))

  (local (defthm position-equal-ac-removal
           (implies (acl2-numberp acc)
                    (equal (position-equal-ac item lst acc)
                           (and (simpler-position-equal-ac item lst)
                                (+ acc (simpler-position-equal-ac item lst)))))
           :hints(("Goal" :in-theory (enable position-equal-ac)))))

  (local (defthm position-equal-ac-elim-accumulator
           (implies (and (syntaxp (not (equal n ''0)))
                         (member-equal a x)
                         (acl2-numberp n))
                    (equal (position-equal-ac a x n)
                           (+ n (position-equal-ac a x 0))))))

  (local (in-theory (disable position-equal-ac-removal)))

  (defthm position-equal-of-cons
    (implies (character-listp x)
             (equal (position-equal a (cons b x))
                    (if (equal a b)
                        0
                      (and (position-equal a x)
                           (+ 1 (position-equal a x))))))
    :hints(("Goal" :in-theory (enable position-equal)))))
