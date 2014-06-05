(in-package "ACL2")

(defmacro defderivative-error (fmt &rest args)
  `(er hard 'defderivative ,fmt ,@args))

(defmacro defderivative-fns (invocation wrt)
  (cond ((or (not (symbol-listp invocation))
             (endp invocation))
         (defderivative-error "First argument must be a function invocation of the form (FN ARG1 ARG2 ... ARGN)"))
        ((not (symbolp wrt))
         (defderivative-error "Cannot differential with respect to ~x0." wrt))
        ((not (member-equal wrt invocation))
         (defderivative-error "~x0 must be an argument of ~x1" wrt invocation))
        (t
         (let* ((fn (first invocation))
                (name-base (symbol-name fn))
                (args (rest invocation))
                (difference-fn (intern (string-append name-base "-DIFFERENCE") "ACL2"))
                (differential-fn (intern (string-append name-base "-DIFFERENTIAL") "ACL2"))
                (derivative-fn (intern (string-append name-base "-DERIVATIVE-NONSTD") "ACL2")))
           `(progn
             (defun ,difference-fn (,@args eps)
               (- (,@(subst (list '+ wrt 'eps) wrt invocation))
                  (,@invocation)))
             (defun ,differential-fn (,@args eps)
               (/ (,difference-fn ,@args eps)
                  eps))
             
             (defun ,derivative-fn (,@args)
               (standard-part (,differential-fn ,@args (/ (i-large-integer))))))))))
    