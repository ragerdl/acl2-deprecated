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
(include-book "../mlib/writer")
(include-book "../mlib/strip")
(include-book "../mlib/expr-tools")
(local (include-book "../util/arithmetic"))

(deflist vl-locationlist-p (x)
  ;; BOZO find me a home
  (vl-location-p x)
  :guard t
  :elementp-of-nil nil)


(defsection duplicate-detect
  :parents (checkers)
  :short "Check for instances and assignments that are literally identical."

  :long "<p>This is a heuristic for generating warnings.  We look for
assignments, module instances, and gate instances that are identical <see
topic='@(url fixing-functions)'>up to fixing</see>.  These sorts of things
might well be copy/paste errors.</p>")

(local (xdoc::set-default-parents duplicate-detect))

(define vl-locationlist-string ((n natp))
  :guard (<= n 9)
  :parents (vl-make-duplicate-warning)
  :returns (str stringp :rule-classes :type-prescription)
  (cond ((zp n)
         "")
        ((= n 1)
         (cat "~l1"))
        ((= n 2)
         (cat "~l2 and ~l1"))
        (t
         (cat "~l" (natstr n) ", " (vl-locationlist-string (- n 1)))))
  ///
  (defthm stringp-of-vl-locationlist-string
    (stringp (vl-locationlist-string n))
    :rule-classes :type-prescription))

(define vl-make-duplicate-warning ((type stringp)
                                   (locs vl-locationlist-p)
                                   (modname stringp))
  :returns (warning vl-warning-p)
  (b* ((locs        (redundant-list-fix locs))
       (elide-p     (> (len locs) 9))
       (elided-locs (if elide-p (take 9 locs) locs)))
    (make-vl-warning
     :type :vl-warn-duplicates
     :msg  (cat "In module ~m0, found duplicated " type " at "
                (vl-locationlist-string (len elided-locs))
                (if elide-p
                    " (and other locations)."
                  "."))
     :args (cons modname elided-locs)
     :fatalp nil
     :fn 'vl-make-duplicate-warning)))

(define vl-duplicate-gateinst-locations
  ((dupe vl-gateinst-p      "Some gateinst that was duplicated (fixed).")
   (fixed vl-gateinstlist-p "Fixed versions of @('orig')")
   (orig  vl-gateinstlist-p "Original gate instances, i.e., before fixing."))
  :guard (same-lengthp fixed orig)
  :returns (matches vl-locationlist-p "Locations of gates matching @('dupe')."
                    :hyp :fguard)
  (b* (((when (atom fixed))
        nil)
       (rest (vl-duplicate-gateinst-locations dupe (cdr fixed) (cdr orig)))
       ((when (equal dupe (car fixed)))
        (cons (vl-gateinst->loc (car orig)) rest)))
    rest))

(define vl-duplicate-gateinst-warnings
  ((dupes vl-gateinstlist-p "The gateinsts that were duplicated.  (fixed).")
   (fixed vl-gateinstlist-p "Fixed versions of @('orig').")
   (orig  vl-gateinstlist-p "Original gate instances, i.e., before fixing.")
   (modname stringp))
  :guard (same-lengthp fixed orig)
  :returns (warnings vl-warninglist-p "Warnings for each duplicate gateinst.")
  (b* (((when (atom dupes))
        nil)
       (locs    (vl-duplicate-gateinst-locations (car dupes) fixed orig))
       (warning (vl-make-duplicate-warning "gate instances" locs modname))
       (rest    (vl-duplicate-gateinst-warnings (cdr dupes) fixed orig modname)))
    (cons warning rest)))

(define vl-duplicate-modinst-locations
  ((dupe  vl-modinst-p "Some modinst that was duplicated (fixed).")
   (fixed vl-modinstlist-p "Fixed versions of @('orig').")
   (orig  vl-modinstlist-p "Original module instances, i.e., before fixing."))
  :guard (same-lengthp fixed orig)
  :returns (matches vl-locationlist-p "Locations of instances matching @('dupe')."
                    :hyp :fguard)
  (b* (((when (atom fixed))
        nil)
       (rest (vl-duplicate-modinst-locations dupe (cdr fixed) (cdr orig)))
       ((when (equal dupe (car fixed)))
        (cons (vl-modinst->loc (car orig)) rest)))
    rest))

(define vl-duplicate-modinst-warnings
  ((dupes vl-modinstlist-p "The modinsts that were duplicated.  (fixed).")
   (fixed vl-modinstlist-p "Fixed versions of @('orig').")
   (orig  vl-modinstlist-p "Original mod instances, i.e., before fixing.")
   (modname stringp))
  :guard (same-lengthp fixed orig)
  :returns (warnings vl-warninglist-p "Warnings for each duplicate modinst.")
  (b* (((when (atom dupes))
        nil)
       (locs    (vl-duplicate-modinst-locations (car dupes) fixed orig))
       (warning (vl-make-duplicate-warning "module instances" locs modname))
       (rest    (vl-duplicate-modinst-warnings (cdr dupes) fixed orig modname)))
    (cons warning rest)))

(define vl-duplicate-assign-locations
  ((dupe  vl-assign-p     "Some assign that was duplicated (fixed).")
   (fixed vl-assignlist-p "Fixed versions of @('orig').")
   (orig  vl-assignlist-p "Original module instances, i.e., before fixing."))
  :guard (same-lengthp fixed orig)
  :returns (matches vl-locationlist-p "Locations of instances matching @('dupe')."
                    :hyp :fguard)
  (b* (((when (atom fixed))
        nil)
       (rest (vl-duplicate-assign-locations dupe (cdr fixed) (cdr orig)))
       ((when (equal dupe (car fixed)))
        (cons (vl-assign->loc (car orig)) rest)))
    rest))

(define vl-duplicate-assign-warnings
  ((dupes vl-assignlist-p "The assigns that were duplicated.  (fixed).")
   (fixed vl-assignlist-p "Fixed versions of @('orig').")
   (orig  vl-assignlist-p "Original mod instances, i.e., before fixing.")
   (modname stringp))
  :guard (same-lengthp fixed orig)
  :returns (warnings vl-warninglist-p "Warnings for each duplicate assign.")
  :guard-debug t
  (b* (((when (atom dupes))
        nil)
       (locs    (vl-duplicate-assign-locations (car dupes) fixed orig))
       (lvalue  (vl-assign->lvalue (car dupes)))
       (type    (if (vl-idexpr-p lvalue)
                    (cat "assignments to " (vl-idexpr->name lvalue))
                  (let ((lvalue-str (vl-pps-origexpr lvalue)))
                    (if (< (length lvalue-str) 40)
                        (cat "assignments to " lvalue-str)
                      (cat "assignments to \""
                           (subseq lvalue-str 0 40)
                           "...\"")))))
       (warning (vl-make-duplicate-warning type locs modname))
       (rest    (vl-duplicate-assign-warnings (cdr dupes) fixed orig modname)))
    (cons warning rest)))

(define vl-module-duplicate-detect ((x vl-module-p))
  :short "Detect duplicate assignments and instances throughout a module."
  :returns (new-x vl-module-p :hyp :fguard
                  "Same as @('x'), but perhaps with more warnings.")
  (b* (((vl-module x) x)

       (gateinsts-fix (vl-gateinstlist-strip x.gateinsts))
       (modinsts-fix  (vl-modinstlist-strip x.modinsts))
       (assigns-fix   (vl-assignlist-strip x.assigns))

       (gateinst-dupes (duplicated-members gateinsts-fix))
       (modinst-dupes  (duplicated-members modinsts-fix))
       (assign-dupes   (duplicated-members assigns-fix))

       ((unless (or gateinst-dupes modinst-dupes assign-dupes))
        x)

       (gate-warnings
        (and gateinst-dupes
             (vl-duplicate-gateinst-warnings gateinst-dupes gateinsts-fix
                                             x.gateinsts x.name)))

       (mod-warnings
        (and modinst-dupes
             (vl-duplicate-modinst-warnings modinst-dupes modinsts-fix
                                            x.modinsts x.name)))

       (ass-warnings
        (and assign-dupes
             (vl-duplicate-assign-warnings assign-dupes assigns-fix
                                           x.assigns x.name)))

       (warnings (append gate-warnings
                         mod-warnings
                         ass-warnings
                         x.warnings)))

    (change-vl-module x :warnings warnings)))

(defprojection vl-modulelist-duplicate-detect (x)
  (vl-module-duplicate-detect x)
  :guard (vl-modulelist-p x)
  :result-type vl-modulelist-p)

(define vl-design-duplicate-detect
  :short "Top-level @(see duplicate-detect) check."
  ((x vl-design-p))
  :returns (new-x vl-design-p)
  (b* ((x (vl-design-fix x))
       ((vl-design x) x))
    (change-vl-design x :mods (vl-modulelist-duplicate-detect x.mods))))


