; Centaur Bitops Library
; Copyright (C) 2010-2011 Centaur Technology
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

; ihs-extensions.lisp
;
; This book is can be used instead of ihs/logops-lemmas to add a bunch of
; additional theorems and provide a more sensible theory.  This book should
; typically be only locally included since it makes various changes to the
; global theory such as disabling floor, mod, expt, etc.

(include-book "ihsext-basics")
(include-book "defaults")
(include-book "integer-length")

; (local (include-book "arithmetic-3/extra/top-ext" :dir :system))
(local (include-book "equal-by-logbitp"))

; (local (in-theory (disable expt-between-one-and-two)))




(local (defun dec-induct (n)
         (if (zp n)
             n
           (dec-induct (1- n)))))

(local (defun dec-dec-induct (a b)
         (if (zp a)
             (list a b)
           (dec-dec-induct (- a 1) (- b 1)))))

(local (defun logcdr-logcdr-induct (x y)
         (if (zp x)
             nil
           (if (zp y)
               nil
             (logcdr-logcdr-induct (logcdr x) (logcdr y))))))

(local (defun dec-logcdr-induct (a x)
         (if (zp a)
             (list a x)
           (dec-logcdr-induct (1- a) (logcdr x)))))

(local (defun dec-logcdr-logcdr-induct (a x y)
         (if (zp a)
             (list a x y)
           (dec-logcdr-logcdr-induct (- a 1)
                                     (logcdr x)
                                     (logcdr y)))))


(defthm ash-zero
  (equal (ash x 0)
         (ifix x))
  :hints(("Goal" :in-theory (enable ash* ash-induct))))

(defthm ash-1-removal
  (equal (ash 1 n)
         (if (integerp n)
             (if (<= 0 n)
                 (expt 2 n)
               0)
           1))
  :hints(("Goal" :in-theory (enable expt-2-is-ash ash*))))

(theory-invariant (not (and (active-runep '(:rewrite ash-1-removal))
                            (active-runep '(:rewrite expt-2-is-ash)))))

(defthm logcar-possibilities
  (or (equal (logcar a) 0)
      (equal (logcar a) 1))
  :rule-classes ((:forward-chaining :trigger-terms ((logcar a))))
  :hints(("Goal" :use logcar-type)))

(defthm |(logbitp 0 x)|
  (equal (logbitp 0 x)
         (equal (logcar x) 1))
  :hints(("Goal" :in-theory (enable logbitp**))))

(encapsulate
  ()
  ;; The following theorems improve logbitp-0-minus-1 by eliminating
  ;; the unnecessary hyps.

  (defthm |(logbitp a 0)|
    (equal (logbitp a 0) nil))

  (defthm |(logbitp a -1)|
    (equal (logbitp a -1) t)
    :hints(("Goal"
            :induct (dec-induct a)
            :in-theory (enable logbitp**))))

  (in-theory (disable logbitp-0-minus-1)))



(defthm logbitp-upper-bound
  (implies (and (logbitp a x)
                (natp a)
                (natp x))
           (< a (integer-length x)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal"
          :induct (dec-logcdr-induct a x)
          :in-theory (enable logbitp**))))

;; This was slightly rephrased in ihsext-basics.lisp
;;(defthm logcar-of-logior
;;  (equal (logcar (logior x y))
;;         (if (or (= (logcar x) 1)
;;                 (= (logcar y) 1))
;;             1
;;           0))
;;  :hints(("Goal"
;;          :expand (logior x y)
;;          :in-theory (enable logior**))))

;;(defthm logcar-of-logand
;;  (equal (logcar (logand x y))
;;         (if (and (= (logcar x) 1)
;;                  (= (logcar y) 1))
;;             1
;;           0))
;;  :hints(("Goal"
;;          :expand (logand x y)
;;          :in-theory (enable logand**))))

;;(defthm logcar-of-lognot
;;  (equal (logcar (lognot x))
;;         (if (= (logcar x) 1)
;;             0
;;           1))
;;  :hints(("Goal" :in-theory (enable lognot**))))

;;(defthm logcar-of-logxor
;;  (equal (logcar (logxor x y))
;;         (if (or (and (= (logcar x) 1)
;;                      (= (logcar y) 1))
;;                 (and (= (logcar x) 0)
;;                      (= (logcar y) 0)))
;;             0
;;           1))
;;  :hints(("Goal"
;;          :expand (logxor x y)
;;          :in-theory (enable logxor**))))

(defthm |(< (lognot a) 0)|
  (equal (< (lognot a) 0)
         (if (integerp a)
             (<= 0 a)
           t))
  :rule-classes ((:rewrite)
                 (:type-prescription :corollary
                                     (implies (natp a)
                                              (and (integerp (lognot a))
                                                   (< (lognot a) 0))))
                 (:type-prescription :corollary
                                     (implies (and (integerp a)
                                                   (< a 0))
                                              (and (integerp (lognot a))
                                                   (<= 0 (lognot a)))))
                 (:linear :corollary
                          (implies (natp a)
                                   (< (lognot a) 0)))
                 (:linear :corollary
                          (implies (and (integerp a)
                                        (< a 0))
                                   (<= 0 (lognot a)))))
  :hints(("Goal" :in-theory (enable lognot))))

(defthm |(equal (lognot a) 0)|
  ;; This isn't really necessary since cancel-equal-lognot can get it instead.
  ;; On the other hand, this can be an abbreviation rule.
  (equal (equal (lognot a) 0)
         (equal a -1)))


(defthm |(<= 0 (logand a b))|
  (equal (< (logand a b) 0)
         (not (or (not (integerp a))
                  (not (integerp b))
                  (<= 0 a)
                  (<= 0 b))))
  :rule-classes ((:rewrite)
                 (:linear :corollary (implies (natp a)
                                              (<= 0 (logand a b))))
                 (:linear :corollary (implies (natp b)
                                              (<= 0 (logand a b))))
                 (:linear :corollary (implies (and (< a 0)
                                                   (< b 0)
                                                   (integerp a)
                                                   (integerp b))
                                              (< (logand a b) 0)))
                 (:type-prescription :corollary (implies (natp a)
                                                         (and (integerp (logand a b))
                                                              (<= 0 (logand a b)))))
                 (:type-prescription :corollary (implies (natp b)
                                                         (and (integerp (logand a b))
                                                              (<= 0 (logand a b)))))
                 (:type-prescription :corollary (implies (and (< a 0)
                                                              (< b 0)
                                                              (integerp a)
                                                              (integerp b))
                                                         (and (integerp (logand a b))
                                                              (< (logand a b) 0)))))
  :hints(("Goal" :in-theory (enable logand))))

(defthm |(< (logior a b) 0)|
  (equal (< (logior a b) 0)
         (or (and (integerp a)
                  (< a 0))
             (and (integerp b)
                  (< b 0))))
  :rule-classes ((:rewrite)
                 (:linear :corollary
                          (implies (and (natp a)
                                        (natp b))
                                   (<= 0 (logior a b))))
                 (:type-prescription :corollary
                                     (implies (and (natp a)
                                                   (natp b))
                                              (and (integerp (logior a b))
                                                   (<= 0 (logior a b)))))
                 (:linear :corollary
                          (implies (and (integerp a)
                                        (< a 0))
                                   (< (logior a b) 0)))
                 (:type-prescription :corollary
                                     (implies (and (integerp a)
                                                   (< a 0))
                                              (and (integerp (logior a b))
                                                   (< (logior a b) 0))))
                 (:linear :corollary
                          (implies (and (integerp b)
                                        (< b 0))
                                   (< (logior a b) 0)))
                 (:type-prescription :corollary
                                     (implies (and (integerp b)
                                                   (< b 0))
                                              (and (integerp (logior a b))
                                                   (< (logior a b) 0)))))
  :hints(("Goal" :in-theory (enable logior))))


(defthm |(< (logxor a b) 0)|
  (equal (< (logxor a b) 0)
         (if (< (ifix a) 0)
             (not (< (ifix b) 0))
           (< (ifix b) 0)))
  :rule-classes ((:rewrite)
                 (:linear :corollary
                          (implies (and (natp a)
                                        (natp b))
                                   (<= 0 (logxor a b))))
                 (:type-prescription :corollary
                                     (implies (and (natp a)
                                                   (natp b))
                                              (and (integerp (logxor a b))
                                                   (<= 0 (logxor a b)))))
                 (:linear :corollary
                          (implies (and (< a 0)
                                        (integerp a)
                                        (natp b))
                                   (< (logxor a b) 0)))
                 (:type-prescription :corollary
                                     (implies (and (< a 0)
                                                   (integerp a)
                                                   (natp b))
                                              (and (integerp (logxor a b))
                                                   (< (logxor a b) 0))))

                 (:linear :corollary
                          (implies (and (< b 0)
                                        (integerp b)
                                        (natp a))
                                   (< (logxor a b) 0)))
                 (:type-prescription :corollary
                                     (implies (and (< b 0)
                                                   (integerp b)
                                                   (natp a))
                                              (and (integerp (logxor a b))
                                                   (< (logxor a b) 0))))

                 (:linear :corollary
                          (implies (and (< a 0)
                                        (< b 0)
                                        (integerp a)
                                        (integerp b))
                                   (<= 0 (logxor a b))))
                 (:type-prescription :corollary
                                     (implies (and (< a 0)
                                                   (< b 0)
                                                   (integerp a)
                                                   (integerp b))
                                              (and (integerp (logxor a b))
                                                   (<= 0 (logxor a b)))))
                 )
  :hints(("Goal" :in-theory (enable logxor))))



(encapsulate
  ()

  (local (in-theory (e/d* (ihsext-inductions
                           ihsext-recursive-redefs
                           expt-2-is-ash)
                          (ash-1-removal))))

  (defthm logbitp-of-expt-2
    (implies (natp b)
             (equal (logbitp a (expt 2 b))
                    (equal (nfix a) b)))))


(defthm expt-2-lower-bound-by-logbitp
  (implies (and (logbitp n x)
                (natp n)
                (natp x))
           (<= (expt 2 n)
               x))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal" :in-theory (e/d* (ihsext-arithmetic
                                   ihsext-recursive-redefs
                                   ihsext-inductions)
                                  (ash-1-removal)))))


(defthmd logbitp-when-too-small
  (implies (and (< a (expt 2 n))
                (natp a)
                (natp n))
           (equal (logbitp n a)
                  nil)))


(encapsulate
 ()

 (local (in-theory (e/d* (ihsext-arithmetic)
                         (ash-1-removal))))


 (defthm |(logbitp bit (mod a (expt 2 n)))|
   (implies (and (natp bit)
                 (integerp a)
                 (natp n))
            (equal (logbitp bit (mod a (expt 2 n)))
                   (if (< bit n)
                       (logbitp bit a)
                     nil)))))



(defthm normalize-logbitp-when-mods-equal
  (implies (and (equal (mod a (expt 2 n))
                       (mod b (expt 2 n)))
                (syntaxp (term-order b a))
                (< bit n)
                (natp bit)
                (natp n)
                (integerp a)
                (integerp b))
           (equal (logbitp bit b)
                  (logbitp bit a)))
  :hints(("Goal"
          :in-theory (disable |(logbitp bit (mod a (expt 2 n)))|)
          :use ((:instance |(logbitp bit (mod a (expt 2 n)))|)
                (:instance |(logbitp bit (mod a (expt 2 n)))|
                           (a b))))))

(defthmd integer-length-of-loghead
  (<= (integer-length (loghead k a))
      (nfix k))
  :hints(("Goal" :in-theory (enable* ihsext-inductions
                                     ihsext-recursive-redefs)))
  :rule-classes :linear)

(defthm smaller-mods-are-still-the-same
  (implies (and (equal (mod a (expt 2 n))
                       (mod b (expt 2 n)))
                (< k n)
                (integerp a)
                (integerp b)
                (natp k)
                (natp n))
           (equal (equal (mod a (expt 2 k))
                         (mod b (expt 2 k)))
                  t))
  :hints(("Goal" :in-theory (e/d* (ihsext-arithmetic
                                   integer-length-of-loghead
                                   ihsext-inductions
                                   ihsext-recursive-redefs)
                                  (ash-1-removal)))))

(defthm +-of-logcons-with-cin
  (implies (bitp cin)
           (equal (+ cin
                     (logcons b1 r1)
                     (logcons b2 r2))
                  (logcons (b-xor cin (b-xor b1 b2))
                           (+ (b-ior (b-and cin b1)
                                     (b-ior (b-and cin b2)
                                            (b-and b1 b2)))
                              (ifix r1)
                              (ifix r2)))))
  :hints(("Goal" :in-theory (enable logcons))))

(defthm +-of-logcons
  (equal (+ (logcons b1 r1)
            (logcons b2 r2))
         (logcons (b-xor b1 b2)
                  (+ (b-and b1 b2)
                     (ifix r1)
                     (ifix r2))))
  :hints(("Goal" :in-theory (e/d (logcons) (equal-logcons)))))

(encapsulate nil

  ;;(local (include-book "arithmetic-3/extra/top-ext" :dir :system))
  ;;(local (in-theory (disable expt-between-one-and-two
  ;;                           exponents-add-for-nonneg-exponents)))

  (local (include-book "arithmetic/top-with-meta" :dir :system))
  (local (in-theory (e/d* (ihsext-arithmetic
                           ihsext-inductions
                           ihsext-recursive-redefs
                           logcons-<-n-strong
                           logcons->-n-strong)
                          (ash-1-removal
                           exponents-add-for-nonneg-exponents
                           expt))))
  
  (defthm |(2^n + a mod 2^n) when a < 2^n+1|
    (implies (and (case-split (< a (expt 2 (+ 1 n))))
                  (natp a)
                  (natp n))
             (equal (+ (expt 2 n) (mod a (expt 2 n)))
                    (cond ((< a (expt 2 n))
                           (+ (expt 2 n) a))
                          ((< a (expt 2 (+ 1 n)))
                           a))))
    :hints(("Goal" :induct (logbitp-ind n a)
            :in-theory (disable ash*)
            :do-not-induct t)
           (and stable-under-simplificationp
                '(:in-theory (enable ash*)))))

  (defthm small-mods
    (implies (integerp n)
             (and (equal (mod n 1) 0)
                  (equal (mod n 2) (logcar n))))
    :hints (("goal" :use ((:instance mod-to-loghead (n 0) (i n))
                          (:instance mod-to-loghead (n 1) (i n)))
             :in-theory (disable mod-to-loghead))))

  (theory-invariant (not (and (active-runep '(:rewrite small-mods))
                              (active-runep '(:definition logcar)))))

  (defthm |(2^n + a mod 2^n) when 2^n+1 <= a, a[n] = 1|
    (implies (and (case-split (not (< a (expt 2 (+ 1 n)))))
                  (logbitp n a)
                  (natp a)
                  (natp n))
             (equal (+ (expt 2 n) (mod a (expt 2 n)))
                    (mod a (expt 2 (+ 1 n)))))
    :hints(("Goal" :induct (logbitp-ind n a)
            :in-theory (disable ash*)
            :do-not-induct t)
           (and stable-under-simplificationp
                '(:in-theory (enable ash*))))))

(in-theory (disable small-mods))
(local (in-theory (enable small-mods)))



(defthm upper-bound-of-logior-for-naturals
  (implies (and (< x (expt 2 n))
                (< y (expt 2 n))
                (natp x)
                (natp y)
                (posp n))
           (< (logior x y) (expt 2 n)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal"
          :in-theory (disable unsigned-byte-p-logior)
          :use ((:instance unsigned-byte-p-logior
                           (i x)
                           (j y)
                           (size n))))))

(defthm upper-bound-of-logxor-for-naturals
  (implies (and (< x (expt 2 n))
                (< y (expt 2 n))
                (natp x)
                (natp y)
                (posp n))
           (< (logxor x y) (expt 2 n)))
  :rule-classes ((:rewrite) (:linear))
  :hints(("Goal"
          :in-theory (disable unsigned-byte-p-logxor)
          :use ((:instance unsigned-byte-p-logxor
                           (i x)
                           (j y)
                           (size n))))))





(encapsulate nil
  (local (include-book "arithmetic-3/extra/top-ext" :dir :system))

  (defthmd |(integerp (expt x n))|
    (implies (and (integerp x)
                  (< 1 x))
             (equal (integerp (expt x n))
                    (<= 0 (ifix n))))
    :hints(("Goal" :in-theory (enable expt)))))

(local (in-theory (enable |(integerp (expt x n))|)))

(defthmd |(logcdr (expt 2 n))|
  (equal (logcdr (expt 2 n))
         (if (posp n)
             (expt 2 (1- n))
           0))
  :hints(("Goal" :in-theory (e/d* (ihsext-arithmetic)
                                  (ash-1-removal))
          :cases ((= 0 n)
                  (and (not (equal 0 n))
                       (integerp n))))))

(local (in-theory (enable |(logcdr (expt 2 n))|)))

(defthmd |(logcar (expt 2 n))|
  (equal (logcar (expt 2 n))
         (if (= (ifix n) 0)
             1
           0))
  :hints(("Goal" :in-theory (e/d* (ihsext-arithmetic
                                   logcar-of-ash)
                                  (ash-1-removal))
          :cases ((<= 0 n)
                  (and (< n 0)
                       (integerp n))))))

(local (in-theory (enable  |(logcar (expt 2 n))|)))

(encapsulate
  nil
  (local (defthm expt->=-0
           (implies (and (rationalp b)
                         (<= 0 b))
                    (<= 0 (expt b x)))
           :hints(("Goal" :in-theory (enable expt)))
           :rule-classes :linear))

  (defthmd logand-with-2^n-is-logbitp
    (implies (natp n)
             (equal (equal (logand x (expt 2 n)) 0)
                    (not (logbitp n x))))
    :rule-classes ((:rewrite)
                   (:rewrite :corollary
                    (implies (natp n)
                             (equal (equal (logand (expt 2 n) x) 0)
                                    (not (logbitp n x))))))
    :hints(("Goal"
            :in-theory (enable logand$ logbitp**)
            :induct (dec-logcdr-induct n x)))))

(local (in-theory (enable logand-with-2^n-is-logbitp)))


;; A variation on this is proved in ihsext-basics
;;(defthm logbitp-of-ash
;;  (implies (natp a)
;;           (equal (logbitp a (ash x n))
;;                  (cond ((or (not (integerp n))
;;                             (= n 0))
;;                         (logbitp a x))
;;                        ((< n 0)
;;                         (logbitp (- a n) x))
;;                        ((< a n)
;;                         nil)
;;                        (t
;;                         (logbitp (- a n) x))))))




(encapsulate nil
  (local (local (include-book "arithmetic-3/extra/top-ext" :dir :system)))

  (defthmd |(mod a (expt 2 n)) < (expt 2 n)|
    (implies (integerp a)
             (< (mod a (expt 2 n))
                (expt 2 n)))
    :rule-classes ((:rewrite) (:linear)))

  (defthmd expt-2-monotonic
    (implies (and (< a b)
                  (integerp a)
                  (integerp b))
             (< (expt 2 a)
                (expt 2 b)))
    :rule-classes ((:rewrite) (:linear))))

(local (in-theory (enable |(mod a (expt 2 n)) < (expt 2 n)|)))
(local (in-theory (enable expt-2-monotonic)))



(encapsulate nil
  (local (local (include-book "arithmetic-3/extra/top-ext" :dir :system)))

  (defthmd |(logbitp n (+ (expt 2 n) a))|
    (implies (and (integerp a)
                  (natp n))
             (equal (logbitp n (+ (expt 2 n) a))
                    (not (logbitp n a))))
    :rule-classes ((:rewrite)
                   (:rewrite :corollary
                    (implies (and (integerp a)
                                  (natp n))
                             (equal (logbitp n (+ a (expt 2 n)))
                                    (not (logbitp n a))))))
    :hints(("Goal" :in-theory (enable logbitp evenp oddp)))))

(local (in-theory (enable |(logbitp n (+ (expt 2 n) a))|)))

(def-ruleset ihs-ext-disabled-rules
  '(|(integerp (expt x n))|
    |(logcdr (expt 2 n))|
    |(logcar (expt 2 n))|
    logand-with-2^n-is-logbitp
    |(mod a (expt 2 n)) < (expt 2 n)|
    expt-2-monotonic
    |(logbitp n (+ (expt 2 n) a))|))
  
