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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "std/util/define" :dir :system)
(include-book "ihs/basic-definitions" :dir :system)
(local (include-book "ihsext-basics"))

(defsection bitops/fast-logext
  :parents (bitops)
  :short "This book provides optimized sign-extension functions, which are
proven equivalent to @(see logext) via @(see mbe).")


(defsection fast-logext
  :parents (bitops/fast-logext logext)
  :short "@(call fast-logext) interprets the least significant @('n') bits of
the integer @('x') as a signed number of width @('n')."

  :long "<p>This is logically identical to @(see logext).  But, for better
performance we adopt a method from Sean Anderson's <a
href='http://graphics.stanford.edu/~seander/bithacks.html'>bit twiddling
hacks</a> page, viz:</p>

@({
unsigned n;                  // number of bits representing the number in x
int x;                       // sign extend this n-bit number to r
int r;                       // resulting sign-extended number
int const m = 1U << (n - 1); // mask can be pre-computed if n is fixed
x = x & ((1U << n) - 1);     // (Skip this if bits in x above position n are already zero.)
r = (x ^ m) - m;
})

<p>@('fast-logext') is actually a macro.  Generally it expands into a call of
@('fast-logext-fn'), which carries out the above computation.  But in the
common cases where @('n') is explicitly 8, 16, 32, or 64, it instead expands
into a call of a specialized, inlined function.</p>

@(def fast-logext)"

  (defmacro fast-logext (n x)
    (cond ((eql n 8)   `(fast-logext8 ,x))
          ((eql n 16)  `(fast-logext16 ,x))
          ((eql n 32)  `(fast-logext32 ,x))
          ((eql n 64)  `(fast-logext64 ,x))
          (t           `(fast-logext-fn ,n ,x)))))

(define fast-logext-exec ((b posp)
                          (x integerp))
  :parents (fast-logext)
  :short "Executable definition of @(see fast-logext) in the general case."
  :inline t
  (b* ((x1 (logand (1- (ash 1 b)) x)) ;; x = x & ((1U << b) - 1)
       (m  (ash 1 (- b 1))))          ;; int const m = 1U << (b - 1)
    (- (logxor x1 m) m))              ;; r = (x ^ m) - m
  ///
  (local (include-book "arithmetic/top" :dir :system))
  (local (include-book "ihs-extensions"))

  (local (defthm l0
           (implies (integerp x)
                    (equal (- x)
                           (+ 1 (lognot x))))
           :hints(("Goal" :in-theory (enable lognot)))))

  (local (defthm l1
           (equal (+ (logcar x) (b-not (logcar x)))
                  1)
           :hints(("Goal" :in-theory (enable b-not)))))

  (local (defthm l2
           (equal (+ (logcar x) (b-not (logcar x)) y)
                  (+ 1 y))))

  (defthm fast-logext-exec-is-logext
    (implies (posp b)
             (equal (fast-logext-exec b x)
                    (logext b x)))
    :hints(("Goal"
            :induct (logext-ind b x)
            :in-theory (e/d* (fast-logext-exec
                              ihsext-recursive-redefs
                              equal-logcons-strong)
                             (ash-1-removal
                              logand-with-bitmask
                              logand-with-negated-bitmask))))))

(define fast-logext-fn ((b posp)
                        (x integerp))
  :parents (fast-logext)
  :enabled t
  :short "Implementation of @(see fast-logext) in the general case."
  (mbe :logic (logext b x)
       :exec (fast-logext-exec b x))
  ///
  (add-macro-alias fast-logext fast-logext-fn))


(define fast-logext8 ((x integerp))
  :parents (fast-logext)
  :short "Optimized implementation of 8-bit sign-extension."
  :inline t
  :enabled t
  (mbe :logic (logext 8 x)
       :exec (the (signed-byte 8)
               (- (the (unsigned-byte 8)
                    (logxor (the (unsigned-byte 8) (logand #xFF x))
                            (the (unsigned-byte 8) #x80)))
                  #x80)))
  :prepwork
  ((local (defthm fast-logext8-crux
            (equal (+ #x-80 (logxor (logand #xFF x) #x80))
                   (logext 8 x))
            :hints(("Goal"
                    :in-theory (e/d (fast-logext-exec)
                                    (fast-logext-exec-is-logext))
                    :use ((:instance fast-logext-exec-is-logext (b 8)))))))))


(define fast-logext16 ((x integerp))
  :parents (fast-logext)
  :short "Optimized implementation of 16-bit sign-extension."
  :inline t
  :enabled t
  (mbe :logic (logext 16 x)
       :exec (the (signed-byte 16)
               (- (the (unsigned-byte 16)
                    (logxor (the (unsigned-byte 16) (logand #xFFFF x))
                            (the (unsigned-byte 16) #x8000)))
                  #x8000)))
  :prepwork
  ((local (defthm fast-logext16-crux
            (equal (+ #x-8000 (logxor (logand #xFFFF x) #x8000))
                   (logext 16 x))
            :hints(("Goal"
                    :in-theory (e/d (fast-logext-exec)
                                    (fast-logext-exec-is-logext))
                    :use ((:instance fast-logext-exec-is-logext (b 16)))))))))


(define fast-logext32 ((x integerp))
  :parents (fast-logext)
  :short "Optimized implementation of 32-bit sign-extension."
  :inline t
  :enabled t
  (mbe :logic (logext 32 x)
       :exec (the (signed-byte 32)
               (- (the (unsigned-byte 32)
                    (logxor (the (unsigned-byte 32) (logand #uxFFFF_FFFF x))
                            (the (unsigned-byte 32) #ux8000_0000)))
                  #ux8000_0000)))
  :prepwork
  ((local (defthm fast-logext32-crux
            (equal (+ #ux-8000_0000 (logxor (logand #uxFFFF_FFFF x) #ux8000_0000))
                   (logext 32 x))
            :hints(("Goal"
                    :in-theory (e/d (fast-logext-exec)
                                    (fast-logext-exec-is-logext))
                    :use ((:instance fast-logext-exec-is-logext (b 32)))))))))


(define fast-logext64 ((x integerp))
  :parents (fast-logext)
  :short "Optimized implementation of 64-bit sign-extension."
  :inline t
  :enabled t
  (mbe :logic (logext 64 x)
       :exec (the (signed-byte 64)
               (- (the (unsigned-byte 64)
                    (logxor (the (unsigned-byte 64) (logand #uxFFFF_FFFF_FFFF_FFFF x))
                            (the (unsigned-byte 64) #ux8000_0000_0000_0000)))
                  #ux8000_0000_0000_0000)))
  :prepwork
  ((local (defthm fast-logext64-crux
            (equal (+ #ux-8000_0000_0000_0000
                      (logxor (logand #uxFFFF_FFFF_FFFF_FFFF x)
                              #ux8000_0000_0000_0000))
                   (logext 64 x))
            :hints(("Goal"
                    :in-theory (e/d (fast-logext-exec)
                                    (fast-logext-exec-is-logext))
                    :use ((:instance fast-logext-exec-is-logext (b 64)))))))))



#||

;; Basic timing tests

(time (loop for i fixnum from 1 to 100000000 do (logext 4 i)))        ;; 5.787 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 8 i)))        ;; 5.446 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 4 i)))   ;; 2.207 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 8 i)))   ;;  .066 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 15 i)))       ;; 5.393 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 16 i)))       ;; 5.381 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 15 i)))  ;; 2.208 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 16 i)))  ;;  .066 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 31 i)))       ;; 5.284 sec
(time (loop for i fixnum from 1 to 100000000 do (logext 32 i)))       ;; 5.237 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 31 i)))  ;; 2.241 sec
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 32 i)))  ;;  .066 sec

(time (loop for i fixnum from 1 to 100000000 do (logext 63 i)))       ;; 6.524 sec, 1.6 GB
(time (loop for i fixnum from 1 to 100000000 do (logext 64 i)))       ;; 6.942 sec, 3.2 GB
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 63 i)))  ;; 42.5 sec (some gc), 12 GB!
(time (loop for i fixnum from 1 to 100000000 do (fast-logext 64 i)))  ;;  .066 sec

||#
