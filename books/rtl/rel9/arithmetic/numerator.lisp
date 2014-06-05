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

;ass also some stuff in nniq.lisp

(local (include-book "ground-zero"))
(local (include-book "fp2"))
(local (include-book "denominator")) ;drop?
(local (include-book "predicate"))

(defthm numerator-of-non-rational-is-zero
  (implies (not (rationalp x))
           (equal (numerator x)
                  0)))


;;
;; type-prescriptions
;;

;(thm (integerp (numerator x))) goes through

(defthm numerator-negative-integer-type-prescription
  (implies (and (< x 0)
                (case-split (rationalp x)))
           (and (< (numerator x) 0)
                (integerp (numerator x))))
  :rule-classes (:type-prescription))

(defthm numerator-positive-integer-type-prescription
  (implies (and (< 0 x)
                (case-split (rationalp x)))
           (and (< 0 (numerator x))
                (integerp (numerator x))))
  :rule-classes (:type-prescription))
           
(defthm numerator-non-positive-integer-type-prescription
  (implies (<= x 0)
           (and (<= (numerator x) 0)
                (integerp (numerator x))))
  :rule-classes (:type-prescription))

(defthm numerator-non-negative-integer-type-prescription
  (implies (<= 0 x)
           (and (<= 0 (numerator x))
                (integerp (numerator x))))
  :rule-classes (:type-prescription))

;;
;; comparisons with zero
;;


(defthm numerator-less-than-zero
  (implies (case-split (rationalp x))
           (equal (< (numerator x) 0)
                  (< x 0)))
   :hints (("goal" :in-theory (disable rational-implies2)
           :use (rational-implies2))))

(defthm numerator-greater-than-zero
  (implies (case-split (rationalp x))
           (equal (< 0 (numerator x))
                  (< 0 x)))
   :hints (("goal" :in-theory (disable rational-implies2)
           :use (rational-implies2))))

(defthm numerator-equal-zero
  (implies (case-split (rationalp x))
           (equal (equal (numerator x) 0)
                  (equal x 0))))


;;

(defthm numerator-of-integer-is-the-integer-itself
  (implies (integerp x)
           (equal (numerator x)
                  x))
   :hints (("Goal" :in-theory (disable rational-implies2)
           :use (rational-implies2))))