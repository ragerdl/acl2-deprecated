; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
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
(include-book "defs")
(local (include-book "arithmetic"))
(local (include-book "osets"))

(defsection vl-string-keys-p
  :parents (utilities)
  :short "Recognizer for alists whose keys are strings."

;; BOZO eliminate, use defalist?

  (defund vl-string-keys-p (x)
    (declare (xargs :guard t))
    (if (consp x)
        (and (consp (car x))
             (stringp (caar x))
             (vl-string-keys-p (cdr x)))
      (not x)))

  (local (in-theory (enable vl-string-keys-p)))

  (defthm vl-string-keys-p-when-not-consp
    (implies (not (consp x))
             (equal (vl-string-keys-p x)
                    (not x))))

  (defthm vl-string-keys-p-of-cons
    (equal (vl-string-keys-p (cons a x))
           (and (consp a)
                (stringp (car a))
                (vl-string-keys-p x))))

  (defthm vl-string-keys-p-of-hons-shrink-alist
    (implies (and (vl-string-keys-p x)
                  (vl-string-keys-p ans))
             (vl-string-keys-p (hons-shrink-alist x ans)))
    :hints(("Goal" :in-theory (e/d (hons-shrink-alist)
                                   ((force))))))

  (defthm string-listp-of-strip-cars-when-vl-string-keys-p
    (implies (vl-string-keys-p x)
             (string-listp (strip-cars x))))

  (defthm vl-string-keys-p-of-make-lookup-alist
    (equal (vl-string-keys-p (make-lookup-alist x))
           (string-listp (list-fix x)))
    :hints(("Goal" :in-theory (enable make-lookup-alist)))))



(defsection vl-string-values-p
  :parents (utilities)
  :short "Recognizer for alists whose values are strings."

;; BOZO eliminate, use defalist?

  (defund vl-string-values-p (x)
    (declare (xargs :guard t))
    (if (consp x)
        (and (consp (car x))
             (stringp (cdar x))
             (vl-string-values-p (cdr x)))
      (not x)))

  (local (in-theory (enable vl-string-values-p)))

  (defthm vl-string-values-p-when-not-consp
    (implies (not (consp x))
             (equal (vl-string-values-p x)
                    (not x))))

  (defthm vl-string-values-p-of-cons
    (equal (vl-string-values-p (cons a x))
           (and (consp a)
                (stringp (cdr a))
                (vl-string-values-p x))))

  (defthm vl-string-values-p-of-hons-shrink-alist
    (implies (and (vl-string-values-p x)
                  (vl-string-values-p ans))
             (vl-string-values-p (hons-shrink-alist x ans)))
    :hints(("Goal" :in-theory (e/d (hons-shrink-alist)
                                   ((force))))))

  (defthm stringp-of-cdr-of-hons-assoc-equal-when-vl-string-values-p
    (implies (vl-string-values-p x)
             (equal (stringp (cdr (hons-assoc-equal a x)))
                    (if (hons-assoc-equal a x)
                        t
                      nil)))
    :hints(("Goal" :induct (len x)))))



(defsection vl-string-list-values-p
  :parents (utilities)
  :short "Recognizer for alists whose values are string lists."

;; BOZO eliminate, use defalist?

  (defund vl-string-list-values-p (x)
    (declare (xargs :guard t))
    (if (consp x)
        (and (consp (car x))
             (string-listp (cdar x))
             (vl-string-list-values-p (cdr x)))
      (not x)))

  (local (in-theory (enable vl-string-list-values-p)))

  (defthm vl-string-list-values-p-when-not-consp
    (implies (not (consp x))
             (equal (vl-string-list-values-p x)
                    (not x))))

  (defthm vl-string-list-values-p-of-cons
    (equal (vl-string-list-values-p (cons a x))
           (and (consp a)
                (string-listp (cdr a))
                (vl-string-list-values-p x))))

  (defthm vl-string-list-values-p-of-hons-shrink-alist
    (implies (and (vl-string-list-values-p x)
                  (vl-string-list-values-p ans))
             (vl-string-list-values-p (hons-shrink-alist x ans)))
    :hints(("Goal" :in-theory (e/d (hons-shrink-alist)
                                   ((force))))))

  (defthm string-listp-of-cdr-of-hons-assoc-equal-when-vl-string-list-values-p
    (implies (vl-string-list-values-p x)
             (string-listp (cdr (hons-assoc-equal a x))))))



(defsection vl-set-values-p
  :parents (utilities)
  :short "Recognizer for alists whose every value is an ordered set."

;; BOZO eliminate, use defalist?

  (defund vl-set-values-p (x)
    (declare (xargs :guard (alistp x)))
    (if (consp x)
        (and (setp (cdar x))
             (vl-set-values-p (cdr x)))
      t))

  (local (in-theory (enable vl-set-values-p)))

  (defthm vl-set-values-p-when-not-consp
    (implies (not (consp x))
             (equal (vl-set-values-p x)
                    t)))

  (defthm vl-set-values-p-of-cons
    (equal (vl-set-values-p (cons a x))
           (and (setp (cdr a))
                (vl-set-values-p x))))

  (defthm vl-set-values-p-of-hons-shrink-alist
    (implies (and (vl-set-values-p x)
                  (vl-set-values-p ans))
             (vl-set-values-p (hons-shrink-alist x ans)))
    :hints(("Goal" :in-theory (e/d (hons-shrink-alist)
                                   ((force))))))

  (defthm setp-of-cdr-of-hons-assoc-equal-when-vl-set-values-p
    (implies (vl-set-values-p x)
             (setp (cdr (hons-assoc-equal a x))))
    :hints(("Goal" :in-theory (disable (force))))))



(defsection vl-mergesort-values
  :parents (utilities)
  :short "Given an alist, @(call vl-mergesort-values) produces a new, fast
alist by sorting each value."

  :long "<p>Since a fast alist is returned, make sure to free it once you
are done to avoid memory leaks.</p>"

  (defund vl-mergesort-values (x)
    (declare (xargs :guard (alistp x)))
    (if (consp x)
        (hons-acons (caar x)
                    (mergesort (cdar x))
                    (vl-mergesort-values (cdr x)))
      nil))

  (local (in-theory (enable vl-mergesort-values)))

  (defthm vl-mergesort-values-when-not-consp
    (implies (not (consp x))
             (equal (vl-mergesort-values x)
                    nil)))

  (defthm vl-mergesort-values-of-cons
    (equal (vl-mergesort-values (cons a x))
           (cons (cons (car a) (mergesort (cdr a)))
                 (vl-mergesort-values x))))

  (defthm vl-set-values-p-of-vl-mergesort-values
    (vl-set-values-p (vl-mergesort-values x)))

  (defthm alistp-of-vl-mergesort-values
    (alistp (vl-mergesort-values x)))

  (defthm hons-assoc-equal-of-vl-mergesort-values
    (implies (force (alistp x))
             (equal (cdr (hons-assoc-equal key (vl-mergesort-values x)))
                    (mergesort (cdr (hons-assoc-equal key x))))))

  (defthm vl-string-keys-p-of-vl-mergesort-values
    (implies (vl-string-keys-p x)
             (vl-string-keys-p (vl-mergesort-values x))))

  (defthm vl-string-list-values-p-of-vl-mergesort-values
    (implies (vl-string-list-values-p x)
             (vl-string-list-values-p (vl-mergesort-values x))))

  (defthm in-of-hons-assoc-equal-of-vl-mergesort-values
    (implies (force (alistp x))
             (equal (in a (cdr (hons-assoc-equal b (vl-mergesort-values x))))
                    (if (member-equal a (cdr (hons-assoc-equal b x)))
                        t
                      nil)))))
