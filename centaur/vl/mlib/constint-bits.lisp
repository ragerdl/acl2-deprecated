; VL Verilog Toolkit
; Copyright (C) 2008-2014 Centaur Technology
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
(include-book "welltyped")
(local (include-book "../util/arithmetic"))
(local (include-book "arithmetic-3/floor-mod/floor-mod" :dir :system))
(local (std::add-default-post-define-hook :fix))
(local (in-theory (disable acl2::functional-commutativity-of-minus-*-left
                           acl2::normalize-factors-gather-exponents)))

;; The code here is styled after vl-msb-bitslice-constint, but whereas that
;; code produces new expressions, here we just produce a bit list.

(local (defthm logand-1
         (implies (natp value)
                  (equal (logand value 1)
                         (mod value 2)))))

(define vl-constint-lsb-bits-aux
  :parents (vl-constint->msb-bits)
  ((len   natp)
   (value natp))
  :returns (lsb-bits vl-bitlist-p)
  :verbosep t
  :measure (nfix len)
  (b* (((when (zp len))
        nil)
       (floor2          (mbe :logic (floor (nfix value) 2)
                             :exec (ash value -1)))
       ((the bit mod2)  (mbe :logic (mod (nfix value) 2)
                             :exec (logand value 1)))
       (bit             (if (eql mod2 0)
                            :vl-0val
                          :vl-1val)))
    (cons bit
          (vl-constint-lsb-bits-aux (mbe :logic (- (nfix len) 1)
                                         :exec (- len 1))
                                    floor2)))
  ///
  (defthm true-listp-of-vl-constint-lsb-bits-aux
    (true-listp (vl-constint-lsb-bits-aux len value))
    :rule-classes :type-prescription)
  (defthm len-of-vl-constint-lsb-bits-aux
    (equal (len (vl-constint-lsb-bits-aux len value))
           (nfix len))))


(define vl-constint-msb-bits-aux
  :parents (vl-constint->msb-bits)
  :short "Accumulate lsb's into acc, which produces an MSB-ordered list."
  ((len natp)
   (value natp)
   acc)
  :measure (nfix len)
  :enabled t
  (mbe :logic
       (revappend (vl-constint-lsb-bits-aux len value) acc)
       :exec
       (b* (((when (zp len))
             acc)
            (floor2           (mbe :logic (floor value 2)
                                   :exec (ash value -1)))
            ((the bit mod2)   (mbe :logic (mod value 2)
                                   :exec (logand value 1)))
            (bit              (if (eql mod2 0)
                                  :vl-0val
                                :vl-1val)))
         (vl-constint-msb-bits-aux (mbe :logic (- (nfix len) 1)
                                        :exec (- len 1))
                                   floor2
                                   (cons bit acc))))
    :prepwork
    ((local (in-theory (enable vl-constint-lsb-bits-aux)))))


(define vl-constint->msb-bits
  :parents (vl-constint-p)
  :short "Explode a <see topic='@(url vl-expr-welltyped-p)'>well-typed</see>
@(see vl-constint-p) atom into MSB-ordered @(see vl-bitlist-p)."

  ((x vl-expr-p))
  :guard (and (vl-atom-p x)
              (vl-atom-welltyped-p x)
              (vl-fast-constint-p (vl-atom->guts x)))
  :returns (bits vl-bitlist-p)

  :long "<p>We require that @('X') is a well-typed constant integer expression,
i.e., our @(see expression-sizing) transform should have already been run.
Note that the \"propagation step\" of expression sizing should have already
handled any sign/zero extensions, so we assume here that the atom's
@('finalwidth') is already correct and that no extensions are necessary.</p>"

  :prepwork
  ((local (in-theory (enable vl-atom-welltyped-p))))

  (vl-constint-msb-bits-aux (vl-atom->finalwidth x)
                            (vl-constint->value (vl-atom->guts x))
                            nil)
  ///
  (defthm true-listp-of-vl-constint->msb-bits
    (true-listp (vl-constint->msb-bits x))
    :rule-classes :type-prescription)
  (defthm len-of-vl-constint->msb-bits
    (equal (len (vl-constint->msb-bits x))
           (nfix (vl-atom->finalwidth x)))))


(local
 (assert! (equal (vl-constint->msb-bits
                  (make-vl-atom :guts (make-vl-constint :origwidth 5
                                                        :origtype :vl-signed
                                                        :value 7)
                                :finalwidth 5
                                :finaltype :vl-signed))
                 (list :vl-0val
                       :vl-0val
                       :vl-1val
                       :vl-1val
                       :vl-1val))))

(local
 (assert! (equal (vl-constint->msb-bits
                  (make-vl-atom :guts (make-vl-constint :origwidth 5
                                                        :origtype :vl-unsigned
                                                        :value 15)
                                :finalwidth 5
                                :finaltype :vl-unsigned))
                 (list :vl-0val
                       :vl-1val
                       :vl-1val
                       :vl-1val
                       :vl-1val))))



