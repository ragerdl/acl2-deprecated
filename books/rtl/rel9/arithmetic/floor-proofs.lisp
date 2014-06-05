; RTL - A Formal Theory of Register-Transfer Logic and Computer Arithmetic 
; Copyright (C) 1995-2013 Advanced Mirco Devices, Inc. 
;
; Contact:
;   David Russinoff
;   1106 W 9th St., Austin, TX 78703
;   http://www.russsinoff.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
; PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with
; this program; see the file "gpl.txt" in this directory.  If not, write to the
; Free Software Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA
; 02110-1335, USA.
;
; Author: David M. Russinoff (david@russinoff.com)

(in-package "ACL2")

(local (include-book "ground-zero"))
(local (include-book "fp2"))
(local (include-book "denominator"))
(local (include-book "numerator"))
(local (include-book "predicate"))
(local (include-book "nniq"))
(local (include-book "product"))
(local (include-book "unary-divide"))
(local (include-book "rationalp"))
(local (include-book "inverted-factor"))
(local (include-book "../../../meta/meta-plus-lessp"))
; (thm (rationalp (floor i j)))) goes through



(defthm floor-non-negative-integerp-type-prescription
  (implies (and (<= 0 i)
                (<= 0 j)
                (case-split (not (complex-rationalp j))) ;gen?
                )
           (and (<= 0 (floor i j))
                (integerp (floor i j))))
  :rule-classes (:type-prescription)
  :hints (("Goal" :in-theory (set-difference-theories
                              (enable floor)
                              '()))
          ))

;nope. (floor #C(0 -1)  #C(0 -1)) = 1
;(defthm floor-with-j-non-rational
;  (implies (not (rationalp j))
 ;          (equal (floor i j)
  ;                0))
;  :hints (("Goal" :in-theory (set-difference-theories
 ;                             (enable floor)
  ;                            '(a13 FL-WEAKLY-MONOTONIC)))
   ;       ))


(defthm floor-non-negative
  (implies (and (<= 0 i)
                (<= 0 j)
                (case-split (not (complex-rationalp i)));drop?
                ;(case-split (rationalp j))
                )
           (<= 0 (floor i j)))

  :hints (("Goal" :in-theory (set-difference-theories
                              (enable floor)
                              '()))
          ))


(defthm floor-with-i-not-rational-but-j-rational
  (implies (and (not (rationalp i))
                (rationalp j)
                )
           (equal (floor i j)
                  0))
  :hints (("Goal" :in-theory (enable floor)))
)


(defthm floor-compare-to-zero
  (implies (and (case-split (rationalp i))
                (case-split (rationalp j)))
           (equal (< (floor i j) 0)
                  (or (and (< i 0) (< 0 j))
                      (and (< 0 i) (< j 0))
                      )))
  :hints (("Goal" :in-theory (enable floor)))
  )

(defthm floor-of-non-acl2-number
  (implies (not (acl2-numberp i))
           (and (equal (floor i j)
                       0)
                (equal (floor j i)
                       0)))
  :hints (("Goal" :in-theory (enable floor)))
  )

;linear? how should it be phrased?
;too many hints.  without the frac-coeff rule, things worked out here
(defthm floor-upper-bound
    (implies (and (case-split (rationalp i))
                  (case-split (rationalp j))
                  )
	     (<= (floor i j) (/ i j)))
    :hints (("Goal" :use ( (:instance nonnegative-integer-quotient-lower-bound-rewrite
                                      (i (* -1 (NUMERATOR (* I (/ J)))))
                                      (j (DENOMINATOR (* I (/ J)))))
                           (:instance  nonnegative-integer-quotient-upper-bound-rewrite
                                      (i (* -1 (NUMERATOR (* I (/ J)))))
                                      (j (DENOMINATOR (* I (/ J)))))
                           (:instance  nonnegative-integer-quotient-lower-bound-rewrite
                                      (i (NUMERATOR (* I (/ J))))
                                      (j (DENOMINATOR (* I (/ J)))))
                           (:instance  nonnegative-integer-quotient-upper-bound-rewrite
                                      (i (NUMERATOR (* I (/ J))))
                                      (j (DENOMINATOR (* I (/ J))))))
                           
             :in-theory (set-difference-theories
                         (enable floor)
                         '(  nonnegative-integer-quotient-lower-bound-rewrite
                             nonnegative-integer-quotient-upper-bound-rewrite
                           ))))
    :rule-classes (:rewrite (:linear :trigger-terms ((floor i j))))
  )



(defthm floor-equal-i-over-j-rewrite
  (implies (and (case-split (not (equal j 0)))
                (case-split (rationalp i))
                (case-split (rationalp j))
                )
           (equal (EQUAL (* J (FLOOR I J)) I)
                  (integerp (* i (/ j)))))
  :otf-flg t
  :hints (("Goal" :in-theory (set-difference-theories
                              (enable floor)
                              '( nonnegative-integer-quotient-lower-bound-rewrite
                                 nonnegative-integer-quotient-max-value-rewrite))
           :use(
                (:instance  nonnegative-integer-quotient-max-value-rewrite
                            (i (* -1 (NUMERATOR (* I (/ J)))))
                            (j (DENOMINATOR (* I (/ J)))))
           
                (:instance  nonnegative-integer-quotient-lower-bound-rewrite
                            (i (* -1 (NUMERATOR (* I (/ J)))))
                            (j (DENOMINATOR (* I (/ J))))))
           )  )
  )



(defthm dumb
  (equal (< x x)
         nil))

(defthm floor-with-j-zero
  (equal (floor i 0)
                  0)
  :hints (("Goal" :in-theory (enable floor)))
)


;(defthm floor-greater-than-zero-rewrite
 ; (equal (< 0 (fl i j))
  ;       (

(defthm floor-upper-bound-2
  (implies (and (<= 0 j)
                (case-split (rationalp i))
                (case-split (rationalp j))
                (case-split (not (equal j 0)))
                )
           (<= (* j (floor i j)) i))
  :hints (("Goal" :in-theory (disable  floor-upper-bound)
           :use  floor-upper-bound))
  :rule-classes (:rewrite (:linear :trigger-terms ((floor i j))))

  )


(defthm floor-upper-bound-3
  (implies (and (<= j 0)
                (case-split (rationalp i))
                (case-split (rationalp j))
                (case-split (not (equal j 0)))
                )
           (<= i (* j (floor i j))))
  :hints (("Goal" :in-theory (disable  floor-upper-bound)
           :use  floor-upper-bound))
  :rule-classes (:rewrite (:linear :trigger-terms ((floor i j))))

  )


;BOZO remove the disables (and prove better nniq rules, and disable nniq!)
(defthm floor-lower-bound
  (implies (and (case-split (rationalp i))
                (case-split (rationalp j))
                )
           (< (+ -1 (* i (/ j))) (floor i j)))
  :otf-flg t
  :hints (("Goal"
             
           :in-theory (set-difference-theories
                       (enable floor)
                       '( ;why do these disables help so much?
                         less-than-multiply-through-by-inverted-factor-from-left-hand-side
                         less-than-multiply-through-by-inverted-factor-from-right-hand-side
                         EQUAL-MULTIPLY-THROUGH-BY-INVERTED-FACTOR-FROM-RIGHT-HAND-SIDE
                         )
                       )))
  :rule-classes (:rewrite (:linear :trigger-terms ((floor i j)))))





(defthm floor-when-arg-quotient-isnt-rational
  (IMPLIES (NOT (RATIONALP (* i (/ j))))
           (EQUAL (FLOOR i j) 0))
  :hints (("Goal" :in-theory (enable floor))))

(defthm floor-of-non-rational-by-one
  (implies (not (rationalp i))
           (equal (floor i 1)
                  0))
  :hints (("Goal" :in-theory (enable floor))))

(defthm floor-of-rational-and-complex
  (implies (and (rationalp i)
                (not (rationalp j))
                (case-split (acl2-numberp j)))
           (and (equal (floor i j)
                       0)
                (equal (floor j i)
                       0)))
  :hints (("Goal" :in-theory (enable floor))))

#|
(defthm floor-of-two-complexes
  (implies (and (complex-rationalp i)
                (complex-rationalp j))
           (equal (floor i j)
                  (if (rationalp (/ i j))
                      (floor (/ i j) 1)
                    0)))
  :hints (("Goal" :in-theory (enable floor))))
|#

(defthm floor-with-i-not-rational
  (implies (not (rationalp i))
           (equal (floor i j)
                  (if (and (complex-rationalp i) (complex-rationalp j) (rationalp (/ i j)))
                      (floor (/ i j) 1)
                    0)))
  :hints (("Goal" :in-theory (enable floor))))

(defthm floor-with-j-not-rational
  (implies (not (rationalp j))
           (equal (floor i j)
                  (if (and (complex-rationalp i) (complex-rationalp j) (rationalp (/ i j)))
                      (floor (/ i j) 1)
                    0)))
  :hints (("Goal" :in-theory (enable floor))))




(defthm floor-with-j-not-rational-but-i-rational
  (implies (and (not (rationalp i))
                (rationalp j)
                )
           (equal (floor i j)
                  0)))

#|
(defthm floor-by-one-equal-zero
  (implies (and (rationalp i)
                (rationalp j))
           (equal (EQUAL 0 (FLOOR (* i (/ j)) 1))
                  (integerp (* i (/ j)))))
  :hints (("Goal" :in-theory (enable floor)))
)
|#

(defthm floor-of-zero
  (equal (floor 0 j)
         0))

(defthm floor-of-integer-by-1
  (implies (integerp i)
           (equal (floor i 1)
                  i))
  :hints (("Goal" :in-theory (enable  floor))))