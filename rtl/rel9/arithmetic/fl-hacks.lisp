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

;;;***************************************************************
;;;An ACL2 Library of Floating Point Arithmetic

;;;David M. Russinoff
;;;Advanced Micro Devices, Inc.
;;;February, 1998
;;;***************************************************************

#|
This book contains a few hacks about fl which aren't used elsewhere in support/.

|#

(in-package "ACL2")

(include-book "ground-zero")
;(include-book "basic") ;drop?

(defund fl (x)
  (declare (xargs :guard (real/rationalp x)))
  (floor x 1))

(local (include-book "inverted-factor"))
(local (include-book "nniq"))
(local (include-book "numerator"))
(local (include-book "denominator"))
(local (include-book "fp2"))
(local (include-book "predicate"))
(local (include-book "product"))
(local (include-book "unary-divide"))
(local (include-book "rationalp"))
(local (include-book "integerp"))
(local (include-book "fl")) ;drop?
(local (include-book "mod"))
(local (include-book "even-odd"))
(local (include-book "../../../meta/meta-plus-equal"))

(local (include-book "arith"))

;used anywhere?
;exported in lib/basic
(defthm fl-m-1
  (implies (and (< 0 n) ;(not (equal n 0))
                (integerp m)
                (integerp n)
                )
           (= (fl (- (/ (1+ m) n)))
              (1- (- (fl (/ m n))))))
  :otf-flg t
  :rule-classes ()
  :hints (
          ("goal" :in-theory (disable fl-def-linear-part-2
                                      LESS-THAN-MULTIPLY-THROUGH-BY-INVERTED-FACTOR-FROM-LEFT-HAND-SIDE)
           :use ((:instance  fl-of-fraction-min-change
                             (p (+ 1 m)) (q n))
                 (:instance fl-unique (x (* M (/ N)))
                            (n (+ -1 (+ (/ N) (* M (/ N))))))
                 (:instance fl-unique (x (+ (/ N) (* M (/ N))))
                            (n (FL (* M (/ N)))))

                 ))))

(defthm fl-m-n
  (implies (and (< 0 n)
                (integerp m)
                (integerp n))
           (= (fl (- (/ m n)))
              (1- (- (fl (/ (1- m) n))))))
  :hints (("Goal" :use ((:instance fl-m-1 (m (1- m))))))
  :rule-classes ())

;remove?  doesn't seem to be used anywhere or exported in lib/
;just a special case of the above...
(defthm fl-lemma
    (implies (integerp m)
	     (= (fl (- (/ (1+ m) 2)))
		(1- (- (fl (/ m 2))))))
  :rule-classes ()
  :hints (("goal" :use (:instance fl-m-1 (n 2)))))




