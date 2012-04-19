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
(include-book "parsetree")
(include-book "mlib/expr-tools")
(include-book "wf-reasonable-p")
(local (include-book "util/arithmetic"))


(defwellformed vl-assign-widthsfixed-p (x)
  :guard (vl-assign-p x)
  :body (let ((lvalue (vl-assign->lvalue x))
              (expr   (vl-assign->expr x)))
          (@wf-progn
           (@wf-assert (vl-expr-widthsfixed-p lvalue)
                       :vl-warn-nowidth
                       "~l0: failed to compute width of assignment lvalue.  lvalue = ~x1."
                       (list (vl-assign->loc x) lvalue))
           (@wf-assert (vl-expr-widthsfixed-p expr)
                       :vl-warn-nowidth
                       "~l0: failed to compute width of assignment rhs.  rhs = ~x1."
                       (list (vl-assign->loc x) expr)))))

(defwellformed-list vl-assignlist-widthsfixed-p (x)
  :element vl-assign-widthsfixed-p
  :guard (vl-assignlist-p x))





(defwellformed vl-plainarg-widthsfixed-p (x)

; When I first added support for blanks, I thought that maybe we should regard
; blank arguments as not having fixed widths.  Now I have changed my mind, and
; I do not cause any warnings here for blanks.  My basic argument is: if the
; port is blank, then its width is just going to be the width of whatever we're
; hooking it up to.  It's not like we've failed to infer its width, which is
; really what this check is designed to detect.

  :guard (vl-plainarg-p x)
  :body (let ((expr (vl-plainarg->expr x)))
          (@wf-assert (or (not expr)
                          (vl-expr-widthsfixed-p expr))
                      :vl-warn-nowidth
                      "Failed to compute width of argument ~x0."
                      (list expr))))

(defwellformed-list vl-plainarglist-widthsfixed-p (x)
  :element vl-plainarg-widthsfixed-p
  :guard (vl-plainarglist-p x))



(defwellformed vl-namedarg-widthsfixed-p (x)
  :guard (vl-namedarg-p x)
  :body (let ((expr (vl-namedarg->expr x)))
          (@wf-assert (or (not expr)
                          (vl-expr-widthsfixed-p expr))
                      :vl-warn-nowidth
                      "Failed to compute width of argument ~s0.  Expression: ~x1."
                      (list (vl-namedarg->name x)
                            expr))))

(defwellformed-list vl-namedarglist-widthsfixed-p (x)
  :element vl-namedarg-widthsfixed-p
  :guard (vl-namedarglist-p x))

(defwellformed vl-arguments-widthsfixed-p (x)
  :guard (vl-arguments-p x)
  :body  (if (vl-arguments->namedp x)
             (@wf-call vl-namedarglist-widthsfixed-p (vl-arguments->args x))
           (@wf-call vl-plainarglist-widthsfixed-p (vl-arguments->args x))))

(defwellformed vl-modinst-widthsfixed-p (x)

; BOZO we could really improve this warning a lot by associating it with the
; particular arguments that cause problems, instead of issuing separate
; warnings for all of the arguments first.

  :guard (vl-modinst-p x)
  :body (@wf-assert (vl-arguments-widthsfixed-p (vl-modinst->portargs x))
                    :vl-warn-nowidth
                    "~s0: failed to compute widths of arguments to ~s1."
                    (list (vl-modinst->loc x)
                          (or (vl-modinst->instname x)
                              (cat "<unnamed instance of " (vl-modinst->modname x) ">")))))

(defwellformed-list vl-modinstlist-widthsfixed-p (x)
  :element vl-modinst-widthsfixed-p
  :guard (vl-modinstlist-p x))



(defwellformed vl-gateinst-widthsfixed-p (x)
  :guard (vl-gateinst-p x)
  :body (@wf-assert (vl-plainarglist-widthsfixed-p (vl-gateinst->args x))
                    :vl-warn-nowidth
                    "~s0: failed to compute widths of arguments to ~s1."
                    (list (vl-gateinst->loc x)
                          (or (vl-gateinst->name x)
                              (cat "<unnamed " (symbol-name (vl-gateinst->type x)) " gate>")))))

(defwellformed-list vl-gateinstlist-widthsfixed-p (x)
  :element vl-gateinst-widthsfixed-p
  :guard (vl-gateinstlist-p x))






;; (defwellformed vl-always-widthsfixed-p (x)
;;   :guard (vl-always-p x)

;; ; BOZO this function is basically just not correct.  Need to implement
;; ; proper support for always blocks and statements all the way through.

;;   :body (let ((stmt (vl-always->stmt x)))
;;           (@wf-progn
;;            (@wf-assert (vl-ptctrlstmt-p stmt)
;;                        :vl-always-badctrl
;;                        "~s0: not a good event-control, i.e., \"@(...)\"."
;;                        (list (vl-location-string (vl-always->loc x))))
;;            (@wf-assert (or (not (vl-ptctrlstmt-p stmt))
;;                            (vl-stmt-widthsfixed-p (vl-ptctrlstmt->stmt stmt)))
;;                        :vl-warn-nowidth
;;                        "~s0: failed to resolve widths in always block."
;;                        (list (vl-location-string (vl-always->loc x)))))))

;; (defwellformed-list vl-alwayslist-widthsfixed-p (x)
;;   :element vl-always-widthsfixed-p
;;   :guard (vl-alwayslist-p x))



(defwellformed vl-module-widthsfixed-p (x)
  :guard (vl-module-p x)

; BOZO add checks for initial and always statements.

  :body (@wf-progn
         (@wf-call vl-assignlist-widthsfixed-p (vl-module->assigns x))
         (@wf-call vl-modinstlist-widthsfixed-p (vl-module->modinsts x))
         (@wf-call vl-gateinstlist-widthsfixed-p (vl-module->gateinsts x))))


(defwellformed-list vl-modulelist-widthsfixed-p (x)
  :element vl-module-widthsfixed-p
  :guard (vl-modulelist-p x))



