; GL - A Symbolic Simulation Framework for ACL2
; Copyright (C) 2008-2013 Centaur Technology
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

(in-package "GL")
(include-book "gl-util")

(defstobj interp-st
  is-obligs            ;; interp-defs-alistp
  is-constraint        ;; calist
  is-constraint-db     ;; constraint database
  )

(defconst *glcp-common-inputs*
  '(pathcond clk config interp-st bvar-db state))

(defconst *glcp-common-guards*
  '((acl2::interp-defs-alistp (is-obligs interp-st))
    (glcp-config-p config)
    (acl2::interp-defs-alistp (glcp-config->overrides config))))

(defconst *glcp-stobjs* '(pathcond interp-st bvar-db state))

(defconst *glcp-common-retvals* '(er pathcond interp-st bvar-db state))

(defmacro glcp-value (&rest results)
  `(mv ,@results nil ,@(cdr *glcp-common-retvals*)))

(defmacro glcp-value-nopathcond (&rest results)
  `(mv ,@results nil ,@(cddr *glcp-common-retvals*)))


(defun glcp-interp-error-trace (msg)
  (declare (ignore msg)
           (xargs :guard t))
  nil)

(defmacro break-on-glcp-error (flg)
  (if flg
      '(trace$ (glcp-interp-error-trace
                :entry (progn$
                        (cw "GLCP interpreter error:~%~@0~%" msg)
                        (break$))))
    '(untrace$ glcp-interp-error-trace)))
    

(defmacro glcp-interp-abort (msg &key (nvals '1))
  `(mv ,@(make-list-ac nvals nil nil)
      ,msg ,@(cdr *glcp-common-retvals*)))

(defund glcp-interp-sanitize-error (err)
  (declare (xargs :guard t))
  (if (eq err :unreachable)
      "Unreachable error from a strange source"
    err))

(defthm glcp-interp-sanitize-under-iff
  (iff (glcp-interp-sanitize-error err)
       err)
  :hints(("Goal" :in-theory (enable glcp-interp-sanitize-error))))

(defthm glcp-interp-sanitize-not-unreachable
  (not (equal (glcp-interp-sanitize-error err) :unreachable))
  :hints(("Goal" :in-theory (enable glcp-interp-sanitize-error))))

(defmacro glcp-interp-error (msg &key (nvals '1))
  (declare (xargs :guard t))
  `(let ((msg (glcp-interp-sanitize-error ,msg)))
     (progn$ (glcp-interp-error-trace msg)
             (glcp-interp-abort msg :nvals ,nvals))))

(defmacro patbind-glcp-special (args bindings expr)
  ;; error flag is first arg, rest are regular returns
  `(b* (((mv ,@(cdr args) ,(car args) ,@(cdr *glcp-common-retvals*))
         ,(car bindings)))
     ,expr))

(defmacro patbind-glcp-er (args bindings expr)
  (b* ((nvalsp (member :nvals args))
       (nvals (or (cadr nvalsp) 1))
       (args (take (- (len args) (len nvalsp)) args)))
    `(b* (((mv ,@args patbind-glcp-er-error ,@(cdr *glcp-common-retvals*))
           ,(car bindings))
          ((when patbind-glcp-er-error)
           (glcp-interp-abort patbind-glcp-er-error :nvals ,nvals)))
       (check-vars-not-free
        (patbind-glcp-er-error) ,expr))))

(defmacro glcp-run-branch (branchcond expr)
  ;; This assumes branchcond, then runs expr, a glcp-interp with 1 return
  ;; value.  Before propagating the error we unassume the latest pathcond
  ;; assumption.  If there is a non-:unreachable error, we propagate it.
  ;; Otherwise, we return two values: a flag saying whether there was an
  ;; :unreachable error, and the value returned by the expression.
  `(b* ((branchcond (bfr-constr-fix ,branchcond (is-constraint interp-st)))
        ((mv contra pathcond undo)
         (bfr-assume branchcond pathcond))
        ((when contra)
         (b* ((pathcond (bfr-unassume pathcond undo)))
           (glcp-value t nil)))
        ((glcp-special err retval) ,expr)
        (pathcond (bfr-unassume pathcond undo))
        ((when err)
         (if (eq err :unreachable)
             (glcp-value t nil)
           (glcp-interp-abort err :nvals 2))))
     (glcp-value nil retval)))

;; (defmacro patbind-glcp-er-unassume (args bindings expr)
;;   ;; Note: This propagates errors after unassuming the latest pathcond update
;;   ;; but it also converts :unreachable errors into :branch-unreachable ones.
;;   (b* ((nvalsp (member :nvals args))
;;        (nvals (or (cadr nvalsp) 1))
;;        (args (take (- (len args) (len nvalsp)) args)))
;;     `(b* (((mv ,@args patbind-glcp-er-error ,@(cdr *glcp-common-retvals*))
;;            ,(car bindings))
;;           (pathcond (bfr-unassume pathcond undo))
;;           ((when patbind-glcp-er-error)
;;            (glcp-interp-abort (if (eq patbind-glcp-er-error :unreachable)
;;                                   :branch-unreachable
;;                                 patbind-glcp-er-error)
;;                               :nvals ,nvals)))
;;        (check-vars-not-free
;;         (patbind-glcp-er-error) ,expr))))

(defund glcp-non-branch-err-p (err)
  (declare (xargs :guard t))
  (and err (not (eq err :branch-unreachable))))

;; (defmacro patbind-glcp-catch-branch (args bindings expr)
;;   ;; first arg is variable to bind branch-unreachable flag to
;;   (b* ((nvalsp (member :nvals args))
;;        (nvals (or (cadr nvalsp) 1))
;;        (args (take (- (len args) (len nvalsp)) args)))
;;     `(b* (((mv ,@(cdr args) patbind-glcp-er-error ,@(cdr *glcp-common-retvals*))
;;            ,(car bindings))
;;           ((when (glcp-non-branch-err-p patbind-glcp-er-error))
;;            (glcp-interp-abort patbind-glcp-er-error :nvals ,nvals))
;;           (,(car args) (eq patbind-glcp-er-error :branch-unreachable)))
;;        (check-vars-not-free
;;         (patbind-glcp-er-error) ,expr))))

(defmacro cpathcond ()
  '(bfr-and (bfr-hyp->bfr pathcond)
            (bfr-constr->bfr (is-constraint interp-st))))


(defun glcp-put-name-each (name lst)
  (if (atom lst)
      nil
    (cons (incat name (symbol-name name) "-" (symbol-name (car lst)))
          (glcp-put-name-each name (cdr lst)))))

(mutual-recursion
 (defun event-forms-collect-fn-names (x)
   (if (atom x)
       nil
     (append (event-form-collect-fn-names (car x))
             (event-forms-collect-fn-names (cdr x)))))
 (defun event-form-collect-fn-names (x)
   (case (car x)
     ((defun defund) (list (cadr x)))
     ((mutual-recursion progn)
      (event-forms-collect-fn-names (cdr x))))))

(defund glcp-term-obj-p (x)
  (declare (xargs :guard t))
  (and (consp x)
       (let* ((tag (car x)))
         (or (eq tag :g-apply)
             (eq tag :g-var)))))

(defconst *glcp-interp-template*
  `(progn

     (mutual-recursion
      (defun interp-test
        (x alist intro-bvars . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 12 0 0)
                  :verify-guards nil
                  :guard (and (posp clk)
                              (pseudo-termp x)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((clk (1- clk))
             ((glcp-er xobj)
              (interp-term-equivs x alist '(iff) . ,*glcp-common-inputs*)))
          (simplify-if-test xobj intro-bvars . ,*glcp-common-inputs*)))

      (defun interp-term-equivs
        (x alist contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list clk 2020 (acl2-count x) 40)
                  :guard (and (natp clk)
                              (pseudo-termp x)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (zp clk))
              (glcp-interp-error "The clock ran out.~%"))
             ((glcp-er xobj)
              (interp-term x alist contexts . ,*glcp-common-inputs*))
             ((unless (glcp-term-obj-p xobj))
              (glcp-value xobj))
             ((mv er xobj) (try-equivalences-loop xobj
                                                  pathcond
                                                  contexts clk
                                                  (glcp-config->param-bfr config)
                                                  bvar-db state))
             ((when er) (glcp-interp-error er)))
          (glcp-value xobj)))



      (defun interp-term
        (x alist contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 2020 (acl2-count x) 20)
                  :well-founded-relation acl2::nat-list-<
                  :hints (("goal"
                           :in-theory (e/d** ((:rules-of-class :executable-counterpart :here)
                                              acl2::open-nat-list-<
                                              acl2-count len nfix fix
                                              acl2-count-of-general-consp-car
                                              acl2-count-of-general-consp-cdr
                                              car-cons cdr-cons commutativity-of-+
                                              unicity-of-0 null atom
                                              eq acl2-count-last-cdr-when-cadr-hack
                                              car-cdr-elim natp-compound-recognizer
                                              acl2::zp-compound-recognizer
                                              acl2::posp-compound-recognizer
                                              pos-fix
                                              g-ite-depth-sum-of-gl-args-split-ite-then
                                              g-ite-depth-sum-of-gl-args-split-ite-else
                                              g-ite->test-acl2-count-decr
                                              g-ite->then-acl2-count-decr
                                              g-ite->else-acl2-count-decr
                                              g-apply->args-acl2-count-thm
                                              acl2-count-of-car-g-apply->args
                                              acl2-count-of-cadr-g-apply->args
                                              acl2-count-of-car
                                              (:type-prescription acl2-count)
                                              (:t len)))))
                  :verify-guards nil
                  :guard (and (posp clk)
                              (pseudo-termp x)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (null x)) (glcp-value nil))
             ((when (symbolp x))
              (glcp-value (cdr (hons-assoc-equal x alist))))
             ((when (atom x))
              (glcp-interp-error
               (acl2::msg "GLCP:  The unquoted atom ~x0 is not a term~%"
                          x)))
             ((when (eq (car x) 'quote))
              (glcp-value (g-concrete-quote (car (cdr x)))))
             ((when (consp (car x)))
              (b*
                (((glcp-er actuals)
                  (interp-list (cdr x)
                               alist . ,*glcp-common-inputs*))
                 (formals (car (cdar x)))
                 (body (car (cdr (cdar x)))))
                (if (and (mbt (and (equal (len actuals) (len formals))
                                   (symbol-listp formals)))
                         (acl2::fast-no-duplicatesp formals)
                         (not (member-eq nil formals)))
                    (interp-term body (pairlis$ formals actuals)
                                 contexts . ,*glcp-common-inputs*)
                  (glcp-interp-error (acl2::msg "Badly formed lambda application: ~x0~%"
                                                x)))))
             ((when (eq (car x) 'if))
              (let ((test (car (cdr x)))
                    (tbr (car (cdr (cdr x))))
                    (fbr (car (cdr (cdr (cdr x))))))
                (interp-if/or test tbr fbr alist contexts . ,*glcp-common-inputs*)))

             ((when (eq (car x) 'gl-aside))
              (if (eql (len x) 2)
                  (prog2$ (gl-aside-wormhole (cadr x) alist)
                          (glcp-value nil))
                (glcp-interp-error "Error: wrong number of args to GL-ASIDE~%")))
             ((when (eq (car x) 'gl-ignore))
              (glcp-value nil))
             ((when (eq (car x) 'gl-hide))
              (glcp-value (gl-term-to-apply-obj x alist)))
             ((when (eq (car x) 'gl-error))
              (if (eql (len x) 2)
                  (b* (((glcp-er result)
                        (interp-term (cadr x)
                                     alist nil . ,*glcp-common-inputs*))
                       (state (f-put-global 'gl-error-result
                                            result state)))
                    (glcp-interp-error
                     (acl2::msg
                      "Error: GL-ERROR call encountered.  Data associated with the ~
                      error is accessible using (@ ~x0).~%"
                      'gl-error-result)))
                (glcp-interp-error "Error: wrong number of args to GL-ERROR~%")))
             ((when (eq (car x) 'return-last))
              (if (eql (len x) 4)
                  (if (equal (cadr x) ''acl2::time$1-raw)
                      (b* (((mv time$-args err ,@(cdr *glcp-common-retvals*))
                            (let ((clk (1- clk)))
                              (interp-term-equivs
                               (caddr x)
                               alist nil . ,*glcp-common-inputs*))))
                        (mbe :logic (interp-term
                                     (car (last x)) alist contexts . ,*glcp-common-inputs*)
                             :exec
                             (if (and (not err)
                                      (general-concretep time$-args))
                                 (return-last
                                  'acl2::time$1-raw
                                  (general-concrete-obj time$-args)
                                  (interp-term (car (last x))
                                               alist contexts . ,*glcp-common-inputs*))
                               (time$
                                (interp-term (car (last x))
                                             alist contexts . ,*glcp-common-inputs*)))))
                    (interp-term (car (last x))
                                 alist contexts . ,*glcp-common-inputs*))
                (glcp-interp-error "Error: wrong number of args to RETURN-LAST~%")))
             (fn (car x))
             ;; outside-in rewriting?
             ((glcp-er actuals)
              (interp-list (cdr x)
                           alist . ,*glcp-common-inputs*)))
          (interp-fncall-ifs fn actuals x contexts . ,*glcp-common-inputs*)))

      (defun interp-fncall-ifs
        (fn actuals x contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 1919 (g-ite-depth-sum actuals) 20)
                  :guard (and (posp clk)
                              (symbolp fn)
                              (contextsp contexts)
                              (not (eq fn 'quote))
                              (true-listp actuals)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* (((unless (glcp-lift-ifsp fn (glcp-config->lift-ifsp config)
                                      (w state)))
              (interp-fncall fn actuals x contexts . ,*glcp-common-inputs*))
             ((mv has-if test then-args else-args)
              (gl-args-split-ite actuals))
             ((unless has-if)
              (interp-fncall fn actuals x contexts . ,*glcp-common-inputs*))
             ((glcp-er test-bfr)
              (simplify-if-test test t . ,*glcp-common-inputs*))
             ((glcp-er then-unreach then-obj)
              (maybe-interp-fncall-ifs fn then-args x contexts test-bfr
                                       . ,*glcp-common-inputs*))
             ((glcp-er else-unreach else-obj)
              (maybe-interp-fncall-ifs fn else-args x contexts (bfr-not test-bfr)
                                       . ,*glcp-common-inputs*))
             ((when then-unreach)
              (if else-unreach
                  (glcp-interp-abort :unreachable)
                (glcp-value else-obj)))
             ((when else-unreach) (glcp-value then-obj)))
          (merge-branches test-bfr then-obj else-obj nil contexts . ,*glcp-common-inputs*)))


      (defun maybe-interp-fncall-ifs (fn actuals x contexts branchcond . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 1919 (g-ite-depth-sum actuals) 45)
                  :verify-guards nil
                  :guard (and (posp clk)
                              (symbolp fn)
                              (contextsp contexts)
                              (not (eq fn 'quote))
                              (true-listp actuals)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (glcp-run-branch
         branchcond
         (interp-fncall-ifs
          fn actuals x contexts . ,*glcp-common-inputs*)))

      (defun interp-fncall
        (fn actuals x contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 1414 0 20)
                  :guard (and (posp clk)
                              (symbolp fn)
                              (not (eq fn 'quote))
                              (true-listp actuals)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             (uninterp (cdr (hons-assoc-equal fn (table-alist
                                                  'gl-uninterpreted-functions (w
                                                                               state)))))
             ((mv fncall-failed ans)
              (if (and (not uninterp)
                       (general-concrete-listp actuals))
                  (acl2::magic-ev-fncall fn (general-concrete-obj-list actuals)
                                         state t nil)
                (mv t nil)))
             ((unless fncall-failed)
              (glcp-value (mk-g-concrete ans)))
             ((glcp-er successp term bindings)
              (rewrite fn actuals :fncall contexts . ,*glcp-common-inputs*))
             ((when successp)
              (b* ((clk (1- clk)))
                (interp-term-equivs term bindings contexts . ,*glcp-common-inputs*)))
             ((mv ok ans pathcond)
              (run-gified fn actuals pathcond clk config bvar-db state))
             ((when ok) (glcp-value ans))
             ((when uninterp)
              (glcp-value (g-apply fn actuals)))
             ((mv erp body formals obligs1)
              (acl2::interp-function-lookup fn
                                            (is-obligs interp-st)
                                            (glcp-config->overrides config)
                                            (w state)))
             ((when erp) (glcp-interp-error erp))
             (interp-st (update-is-obligs obligs1 interp-st))
             ((unless (equal (len formals) (len actuals)))
              (glcp-interp-error
               (acl2::msg
                "~
In the function call ~x0, function ~x1 is given ~x2 arguments,
but its arity is ~x3.  Its formal parameters are ~x4."
                x fn (len actuals)
                (len formals)
                formals)))
             (clk (1- clk)))
          (interp-term-equivs body (pairlis$ formals actuals)
                              contexts . ,*glcp-common-inputs*)))

      (defun interp-if/or (test tbr fbr alist contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 2020 (+ (acl2-count test)
                                                       (acl2-count tbr)
                                                       (acl2-count fbr)) 60)
                  :verify-guards nil
                  :guard (and (posp clk)
                              (pseudo-termp test)
                              (pseudo-termp tbr)
                              (pseudo-termp fbr)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (if (hqual test tbr)
            (interp-or test fbr alist contexts . ,*glcp-common-inputs*)
          (interp-if test tbr fbr alist contexts . ,*glcp-common-inputs*)))

      (defun maybe-interp (x alist contexts branchcond . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 2020 (acl2-count x) 45)
                  :verify-guards nil
                  :guard (and (natp clk)
                              (pseudo-termp x)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (glcp-run-branch
         branchcond
         (interp-term-equivs
          x alist contexts . ,*glcp-common-inputs*)))

      (defun interp-or (test fbr alist contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 2020 (+ (acl2-count test)
                                                       (acl2-count fbr)) 50)
                  :verify-guards nil
                  :guard (and (posp clk)
                              (pseudo-termp test)
                              (pseudo-termp fbr)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* (((glcp-er test-obj)
              (interp-term-equivs
               test alist (glcp-or-test-contexts contexts)  . ,*glcp-common-inputs*))
             ((glcp-er test-bfr)
              (simplify-if-test test-obj t . ,*glcp-common-inputs*))
             ((glcp-er else-unreach else)
              (maybe-interp
               fbr alist contexts (bfr-not test-bfr) . ,*glcp-common-inputs*))
             ((when else-unreach)
              (glcp-value test-obj)))
          (merge-branches test-bfr test-obj else nil contexts . ,*glcp-common-inputs*)))

      (defun interp-if (test tbr fbr alist contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 2020 (+ (acl2-count test)
                                                       (acl2-count tbr)
                                                       (acl2-count fbr)) 50)
                  :verify-guards nil
                  :guard (and (posp clk)
                              (pseudo-termp test)
                              (pseudo-termp tbr)
                              (pseudo-termp fbr)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* (((glcp-er test-bfr)
              (interp-test
               test alist t . ,*glcp-common-inputs*))
             ((glcp-er then-unreachable then)
              (maybe-interp
               tbr alist contexts test-bfr . ,*glcp-common-inputs*))
             ((glcp-er else-unreachable else)
              (maybe-interp
               fbr alist contexts (bfr-not test-bfr) . ,*glcp-common-inputs*))
             ((when then-unreachable)
              (if else-unreachable
                  (glcp-interp-abort :unreachable)
                (glcp-value else)))
             ((when else-unreachable)
              (glcp-value then)))
          (merge-branches test-bfr then else nil contexts . ,*glcp-common-inputs*)))

      (defun merge-branches (test-bfr then else switchedp contexts . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list (pos-fix clk) 1818
                                 (+ (acl2-count then) (acl2-count else))
                                 (if switchedp 20 30))
                  :verify-guards nil
                  :guard (and (posp clk)
                              (contextsp contexts)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (eq test-bfr t)) (glcp-value then))
             ((when (eq test-bfr nil)) (glcp-value else))
             ((when (hons-equal then else)) (glcp-value then))
             ((when (or (atom then)
                        (and (g-keyword-symbolp (tag then))
                             (or (not (eq (tag then) :g-apply))
                                 (not (symbolp (g-apply->fn then)))
                                 (eq (g-apply->fn then) 'quote)))))
              (if switchedp
                  (merge-branch-subterms
                   (bfr-not test-bfr) else then . ,*glcp-common-inputs*)
                (merge-branches (bfr-not test-bfr) else then t contexts . ,*glcp-common-inputs*)))
             (fn (if (eq (tag then) :g-apply)
                     (g-apply->fn then)
                   'cons))
             (rules (glcp-get-branch-merge-rules fn (w state)))
             (runes (rewrite-rules->runes rules))
             ((glcp-er successp term bindings)
              (rewrite-apply-rules
               rules runes 'if (list (g-boolean test-bfr) then else)
               contexts . ,*glcp-common-inputs*))
             ((when successp)
              (b* ((clk (1- clk)))
                (interp-term-equivs term bindings contexts . ,*glcp-common-inputs*))))
          (if switchedp
              (merge-branch-subterms (bfr-not test-bfr) else then . ,*glcp-common-inputs*)
            (merge-branches (bfr-not test-bfr) else then t contexts . ,*glcp-common-inputs*))))

      (defun merge-branch-subterms (test-bfr then else
                                             . ,*glcp-common-inputs*)
        (declare (xargs :measure (list (pos-fix clk) 1818
                                       (+ (acl2-count then) (acl2-count else))
                                       15)
                        :guard (and (posp clk)
                                    . ,*glcp-common-guards*)
                        :stobjs ,*glcp-stobjs*))
        (b* (((when (or (atom then)
                        (atom else)
                        (xor (eq (tag then) :g-apply)
                             (eq (tag else) :g-apply))
                        (not (or (eq (tag then) :g-apply)
                                 (and (general-consp then)
                                      (general-consp else))))
                        (and (eq (tag then) :g-apply)
                             (not (and (symbolp (g-apply->fn then))
                                       (not (eq (g-apply->fn then) 'quote))
                                       (eq (g-apply->fn then) (g-apply->fn else))
                                       (int= (len (g-apply->args then))
                                             (len (g-apply->args else))))))))
              (b* (((mv res pathcond) (gobj-ite-merge test-bfr then else pathcond)))
                (glcp-value res)))
             ((unless (eq (tag then) :g-apply))
              (b* (((glcp-er car) (merge-branches test-bfr
                                                  (general-consp-car then)
                                                  (general-consp-car else)
                                                  nil nil . ,*glcp-common-inputs*))
                   ((glcp-er cdr) (merge-branches test-bfr
                                                  (general-consp-cdr then)
                                                  (general-consp-cdr else)
                                                  nil nil . ,*glcp-common-inputs*)))
                (glcp-value ;; (gl-cons-split-ite car cdr)
                 (gl-cons-maybe-split car cdr
                                      (glcp-config->split-conses config)
                                      (w state)))))
             ((glcp-er args)
              (merge-branch-subterm-lists test-bfr
                                          (g-apply->args then)
                                          (g-apply->args else)
                                          . ,*glcp-common-inputs*)))
          (glcp-value (gl-fncall-maybe-split
                       (g-apply->fn then) args
                       (glcp-config->split-fncalls config)
                       (w state)))))

      (defun merge-branch-subterm-lists (test-bfr then else
                                                  . ,*glcp-common-inputs*)
        (declare (xargs :measure (list (pos-fix clk) 1818
                                       (+ (acl2-count then) (acl2-count else))
                                       15)
                        :guard (and (posp clk)
                                    (equal (len then) (len else))
                                    . ,*glcp-common-guards*)
                        :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (atom then))
              (glcp-value nil))
             ((cons then1 thenr) then)
             ((cons else1 elser) else)
             ((glcp-er rest) (merge-branch-subterm-lists test-bfr thenr elser
                                                         . ,*glcp-common-inputs*))
             ((glcp-er first) (merge-branches test-bfr then1 else1 nil nil
                                              . ,*glcp-common-inputs*)))
          (glcp-value (cons first rest))))

      (defun maybe-simplify-if-test (test-obj intro-bvars branchcond
                                              . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list clk 1300 (acl2-count test-obj) 15)
                  :verify-guards nil
                  :guard (and (natp clk)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (glcp-run-branch
         branchcond
         (simplify-if-test
          test-obj intro-bvars . ,*glcp-common-inputs*)))

      ;; returns a glcp-value of a bfr
      (defun simplify-if-test (test-obj intro-bvars . ,*glcp-common-inputs*)
        (declare (xargs
                  :measure (list clk 1300 (acl2-count test-obj) 10)
                  :verify-guards nil
                  :guard (and (natp clk)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond)))
          (if (atom test-obj)
              (glcp-value (and test-obj t))
            (pattern-match test-obj
              ((g-boolean bfr)
               (b* ((bfr (hyp-fix bfr pathcond))
                    (bfr (bfr-constr-fix bfr (is-constraint interp-st))))
                 (glcp-value bfr)))
              ((g-number &) (glcp-value t))
              ((g-concrete v) (glcp-value (and v t)))
              ((g-var &)
               (b* (((mv bvar bvar-db) (add-term-bvar-unique test-obj bvar-db))
                    (bvar-db (maybe-add-equiv-term test-obj bvar bvar-db state))
                    (bfr (bfr-to-param-space (glcp-config->param-bfr config)
                                             (bfr-var bvar)))
                    (bfr (hyp-fix bfr pathcond))
                    (bfr (bfr-constr-fix bfr (is-constraint interp-st))))
                 (glcp-value bfr)))
              ((g-ite test then else)
               (b* (((glcp-er test-bfr) (simplify-if-test
                                         test intro-bvars . ,*glcp-common-inputs*))
                    (then-hyp test-bfr)
                    (else-hyp (bfr-not test-bfr))
                    ((glcp-er then-unreach then-bfr)
                     (maybe-simplify-if-test
                      then intro-bvars then-hyp . ,*glcp-common-inputs*))
                    ((glcp-er else-unreach else-bfr)
                     (maybe-simplify-if-test
                      else intro-bvars else-hyp . ,*glcp-common-inputs*))
                    ((when then-unreach)
                     (if else-unreach
                         (glcp-interp-abort :unreachable)
                       (glcp-value else-bfr)))
                    ((when else-unreach)
                     (glcp-value then-bfr)))
                 ;; Seems unlikely that hyp-fix would give any reductions here:
                 ;; maybe test this
                 (glcp-value (bfr-ite test-bfr then-bfr else-bfr))))
              ((g-apply fn args)
               (simplify-if-test-fncall fn args intro-bvars . ,*glcp-common-inputs*))
              (& ;; cons
               (glcp-value t))))))



      (defun simplify-if-test-fncall (fn args intro-bvars
                                         . ,*glcp-common-inputs*)

        (declare (xargs
                  :measure (list clk 1300 (acl2-count args) 10)
                  :verify-guards nil
                  :guard (and (natp clk)
                              . ,*glcp-common-guards*)
                  :stobjs ,*glcp-stobjs*))

        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (or (not (symbolp fn))
                        (eq fn 'quote)))
              (glcp-interp-error (acl2::msg "Non function symbol in g-apply: ~x0" fn)))

             ((when (and (eq fn 'not)
                         (eql (len args) 1)))
              (b* (((glcp-er neg-bfr)
                    (simplify-if-test (first args) intro-bvars . ,*glcp-common-inputs*)))
                (glcp-value (bfr-not neg-bfr))))
             ((when (and (eq fn 'equal)
                         (eql (len args) 2)
                         (or (eq (car args) nil)
                             (eq (cadr args) nil))))
              (b* (((glcp-er neg-bfr)
                    (simplify-if-test (or (car args) (cadr args)) intro-bvars . ,*glcp-common-inputs*)))
                (glcp-value (bfr-not neg-bfr))))

             ((when (and (eq fn 'gl-force-check-fn)
                         (eql (len args) 3)))
              (b* (((glcp-er sub-bfr)
                    (simplify-if-test (first args) intro-bvars . ,*glcp-common-inputs*))
                   ((mv pathcond-sat newcond)
                    (bfr-force-check sub-bfr
                                     (if (second args)
                                         (cpathcond)
                                       t)
                                     (third args)))
                   ((when pathcond-sat)
                    (glcp-value newcond)))
                ;; Not really an error: just found out that the path condition
                ;; is unsat.
                (glcp-interp-abort :unreachable)))

             ((when (zp clk))
              (glcp-interp-error "Clock ran out in simplify-if-test"))

             ((glcp-er successp term bindings)
              (rewrite fn args :if-test '(iff) . ,*glcp-common-inputs*))
             ((when successp)
              (interp-test term bindings intro-bvars
                           . ,*glcp-common-inputs*))
             
             (x (g-apply fn args))
             (look (get-term->bvar x bvar-db))

             ((when look)
              (b* ((bfr (bfr-to-param-space (glcp-config->param-bfr config)
                                            (bfr-var look)))
                   (bfr (bfr-constr-fix bfr (is-constraint interp-st)))
                   (bfr (hyp-fix bfr pathcond)))
                (glcp-value bfr)))

             ((unless intro-bvars)
              (glcp-interp-abort :intro-bvars-fail))

             (bvar (next-bvar bvar-db))
             (bvar-db (add-term-bvar x bvar-db))
             (bvar-db (maybe-add-equiv-term x bvar bvar-db state))
             ((glcp-er) (add-bvar-constraints x . ,*glcp-common-inputs*))
             (bfr (bfr-to-param-space (glcp-config->param-bfr config)
                                      (bfr-var bvar)))
             (bfr (bfr-constr-fix bfr (is-constraint interp-st)))
             (bfr (hyp-fix bfr pathcond)))
          (glcp-value bfr)))

      (defun add-bvar-constraints (lit . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (posp clk)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 1000 0 0))
                 (ignorable pathcond))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             (ccat (is-constraint-db interp-st))
             ((mv substs ccat) (ec-call (gbc-process-new-lit lit ccat state)))
             (interp-st (update-is-constraint-db ccat interp-st)))
          (add-bvar-constraint-substs substs . ,*glcp-common-inputs*)))

      (defun add-bvar-constraint-substs (substs . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (posp clk)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 900 (len substs) 0))
                 (ignorable pathcond))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (atom substs)) (glcp-value))
             (subst (car substs))
             ((unless (and (consp subst)
                           (symbolp (car subst))
                           (alistp (cdr subst))))
              (add-bvar-constraint-substs (cdr substs) . ,*glcp-common-inputs*))
             ((cons thm alist) subst)
             (thm-body (acl2::meta-extract-formula thm state))
             ((unless (pseudo-termp thm-body))
              (add-bvar-constraint-substs (cdr substs) . ,*glcp-common-inputs*))
             ((mv new-constraint . ,(remove 'pathcond *glcp-common-retvals*))
              (b* (((acl2::local-stobjs pathcond)
                    (mv new-constraint . ,*glcp-common-retvals*))
                   (pathcond (bfr-hyp-init pathcond)))
                (interp-test thm-body alist nil . ,*glcp-common-inputs*)))
             ((when (eq er :intro-bvars-fail))
              (add-bvar-constraint-substs (cdr substs) . ,*glcp-common-inputs*))
             ((when er) (glcp-interp-abort er :nvals 0))
             ((mv ?contra upd-constraint &)
              (bfr-constr-assume new-constraint (is-constraint interp-st)))
             ;; BOZO What do we do with a contradiction at this point?
             ;; Maybe we can prove it's impossible?
             (interp-st (update-is-constraint upd-constraint interp-st)))
          (add-bvar-constraint-substs (cdr substs) . ,*glcp-common-inputs*)))


      (defun rewrite (fn actuals rwtype contexts . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (posp clk)
                                    (symbolp fn)
                                    (not (eq fn 'quote))
                                    (contextsp contexts)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 1212 0 0))
                 (ignorable rwtype))

        ;; (mv erp obligs1 successp term bindings bvar-db state)
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             (rules (cdr (hons-assoc-equal fn (table-alist 'gl-rewrite-rules (w state)))))
             ;; or perhaps we should pass the table in the obligs? see if this is
             ;; expensive
             ((unless (and rules (true-listp rules))) ;; optimization (important?)
              (glcp-value nil nil nil))
             (fn-rewrites (getprop fn 'acl2::lemmas nil 'current-acl2-world (w state))))
          (rewrite-apply-rules
           fn-rewrites rules fn actuals contexts . ,*glcp-common-inputs*)))


      (defun rewrite-apply-rules
        (fn-rewrites rules fn actuals contexts . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (true-listp rules)
                                    (posp clk)
                                    (symbolp fn)
                                    (not (eq fn 'quote))
                                    (contextsp contexts)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 88 (len fn-rewrites) 0)))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (atom fn-rewrites))
              ;; no more rules, fail
              (glcp-value nil nil nil))
             (rule (car fn-rewrites))
             ((unless (acl2::weak-rewrite-rule-p rule))
              (cw "malformed rewrite rule?? ~x0~%" rule)
              (rewrite-apply-rules
               (cdr fn-rewrites) rules fn actuals contexts . ,*glcp-common-inputs*))
             ((unless (member-equal (acl2::rewrite-rule->rune rule) rules))
              (rewrite-apply-rules
               (cdr fn-rewrites) rules fn actuals contexts . ,*glcp-common-inputs*))
             ((glcp-er successp term bindings :nvals 3)
              (rewrite-apply-rule
               rule fn actuals contexts . ,*glcp-common-inputs*))
             ((when successp)
              (glcp-value successp term bindings)))
          (rewrite-apply-rules
           (cdr fn-rewrites) rules fn actuals contexts . ,*glcp-common-inputs*)))

      (defun rewrite-apply-rule
        (rule fn actuals contexts . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (acl2::weak-rewrite-rule-p rule)
                                    (posp clk)
                                    (symbolp fn)
                                    (not (eq fn 'quote))
                                    (contextsp contexts)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 44 0 0)))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((rewrite-rule rule) rule)
             ((unless (and (symbolp rule.equiv)
                           (not (eq rule.equiv 'quote))
                           ;; (ensure-equiv-relationp rule.equiv (w state))
                           (not (eq rule.subclass 'acl2::meta))
                           (pseudo-termp rule.lhs)
                           (consp rule.lhs)
                           (eq (car rule.lhs) fn)))
              (cw "malformed gl rewrite rule (lhs)?? ~x0~%" rule)
              (glcp-value nil nil nil))
             ((unless (or (eq rule.equiv 'equal)
                          ;; bozo check refinements
                          (member rule.equiv contexts)))
              (glcp-value nil nil nil))
             ((mv unify-ok gobj-bindings)
              (glcp-unify-term/gobj-list (cdr rule.lhs) actuals nil))
             ((unless unify-ok) (glcp-value nil nil nil))
             ((unless (pseudo-term-listp rule.hyps))
              (cw "malformed gl rewrite rule (hyps)?? ~x0~%" rule)
              (glcp-value nil nil nil))
             ((glcp-er hyps-ok gobj-bindings :nvals 3)
              (relieve-hyps rule.rune rule.hyps gobj-bindings . ,*glcp-common-inputs*))
             ((unless hyps-ok) (glcp-value nil nil nil))
             ((unless (pseudo-termp rule.rhs))
              (cw "malformed gl rewrite rule (rhs)?? ~x0~%" rule)
              (glcp-value nil nil nil)))
          (glcp-value t rule.rhs gobj-bindings)))

      (defun relieve-hyps (rune hyps bindings . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (pseudo-term-listp hyps)
                                    (posp clk)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 22 (len hyps) 0))
                 (ignorable rune))
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (atom hyps)) (glcp-value t bindings))
             ((glcp-er ok bindings :nvals 2)
              (relieve-hyp rune (car hyps) bindings . ,*glcp-common-inputs*))
             ((when (not ok)) (glcp-value nil bindings)))
          (relieve-hyps rune (cdr hyps) bindings . ,*glcp-common-inputs*)))

      (defun relieve-hyp (rune hyp bindings . ,*glcp-common-inputs*)
        (declare (xargs :stobjs ,*glcp-stobjs*
                        :guard (and (pseudo-termp hyp)
                                    (posp clk)
                                    . ,*glcp-common-guards*)
                        :measure (list (pos-fix clk) 15 0 0))
                 (ignorable rune))
        ;; "Simple" version for now; maybe free variable bindings, syntaxp, etc later...
        (b* ((pathcond (lbfr-hyp-fix pathcond))
             ((when (and (consp hyp) (eq (car hyp) 'synp)))
              (b* (((mv erp successp bindings)
                    (glcp-relieve-hyp-synp hyp bindings state))
                   ((when erp) (glcp-interp-error
                                (if (eq erp t) "t" erp) :nvals 2)))
                (glcp-value successp bindings)))
             ((mv bfr . ,*glcp-common-retvals*)
              (interp-test hyp bindings nil . ,*glcp-common-inputs*))
             ((when (eq er :intro-bvars-fail))
              (glcp-value nil bindings))
             ((when er) (glcp-interp-abort er :nvals 2))
             ((when (eq bfr t))
              (glcp-value t bindings)))
          (glcp-value nil bindings)))

      (defun interp-list
        (x alist . ,*glcp-common-inputs*)
        (declare
         (xargs
          :measure (list (pos-fix clk) 2020 (acl2-count x) 20)
          :guard (and (natp clk)
                      (pseudo-term-listp x)
                      . ,*glcp-common-guards*)
          :stobjs ,*glcp-stobjs*))
        (b* ((pathcond (lbfr-hyp-fix pathcond)))
          (if (atom x)
              (glcp-value nil)
            (b* (((glcp-er car)
                  (interp-term-equivs (car x)
                                      alist nil . ,*glcp-common-inputs*))
                 ((glcp-er cdr)
                  (interp-list (cdr x)
                               alist . ,*glcp-common-inputs*)))
              (glcp-value (cons car cdr)))))))

     (defund interp-top-level-term
       (term alist . ,(subst 'pathcond-bfr 'pathcond *glcp-common-inputs*))
       (declare (xargs :guard (and (pseudo-termp term)
                                   (natp clk)
                                   . ,*glcp-common-guards*)
                       :stobjs ,(remove 'pathcond *glcp-stobjs*)
                       :verify-guards nil))
       (b* (((acl2::local-stobjs pathcond)
             (mv bfr-val . ,*glcp-common-retvals*))
            (config (glcp-config-update-term term config))
            (pathcond (bfr-hyp-init pathcond))
            ((mv contra pathcond ?undo) (bfr-assume pathcond-bfr pathcond))
            ((when contra)
             (cw "Path condition is unsatisfiable~%")
             (glcp-value nil)))
         (interp-test
          term alist t . ,*glcp-common-inputs*)))

     (defund interp-concl
       (term alist pathcond-bfr clk config interp-st bvar-db1 bvar-db state)
       (declare (xargs :guard (and (pseudo-termp term)
                                   (natp clk)
                                   . ,*glcp-common-guards*)
                       :stobjs (interp-st bvar-db bvar-db1 state)
                       :verify-guards nil))
       (b* ((al (gobj-alist-to-param-space alist pathcond-bfr))
            (bvar-db (init-bvar-db (base-bvar bvar-db1) bvar-db))
            (bvar-db (parametrize-bvar-db pathcond-bfr bvar-db1 bvar-db))
            ;;; NOTE: Need to add function to parametrize constraint alists and
            ;;; HYP absstobs
            ((mv contra constraint &)
             (bfr-constr-assume
              (bfr-to-param-space pathcond-bfr
                                  (bfr-constr->bfr
                                   (is-constraint interp-st)))
              (bfr-constr-init)))
            (constraint-db (parametrize-constraint-db pathcond-bfr
                                                      (is-constraint-db interp-st)))
            (config (glcp-config-update-param pathcond-bfr config))
            (interp-st (update-is-constraint constraint
                                             interp-st))
            (interp-st (update-is-constraint-db constraint-db interp-st))
            ((when contra)
             (cw "Constraints unsatisfiable~%")
             (glcp-value-nopathcond t))
            
            ((unless pathcond-bfr)
             (glcp-value-nopathcond t))
            (pathcond-bfr (bfr-to-param-space pathcond-bfr pathcond-bfr)))
         (interp-top-level-term
          term al . ,(subst 'pathcond-bfr 'pathcond *glcp-common-inputs*))))

     (defund interp-hyp/concl
       (hypo concl alist clk config interp-st next-bvar bvar-db bvar-db1 state)
       (declare (xargs :guard (and (pseudo-termp hypo)
                                   (pseudo-termp concl)
                                   (natp clk)
                                   . ,*glcp-common-guards*)
                       :stobjs (interp-st bvar-db bvar-db1 state)
                       :verify-guards nil))
       (b* ((bvar-db (init-bvar-db next-bvar bvar-db))
            (bvar-db1 (init-bvar-db next-bvar bvar-db1))
            (config (glcp-config-update-param t config))
            ((mv hyp-bfr . ,(remove 'pathcond *glcp-common-retvals*))
             (interp-top-level-term
              hypo alist . ,(subst t 'pathcond *glcp-common-inputs*)))
            ((when er)
             (mv hyp-bfr nil bvar-db1 . ,(remove 'pathcond *glcp-common-retvals*)))
            ((mv vac-check-sat vac-check-succeeded &)
             (if (glcp-config->check-vacuous config)
                 (bfr-sat hyp-bfr)
               (mv nil t nil)))
            ((when (and (glcp-config->abort-vacuous config)
                        (not vac-check-succeeded)))
             (mv hyp-bfr nil bvar-db1
                 "Vacuity check did not finish"
                 . ,(cddr *glcp-common-retvals*)))
            ((when (and (glcp-config->abort-vacuous config)
                        (not vac-check-sat)))
             (mv hyp-bfr nil bvar-db1
                 "Hypothesis is not satisfiable"
                 . ,(cddr *glcp-common-retvals*)))
            (- (and (not vac-check-succeeded)
                    (cw "Note: vacuity check did not finish~%")))
            (- (and (not vac-check-sat)
                    (cw "Note: hypothesis is not satisfiable~%")))
            ((mv concl-bfr .
                 ,(subst 'bvar-db1 'bvar-db
                         (remove 'pathcond *glcp-common-retvals*)))
             (interp-concl
              concl alist hyp-bfr clk config interp-st bvar-db bvar-db1 state)))
         (mv hyp-bfr concl-bfr bvar-db1 . ,(remove 'pathcond *glcp-common-retvals*))))

     ;; almost-user-level wrapper
     (defun interp-term-under-hyp (hypo term al next-bvar config interp-st bvar-db bvar-db1 state)
       (declare (xargs :stobjs (interp-st bvar-db bvar-db1 state)
                       :verify-guards nil))
       (b* ((bvar-db (init-bvar-db next-bvar bvar-db))
            (bvar-db1 (init-bvar-db next-bvar bvar-db1))
            (interp-st (update-is-obligs nil interp-st))
            (interp-st (update-is-constraint (bfr-constr-init) interp-st))
            (interp-st (update-is-constraint-db (table-alist
                                                 'gl-bool-constraints (w state))
                                                interp-st))
            ((mv hyp-bfr . ,(remove 'pathcond *glcp-common-retvals*))
             (interp-top-level-term
              hypo al t (glcp-config->hyp-clk config) config interp-st bvar-db
              state))
            ((when er) (mv nil nil nil er interp-st bvar-db bvar-db1 state))
            (param-al (gobj-alist-to-param-space al hyp-bfr))
            (bvar-db1 (parametrize-bvar-db hyp-bfr bvar-db bvar-db1))
            (config (glcp-config-update-param hyp-bfr config))
            (hyp-bfr (bfr-to-param-space hyp-bfr hyp-bfr))
            ((mv res-obj . ,(subst 'bvar-db1 'bvar-db
                                   (remove 'pathcond *glcp-common-retvals*)))
             (interp-top-level-term
              term param-al hyp-bfr (glcp-config->concl-clk config) config
              interp-st bvar-db1 state)))
         (mv hyp-bfr param-al res-obj er interp-st bvar-db bvar-db1 state)))))


#||

"GL"
(trace$ (glcp-rewrite-fncall-apply-rule
         :cond (b* (((rewrite-rule rule) rule)
                    ((unless (eq (cadr rule.rune) 'logand-of-logapp))
                     nil)
                    ((unless (and (eq rule.equiv 'equal)
                                  (not (eq rule.subclass 'acl2::meta))
                                  (pseudo-termp rule.lhs)
                                  (consp rule.lhs)
                                  (eq (car rule.lhs) fn)))
                     (cw "malformed gl rewrite rule (lhs)?? ~x0~%" rule))
                    ((mv unify-ok ?gobj-bindings)
                     (glcp-unify-term/gobj-list (cdr rule.lhs) actuals nil)))
                 unify-ok)))


||#

(defconst *glcp-clause-proc-template*
  `(progn
     (defun run-parametrized
       (hyp concl vars bindings id obligs config state)
       (b* ((bound-vars (strip-cars bindings))
            ((glcp-config config) config)
            ((er hyp)
             (if (pseudo-termp hyp)
                 (let ((hyp-unbound-vars
                        (set-difference-eq (collect-vars hyp)
                                           bound-vars)))
                   (if hyp-unbound-vars
                       (prog2$ (flush-hons-get-hash-table-link obligs)
                               (glcp-error (acl2::msg "~
In ~@0: The hyp contains the following unbound variables: ~x1~%"
                                                      id hyp-unbound-vars)))
                     (value hyp)))
               (glcp-error "The hyp is not a pseudo-term.~%")))
            ((unless (shape-spec-bindingsp bindings))
             (flush-hons-get-hash-table-link obligs)
             (glcp-error
              (acl2::msg "~
In ~@0: the bindings don't satisfy shape-spec-bindingsp: ~x1"
                         id bindings)))
            (obj (strip-cadrs bindings))
            ((unless (and (acl2::fast-no-duplicatesp (shape-spec-list-indices obj))
                          (acl2::fast-no-duplicatesp-equal (shape-spec-list-vars obj))))
             (flush-hons-get-hash-table-link obligs)
             (glcp-error
              (acl2::msg "~
In ~@0: the indices or variables contain duplicates in bindings ~x1"
                         id bindings)))
            ((unless (subsetp-equal vars bound-vars))
             (flush-hons-get-hash-table-link obligs)
             (glcp-error
              (acl2::msg "~
In ~@0: The conclusion countains the following unbound variables: ~x1~%"
                         id (set-difference-eq vars bound-vars))))
            (constraint-db (gbc-db-make-fast
                            (table-alist 'gl-bool-constraints (w state))))
            ((unless (gbc-db-emptyp constraint-db))
             (flush-hons-get-hash-table-link obligs)
             (gbc-db-free constraint-db)
             (glcp-error
              (acl2::msg "The constraint database stored in the table ~
                          GL::GL-BOOL-CONSTRAINTS contains nonempty ~
                          substitutions -- somehow it has gotten corrupted!~%")))
            (config (change-glcp-config config :shape-spec-alist bindings))
            (al (shape-specs-to-interp-al bindings))
            (cov-clause
             (list '(not (gl-cp-hint 'coverage))
                   (dumb-negate-lit hyp)
                   (shape-spec-list-oblig-term
                    obj
                    (strip-cars bindings))))
            ((acl2::local-stobjs bvar-db bvar-db1 interp-st)
             (mv erp val state bvar-db bvar-db1 interp-st))
            (interp-st (update-is-obligs obligs interp-st))
            (interp-st (update-is-constraint (bfr-constr-init) interp-st))
            (interp-st (update-is-constraint-db constraint-db interp-st))
            (next-bvar (shape-spec-max-bvar-list (strip-cadrs bindings)))
            ((mv hyp-bfr concl-bfr bvar-db1 . ,(remove 'pathcond *glcp-common-retvals*))
             (interp-hyp/concl
              hyp concl al config.concl-clk  config interp-st next-bvar bvar-db
              bvar-db1 state))
            ((when er)
             (flush-hons-get-hash-table-link (is-obligs interp-st))
             (gbc-db-free (is-constraint-db interp-st))
             (mv er nil state bvar-db bvar-db1 interp-st))
            ((mv erp val-clause state)
             (glcp-analyze-interp-result
              hyp-bfr concl-bfr (bfr-constr->bfr (is-constraint interp-st))
              bindings id concl config bvar-db1 state))
            ((when erp)
             (flush-hons-get-hash-table-link (is-obligs interp-st))
             (gbc-db-free (is-constraint-db interp-st))
             (mv erp nil state bvar-db bvar-db1 interp-st))
            ((mv erp val state)
             (value (list val-clause cov-clause (is-obligs interp-st)))))
         (gbc-db-free (is-constraint-db interp-st))
         (mv erp val state bvar-db bvar-db1 interp-st)))

     ;; abort-unknown abort-ctrex exec-ctrex abort-vacuous nexamples hyp-clk concl-clk
     ;; clause-proc-name overrides  run-before run-after case-split-override


     ,'(defun run-cases
         (param-alist concl vars obligs config state)
         (if (atom param-alist)
             (value (cons nil obligs))
           (b* (((er (cons rest obligs))
                 (run-cases
                  (cdr param-alist) concl vars obligs config state))
                (hyp (caar param-alist))
                (id (cadar param-alist))
                (g-bindings (cddar param-alist))
                (- (glcp-cases-wormhole (glcp-config->run-before config) id))
                ((er (list val-clause cov-clause obligs))
                 (run-parametrized
                  hyp concl vars g-bindings id obligs config state))
                (- (glcp-cases-wormhole (glcp-config->run-after config) id)))
             (value (cons (list* val-clause cov-clause rest) obligs)))))


     ,'(defun clause-proc (clause hints state)
         (b* (;; ((unless (sym-counterparts-ok (w state)))
              ;;  (glcp-error "The installed symbolic counterparts didn't satisfy all our checks"))
              ((list bindings param-bindings hyp param-hyp concl ?untrans-concl config) hints)
              ((er overrides)
               (preferred-defs-to-overrides
                (table-alist 'preferred-defs (w state)) state))
              (config (change-glcp-config config :overrides overrides))
              ((er hyp)
               (if (pseudo-termp hyp)
                   (value hyp)
                 (glcp-error "The hyp is not a pseudo-term.~%")))
              (hyp-clause (cons '(not (gl-cp-hint 'hyp))
                                (append clause (list hyp))))
              ((er concl)
               (if (pseudo-termp concl)
                   (value concl)
                 (glcp-error "The concl is not a pseudo-term.~%")))
              (concl-clause (cons '(not (gl-cp-hint 'concl))
                                  (append clause (list (list 'not concl))))))
           (if param-bindings
               ;; Case splitting.
               (b* (((er param-hyp)
                     (if (pseudo-termp param-hyp)
                         (value param-hyp)
                       (glcp-error "The param-hyp is not a pseudo-term.~%")))
                    (full-hyp (conjoin (list param-hyp hyp)))
                    (param-alist (param-bindings-to-alist
                                  full-hyp param-bindings))
                    ;; If the hyp holds, then one of the cases in the
                    ;; param-alist holds.
                    (params-cov-term (disjoin (strip-cars param-alist)))
                    (params-cov-vars (collect-vars params-cov-term))
                    (- (cw "Checking case split coverage ...~%"))
                    ((er (list params-cov-res-clause
                               params-cov-cov-clause obligs0))
                     (if (glcp-config->case-split-override config)
                         (value (list `((not (gl-cp-hint 'casesplit))
                                        (not ,hyp)
                                        ,params-cov-term)
                                      '('t)
                                      'obligs))
                       (run-parametrized
                        hyp params-cov-term params-cov-vars bindings
                        "case-split coverage" 'obligs config state)))
                    (- (cw "Case-split coverage OK~%"))
                    ((er (cons cases-res-clauses obligs1))
                     (run-cases
                      param-alist concl (collect-vars concl) obligs0 config state)))
                 (clear-memoize-table 'glcp-get-branch-merge-rules)
                 (value (list* hyp-clause concl-clause
                               (append cases-res-clauses
                                       (list* params-cov-res-clause
                                              params-cov-cov-clause
                                              (acl2::interp-defs-alist-clauses
                                               (flush-hons-get-hash-table-link obligs1)))))))
             ;; No case-splitting.
             (b* (((er (list res-clause cov-clause obligs))
                   (run-parametrized
                    hyp concl (collect-vars concl) bindings
                    "main theorem" nil config state)))
               (cw "GL symbolic simulation OK~%")
               (clear-memoize-table 'glcp-get-branch-merge-rules)
               (value (list* hyp-clause concl-clause
                             res-clause cov-clause
                             (acl2::interp-defs-alist-clauses
                              (flush-hons-get-hash-table-link obligs))))))))))


(defconst *glcp-fnnames*
  (event-forms-collect-fn-names (list *glcp-interp-template*
                                      *glcp-clause-proc-template*)))
