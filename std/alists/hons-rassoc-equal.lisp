; Standard Association Lists Library
; Copyright (C) 2013 Centaur Technology
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
(include-book "../lists/list-defuns")
(include-book "alist-keys")
(include-book "alist-vals")
(local (include-book "../lists/list-fix"))

(defsection hons-rassoc-equal
  :parents (std/alists)
  :short "@(call hons-rassoc-equal) returns the first pair found in the alist
@('alist') whose value is @('val'), if one exists, or @('nil') otherwise."

  :long "<p>This is a \"modern\" equivalent of @(see rassoc), which properly
respects the non-alist convention; see @(see std/alists) for discussion of this
convention.</p>"

  (defund hons-rassoc-equal (val alist)
    (declare (xargs :guard t))
    (cond ((atom alist)
           nil)
          ((and (consp (car alist))
                (equal val (cdar alist)))
           (car alist))
          (t
           (hons-rassoc-equal val (cdr alist)))))

  (local (in-theory (enable hons-rassoc-equal)))

  (defthm hons-rassoc-equal-when-atom
    (implies (atom alist)
             (equal (hons-rassoc-equal val alist)
                    nil)))

  (defthm hons-rassoc-equal-of-hons-acons
    (equal (hons-rassoc-equal a (cons (cons key b) alist))
           (if (equal a b)
               (cons key b)
             (hons-rassoc-equal a alist))))

  (defthm hons-rassoc-equal-type
    (or (not (hons-rassoc-equal val alist))
        (consp (hons-rassoc-equal val alist)))
    :rule-classes :type-prescription)

  (encapsulate
    ()
    (local (defthmd l0
             (equal (hons-rassoc-equal key (list-fix alist))
                    (hons-rassoc-equal key alist))))

    (defcong list-equiv equal (hons-rassoc-equal key alist) 2
      :hints(("Goal"
              :in-theory (enable list-equiv)
              :use ((:instance l0 (alist alist))
                    (:instance l0 (alist alist-equiv)))))))

  (defthm consp-of-hons-rassoc-equal
    (equal (consp (hons-rassoc-equal val alist))
           (if (hons-rassoc-equal val alist)
               t
             nil)))

  (defthm cdr-of-hons-rassoc-equal
    (equal (cdr (hons-rassoc-equal val alist))
           (if (hons-rassoc-equal val alist)
               val
             nil)))

  (defthm member-equal-of-alist-vals-under-iff
    (iff (member-equal val (alist-vals alist))
         (hons-rassoc-equal val alist))
    :hints(("Goal" :in-theory (enable hons-rassoc-equal
                                      alist-vals))))

  (defthm hons-assoc-equal-of-car-when-hons-rassoc-equal
    (implies (hons-rassoc-equal val alist)
             (hons-assoc-equal (car (hons-rassoc-equal val alist)) alist))
    :hints(("Goal" :in-theory (enable hons-assoc-equal
                                      hons-rassoc-equal))))

  (defthm hons-assoc-equal-of-car-when-hons-rassoc-equal-and-no-duplicates
    (implies (and (no-duplicatesp-equal (alist-keys alist))
                  (hons-rassoc-equal val alist))
             (equal (hons-assoc-equal (car (hons-rassoc-equal val alist)) alist)
                    (hons-rassoc-equal val alist)))
    :hints(("Goal" :in-theory (enable hons-assoc-equal
                                      hons-rassoc-equal))))

  (defthm member-equal-of-car-when-hons-rassoc-equal
    (implies (hons-rassoc-equal val alist)
             (member-equal (car (hons-rassoc-equal val alist))
                           (alist-keys alist))))

  (defthm hons-rassoc-equal-of-cdr-when-hons-assoc-equal
    (implies (hons-assoc-equal key alist)
             (hons-rassoc-equal (cdr (hons-assoc-equal key alist)) alist))
    :hints(("Goal" :in-theory (enable hons-assoc-equal
                                      hons-rassoc-equal))))

  (defthm hons-rassoc-equal-of-cdr-when-hons-assoc-equal-and-no-duplicates
    (implies (and (no-duplicatesp-equal (alist-vals alist))
                  (hons-assoc-equal key alist))
             (equal (hons-rassoc-equal (cdr (hons-assoc-equal key alist)) alist)
                    (hons-assoc-equal key alist)))
    :hints(("Goal" :in-theory (enable hons-assoc-equal
                                      hons-rassoc-equal)))))


