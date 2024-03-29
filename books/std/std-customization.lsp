; ACL2 Customization File for The Standard Approach to Using ACL2
; Copyright (C) 2009-2013 Centaur Technology
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
; Contributing author: David Rager <ragerdl@deftm.com>



; The easiest way to use this file is to just add an acl2-customization.lsp
; file to your home directory that says:
;
;   (ld "std/std-customization.lsp" :dir :system)
;
; You can, of course, put whatever additional customization you want in your
; own customization file, then.


; There's no in-package here, because it could screw up packages loaded by
; custom acl2-customization.lsp files.  Instead we use the #!ACL2 syntax to try
; to make sure this file can be read from any package.

#!ACL2
(set-deferred-ttag-notes t state)

#!ACL2
(set-inhibit-output-lst '(proof-tree))


#!ACL2
(with-output
  :off (summary event)
  (progn
    (defmacro d (name)
      ;; A handy macro that lets you write :d fn to disassemble a function.  I
      ;; mostly have this because my fingers always type ":diassemble$" instead of
      ;; ":disassemble$"
      (cond ((symbolp name)
             `(disassemble$ ',name :recompile nil))
            ((and (quotep name)
                  (symbolp (unquote name)))
             `(disassemble$ ',(unquote name) :recompile nil))
            ((and (quotep name)
                  (quotep (unquote name))
                  (symbolp (unquote (unquote name))))
             `(disassemble$ ',(unquote (unquote name)) :recompile nil))
            (t
             (er hard? 'd "Not a symbol or quoted symbol: ~x0~%" name))))

    (defmacro why (rule)
      ;; A handy macro that lets you figure out why a rule isn't firing.
      ;; This is useful to me because I can never remember the :monitor
      ;; syntax.
      `(er-progn
        (brr t)
        (monitor '(:rewrite ,rule) ''(:eval :go t))))

    (defun explain-fn (state)
      (declare (xargs :stobjs (state)
                      :mode :program))
      (mv-let (clause ttree)
        (clausify-type-alist (get-brr-local 'type-alist state)
                             (list (cddr (get-brr-local 'failure-reason state)))
                             (ens state) (w state) nil nil)
        (declare (ignore ttree))
        (prettyify-clause clause
                          nil
                          (w state))))

    (defmacro explain ()
      `(prog2$ (cw "Printing target with hyps derived from type-alist~%")
               (explain-fn state)))

    (defmacro why-explain (rule)
      `(er-progn
        (brr t)
        (monitor '(:rewrite ,rule) ''(:eval
                                      :ok-if (brr@ :wonp)
                                      (explain)))))

    (defmacro with-redef (&rest forms)
      ;; A handy macro you can use to temporarily enable redefinition, but then
      ;; keep it disabled for the rest of the session
      `(progn
         (defttag with-redef)
         (progn!
          (set-ld-redefinition-action '(:doit . :overwrite) state)
          (progn . ,forms)
          (set-ld-redefinition-action nil state))))))



; XDOC SUPPORT
;
;   - Always load the xdoc package, which is pretty fast.
;
;   - Unless :SUPPRESS-PRELOAD-XDOC has been assigned, also get the xdoc
;     database preloaded so that :XDOC commands are very fast and never
;     leave any nonsense in your history.
;
; The second part is somewhat slow and makes ACL2 take noticeably longer to
; boot up.  However, for me, on the par, it seems worth it to make :xdoc much
; more useful.
;
; The suppress-preload-xdoc mechanism can be used to make sure that xdoc does
; NOT get preloaded.  Why would you want to do this?
;
; Well, a few libraries (e.g., str) have some files (package definitions,
; str::cat, etc.) that are included in the xdoc implementation code that gets
; loaded by (xdoc::colon-xdoc-init).  When you're hacking on these libraries,
; it's very easy to, e.g., change something that causes xdoc to be completely
; unloadable until you recertify everything.
;
; At any rate, if for this (or some other reason) you don't want to
; automatically do this xdoc initialization, you can just add:
;
;   (assign :suppress-preload-xdoc t)
;
; Before loading std-customization.lsp.

#!ACL2
(with-output
  :off (summary event)
  (ld "std/package.lsp" :dir :system))

#!ACL2
(make-event
 (if (not (boundp-global :suppress-preload-xdoc state))
     `(progn
        (include-book "xdoc/top" :dir :system)
        (include-book "xdoc/debug" :dir :system)
        (xdoc::colon-xdoc-init))
   `(value-triple nil)))


; maybe actually report correct times
(assign get-internal-time-as-realtime t)
