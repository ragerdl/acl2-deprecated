; Centaur Bitops Library
; Copyright (C) 2010-2013 Centaur Technology
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

; fast-logrev.lisp
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "ACL2")
(include-book "std/util/define" :dir :system)
(include-book "centaur/misc/arith-equivs" :dir :system)
(local (include-book "signed-byte-p"))
(local (include-book "ihsext-basics"))
(local (include-book "centaur/gl/gl" :dir :system))
(local (include-book "equal-by-logbitp"))
(local (include-book "arithmetic/top" :dir :system))

(defxdoc bitops/fast-logrev
  :parents (bitops logrev)
  :short "Optimized definitions of @(see logrev) at particular sizes.")

(local (xdoc::set-default-parents bitops/fast-logrev))

(define fast-logrev-u8 ((x :type (unsigned-byte 8)))
  :returns (reverse-x)
  :inline t
  :enabled t
  :verify-guards nil
  :short "Fast implementation of @('(logrev 8 x)') for bytes."

  :long "<p>This function is based on the <i>Reverse the bits in a byte with 7
operations (no 64-bit)</i> algorithm, described on Sean Anderson's <a
href='http://graphics.stanford.edu/~seander/bithacks.html#ReverseByteWith32Bits'>Bit
Twiddling Hacks</a> page.</p>

<p>I use this non-64-bit version, even though it takes more operations than
some of the other algorithms, because it uses at most a 49-bit integer, which
is a fixnum on CCL and probably most other 64-bit Lisps.  In contrast, the
64-bit algorithms (probably) would require bignums.</p>

<p>Anyway, it's at least a pretty good improvement over @(see logrev).</p>

@({
   (let ((byte #b101010)
         (times 100000000))
     ;; 12.18 seconds
     (time (loop for i fixnum from 1 to times do (logrev 8 byte)))
     ;; .32 seconds
     (time (loop for i fixnum from 1 to times do (fast-logrev-u8 byte))))
})"

; Original version:
;
; b = ((b * 0x0802LU & 0x22110LU) | (b * 0x8020LU & 0x88440LU)) * 0x10101LU >> 16;
;
; Rewritten to make precedence clear:
;
; temp1 = (b * 0x0802LU & 0x22110LU)
; temp2 = (b * 0x8020LU & 0x88440LU)
; temp3 = temp1 | temp2
; temp4 = temp3 * 0x10101LU
; result = temp4 >> 16

  (mbe :logic (logrev 8 x)
       :exec
       (b* (((the (unsigned-byte 32) t1)
             (logand (the (unsigned-byte 32) (* (the (unsigned-byte 16) x)
                                                (the (unsigned-byte 16) #x0802)))
                     (the (unsigned-byte 32) #x22110)))
            ((the (unsigned-byte 32) t2)
             (logand (the (unsigned-byte 32) (* (the (unsigned-byte 16) x)
                                           (the (unsigned-byte 16) #x8020)))
                     (the (unsigned-byte 32) #x88440)))
            ((the (unsigned-byte 32) t3)
             (logior (the (unsigned-byte 32) t1)
                     (the (unsigned-byte 32) t2)))
            ((the (unsigned-byte 49) t4)
             (* (the (unsigned-byte 32) t3)
                (the (unsigned-byte 17) #x10101)))
            ((the (unsigned-byte 33) t5)
             (ash t4 -16)))
         (the (unsigned-byte 8)
           (logand t5 #xFF))))

  ///
  (local (defthm crock
           ;; Unfortunately, the signed-byte-p book's lemmas for bounding * don't
           ;; handle mixed sizes very well.
           (implies (and (unsigned-byte-p 32 a)
                         (unsigned-byte-p 17 b))
                    (and (unsigned-byte-p 49 (* a b))
                         (unsigned-byte-p 49 (* b a))))
           :hints(("goal" :use ((:instance lousy-unsigned-byte-p-of-*-mixed
                                           (n1 32)
                                           (n2 17)))))))

  (local (def-gl-thm crock2
           :hyp (unsigned-byte-p 8 x)
           :concl
           (EQUAL (LOGREV 8 X)
                  (LOGHEAD 8
                           (LOGTAIL 16
                                    (* 65793
                                       (LOGIOR (LOGAND 139536 (* 2050 X))
                                               (LOGAND 558144 (* 32800 X)))))))
           :g-bindings (gl::auto-bindings (:nat x 8))))

  (verify-guards+ fast-logrev-u8))


(define fast-logrev-u16 ((x :type (unsigned-byte 16)))
  :returns (reverse-x)
  :enabled t
  :short "Fast implementation of @('(logrev 16 x)') for 16-bit unsigned values."
  :long "
@({
    (let ((x     #xdead)
          (times 100000000))
      ;; 24.198 seconds
      (time (loop for i fixnum from 1 to times do (logrev 16 x)))
      ;; 1.214 seconds
      (time (loop for i fixnum from 1 to times do (fast-logrev-u16 x))))
})"
  :verify-guards nil
  (mbe :logic (logrev 16 x)
       :exec
       (b* (((the (unsigned-byte 8) low)   (logand x #xFF))
            ((the (unsigned-byte 8) high)  (ash x -8))
            ((the (unsigned-byte 8) rlow)  (fast-logrev-u8 low))
            ((the (unsigned-byte 8) rhigh) (fast-logrev-u8 high)))
         (the (unsigned-byte 16)
           (logior (the (unsigned-byte 16) (ash rlow 8))
                   rhigh))))
  ///
  (local (defthm crock
           (equal (logrev 16 x)
                  (logior (ash (logrev 8 x) 8)
                          (logrev 8 (logtail 8 x))))
           :hints((equal-by-logbitp-hammer))))
  (verify-guards fast-logrev-u16))



(define fast-logrev-u32 ((x :type (unsigned-byte 32)))
  :returns (reverse-x)
  :enabled t
  :short "Faster implementation of @('(logrev 32 x)') for 32-bit unsigned
values."
  :long "<p>We could probably do better using the <i>Reverse an N-bit quantity
in parallel in 5 * lg(N) operations</i> algorithm, but this is at least pretty
fast.</p>

@({
    (let ((x     #xdeadbeef)
          (times 50000000))
      ;; 23.864 seconds
      (time (loop for i fixnum from 1 to times do (logrev 32 x)))
      ;; 1.296 seconds
      (time (loop for i fixnum from 1 to times do (fast-logrev-u32 x))))
})"

  :verify-guards nil
  (mbe :logic (logrev 32 x)
       :exec
       (b* (((the (unsigned-byte 16) low)   (logand x #xFFFF))
            ((the (unsigned-byte 16) high)  (ash x -16))
            ((the (unsigned-byte 16) rlow)  (fast-logrev-u16 low))
            ((the (unsigned-byte 16) rhigh) (fast-logrev-u16 high)))
         (the (unsigned-byte 32)
           (logior (the (unsigned-byte 32) (ash rlow 16))
                   rhigh))))
  ///
  (local (defthm crock
           (equal (logrev 32 x)
                  (logior (ash (logrev 16 x) 16)
                          (logrev 16 (logtail 16 x))))
           :hints((equal-by-logbitp-hammer))))
  (verify-guards fast-logrev-u32))



(define fast-logrev-u64 ((x :type (unsigned-byte 64)))
  :returns (reverse-x)
  :enabled t
  :short "Faster implementation of @('(logrev 64 x)') for 64-bit unsigned
values."
  :long "<p>We could probably do better using the <i>Reverse an N-bit quantity
in parallel in 5 * lg(N) operations</i> algorithm, but this is at least
pretty fast.</p>

@({
    (let ((x     #xfeedd00ddeadbeef)
          (times 10000000))
      ;; 21.744 seconds, 3.2 GB
      (time (loop for i fixnum from 1 to times do (logrev 64 x)))
      ;; .767 seconds, 320 MB
      (time (loop for i fixnum from 1 to times do (fast-logrev-u64 x))))
})"

  :verify-guards nil
  (mbe :logic (logrev 64 x)
       :exec
       (b* (((the (unsigned-byte 32) low)   (logand x #xFFFFFFFF))
            ((the (unsigned-byte 32) high)  (ash x -32))
            ((the (unsigned-byte 32) rlow)  (fast-logrev-u32 low))
            ((the (unsigned-byte 32) rhigh) (fast-logrev-u32 high)))
         (the (unsigned-byte 64)
           (logior (the (unsigned-byte 64) (ash rlow 32))
                   rhigh))))
  ///
  (local (defthm crock
           (equal (logrev 64 x)
                  (logior (ash (logrev 32 x) 32)
                          (logrev 32 (logtail 32 x))))
           :hints((equal-by-logbitp-hammer))))
  (verify-guards fast-logrev-u64))
