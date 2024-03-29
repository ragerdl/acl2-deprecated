; Standard Utilities Library
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
;
; Additional copyright notice:
;
; This file is adapted from Milawa, which is also released under the GPL.

(in-package "STD")
(include-book "deflist")
(include-book "std/strings/defs-program" :dir :system)
(include-book "std/lists/append" :dir :system)
(include-book "centaur/nrev/pure" :dir :system)
(include-book "define")
(set-state-ok t)

(defun variable-or-constant-listp (x)
  (declare (xargs :guard t))
  (if (atom x)
      t
    (and (or (symbolp (car x))
             (quotep (car x))
             ;; things that quote to themselves
             (acl2-numberp (car x))
             (stringp (car x))
             (characterp (car x)))
         (variable-or-constant-listp (cdr x)))))

(defun collect-vars (x)
  (declare (xargs :guard t))
  (if (atom x)
      nil
    (if (and (symbolp (car x))
             (not (keywordp (car x))))
        (cons (car x) (collect-vars (cdr x)))
      (collect-vars (cdr x)))))


(defxdoc defprojection
  :parents (std/util)
  :short "Project a transformation across a list."

  :long "<p>Defprojection allows you to quickly introduce a function like
@('map f').  That is, given an element-transforming function, @('f'), it can
define a new function that applies @('f') to every element in a list.  It also
sets up a basic theory with rules about @(see len), @(see append), etc., and
generates basic, automatic @(see xdoc) documentation.</p>

<h4>General form:</h4>

@({
 (defprojection name extended-formals
   element
   [keyword options]
   [/// other events]
   )

 Options                 Defaults
  :nil-preservingp         nil
  :guard                   t
  :verify-guards           t
  :result-type             nil
  :returns                 nil
  :mode                    current defun-mode
  :already-definedp        nil
  :parallelize             nil
  :verbosep                nil
  :parents                 nil
  :short                   nil
  :long                    nil
})

<h4>Basic Examples</h4>

@({
    (defprojection my-strip-cars (x)
      (car x)
      :guard (alistp x))
})

<p>defines a new function, @('my-strip-cars'), that is like the built-in ACL2
function @(see strip-cars).</p>

<p><b><color rgb='#ff0000'>Note</color></b>: @('x') is treated in a special
way.  It refers to the whole list in the formals and guards, but refers to
individual elements of the list in the @('element') portion.  This is similar
to how other macros like @(see deflist), @(see defalist), and @(see
defmapappend) handle @('x').</p>

<p>A @(see define)-like syntax is also available:</p>

@({
    (defprojection my-square-list ((x integer-listp))
      :result (squared-x integer-listp)
      (* x x))
})

<h3>Usage and Optional Arguments</h3>

<p>Let @('pkg') be the package of @('name').  All functions, theorems, and
variables are created in this package.  One of the formals must be @('pkg::x'),
and this argument represents the list that will be transformed.  Otherwise, the
only restriction on formals is that you may not use the names @('pkg::a'),
@('pkg::n'), @('pkg::y'), and @('pkg::acc'), because we use these variables in
the theorems we generate.</p>

<p>The optional @(':nil-preservingp') argument can be set to @('t') when the
element transformation satisfies @('(element nil ...) = nil').  This allows
@('defprojection') to produce slightly better theorems.</p>

<p>The optional @(':guard') and @(':verify-guards') are given to the
@('defund') event that we introduce.  Often @(see deflist) is convenient for
introducing the necessary guard.</p>

<p>The optional @(':result-type') keyword defaults to @('nil'), and in this
case no additional \"type theorem\" will be inferred.  But, if you instead give
the name of a unary predicate like @('nat-listp'), then a defthm will be
generated that looks like @('(implies (force guard) (nat-listp (name ...)))')
while @('name') is still enabled.  This is not a very general mechanism, but it
is often good enough to save a lot of typing.</p>

<p>The optional @(':returns') keyword is similar to that of @(see define), and
is a more general mechanism than @(':result-type').</p>

<p>The optional @(':already-definedp') keyword can be set if you have already
defined the function.  This can be used to generate all of the ordinary
@('defprojection') theorems without generating a @('defund') event, and is
useful when you are dealing with mutually recursive transformations.</p>

<p>The optional @(':mode') keyword can be set to @(':logic') or @(':program')
to introduce the recognizer in logic or program mode.  The default is whatever
the current default defun-mode is for ACL2, i.e., if you are already in program
mode, it will default to program mode, etc.</p>

<p>The optional @(':parallelize') keyword can be set to @('t') if you want to
try to speed up the execution of new function using parallelism.  This is
experimental and only works with ACL2(p).  Note: we don't do anything smart to
split the work up into large chunks, and you lose tail-recursion when you use
this.</p>

<p>The optional @(':verbosep') flag can be set to @('t') if you want
defprojection to print everything it's doing.  This may be useful if you run
into any failures, or if you are simply curious about what is being
introduced.</p>

<p>The optional @(':parents'), @(':short'), and @(':long') keywords are as in
@(see defxdoc).  Typically you only need to specify @(':parents'), perhaps
implicitly with @(see xdoc::set-default-parents), and suitable documentation
will be automatically generated for @(':short') and @(':long').  If you don't
like this documentation, you can supply your own @(':short') and/or @(':long')
to override it.</p>

<h3>Support for Other Events</h3>

<p>Defprojection implements the same @('///') syntax as other macros like @(see
define).  This allows you to put related events near the definition and have
them included in the automatic documentation.  As with define, the new
projection function is enabled during the @('///') section.  Here is an
example:</p>

@({
    (defprojection square-each (x)
      (square x)
      :guard (integer-listp x)
      ///
      (defthm pos-listp-of-square-each
        (pos-listp (square-each x))))
})

<p>It is valid to use an @('///') section with a @(':result-type') theorem.  We
arbitrarily say the @(':result-type') theorem comes first.</p>

<p>Deprecated.  The optional @(':rest') keyword was a precursor to @('///').
It is still implemented, but its use is now discouraged.  If both @(':rest')
and @('///') events are used, we arbitrarily put the @(':rest') events
first.</p>

<p>The optional @(':optimize') keyword was historically used to optionally
optimize the projection using @('nreverse').  We now use @(see nrev::nrev)
instead, and since this doesn't require a ttag, the @(':optimize') flag
now does nothing.</p>")

(defthmd defprojection-append-nil-is-list-fix
  (equal (append x nil)
         (list-fix x)))

(deftheory defprojection-theory
  (union-theories '(acl2::append-to-nil
                    acl2::append-when-not-consp
                    acl2::append-of-cons
                    acl2::associativity-of-append
                    acl2::rev-of-cons
                    acl2::rev-when-not-consp
                    acl2::revappend-removal
                    acl2::reverse-removal)
                  (union-theories (theory 'minimal-theory)
                                  (theory 'deflist-support-lemmas))))


(defconst *defprojection-valid-keywords*
  '(:nil-preservingp
    :guard
    :verify-guards
    :result-type
    :returns
    :mode
    :already-definedp
    :parallelize
    :verbosep
    :parents
    :short
    :long
    :rest     ;; deprecated
    :optimize ;; deprecated
    ))

(defun defprojection-fn (name raw-formals element kwd-alist other-events state)
  (declare (xargs :mode :program))
  (b* ((__function__ 'defprojection)
       (mksym-package-symbol name)
       (world (w state))

       ;; Special variables that are reserved by defprojection
       (x   (intern-in-package-of-symbol "X" name))
       (a   (intern-in-package-of-symbol "A" name))
       (n   (intern-in-package-of-symbol "N" name))
       (y   (intern-in-package-of-symbol "Y" name))
       (acc (intern-in-package-of-symbol "ACC" name))

       (eformals (parse-formals name raw-formals '(:type) world))
       (formal-names (formallist->names eformals))

       ((unless (no-duplicatesp formal-names))
        (raise "The formals must be a list of unique symbols, but the formals ~
                are ~x0." formal-names))
       ((unless (member x formal-names))
        (raise "The formals must contain X, but are ~x0." formal-names))
       ((unless (and (not (member a formal-names))
                     (not (member n formal-names))
                     (not (member y formal-names))
                     (not (member acc formal-names))))
        (raise "As a special restriction, formal-names may not mention a, n, or y, ~
                but the formals are ~x0." formal-names))
       ((unless (and (consp element)
                     (symbolp (car element))))
        (raise "The element transformation should be a function/macro call, ~
                but is ~x0." element))

       (list-fn   name)
       (list-args formal-names)
       (elem-fn   (car element))
       (elem-args (cdr element))
       (exec-fn   (mksym list-fn '-exec))
       (nrev-fn   (mksym list-fn '-nrev))
       (elem-syms (collect-vars elem-args))

       ((unless (variable-or-constant-listp elem-args))
        (raise "The element's arguments must be a function applied to the ~
                formals or constants, but are: ~x0." elem-args))

       ((unless (and (no-duplicatesp elem-syms)
                     (subsetp elem-syms formal-names)
                     (subsetp formal-names elem-syms)))
        (raise "The variables in the :element do not agree with the formals:~% ~
                - formals: ~x0~% ~
                - element vars: ~x1~%" formal-names elem-syms))


       (nil-preservingp  (getarg :nil-preservingp  nil kwd-alist))
       (guard            (getarg :guard            t   kwd-alist))
       (verify-guards    (getarg :verify-guards    t   kwd-alist))
       (result-type      (getarg :result-type      nil kwd-alist))
       (returns          (getarg :returns          nil kwd-alist))
       (already-definedp (getarg :already-definedp nil kwd-alist))
       (optimize         (getarg :optimize         t   kwd-alist))
       (parallelize      (getarg :parallelize      nil kwd-alist))
       ;(verbosep         (getarg :verbosep         nil kwd-alist))
       (short            (getarg :short            nil kwd-alist))
       (long             (getarg :long             nil kwd-alist))

       (rest             (append
                          (getarg :rest nil kwd-alist)
                          other-events))

       (mode             (getarg :mode
                                 (default-defun-mode world)
                                 kwd-alist))

       (parents-p (assoc :parents kwd-alist))
       (parents   (cdr parents-p))
       (parents   (if parents-p
                      parents
                    (xdoc::get-default-parents world)))

       ((unless (booleanp verify-guards))
        (raise ":verify-guards must be a boolean, but is ~x0." verify-guards))
       ((unless (booleanp nil-preservingp))
        (raise ":nil-preservingp must be a boolean, but is ~x0." nil-preservingp))
       ((unless (booleanp already-definedp))
        (raise ":already-definedp must be a boolean, but is ~x0." already-definedp))
       ((unless (booleanp optimize))
        (raise ":optimize must be a boolean, but is ~x0." optimize))
       ((unless (booleanp parallelize))
        (raise ":parallelize must be a boolean, but is ~x0." parallelize))
       ((unless (symbolp result-type))
        (raise ":result-type must be a symbol, but is ~x0." result-type))
       ((unless (or (eq mode :logic)
                    (eq mode :program)))
        (raise ":mode must be one of :logic or :program, but is ~x0." mode))

       (short (or short
                  (and parents
                       (concatenate 'string "@(call " (symbol-name list-fn) ") maps "
                                    "@(see " (symbol-package-name elem-fn)
                                    "::" (symbol-name elem-fn) ") across a list."))))

       (long (or long
                 (and parents
                      (concatenate 'string
                                   "<p>This is an ordinary @(see std::defprojection).</p>"))))

       (prepwork (if already-definedp
                     nil
                   `((define ,exec-fn (,@raw-formals ,acc)
                       ;; For backwards compatibility we still define a -exec
                       ;; function, but it produces the elements in the wrong
                       ;; order so it is usually not what you want.
                       ;; Previously we required that acc was a true-listp in
                       ;; the guard.  But on reflection, this really isn't
                       ;; necessary, and omitting it can simplify the guards of
                       ;; other functions that are directly calling -exec
                       ;; functions.
                       :guard ,guard
                       :mode ,mode
                       ;; We tell ACL2 not to normalize because otherwise type
                       ;; reasoning can rewrite the definition, and ruin some
                       ;; of our theorems below, e.g., when ELEMENT is known to
                       ;; be zero always.
                       :normalize nil
                       :verify-guards nil
                       :parents nil
                       :hooks nil
                       (if (consp ,x)
                           (,exec-fn ,@(subst `(cdr ,x) x list-args)
                                     (cons (,elem-fn ,@(subst `(car ,x) x elem-args))
                                           ,acc))
                         ,acc))

                     (define ,nrev-fn (,@raw-formals nrev::nrev)
                       :guard ,guard
                       :mode ,mode
                       :normalize nil
                       :verify-guards nil
                       :parents nil
                       :hooks nil
                       (if (atom ,x)
                           (nrev::nrev-fix nrev::nrev)
                         (let ((nrev::nrev (nrev::nrev-push (,elem-fn ,@(subst `(car ,x) x elem-args)) nrev::nrev)))
                           (,nrev-fn ,@(subst `(cdr ,x) x list-args) nrev::nrev)))))))

       (def  (if already-definedp
                 nil
               `((define ,list-fn (,@raw-formals)
                   ,@(and parents-p `(:parents ,parents))
                   ,@(and short     `(:short ,short))
                   ,@(and long      `(:long ,long))
                   :returns ,returns
                   :guard ,guard
                   :mode ,mode
                   ;; we tell ACL2 not to normalize because otherwise type
                   ;; reasoning can rewrite the definition, and ruin some of our
                   ;; theorems below, e.g., when ELEMENT is known to be zero.
                   :normalize nil
                   :verify-guards nil
                   :prepwork ,prepwork
                   ,(if parallelize
                        `(if (consp ,x)
                             (pargs (cons (,elem-fn ,@(subst `(car ,x) x elem-args))
                                          (,list-fn ,@(subst `(cdr ,x) x list-args))))
                           nil)
                      `(mbe :logic
                            (if (consp ,x)
                                (cons (,elem-fn ,@(subst `(car ,x) x elem-args))
                                      (,list-fn ,@(subst `(cdr ,x) x list-args)))
                              nil)
                            :exec
                            (nrev::with-local-nrev
                              (,nrev-fn ,@list-args nrev::nrev))))))))

       ((when (eq mode :program))
        `(defsection ,name
           (program)
           ,@def
           . ,(and rest
                   `((defsection ,(mksym name '-rest)
                       ,@(and parents
                              (not already-definedp)
                              `(:extension ,name))
                       . ,rest)))))

       (listp-when-not-consp  (mksym list-fn '-when-not-consp))
       (listp-of-cons         (mksym list-fn '-of-cons))
       (listp-nil-preservingp (mksym list-fn '-nil-preservingp-lemma))

       (main-thms
        `(
          ,@(and nil-preservingp
                 `((value-triple
                    (cw "Defprojection: attempting to justify, using your ~
                         current theory, :nil-preserving ~x0, if necessary.~%"
                        ',name))
                   (with-output :stack :pop
                     (local (maybe-defthm-as-rewrite
                             ,listp-nil-preservingp
                             (equal (,elem-fn ,@(subst ''nil x elem-args))
                                    nil)
                             ;; We just rely on the user to be able to prove this
                             ;; in their current theory.
                             )))))

          (local (make-event
                  ;; Bllalaaaaah... This sucks so bad.  I just want to have a
                  ;; rule with this name, whatever it is.
                  (if (is-theorem-p ',listp-nil-preservingp (w state))
                      (value '(value-triple :invisible))
                    (value '(defthm ,listp-nil-preservingp
                              (or (equal (alistp x) t)
                                  (equal (alistp x) nil))
                              :rule-classes :type-prescription
                              :hints(("Goal"
                                      :in-theory
                                      '((:type-prescription alistp)))))))))

          (value-triple (cw "Defprojection: proving defprojection theorems.~%"))
          (defthm ,listp-when-not-consp
            (implies (not (consp ,x))
                     (equal (,list-fn ,@list-args)
                            nil))
            :hints(("Goal"
                    :in-theory
                    (union-theories '(,list-fn)
                                    (theory 'defprojection-theory)))))

          (defthm ,listp-of-cons
            (equal (,list-fn ,@(subst `(cons ,a ,x) x list-args))
                   (cons (,elem-fn ,@(subst a x elem-args))
                         (,list-fn ,@list-args)))
            :hints(("Goal"
                    :in-theory
                    (union-theories '(,list-fn)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'true-listp-of- list-fn)
            (equal (true-listp (,list-fn ,@list-args))
                   t)
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'len-of- list-fn)
            (equal (len (,list-fn ,@list-args))
                   (len ,x))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'consp-of- list-fn)
            (equal (consp (,list-fn ,@list-args))
                   (consp ,x))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'car-of- list-fn)
            (equal (car (,list-fn ,@list-args))
                   ,(if nil-preservingp
                        `(,elem-fn ,@(subst `(car ,x) x elem-args))
                      `(if (consp ,x)
                           (,elem-fn ,@(subst `(car ,x) x elem-args))
                         nil)))
            :hints(("Goal"
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons
                                      . ,(and nil-preservingp
                                              `(,listp-nil-preservingp
                                                acl2::default-car)))
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'cdr-of- list-fn)
            (equal (cdr (,list-fn ,@list-args))
                   (,list-fn ,@(subst `(cdr ,x) x list-args)))
            :hints(("Goal"
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))


          (defthm ,(mksym list-fn '-under-iff)
            (iff (,list-fn ,@list-args)
                 (consp ,x))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym list-fn '-of-list-fix)
            (equal (,list-fn ,@(subst `(list-fix ,x) x list-args))
                   (,list-fn ,@list-args))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym list-fn '-of-append)
            (equal (,list-fn ,@(subst `(append ,x ,y) x list-args))
                   (append (,list-fn ,@list-args)
                           (,list-fn ,@(subst y x list-args))))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym list-fn '-of-rev)
            (equal (,list-fn ,@(subst `(rev ,x) x list-args))
                   (rev (,list-fn ,@list-args)))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(,(mksym list-fn '-of-append)
                                      ,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym list-fn '-of-revappend)
            (equal (,list-fn ,@(subst `(revappend ,x ,y) x list-args))
                   (revappend (,list-fn ,@list-args)
                              (,list-fn ,@(subst y x list-args))))
            :hints(("Goal" :in-theory
                    (union-theories '(,(mksym list-fn '-of-append)
                                      ,(mksym list-fn '-of-rev))
                                    (theory 'defprojection-theory)))))

          ,@(if nil-preservingp
                `((defthm ,(mksym 'take-of- list-fn)
                    (equal (take ,n (,list-fn ,@list-args))
                           (,list-fn ,@(subst `(take ,n ,x) x list-args)))
                    :hints(("Goal"
                            :induct (take ,n ,x)
                            :in-theory
                            (union-theories '(acl2::take-redefinition
                                              ,listp-when-not-consp
                                              ,listp-of-cons
                                              . ,(and nil-preservingp
                                                      `(,listp-nil-preservingp
                                                        acl2::default-car)))
                                            (theory 'defprojection-theory))))))
              nil)

          (defthm ,(mksym 'nthcdr-of- list-fn)
            (equal (nthcdr ,n (,list-fn ,@list-args))
                   (,list-fn ,@(subst `(nthcdr ,n ,x) x list-args)))
            :hints(("Goal"
                    :induct (nthcdr ,n ,x)
                    :in-theory
                    (union-theories '(nthcdr
                                      ,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'member-equal-of- elem-fn '-in- list-fn '-when-member-equal)
            (implies (member-equal ,a (double-rewrite ,x))
                     (member-equal (,elem-fn ,@(subst a x elem-args))
                                   (,list-fn ,@list-args)))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(member-equal
                                      ,listp-when-not-consp
                                      ,listp-of-cons)
                                    (theory 'defprojection-theory)))))

          (defthm ,(mksym 'subsetp-equal-of- list-fn 's-when-subsetp-equal)
            (implies (subsetp-equal (double-rewrite ,x)
                                    (double-rewrite ,y))
                     (subsetp-equal (,list-fn ,@list-args)
                                    (,list-fn ,@(subst y x list-args))))
            :hints(("Goal"
                    :induct (len ,x)
                    :in-theory
                    (union-theories '(subsetp-equal
                                      ,(mksym 'member-equal-of- elem-fn
                                              '-in- list-fn '-when-member-equal)
                                      ,listp-when-not-consp
                                      ,listp-of-cons
                                      car-cons
                                      cdr-cons
                                      car-cdr-elim
                                      (:induction len))
                                    (theory 'minimal-theory)))))

          ,@(if nil-preservingp
                `((defthm ,(mksym 'nth-of- list-fn)
                    (equal (nth ,n (,list-fn ,@list-args))
                           (,elem-fn ,@(subst `(nth ,n ,x) x elem-args)))
                    :hints(("Goal"
                            :induct (nth ,n ,x)
                            :in-theory
                            (union-theories '(nth
                                              ,listp-when-not-consp
                                              ,listp-of-cons
                                              . ,(and nil-preservingp
                                                      `(,listp-nil-preservingp
                                                        acl2::default-car)))
                                            (theory 'defprojection-theory))))))
              nil)

          ,@(if already-definedp
                nil
              `((defthm ,(mksym exec-fn '-removal)
                  ;; we don't need the hyp... (implies (force (true-listp ,acc))
                  (equal (,exec-fn ,@list-args ,acc)
                         (revappend (,list-fn ,@list-args) ,acc))
                  :hints(("Goal"
                          :induct (,exec-fn ,@list-args ,acc)
                          :in-theory
                          (union-theories '(,exec-fn
                                            ,listp-when-not-consp
                                            ,listp-of-cons)
                                          (theory 'defprojection-theory)))))

                (defthm ,(mksym nrev-fn '-removal)
                  (equal (,nrev-fn ,@list-args nrev::nrev)
                         (append nrev::nrev (,list-fn ,@list-args)))
                  :hints(("Goal"
                          :induct (,nrev-fn ,@list-args nrev::nrev)
                          :in-theory
                          (union-theories '(,nrev-fn
                                            acl2::rcons
                                            ACL2::NREV-FIX
                                            ACL2::NREV-PUSH
					    nrev::nrev$a-push
                                            nrev::nrev$a-fix
                                            defprojection-append-nil-is-list-fix
                                            ,listp-when-not-consp
                                            ,listp-of-cons)
                                          (theory 'defprojection-theory)))))

                ))


          )))

    `(defsection ,name
       (logic)
       (value-triple (cw "Defprojection: defining ~x0.~%" ',name))
       ,@def
       (set-inhibit-warnings "disable" "double-rewrite" "non-rec") ;; implicitly local

       (defsection ,(mksym name '-rest)
         ,@(and parents
                (not already-definedp)
                `(:extension ,name))
         ,@main-thms
         ,@(and (not already-definedp)
                verify-guards
                `((value-triple
                   (cw "Defprojection: verifying guards for ~x0.~%" ',name))
                  (with-output
                    :stack :pop
                    :off (acl2::summary)
                    (progn
                      (verify-guards ,nrev-fn
                        :hints(("Goal"
                                :in-theory
                                (union-theories '()
                                                (theory 'defprojection-theory)))
                               (and stable-under-simplificationp
                                    '(:in-theory (enable )))))
                      (verify-guards ,list-fn
                        :hints(("Goal"
                                :in-theory
                                (union-theories '(,list-fn
                                                  ,(mksym nrev-fn '-removal)
                                                  nrev::nrev-finish
                                                  nrev::nrev$a-finish
                                                  acl2::create-nrev
                                                  acl2::list-fix-when-true-listp
                                                  ,(mksym 'true-listp-of- list-fn))
                                                (theory 'defprojection-theory)))
                               (and stable-under-simplificationp
                                    '(:in-theory (enable )))))
                      (verify-guards ,exec-fn
                        :hints(("Goal"
                                :in-theory
                                (union-theories '(,exec-fn)
                                                (theory 'defprojection-theory)))
                               (and stable-under-simplificationp
                                    '(:in-theory (enable )))))
                      ))))

         (local (in-theory (enable ,list-fn
                                   ,listp-when-not-consp
                                   ,listp-of-cons)))
         ,@(and result-type
                `((value-triple (cw "Defprojection: proving :result-type theorem.~%"))
                  (with-output
                    :stack :pop
                    (defthm ,(mksym result-type '-of- list-fn)
                      ,(if (eq guard t)
                           `(,result-type (,list-fn ,@list-args))
                         `(implies (force ,guard)
                                   (,result-type (,list-fn ,@list-args))))
                      :hints(("Goal"
                              :induct (len ,x)
                              :in-theory (enable (:induction len))))))))
         . ,(and rest
                 `((value-triple (cw "Defprojection: submitting /// events.~%"))
                   (with-output
                     :stack :pop
                     (progn . ,rest))))))))


(defmacro defprojection (name &rest args)
  (b* ((__function__ 'defprojection)
       ((unless (symbolp name))
        (raise "Name must be a symbol."))
       (ctx (list 'defprojection name))
       ((mv main-stuff other-events) (split-/// ctx args))
       ((mv kwd-alist formals-elem)
        (extract-keywords ctx *defprojection-valid-keywords* main-stuff nil))
       ((unless (tuplep 2 formals-elem))
        (raise "Wrong number of arguments to defprojection."))
       ((list formals element) formals-elem)
       (verbosep (getarg :verbosep nil kwd-alist)))
    `(with-output
       :stack :push
       ,@(if verbosep
             nil
           '(:gag-mode t :off (acl2::summary
                               acl2::observation
                               acl2::prove
                               acl2::proof-tree
                               acl2::event)))
       (make-event
        `(progn ,(defprojection-fn ',name ',formals ',element ',kwd-alist
                   ',other-events state)
                (value-triple '(defprojection ,',name)))))))
