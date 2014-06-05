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
(include-book "../parsetree")
(local (include-book "../util/arithmetic"))
(local (std::add-default-post-define-hook :fix))

(defxdoc flat-warnings
  :parents (warnings mlib)
  :short "Extract flat lists of warnings from various design elements."

  :long "<p>These functions append together the warnings from, e.g., all
modules in a module list, to create unified lists of warnings.</p>

<p><b>Note</b>: if you want to summarize or print warnings, a @(see
vl-reportcard-p) is typically more useful than a flat list of warnings.</p>

<p><b>Note</b>: these functions don't clean the warnings in any way, and so you
may end up with many redundant warnings.  Because of this, it is probably a
good idea to @(see clean-warnings) before flattening.</p>")

(local (xdoc::set-default-parents flat-warnings))

(defmacro def-vl-flat-warnings (list elem)
  (b* ((mksym-package-symbol (pkg-witness "VL"))
       (fn             (mksym 'vl- list '-flat-warnings))
       (list-p         (mksym 'vl- list '-p))
       (elem->warnings (mksym 'vl- elem '->warnings)))
    `(defmapappend ,fn (x)
       (,elem->warnings x)
       :guard (,list-p x)
       :transform-true-list-p nil
       :short ,(cat "Gather a flat list of all warnings from a @(see " (symbol-name list-p) ").")
       :rest
       ((defthm ,(mksym 'vl-warninglist-p-of- fn)
          (vl-warninglist-p (,fn x)))))))

(def-vl-flat-warnings modulelist module)
(def-vl-flat-warnings udplist udp)
(def-vl-flat-warnings programlist program)
(def-vl-flat-warnings interfacelist interface)
(def-vl-flat-warnings configlist config)
(def-vl-flat-warnings packagelist package)

(define vl-design-flat-warnings ((x vl-design-p))
  :short "Gather a flat list of warnings from a @(see vl-design-p)."
  :returns (warnings vl-warninglist-p)
  (mbe :logic
       (b* (((vl-design x) x))
         (append (vl-modulelist-flat-warnings x.mods)
                 (vl-udplist-flat-warnings x.udps)
                 (vl-interfacelist-flat-warnings x.interfaces)
                 (vl-programlist-flat-warnings x.programs)
                 (vl-packagelist-flat-warnings x.packages)
                 (vl-configlist-flat-warnings x.configs)))
       :exec
       ;; BOZO fix up defmapappend to use nrev and then rework this.
       (b* (((vl-design x) x)
            (acc nil)
            (acc (vl-modulelist-flat-warnings-exec x.mods acc))
            (acc (vl-udplist-flat-warnings-exec x.udps acc))
            (acc (vl-interfacelist-flat-warnings-exec x.interfaces acc))
            (acc (vl-programlist-flat-warnings-exec x.programs acc))
            (acc (vl-packagelist-flat-warnings-exec x.packages acc))
            (acc (vl-configlist-flat-warnings-exec x.configs acc)))
         (reverse acc))))


