; ACL2 String Library
; Copyright (C) 2009-2010 Centaur Technology
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

(in-package "STR")
(include-book "strprefixp")
(local (include-book "misc/assert" :dir :system))

(local (defthm prefixp-reflexive
         (prefixp x x)
         :hints(("Goal" :in-theory (enable prefixp)))))

(local (defthm crock
         (implies (and (equal (len x) (len y))
                       (true-listp x)
                       (true-listp y))
                  (equal (prefixp x y)
                         (equal x y)))
         :hints(("Goal" :in-theory (enable prefixp)))))

(local (defthm len-of-nthcdr
         (implies (and (natp n)
                       (<= n (len x)))
                  (equal (len (nthcdr n x))
                         (- (len x) n)))
         :hints(("Goal" :in-theory (enable nthcdr)))))

(defsection strsuffixp
  :parents (substrings)
  :short "Case-sensitive string suffix test."

  :long "<p>@(call strsuffixp) determines if the string <tt>x</tt> is a suffix
of the string <tt>y</tt>, in a case-sensitive manner.</p>

<p>Logically, we ask whether <tt>|x| &lt; |y|</tt>, and whether</p>

<code>
  (equal (nthcdr (- |y| |x|) (coerce x 'list))
         (coerce y 'list)
</code>

<p>But we use a more efficient implementation that avoids coercing the strings
into lists; basically we ask if the last <tt>|x|</tt> characters of <tt>y</tt>
are equal to <tt>x</tt>.</p>

<p>As a corner case, note that this regards the empty string as a suffix of
every other string.  That is, <tt>(strsuffixp \"\" x)</tt> is always
<tt>t</tt>.</p>"

  (defund strsuffixp (x y)
    (declare (xargs :guard (and (stringp x)
                                (stringp y))))
    (let* ((xlen (length x))
           (ylen (length y)))
      (and (<= xlen ylen)
           (mbe :logic
                (equal (nthcdr (- ylen xlen) (coerce y 'list))
                       (coerce x 'list))
                :exec
                (strprefixp-impl x y 0 (- ylen xlen) xlen ylen)))))

  (local (in-theory (enable strsuffixp)))

  (local (defthm c0
           (implies (and (natp n)
                         (<= (len x) n)
                         (true-listp x))
                    (equal (nthcdr n x) nil))))

  (local (defthm c1
           (implies (true-listp x)
                    (not (nthcdr (len x) x)))))

  (defthm strsuffixp-of-empty
    (strsuffixp "" y))

  (local
   (progn
     (assert! (strsuffixp "" ""))
     (assert! (strsuffixp "" "foo"))
     (assert! (strsuffixp "o" "foo"))
     (assert! (strsuffixp "oo" "foo"))
     (assert! (not (strsuffixp "ooo" "foo")))
     (assert! (not (strsuffixp "fo" "foo")))
     (assert! (strsuffixp "foo" "foo")))))
