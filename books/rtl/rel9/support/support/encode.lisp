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

(local ; ACL2 primitive
 (defun natp (x)
   (declare (xargs :guard t))
   (and (integerp x)
        (<= 0 x))))

(defund bvecp (x k)
  (declare (xargs :guard (integerp k)))
  (and (integerp x)
       (<= 0 x)
       (< x (expt 2 k))))


(defund fl (x)
  (declare (xargs :guard (real/rationalp x)))
  (floor x 1))

(local (include-book "../../arithmetic/top"))

(defun expo-measure (x)
;  (declare (xargs :guard (and (real/rationalp x) (not (equal x 0)))))
  (cond ((not (rationalp x)) 0)
	((< x 0) '(2 . 0))
	((< x 1) (cons 1 (fl (/ x))))
	(t (fl x))))

(defund expo (x)
  (declare (xargs :guard t
                  :measure (expo-measure x)))
  (cond ((or (not (rationalp x)) (equal x 0)) 0)
	((< x 0) (expo (- x)))
	((< x 1) (1- (expo (* 2 x))))
	((< x 2) 0)
	(t (1+ (expo (/ x 2))))))

(local (include-book "ground-zero"))
(local (include-book "bvecp"))
(local (include-book "ash"))
(local (include-book "float"))

(defund encode (x n)
  (declare (xargs :guard (and (acl2-numberp x)
                              (integerp n)
                              (<= 0 n))))
  (if (zp n) 
      0
    (if (= x (ash 1 n))
        n
      (encode x (1- n)))))

(defthm encode-nonnegative-integer-type
  (and (integerp (encode x n))
       (<= 0 (encode x n)))
  :rule-classes (:type-prescription)
  :hints (("Goal" :in-theory (enable encode))))

;this rule is no better than encode-nonnegative-integer-type and might be worse:
(in-theory (disable (:type-prescription encode)))

(defthm encode-natp
  (natp (encode x n)))

(defthm encode-bvecp-helper
  (implies (and (case-split (integerp n))
                (case-split (<= 0 n))
                )
           (bvecp (encode x n) (+ 1 (expo n)))) ;The +1 is necessary
  :hints (("Subgoal *1/5" :use (:instance EXPT-WEAK-MONOTONE
                                          (n (+ 1 (EXPO (1- N)))) 
                                          (m (+ 1 (EXPO N))))
           :in-theory (set-difference-theories
                       (enable encode bvecp power2p ash-rewrite)
                       '(
                         expt-compare
                         )))
          ("Goal"
           :in-theory (set-difference-theories
                       (enable encode bvecp power2p ash-rewrite)
                       '(
                         expt-compare
                         )))
          ))

(defthm encode-bvecp-old
  (implies (and (<= (+ 1 (expo n)) k)
                (case-split (integerp k))
                )
           (BVECP (ENCODE x n) k))
  :hints (("Goal" :in-theory (disable encode-bvecp-helper)
           :expand (ENCODE X N)
           :use  (encode-bvecp-helper))))

(defthmd expo-expt-reduction
  (implies (and (integerp k)
                (rationalp n)
                (< 0 n)
                (< n (expt 2 k)))
           (<= (+ 1 (expo n)) k))
  :hints (("Goal" :use ((:instance expo-comparison-rewrite-to-bound-2
                                   (k (1- k))
                                   (x n)))
           :in-theory (disable expo-comparison-rewrite-to-bound-2))))

(local
 (defthmd encode-non-positive-integer
   (implies (not (and (integerp n)
                      (< 0 n)))
            (equal (encode x n) 0))
   :hints (("Goal" :expand ((encode x n))))))

(defthm encode-bvecp
  (implies (and (< n (expt 2 k))
                (case-split (integerp k)))
           (bvecp (encode x n) k))
  :hints (("Goal" :in-theory (enable expo-expt-reduction encode-non-positive-integer)
           :cases ((and (integerp n) (< 0 n))))))

; may not need this now
(defthm encode-reduce-n
  (implies (and (integerp n)
                (<= 0 n)
                (bvecp x n))
           (equal (encode x n)
                  (encode x (1- n))))
  :hints (("Goal" :in-theory (set-difference-theories
                              (enable encode bvecp power2p ash-rewrite )
                              '(
                                expt-compare
                                )))))


