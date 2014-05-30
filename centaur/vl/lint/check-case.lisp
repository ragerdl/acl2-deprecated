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
(include-book "../mlib/modnamespace")
(include-book "../mlib/writer")
(include-book "../util/cwtime")
(local (include-book "../util/arithmetic"))
(local (include-book "../util/osets"))

(defsection check-case
  :parents (lint)
  :short "Basic checker to ensure that wire names don't differ only by case."

  :long "<p>Stylistically, we don't think wire names ought to differ only by
case.  Such names might indicate a typo.  They could also cause problems for
any Verilog tools that standardize all wire names to lowercase, etc.</p>")

(local (xdoc::set-default-parents check-case))

(define vl-collect-ieqv-strings-aux
  :parents (vl-collect-ieqv-strings)
  ((a stringp      "Already lowercased.")
   (x string-listp "Not already lowercased."))
  :returns (equiv-strs string-listp :hyp (string-listp x))
  :long "<p>Linear in the length of @('x').</p>"
  (cond ((atom x)
         nil)
        ((equal a (str::downcase-string (car x)))
         (cons (car x) (vl-collect-ieqv-strings-aux a (cdr x))))
        (t
         (vl-collect-ieqv-strings-aux a (cdr x)))))

(define vl-collect-ieqv-strings ((a stringp)
                                 (x string-listp))
  :short "@(call vl-collect-ieqv-strings) returns all strings in the list
@('x') that are case-equivalent to the string @('a')."
  :long "<p>This is pretty dumb, but we at least avoid downcasing @('a')
repeatedly.  Linear in the length of @('x').</p>"
  :returns (equiv-strs string-listp :hyp (string-listp x))
  (vl-collect-ieqv-strings-aux (str::downcase-string a) x))

(define vl-find-case-equivalent-strings-aux
  :parents (vl-find-case-equivalent-strings)
  ((x string-listp  "Some subset of all the strings we're considering.")
   (y string-listp  "The full list of all the strings, fixed."))
  :returns (equiv-sets string-list-listp :hyp (string-listp y))
  :long "<p>O(n^2) in the length of X, but X should be the list of duplicated
  strings, so there shouldn't be many.</p>"
  (if (atom x)
      nil
    (cons (vl-collect-ieqv-strings (car x) y)
          (vl-find-case-equivalent-strings-aux (cdr x) y))))

(define vl-find-case-equivalent-strings
  :short "Find all case-equivalent strings in a string-list."
  ((x string-listp))
  :returns (equiv-sets string-list-listp :hyp :fguard
                       "Each sub-list is a set of case-equivalent strings
                        that occur within @('x').")
  (b* ((xl    (str::downcase-string-list x)) ;; O(n) in |X|
       (dupes (duplicated-members xl))       ;; O(n log n) in |X|
       (sets  (vl-find-case-equivalent-strings-aux dupes x))) ;; O(n^2) in |dupes|
    sets)
  ///
  (local (assert! (equal (vl-find-case-equivalent-strings
                          (list "foo" "BAR" "baz" "Foo" "Bar"))
                         '(("BAR" "Bar")
                           ("foo" "Foo"))))))


(define vl-equiv-strings-to-lines ((x string-list-listp) &key (ps 'ps))
  (if (atom x)
      ps
    (vl-ps-seq
     (vl-basic-cw "      - ~&0~%" (car x))
     (vl-equiv-strings-to-lines (cdr x)))))

(define vl-module-check-case ((x vl-module-p))
  :returns (new-x vl-module-p :hyp :fguard "Maybe with new warnings.")
  (b* (((vl-module x) x)
       (names (append (vl-portdecllist->names x.portdecls)
                      (vl-module->modnamespace x)))
       ;; Sort them to eliminate any repetitions of the same name.
       (names       (cwtime (mergesort names)
                            :name check-case-gather-names
                            :mintime 1/2))
       (equiv-names (cwtime (vl-find-case-equivalent-strings names)
                            :name check-case-find-equiv-strs
                            :mintime 1/2))
       ((unless equiv-names)
        x)
       (w (make-vl-warning
           :type :vl-warn-case-sensitive-names
           :msg "In ~a0, found names that differ only by case.  This might ~
                 indicate a typo, and otherwise it might cause problems for ~
                 some Verilog tools.  Details: ~%~s1"
           :args (list x.name (with-local-ps (vl-equiv-strings-to-lines equiv-names)))
           :fatalp nil
           :fn __function__)))
    (change-vl-module x :warnings (cons w x.warnings))))

(defprojection vl-modulelist-check-case (x)
  (vl-module-check-case x)
  :guard (vl-modulelist-p x)
  :result-type vl-modulelist-p)

(define vl-design-check-case ((x vl-design-p))
  :returns (new-x vl-design-p)
  (b* ((x (vl-design-fix x))
       ((vl-design x) x))
    (change-vl-design x :mods (vl-modulelist-check-case x.mods))))
