; Record Like Stobjs
; Copyright (C) 2011-2012 Centaur Technology
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
(include-book "defrstobj")
(include-book "typed-record-tests")  ;; for various typed-record types


; basic-tests.lisp
;
; This is just some basic tests of the defrstobj command.  We do some messing
; with packages to see if the macro breaks, and also try defining a large
; machine to see how well proving the supporting theorems scales.

(defrstobj m1  ;; "machine 1"                 ; Executable interface:

  (regs  :type (array integer (32))           ; (get-regs i m1)
         :initially 5                         ; (set-regs i val m1)
         :typed-record int-tr-p)

  (pctr  :type integer                        ; (get-pctr m1)
         :initially 0)                        ; (set-pctr x m1)

  :inline t)


(defrstobj rstobj::m2 ;; weird package to see if we blow up

  ;; Test of a machine with multiple arrays and other fields

  (m2-regs :type (array integer (64))
           :initially 37
           :typed-record int-tr-p)

  ;; Large array to make sure we don't blow up
  (m2-mem  :type (array integer (8192))
           :initially 0
           :typed-record int-tr-p)

  (m2-foo  :initially nil)
  (m2-bar  :initially bar)

  (m2-actr :type integer :initially 0)
  (m2-bctr :type integer :initially 1)

  :inline t)



(defrstobj m3

  ;; Test of some other typed-record types

  (m3-regs :type (array integer (64))
           :initially 37
           :typed-record int-tr-p)

  (rstobj::m3-mem  :type (array integer (8192))
           :initially 0
           :typed-record int-tr-p)

  (m3-chars :type (array character (256))
            :initially #\a
            :typed-record char-tr-p)

  (m3-bits  :type (array bit (12345))
            :initially 0
            :typed-record bit-tr-p)

  (m3-foo  :initially nil)
  (m3-bar  :initially bar)

  (m3-actr :type integer :initially 0)
  (m3-bctr :type integer :initially 1)

  :inline t)


(defrstobj m4

  (m4-regs :type (array (unsigned-byte 128) (64))
           :initially 321
           :typed-record ub128-tr-p)

  (m4-mem :type (array (unsigned-byte 8) (65536))
          :initially 17
          :typed-record ub8-tr-p)

  (m4-sregs :type (array (signed-byte 32) (11))
            :initially 12
            :typed-record sb32-tr-p)

  (m4-flags :type (unsigned-byte 1234) :initially 127)

  :inline t)


(defrstobj m5

  ;; Just a big test of a stobj with many array fields and many normal fields.
  ;; Performance is not great yet, but maybe we can improve it.

  (m5-arr0 :type (array (unsigned-byte 128) (64))
           :initially 0
           :typed-record ub128-tr-p)

  (m5-arr1 :type (array (unsigned-byte 128) (64))
           :initially 0
           :typed-record ub128-tr-p)

  (m5-arr2 :type (array (unsigned-byte 128) (64))
           :initially 0
           :typed-record ub128-tr-p)

  (m5-arr3 :type (array (unsigned-byte 128) (64))
           :initially 0
           :typed-record ub128-tr-p)

  (m5-arr4 :type (array (unsigned-byte 128) (64))
           :initially 0
           :typed-record ub128-tr-p)



  (m5-arr5 :type (array (unsigned-byte 8) (64))
           :initially 0
           :typed-record ub8-tr-p)

  (m5-arr6 :type (array (unsigned-byte 8) (64))
           :initially 0
           :typed-record ub8-tr-p)

  (m5-arr7 :type (array (unsigned-byte 8) (64))
           :initially 0
           :typed-record ub8-tr-p)

  (m5-arr8 :type (array (unsigned-byte 8) (64))
           :initially 0
           :typed-record ub8-tr-p)

  (m5-arr9 :type (array (unsigned-byte 8) (64))
           :initially 0
           :typed-record ub8-tr-p)


  (m5-arr10 :type (array integer (64))
            :initially 0
            :typed-record int-tr-p)

  (m5-arr11 :type (array integer (64))
            :initially 0
            :typed-record int-tr-p)

  (m5-arr12 :type (array integer (64))
            :initially 0
            :typed-record int-tr-p)

  (m5-arr13 :type (array integer (64))
            :initially 0
            :typed-record int-tr-p)

  (m5-arr14 :type (array integer (64))
            :initially 0
            :typed-record int-tr-p)


  (m5-fld1 :type integer :initially 0)
  (m5-fld2 :type integer :initially 0)
  (m5-fld3 :type integer :initially 0)
  (m5-fld4 :type integer :initially 0)
  (m5-fld5 :type integer :initially 0)

  (m5-fld6 :type character :initially #\a)
  (m5-fld7 :type character :initially #\a)
  (m5-fld8 :type character :initially #\a)
  (m5-fld9 :type character :initially #\a)
  (m5-fld10 :type character :initially #\a)

  (m5-fld11 :initially nil)
  (m5-fld12 :initially nil)
  (m5-fld13 :initially nil)
  (m5-fld14 :initially nil)
  (m5-fld15 :initially nil))


