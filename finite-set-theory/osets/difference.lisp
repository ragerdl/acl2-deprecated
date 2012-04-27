; Fully Ordered Finite Sets
; Copyright (C) 2003-2012 by Jared Davis <jared@cs.utexas.edu>
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public Lic-
; ense along with this program; if not, write to the Free Soft- ware
; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

(in-package "SETS")
(include-book "membership")
(set-verify-guards-eagerness 2)


; Fast Difference
;
; As before, we want to show that difference always creates a set and that the
; produced set has the expected membership properties.  Also as before, these
; proofs are ugly.

; PATCH (0.91): David Rager noticed that as of v0.9, fast-difference was not
; tail recursive, and submitted an updated version.  The original
; fast-difference has been renamed to fast-difference-old, and the new
; fast-difference replaces it.

(defun fast-difference-old (X Y)
  (declare (xargs :measure (fast-measure X Y)
                  :guard (and (setp X) (setp Y))
                  :verify-guards nil))
  (cond ((endp X) nil)
        ((endp Y) X)
        ((equal (car X) (car Y))
         (fast-difference-old (cdr X) (cdr Y)))
        ((mbe :logic (<< (car X) (car Y))
              :exec (fast-lexorder (car X) (car Y)))
         (cons (car X) (fast-difference-old (cdr X) Y)))
        (t
         (fast-difference-old X (cdr Y)))))

(verify-guards fast-difference-old
  :hints(("Goal" :in-theory (enable (:ruleset low-level-rules)))))

(local
 (encapsulate ()

   (local (defthm l0
            (implies (and (consp (fast-difference-old x y))
                          (or (atom x) (<< a (car x)))
                          (setp x))
                     (<< a (car (fast-difference-old x y))))
            :hints(("Goal" :in-theory (enable (:ruleset low-level-rules))))))

   (defthm fast-difference-old-set
     (implies (and (setp X) (setp Y))
              (setp (fast-difference-old X Y)))
     :hints(("Goal" :in-theory (enable (:ruleset low-level-rules)))))

   (local (defthm l1
            (implies (and (member a x)
                          (not (member a y))
                          (setp x)
                          (setp y))
                     (member a (fast-difference-old x y)))
            :hints(("Goal" :in-theory (enable (:ruleset low-level-rules))))))

   (local (defthm l2
            (implies (and (member a (fast-difference-old x y))
                          (setp x)
                          (setp y))
                     (and (member a x)
                          (not (member a y))))
            :hints(("Goal" :in-theory (enable (:ruleset low-level-rules))))))

   (local (defthm member-of-fast-difference-old
            (implies (and (setp x)
                          (setp y))
                     (iff (member a (fast-difference-old x y))
                          (and (member a x)
                               (not (member a y)))))))

   (defthm fast-difference-old-membership
     (implies (and (setp X) (setp Y))
              (equal (in a (fast-difference-old X Y))
                     (and (in a X)
                          (not (in a Y)))))
     :hints(("Goal" :in-theory (enable (:ruleset low-level-rules)))))))


(defun fast-difference (X Y acc)
  (declare (xargs :measure (fast-measure X Y)
                  :guard (and (setp X)
                              (setp Y)
                              (true-listp acc))
                  :verify-guards nil))
  (cond ((endp X) (revappend acc nil))
        ((endp Y) (revappend acc X))
        ((equal (car X) (car Y))
         (fast-difference (cdr X) (cdr Y) acc))
        ((mbe :logic (<< (car X) (car Y))
              :exec (fast-lexorder (car X) (car Y)))
         (fast-difference (cdr X) Y (cons (car X) acc)))
        (t
         (fast-difference X (cdr Y) acc))))

(verify-guards fast-difference
  :hints(("Goal" :in-theory (enable (:ruleset low-level-rules)))))

(encapsulate
  ()
  (local (defthm lemma
           (implies (true-listp acc)
                    (equal (fast-difference x y acc)
                           (revappend acc (fast-difference-old x y))))))

  (local (defthm lemma2
           (equal (fast-difference x y nil)
                  (fast-difference-old x y))))

  (defthm fast-difference-set
    (implies (and (force (setp X))
                  (force (setp Y)))
             (setp (fast-difference X Y nil))))

  (defthm fast-difference-membership
    (implies (and (setp X) (setp Y))
             (equal (in a (fast-difference X Y nil))
                    (and (in a X)
                         (not (in a Y))))))

  (in-theory (disable fast-difference
                      fast-difference-set
                      fast-difference-membership)))



(defsection difference
  :parents (osets)
  :short "@(call difference) removes all members of <tt>Y</tt> from <tt>X</tt>."

  :long "<p>The logical definition is very simple, and the essential
correctness property is given by <tt>difference-in</tt>.</p>

<p>The execution uses a better, O(n) algorithm to remove the elements by
exploiting the set order.</p>"

  (defun difference (X Y)
    (declare (xargs :guard (and (setp X) (setp Y))
                    :verify-guards nil))
    (mbe :logic (cond ((empty X) (sfix X))
                      ((in (head X) Y) (difference (tail X) Y))
                      (t (insert (head X) (difference (tail X) Y))))
         :exec (fast-difference X Y nil)))

  (defthm difference-set
    (setp (difference X Y)))

  (defthm difference-sfix-X
    (equal (difference (sfix X) Y) (difference X Y)))

  (defthm difference-sfix-Y
    (equal (difference X (sfix Y)) (difference X Y)))

  (defthm difference-empty-X
    (implies (empty X)
             (equal (difference X Y) (sfix X))))

  (defthm difference-empty-Y
    (implies (empty Y)
             (equal (difference X Y) (sfix X))))

  (encapsulate ()

    (local (defthm difference-in-X
             (implies (in a (difference X Y))
                      (in a X))))

    (local (defthm difference-in-Y
             (implies (in a (difference X Y))
                      (not (in a Y)))))

    (defthm difference-in
      (equal (in a (difference X Y))
             (and (in a X)
                  (not (in a Y))))))

  (encapsulate
    ()
    ;; bozo shouldn't really need this
    (local (defthm l0
             (implies (and (setp y) (setp x) (empty x))
                      (not (fast-difference x y nil)))
             :hints(("Goal" :in-theory (enable fast-difference
                                               (:ruleset low-level-rules))))))

    (verify-guards difference
      :hints(("Goal" :in-theory (enable fast-difference-set
                                        fast-difference-membership)))))

  (defthm difference-subset-X
    (subset (difference X Y) X))

  (defthm subset-difference
    (equal (empty (difference X Y))
           (subset X Y)))

  (defthm difference-insert-X
    (equal (difference (insert a X) Y)
           (if (in a Y)
               (difference X Y)
             (insert a (difference X Y)))))

  (defthm difference-preserves-subset
    (implies (subset X Y)
             (subset (difference X Z)
                     (difference Y Z)))))