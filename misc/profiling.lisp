; Copyright (C) 2013, Regents of the University of Texas
; Written by Matt Kaufmann, October, 2010
; License: A 3-clause BSD license.  See the LICENSE file distributed with ACL2.

; Interface to some Lisp profilers

; Note: See also oprof.lisp (contributed by Jared Davis).

; This book provides profiling support for certain host Lisps.  Currently it
; supports only CCL and SBCL.  As of this writing (October 2010) it appears
; that profiling an entire package is much more efficient in SBCL than it is in
; CCL.

; Example usage:

; Probably preferred, but SBCL only: statistical call-graph profiling
; (with-sprofiling (mini-proveall)) ; SBCL only
; The following SBCL documentation may be helpful:
;   http://www.sbcl.org/manual/Statistical-Profiler.html

; Also supported:
; (with-profiling "ACL2" (mini-proveall)) ; efficient in SBCL, slow in CCL
; (with-profiling '(rewrite assoc-equal) (mini-proveall))

; This file defines the forms (with-sprofiling form) and (with-profiling fns
; form), under the above restrictions.

; You might prefer with-sprofiling, which shows a call-graph.  If you know of
; ways to improve that display, please feel free to contribute an improvement!

; In the case of with-profiling, fns is evaluated, and the result should be
; either a function symbol, a list of function symbols, or a package name.  The
; indicated symbols are profiled, where a package name indicates all function
; symbols in that package (not including symbols imported from another
; package).

(in-package "ACL2")

(defttag :profiling)

(progn!
 (set-raw-mode t)

; In SBCL 1.1.11 and 1.1.14 installations at the Univ. of Texas, the value of
; sb-ext:*module-provider-functions* is (SB-IMPL::MODULE-PROVIDE-CONTRIB).  In
; 1.1.11, (SB-IMPL::MODULE-PROVIDE-CONTRIB :sb-sprof) evaluates to t, but in
; 1.1.14, it evaluates to nil, which explains why the form (require :sb-sprof)
; in profiling-raw.lsp causes an error in SBCL 1.1.14.  The following is an
; easy way to avoid an error, but it could certainly be made nicer, for example
; by checking if there really is an error.  Anyone in the acl2-books project is
; welcome to make such an improvement!

 (our-ignore-errors (load (concatenate 'string (cbd) "profiling-raw.lsp"))))

(defmacro-last with-profiling)

(defmacro-last with-sprofiling-internal)

(defmacro with-sprofiling (form &rest options)
  (let ((options (or options '(:report :graph :loop nil))))
    `(with-sprofiling-internal ',options ,form)))
