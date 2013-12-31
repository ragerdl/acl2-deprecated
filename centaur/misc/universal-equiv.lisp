; Centaur Miscellaneous Books
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
; Modified by Jared Davis <jared@centtech.com> to add XDOC support.

(in-package "ACL2")
(include-book "clause-processors/equality" :dir :system)
(include-book "xdoc/top" :dir :system)
(set-state-ok t)

(defsection def-universal-equiv
  :parents (macro-libraries)
  :short "A macro for defining universally quantified equivalence relations."

  :long "<p>It is often useful to introduce equivalence relations such as:</p>

<blockquote>
<i>A === B when for every possible element E, A and B agree on E.</i>
</blockquote>

<p>For some particular notion of what <i>agree</i> means.  This macro gives you
a quick way to introduce such a relation, using @(see defun-sk), and then
automatically prove that it is an equivalence relation.  For instance, an
equivalence such as:</p>

@({
    (defun-sk foo-equiv (a b)
      (forall (x y z)
              (and (bar-equiv (foo a x y)
                              (foo b x y))
                   (baz-equiv (fa a z)
                              (fa b z)))))
})

<p>Can be introduced using:</p>

@({
    (def-universal-equiv foo-equiv (a b)
      :qvars (x y z)
      :equivs ((bar-equiv (foo a x y))
               (baz-equiv (fa a z))))
})

<p>When called with @(':defquant t'), we use @(see defquant) instead of @(see
defun-sk).  This requires that the WITNESS-CP book be included.</p>")

(defun universal-equiv-equivterms (var1 var2 equivs)
  (if (atom equivs)
      nil
    (let* ((equivname (caar equivs))
           (term1 (cadar equivs))
           (term2 (esc-substitute
                   term1 (list (cons var1 var2)))))
      (cons (list equivname term1 term2)
            (universal-equiv-equivterms var1 var2 (cdr equivs))))))

(defun universal-equiv-multi-qvar-bindings (n qvars witnesscall)
  (if (atom qvars)
      nil
    (cons `(,(car qvars) (mv-nth ,n ,witnesscall))
          (universal-equiv-multi-qvar-bindings (1+ n) (cdr qvars)
                                               witnesscall))))

(defun universal-equiv-qvar-bindings (witness var1 var2 qvars)
  (let ((qvars (if (and (consp qvars)
                        (not (consp (cdr qvars))))
                   (car qvars)
                 qvars))
        (term (list witness var1 var2)))
    (if (atom qvars)
        (list (list qvars term))
      (universal-equiv-multi-qvar-bindings 0 qvars term))))

(defun universal-equiv-form (equivname qvars equivs defquant
                                       witness-dcls witness-dcls-p
                                       parents parents-p short long
                                       state)
  (declare (xargs :mode :program))
  (let* ((equivterms `(and . ,(universal-equiv-equivterms
                               'x 'y equivs)))
         (witness        (intern-in-package-of-symbol
                          (concatenate 'string (symbol-name equivname) "-WITNESS")
                          equivname))
         (equivname-necc (intern-in-package-of-symbol
                          (concatenate 'string (symbol-name equivname) "-NECC")
                          equivname))
         (equivname-refl (intern-in-package-of-symbol
                          (concatenate 'string (symbol-name equivname) "-REFL")
                          equivname))
         (equivname-symm (intern-in-package-of-symbol
                          (concatenate 'string (symbol-name equivname) "-SYMM")
                          equivname))
         (equivname-trans (intern-in-package-of-symbol
                           (concatenate 'string (symbol-name equivname) "-TRANS")
                           equivname))

         ;; Mimicking how deflist deals with parents/etc.
         (parents (if parents-p
                      parents
                    (or (xdoc::get-default-parents (w state))
                        '(acl2::undocumented))))

         ;; BOZO this is kind of lame, can we generate better docs?
         (long
          (or long
              (and parents
                   (concatenate 'string
                                "<p>This is a universal equivalence, introduced
                     using @(see acl2::def-universal-equiv).</p>"))))
         (long (and long
                    (concatenate 'string long
                                 "@(def "
                                 (symbol-package-name equivname)
                                 "::"
                                 (symbol-name equivname) ")"))))

    `(defsection ,equivname
       ,@(and parents `(:parents ,parents))
       ,@(and short   `(:short ,short))
       ,@(and long    `(:long ,long))

       ,(if qvars
            `(,(if defquant 'defquant 'defun-sk) ,equivname (x y)
               (forall ,qvars ,equivterms)
               ,@(and witness-dcls-p
                      `(:witness-dcls ,witness-dcls)))
          `(defun ,equivname (x y)
             ,equivterms))

       (in-theory (disable ,@(and qvars (list equivname-necc))
                           ,equivname))

       (local
        (defthm ,equivname-refl
          (,equivname x x)
          :hints (("goal" :in-theory (enable ,equivname)))))

       (local
        (defthm ,equivname-symm
          (implies (,equivname x y)
                   (,equivname y x))
          :hints (("goal"
                   ,@(if qvars
                         `(:use
                           ((:instance ,equivname-necc
                                       ,@(universal-equiv-qvar-bindings
                                          witness 'y 'x qvars)))
                           :expand ((,equivname y x)))
                       `(:in-theory (enable ,equivname)))))))

       (local
        (defthm ,equivname-trans
          (implies (and (,equivname x y)
                        (,equivname y z))
                   (,equivname x z))
          :hints (("goal"
                   ,@(if qvars
                         `(:use
                           ((:instance ,equivname-necc
                                       ,@(universal-equiv-qvar-bindings
                                          witness 'x 'z qvars))
                            (:instance ,equivname-necc
                                       ,@(universal-equiv-qvar-bindings
                                          witness 'x 'z qvars)
                                       (x y) (y z)))
                           :expand ((,equivname x z)))
                       `(:in-theory (enable ,equivname)))))))

       (defequiv ,equivname))))

(defmacro def-universal-equiv (name &key qvars equiv-terms defquant
                                    (witness-dcls 'nil witness-dcls-p)
                                    (parents      'nil parents-p)
                                    short long)
  `(make-event
    (let ((form (universal-equiv-form ',name ',qvars ',equiv-terms ',defquant
                                      ',witness-dcls ',witness-dcls-p
                                      ',parents ',parents-p
                                      ',short ',long
                                      state)))
      (value form))))

