; Centaur AIG Library
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
; Original author: Sol Swords <sswords@centtech.com>

(in-package "ACL2")
(include-book "aig-base")

(define aig-print
  :parents (aig-other)
  :short "Convert an AIG into an ACL2-like S-expression."
  ((x "An AIG"))
  :returns (sexpr "A s-expression with AND and NOT calls.")
  :long "<p>We generally don't imagine using this for anything other than
one-off debugging.  Note that the S-expressions you generate this way can
easily be too large to print.</p>"
  :verify-guards nil
  (aig-cases
    x
    :true t
    :false nil
    :var x
    :inv `(not ,(aig-print (car x)))
    :and (let* ((a (aig-print (car x)))
                (d (aig-print (cdr x))))
           `(and ,@(if (and (consp a) (eq (car a) 'and))
                       (cdr a)
                     (list a))
                 ,@(if (and (consp d) (eq (car d) 'and))
                       (cdr d)
                     (list d)))))
  ///
  (local (defthm lemma
           (implies (and (consp (aig-print x))
                         (eq (car (aig-print x)) 'and))
                    (true-listp (cdr (aig-print x))))))
  (verify-guards aig-print)
  (memoize 'aig-print :condition '(consp x)))



(defsection expr-to-aig
  :parents (aig-other)
  :short "Convert an ACL2-like S-expression into an AIG."
  :long "<p>@(call expr-to-aig) accepts S-expressions @('expr') such as:</p>

@({
     a
     (not a)
     (and a b c)
})

<p>It currently accepts S-expressions composed of the following operators, all
of which are assumed to be Boolean-valued (i.e., there's nothing four-valued
going on here):</p>

<ul>
  <li>@('not') -- unary</li>
  <li>@('and'), @('or'), @('nand'), @('nor') -- variable arity</li>
  <li>@('iff'), @('xor'), @('implies') -- binary</li>
  <li>@('if') -- ternary</li>
</ul>

<p>It constructs an AIG from the S-expression using the ordinary @(see
aig-constructors).</p>

<p>This can be useful for one-off debugging.  We probably wouldn't recommend
using it for anything serious, or trying to prove anything about it.</p>"

  (mutual-recursion
   (defun expr-to-aig (expr)
     (declare (Xargs :guard t
                     :measure (+ 1 (* 2 (acl2-count expr)))))
     (if (atom expr)
         expr
       (let ((fn (car expr))
             (args (cdr expr)))
         (cond
          ((and (eq fn 'not) (= (len args) 1))
           (aig-not (expr-to-aig (car args))))
          ((eq fn 'and) (expr-to-aig-args 'and t args))
          ((eq fn 'or)  (expr-to-aig-args 'or nil args))
          ((eq fn 'nand) (aig-not (expr-to-aig-args 'and t args)))
          ((eq fn 'nor)  (aig-not (expr-to-aig-args 'or nil args)))
          ((and (eq fn 'iff) (= (len args) 2))
           (aig-iff (expr-to-aig (car args))
                    (expr-to-aig (cadr args))))
          ((and (eq fn 'xor) (= (len args) 2))
           (aig-xor (expr-to-aig (car args))
                    (expr-to-aig (cadr args))))
          ((and (eq fn 'implies) (= (len args) 2))
           (aig-or (aig-not (expr-to-aig (car args)))
                   (expr-to-aig (cadr args))))
          ((and (eq fn 'if) (= (len args) 3))
           (aig-ite (expr-to-aig (car args))
                    (expr-to-aig (cadr args))
                    (expr-to-aig (caddr args))))
          (t (prog2$ (er hard? 'expr-to-aig "Malformed: ~x0~%" expr)
                     nil))))))
   (defun expr-to-aig-args (op final exprs)
     (declare (xargs :guard t
                     :measure (* 2 (acl2-count exprs))))
     (if (atom exprs)
         final
       (let ((first (expr-to-aig (car exprs)))
             (rest (expr-to-aig-args op final (cdr exprs))))
         (case op
           (and (aig-and first rest))
           (or (aig-or first rest))))))))
