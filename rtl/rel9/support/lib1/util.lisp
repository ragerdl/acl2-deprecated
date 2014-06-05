; RTL - A Formal Theory of Register-Transfer Logic and Computer Arithmetic 
; Copyright (C) 1995-2013 Advanced Mirco Devices, Inc. 
;
; Contact:
;   David Russinoff
;   1106 W 9th St., Austin, TX 78703
;   http://www.russsinoff.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
; PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with
; this program; see the file "gpl.txt" in this directory.  If not, write to the
; Free Software Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA
; 02110-1335, USA.
;
; Author: David M. Russinoff (david@russinoff.com)

(in-package "ACL2")

(set-enforce-redundancy t)

(local (include-book "../support/util"))

;;These macros facilitate localization of events:

(defmacro local-defun (&rest body)
  (list 'local (cons 'defun body)))

(defmacro local-defund (&rest body)
  (list 'local (cons 'defund body)))

(defmacro local-defthm (&rest body)
  (list 'local (cons 'defthm body)))

(defmacro local-defthmd (&rest body)
  (list 'local (cons 'defthmd body)))

(defmacro local-in-theory (&rest body)
  (cons 'local
	(cons (cons 'in-theory (append body 'nil))
	      'nil)))

(defmacro defbvecp (name formals width &key thm-name hyp hints)
  (let* ((thm-name
          (or thm-name
              (intern-in-package-of-symbol
               (concatenate 'string
                            (if (consp width)
                                "BV-ARRP$"
                              "BVECP$")
                            (symbol-name name))
               name)))
         (x (cons name formals))
         (typed-term (if (consp width)
                         (list 'ag 'index x)
                       x))
         (bvecp-concl (if (consp width)
                          (list 'bv-arrp x (car (last width)))
                        (list 'bvecp x width)))
         (concl (list 'and
                      (list 'integerp typed-term)
                      (list '<= 0 typed-term))))
    (list* 'defthm thm-name
           (if hyp
               (list 'implies hyp bvecp-concl)
             bvecp-concl)
           :rule-classes
           (list
            :rewrite
            (list :forward-chaining :trigger-terms (list x))
            (list :type-prescription
                  :corollary
                  (if hyp
                      (list 'implies hyp concl)
                    concl)
                  :typed-term typed-term
                  ;; hints for the corollary 
                  :hints
                  (if (consp width)
                      '(("Goal"
                         :in-theory
                         '(implies bvecp
                                   bv-arrp-implies-nonnegative-integerp)))
                    '(("Goal"
                       :in-theory
                       '(implies bvecp))))))
           (if hints (list :hints hints) nil))))

(defun sub1-induction (n)
      (if (zp n)
          n
        (sub1-induction (1- n))))

; These will be the functions to disable in acl2 proofs about signal bodies.
; We use this in the compiler.
;BOZO This doesn't include cons, which can now appear in signals defs.  I think that's okay, right?  think
;about this and remove the BOZO
(defconst *rtl-operators-after-macro-expansion*
  '(log= log<> 
    log< log<= log> log>= 
    comp2< comp2<= comp2> comp2>=
    land lior lxor lnot
    logand1 logior1 logxor1
    shft
    cat mulcat
    bits bitn setbits setbitn 
    ag as
    * + ; from macroexpansion of mod* or mod+
    ;mod- ;now a macro!
    floor rem decode encode
    ;; bind ; handled specially in fixup-term
    ;; if1 ;  a macro, so we don't disable it
    ;; quote, n!, arr0 ; handled specially in fixup-term
    natp1 ; doesn't matter, only occurs in for-loop defuns (must be enabled in those proofs anyway)
    mk-bvarr mk-bvec
    ))

; Macro fast-and puts conjunctions in a tree form, which can avoid stack
; overflows by ACL2's translate functions.

(defun split-list (lst lo hi)
  (cond ((endp lst) 
         (mv lo hi))
        ((endp (cdr lst)) 
         (mv (cons (car lst) lo) hi))
        (t
         (split-list (cddr lst)
                     (cons (car lst) lo)
                     (cons (cadr lst) hi)))))

(defun fast-and-fn (conjuncts)
  (declare (xargs :mode :program))
  (cond ((endp conjuncts) ''t)
        ((endp (cdr conjuncts)) (car conjuncts))
        (t
         (mv-let (hi lo)
             (split-list conjuncts () ())
           (list 'if
                 (fast-and-fn hi)
                 (fast-and-fn lo)
                 'nil)))))

(defmacro fast-and (&rest conjuncts)
  (fast-and-fn conjuncts))
