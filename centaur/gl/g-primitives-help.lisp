

(in-package "GL")

(include-book "tools/flag" :dir :system)
(include-book "gl-util")
(include-book "bvar-db")
(include-book "glcp-config")

(program)


;; (defun gobjectp-formals-list (formals)
;;   (if (Atom formals)
;;       nil
;;     (cons `(gobjectp ,(car formals))
;;           (gobjectp-formals-list (cdr formals)))))

(defun acl2-count-formals-list (formals)
  (if (atom formals)
      nil
    (cons `(acl2-count ,(car formals))
          (acl2-count-formals-list (cdr formals)))))

;; (defun mbe-gobj-fix-formals-list (formals)
;;   (if (atom formals)
;;       nil
;;     (cons `(,(car formals) (mbe :logic (gobj-fix ,(car formals))
;;                                 :exec ,(car formals)))
;;           (mbe-gobj-fix-formals-list (cdr formals)))))

(defmacro def-g-fn (fn body &key measure)
  `(make-event
    (b* ((gfn (gl-fnsym ',fn))
         (world (w state))
         (formals (wgetprop ',fn 'formals))
         (params '(hyp clk config bvar-db state))
         (measure (or ',measure `(+ . ,(acl2-count-formals-list
                                        formals)))))
      `(progn
         (defun ,gfn (,@formals hyp clk config bvar-db state)
           (declare (xargs :guard (and (natp clk)
                                       (glcp-config-p config))
                           :measure ,measure
                           :verify-guards nil
                           :stobjs (bvar-db state))
                    (ignorable ,@formals . ,params))
             ,,body)
         (table g-functions ',',fn ',gfn)))))

(defmacro def-g-binary-op (fn body)
  `(make-event
    (let* ((fn ',fn)
           (world (w state))
           (formals (wgetprop ',fn 'formals))
           (a (car formals))
           (b (cadr formals)))
      `(def-g-fn ,fn
         (let ((a ',a) (b ',b) (fn ',fn))
           `(cond ((and (general-concretep ,a) (general-concretep ,b))
                   (mk-g-concrete
                    (ec-call (,fn (general-concrete-obj ,a)
                                  (general-concrete-obj ,b)))))
                  ((or (atom ,a)
                       (not (member-eq (tag ,a) '(:g-ite :g-var :g-apply))))
                   (cond ((or (atom ,b)
                              (not (member-eq (tag ,b) '(:g-ite :g-var :g-apply))))
                          ,',',body)
                         ((eq (tag ,b) :g-ite)
                          (if (zp clk)
                              (g-apply ',fn (gl-list ,a ,b))
                            (let* ((test (g-ite->test ,b))
                                   (then (g-ite->then ,b))
                                   (else (g-ite->else ,b)))
                              (g-if test
                                    (,gfn ,a then hyp clk config bvar-db state)
                                    (,gfn ,a else hyp clk config bvar-db state)))))
                         (t (g-apply ',fn (gl-list ,a ,b)))))
                  ((eq (tag ,a) :g-ite)
                   (if (zp clk)
                       (g-apply ',fn (gl-list ,a ,b))
                     (let* ((test (g-ite->test ,a))
                            (then (g-ite->then ,a))
                            (else (g-ite->else ,a)))
                       (g-if test
                             (,gfn then ,b hyp clk config bvar-db state)
                             (,gfn else ,b hyp clk config bvar-db state)))))
                  (t (g-apply ',fn (gl-list ,a ,b)))))))))

;; (defun gobjectp-thmname (fn)
;;   (incat 'gl-thm::foo "GOBJECTP-" (symbol-name fn)))


(defun correct-thmname (fn)
  (incat 'gl-thm::foo (symbol-name fn) "-CORRECT"))

;; (defun correct-thmname-appalist (fn)
;;   (incat 'gl-thm::foo (symbol-name fn) "-CORRECT-APPALIST"))

(defun correct1-thmname (fn)
  (incat 'gl-thm::foo (symbol-name fn) "-CORRECT1"))

;; (defun gobj-fix-thmname (fn)
;;   (incat 'gl-thm::foo (symbol-name fn) "-GOBJ-FIX"))

;; (defun def-gobjectp-thm-fn (gfn fn hints world)
;;   (b* ((formals (wgetprop fn 'formals))
;;        (thmname (gobjectp-thmname gfn)))
;;     `(progn
;;        (defthm ,thmname
;;          (gobjectp (,gfn ,@formals hyp clk config bvar-db state))
;;          :hints ,hints)
;;        (add-to-ruleset! g-gobjectp-lemmas '(,thmname)))))


;; (defmacro def-gobjectp-thm (fn &key hints)
;;   `(make-event
;;     (let ((gfn (gl-fnsym ',fn)))
;;       (def-gobjectp-thm-fn gfn ',fn ,hints (w state)))))


(defun ev-formals-list (ev formals)
  (declare (xargs :mode :logic
                  :guard t))
  (if (atom formals)
      nil
    (cons `(,ev ,(car formals) env)
          (ev-formals-list ev (cdr formals)))))

;; (defun ev-formals-appalist-list (ev formals aps)
;;   (declare (xargs :mode :logic
;;                   :guard t))
;;   (if (atom formals)
;;       nil
;;     (cons `(,ev ,(car formals) env ,aps)
;;           (ev-formals-appalist-list ev (cdr formals) aps))))

;; (defun gobj-fix-formals-list (formals)
;;   (if (atom formals)
;;       nil
;;     (cons `(gobj-fix ,(car formals))
;;           (gobj-fix-formals-list (cdr formals)))))

;; (defun pair-gobj-fix-formals-list (formals)
;;   (if (atom formals)
;;       nil
;;     (cons `(,(car formals) (gobj-fix ,(car formals)))
;;           (pair-gobj-fix-formals-list (cdr formals)))))

(defun def-g-correct-thm-fn (gfn fn ev hints world)
  (b* ((formals (wgetprop fn 'formals))
       (thmname (correct-thmname gfn))
       ;;(thmname2 (correct-thmname-appalist gfn))
       ;; (ev-appalist
       ;;  (cadr (assoc ev (table-alist 'eval-g-table world))))
       )
    `(encapsulate nil
       (defthm ,thmname
         (implies (bfr-eval hyp (car env))
                  (equal (,ev (,gfn ,@formals hyp clk config bvar-db state) env)
                         (,fn . ,(ev-formals-list ev formals))))
         :hints ,hints)
       (in-theory (disable ,gfn))
       ;; (defthm ,thmname2
       ;;   (implies (bfr-eval hyp (car env))
       ;;            (equal (,ev-appalist (,gfn ,@formals hyp clk config bvar-db state) env appalist)
       ;;                   (,fn . ,(ev-formals-appalist-list ev-appalist formals
       ;;                                                     'appalist))))
       ;;   :hints ((geval-appalist-functional-inst-hint
       ;;            ',thmname ',ev)))
                              
       (table sym-counterparts-table ',fn '(,gfn ,thmname))
       (table gl-function-info ',fn '(,gfn (,thmname . ,ev))))))

(defun def-g-correct-thm-macro (fn ev hints)
  `(make-event
    (b* ((fn ',fn)
         (gfn (gl-fnsym fn))
         (world (w state))
         (formals (wgetprop fn 'formals))
         (params '(hyp clk config bvar-db state))
         (?gcall (cons gfn
                      (append formals params)))
         (?fcall (cons fn formals)))
      (def-g-correct-thm-fn gfn ',fn ',ev ,hints (w state)))))

(defmacro def-g-correct-thm (fn ev &key hints)
  (def-g-correct-thm-macro fn ev hints))


(defmacro verify-g-guards (fn &key hints)
  `(make-event
    (let ((gfn (gl-fnsym ',fn)))
      `(verify-guards ,gfn :hints ,,hints))))


(defun not-gobj-depends-on-hyps (formals)
  (if (atom formals)
      nil
    (cons `(not (gobj-depends-on badvar parambfr ,(car formals)))
          (not-gobj-depends-on-hyps (cdr formals)))))

(defun dependency-thmname (fn)
  (incat 'gl-thm::foo (symbol-name fn) "-DEPENDENCIES"))

(defun def-gobj-dependency-thm-fn (gcall fn hints world)
  (b* ((formals (wgetprop fn 'formals))
       (thmname (dependency-thmname fn)))
    `(encapsulate nil
       (defthm ,thmname
         (implies (and . ,(not-gobj-depends-on-hyps formals))
                  (not (gobj-depends-on badvar parambfr ,gcall)))
         :hints ,hints)
       (table sym-counterpart-dep-thms ',fn ',thmname))))

(defun def-gobj-dependency-thm-macro (fn hints)
  `(make-event
    (b* ((fn ',fn)
         (gfn (gl-fnsym fn))
         (world (w state))
         (formals (wgetprop fn 'formals))
         (params '(hyp clk config bvar-db state))
         (gcall (cons gfn
                      (append formals params))))
      (def-gobj-dependency-thm-fn gcall ',fn ,hints (w state)))))

(defmacro def-gobj-dependency-thm (fn &key hints)
  (def-gobj-dependency-thm-macro fn hints))
