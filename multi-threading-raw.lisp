; ACL2 Version 4.2 -- A Computational Logic for Applicative Common Lisp
; Copyright (C) 2011  University of Texas at Austin

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic NOTE-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

; Written by:  Matt Kaufmann               and J Strother Moore
; email:       Kaufmann@cs.utexas.edu      and Moore@cs.utexas.edu
; Department of Computer Science
; University of Texas at Austin
; Austin, TX 78701 U.S.A.

; We thank David L. Rager for contributing an initial version of this file.

; This file is divided into the following sections.

; Section:  Enabling and Disabling Interrupts
; Section:  Multi-Threading Interface
; Section:  Multi-Threading Utility Functions and Macros
; Section:  Multi-Threading Constants

(in-package "ACL2")

; For readability we use #+sb-thread" instead of #+(and sbcl sbl-thread).  We
; therefore make the following check to ensure that these two readtime
; conditionals are equivalent.

#+(and (not sbcl) sb-thread)
(error "Feature sb-thread not supported on Lisps other than SBCL")

;---------------------------------------------------------------------
; Section:  Enabling and Disabling Interrupts

; "Without-interrupts" means that there will be no interrupt from the Lisp
; system, including ctrl+c from the user or an interrupt from another
; thread/process.  For example, if *thread1* is running (progn
; (without-interrupts (process0)) (process1)), then execution of
; (interrupt-thread *thread1* (lambda () (break))) will not interrupt
; (process0).

; But note that "without-interrupts" does not guarantee atomicity; for example,
; it does not mean "without-setq".

(defmacro without-interrupts (&rest forms)

; This macro prevents interrupting evaluation of any of the indicated forms in
; a parallel lisp.  In a non-parallel environment (#-(or ccl sb-thread)),
; we simply evaluate the forms.  This behavior takes priority over any
; enclosing call of with-interrupts.  Since we do not have a good use case for
; providing with-interrupts, we omit it from this interface.

  #+ccl
  `(ccl:without-interrupts ,@forms)
  #+sb-thread
  `(sb-sys:without-interrupts ,@forms)
  #+lispworks

; Lispworks decided to remove "without-interrupts" from their system, because
; its use has changed from meaning "atomic" to meaning "can't be interrupted by
; other threads or processes".  Thus, we use the new primitive,
; "with-interrupts-blocked".

  `(mp:with-interrupts-blocked ,@forms)
  #-(or ccl sb-thread lispworks)
  `(progn ,@forms))

(defmacro unwind-protect-disable-interrupts-during-cleanup
  (body-form &rest cleanup-forms)

; As the name suggests, this is unwind-protect but with a guarantee that
; cleanup-form cannot be interrupted.  Note that CCL's implementation already
; disables interrupts during cleanup.

  #+ccl
  `(unwind-protect ,body-form ,@cleanup-forms)
  #+sb-thread
  `(unwind-protect ,body-form (without-interrupts ,@cleanup-forms))
  #+lispworks
  `(hcl:unwind-protect-blocking-interrupts-in-cleanups ,body-form
                                                       ,@cleanup-forms)
  #-(or ccl sb-thread lispworks)
  `(unwind-protect ,body-form ,@cleanup-forms))

;---------------------------------------------------------------------
; Section:  Threading Interface
;
; The threading interface is intended for system level programmers.  It is not
; intended for the ACL2 user.  When writing system-level multi-threaded code,
; we use implementation-independent interfaces.  If you need a function not
; covered in this interface, create the interface!

; Many of the functions in this interface (lockp, make-lock, and so on) are not
; used elsewhere, but are included here in case we find a use for them later.

; We take a conservative approach for implementations that do not support
; parallelism.  For example, if the programmer asks for a semaphore or lock in
; an unsupported Lisp, then nil is returned.

; We employ counting semaphores.  For details, including a discussion of
; ordering, see comments in the definition of function make-semaphore.

; Note: We use parts of the threading interface for our implementation of the
; parallelism primitives.

#+sb-thread
(defstruct (atomically-modifiable-counter
            (:constructor make-atomically-modifiable-counter-raw))

; SBCL has an atomic increment and decrement interface.  In all small tests,
; this interface works well.  However, when we use this interface to
; parallelize the waterfall of ACL2, it doesn't work.  The observable bug that
; we find is that our Fixnum number is decremented too much (so it becomes -1,
; which is a really large non-negative fixnum).  Rather than sort out the cause
; of this bug, we simply revert to using locks in SBCL.  However, we leave the
; code that implements the use of these atomic increments and decrements.  This
; achieves two things: (1) The code is there if we decide we want to use it
; again later (maybe after reading on the SBCL email lists that a bug with
; these atomic operations was fixed) and (2) We will have an on-going record of
; the code that causes us to observe this bug (note that ACL2 4.2 also contains
; the implementation that uses atomic operations).  Maybe someone will be able
; to tell us what we are doing wrong.

  (val 0 ; :type (unsigned-byte #+x86-64 64 #-x86-64 32)
       )
  (lock (sb-thread:make-mutex :name "counter lock")))

(defun make-atomically-modifiable-counter (initial-value)
  #+ccl
  initial-value
  #+sb-thread
  (make-atomically-modifiable-counter-raw :val initial-value)
  #+lispworks
  initial-value
  #-(or ccl sb-thread lispworks)
  initial-value)

(defmacro define-atomically-modifiable-counter (name initial-value)
  `(defvar ,name (make-atomically-modifiable-counter ,initial-value)))

(defmacro atomically-modifiable-counter-read (counter)
  #+ccl
  counter
  #+sb-thread
  `(atomically-modifiable-counter-val ,counter)
  #+lispworks
  counter
  #-(or ccl sb-thread lispworks)
  counter)

(defmacro atomic-incf (x)

; Warning: CCL and SBCL return different values for atomic-incf.  As of Oct
; 2009, CCL returns the new value, but SBCL returns the old value.  We
; artificially add one to the SBCL return value to make them consistent.  Both
; the CCL maintainer Gary Byers and the SBCL community have confirmed the
; return value of atomic-incf/decf to be reliable.

  #+ccl
  `(ccl::atomic-incf ,x)
  #+sb-thread
;  `(progn ; (sb-debug:backtrace) 
;          (1+ (sb-ext:atomic-incf
;               (atomically-modifiable-counter-val ,x))))

; Parallelism wart: why is nil used in the call to with-recursive-lock?

  `(sb-thread:with-recursive-lock ((atomically-modifiable-counter-lock ,x)) nil
                                  (incf (atomically-modifiable-counter-val ,x)))
  #+lispworks
  `(system:atomic-incf ,x)
  #-(or ccl sb-thread lispworks)
  `(incf ,x))


(defmacro atomic-incf-multiple (counter count)

; Warning: CCL and SBCL return different values for atomic-incf.  As of Oct
; 2009, CCL returns the new value, but SBCL returns the old value.  We
; artificially add one to the SBCL return value to make them consistent.  Both
; the CCL maintainer Gary Byers and the SBCL community have confirmed the
; return value of atomic-incf/decf to be reliable.  According to the Lispworks
; documentation, Lispworks returns the new value.

  #+ccl
  `(without-interrupts (dotimes (i ,count) (ccl::atomic-incf ,counter)))
  #+sb-thread
;  `(+ (sb-ext:atomic-incf 
;       (atomically-modifiable-counter-val ,counter) ,count)
;      ,count)
  `(sb-thread:with-recursive-lock ((atomically-modifiable-counter-lock ,counter)) nil
                                  (incf (atomically-modifiable-counter-val ,counter) ,count))
  #+lispworks
  `(system:atomic-incf ,counter ,count)
  #-(or ccl sb-thread lispworks)
  `(incf ,counter ,count))

(defmacro atomic-decf (x)

; Warning: CCL and SBCL return different values for atomic-incf.  As of Oct
; 2009, CCL returns the new value, but SBCL returns the old value.  We
; artificially subtract one from the SBCL return value to make them consistent.
; Both the CCL maintainer Gary Byers and the SBCL community have confirmed the
; return value of atomic-incf/decf to be reliable.

  #+ccl
  `(ccl::atomic-decf ,x)
  #+sb-thread
;  `(let ((ret-val (1- (sb-ext::atomic-decf (atomically-modifiable-counter-val
;                                            ,x) 1))))
;     (when (> ret-val 999999999999)
;       (print "Warning: resetting atomically modifiable counter to 0")
;       (setf ,x (make-atomically-modifiable-counter-raw :val 0)))
;     0)
  `(sb-thread:with-recursive-lock ((atomically-modifiable-counter-lock ,x)) nil
                                  (decf (atomically-modifiable-counter-val ,x)))
  #+lispworks
  `(system:atomic-decf ,x)
  #-(or ccl sb-thread lispworks)
  `(decf ,x))

(defun lockp (x)
  #+ccl (cl:typep x 'ccl::recursive-lock)
  #+sb-thread (cl:typep x 'sb-thread::mutex)
  #+lispworks (cl:typep x 'mp:lock)
  #-(or ccl sb-thread lispworks)

; We return nil in the uni-threaded case in order to stay in sync with
; make-lock, which returns nil in this case.  In a sense, we want (lockp
; (make-lock x)) to be a theorem if there is no error.

  (null x))

(defun make-lock (&optional lock-name)

; See also deflock.

; Even though CCL nearly always uses a FIFO for threads blocking on a lock,
; it does not guarantee so: no such promise is made by the CCL
; documentation or implementor (in fact, we are aware of a race condition that
; would violate FIFO properties for locks).  Thus, we make absolutely no
; guarantees about ordering; for example, we do not guarantee that the
; longest-blocked thread for a given lock is the one that would enter a
; lock-guarded section first.  However, we suspect that this is usually the
; case for most implementations, so assuming such an ordering property is
; probably a reasonable heuristic.  We would be somewhat surprised to find
; significant performance problems in our own application to ACL2's parallelism
; primitives due to the ordering provided by the underlying system.

  #-(or ccl sb-thread lispworks)
  (declare (ignore lock-name))
  #+ccl (ccl:make-lock lock-name)
  #+sb-thread (sb-thread:make-mutex :name lock-name)
  #+lispworks (mp:make-lock :name lock-name)
  #-(or ccl sb-thread lispworks)

; We return nil in the uni-threaded case in order to stay in sync with lockp.

  nil)

(defmacro deflock (lock-symbol)

; Deflock defines what some Lisps call a "recursive lock", namely a lock that
; can be grabbed more than once by the same thread, but such that if a thread
; outside the owner tries to grab it, that thread will block.

; Note that if lock-symbol is already bound, then deflock will not re-bind
; lock-symbol.

; Parallelism wart: this could also define #+acl2-par wrappers.

  `(defvar ,lock-symbol
     (make-lock (symbol-name ',lock-symbol))))

(defmacro reset-lock (bound-symbol)

; This macro binds the given global (but not necessarily special) variable to a
; lock that is new, at least from a programmer's perspective.

; Reset-lock should only be applied to bound-symbol if deflock has previously
; been applied to bound-symbol.

  `(setq ,bound-symbol (make-lock ,(symbol-name bound-symbol))))

(defmacro with-lock (bound-symbol &rest forms)

; Grab the lock, blocking until it is acquired; evaluate forms; and then
; release the lock.  This macro guarantees mutual exclusion.

  #-(or ccl sb-thread lispworks)
  (declare (ignore bound-symbol))
  (let ((forms

; We ensure that forms is not empty because otherwise, in CCL alone,
; (with-lock some-lock) evaluates to t.  We keep the code simple and consistent
; by modifying forms here for all cases, not just CCL.

         (or forms '(nil))))
    #+ccl
    `(ccl:with-lock-grabbed (,bound-symbol) nil ,@forms)
    #+sb-thread
    `(sb-thread:with-recursive-lock (,bound-symbol) nil ,@forms)
    #+lispworks
    `(mp:with-lock (,bound-symbol) nil ,@forms)

; Parallelism wart: we could define deflock to also define with-lock 
; accessors (e.g., "with-output-lock").

    #-(or ccl sb-thread lispworks)
    `(progn ,@forms)))

(defun run-thread (name fn-symbol &rest args)

; Apply fn-symbol to args.  We follow the precedent set by LISP machines (and
; in turn CCL), which allowed the user to spawn a thread whose initial
; function receives an arbitrary number of arguments.

; We expect this application to occur in a fresh thread with the given name.
; When a call of this function returns, we imagine that this fresh thread can
; be garbage collected; at any rate, we don't hang on to it!

; Note that run-thread returns different types in different Lisps.

; A by-product of our use of lambdas is that fn-symbol doesn't have to be a
; function symbol.  It's quite fine to call run-thread with a lambda, e.g.
;
; (run-thread "hello" (lambda () (print "hi")))
;
; A more sophisticated version of run-thread would probably check whether
; fn-symbol was indeed a symbol and only create a new lambda if it was.

  #-(or ccl sb-thread lispworks)
  (declare (ignore name))
  #+ccl
  (ccl:process-run-function name (lambda () (apply fn-symbol args)))
  #+sb-thread
  (sb-thread:make-thread (lambda () (apply fn-symbol args)) :name name)
  #+lispworks
  (mp:process-run-function name nil (lambda () (apply fn-symbol args)))

; We're going to be nice and let the user's function still run, even though
; it's not split off.

  #-(or ccl sb-thread lispworks)
  (apply fn-symbol args))

(defun interrupt-thread (thread function &rest args)

; Interrupt the indicated thread and then, in that thread, apply function to
; args.  Note that function and args are all evaluated.  When this function
; application returns, the thread resumes from the interrupt (from where it
; left off).

  #-(or ccl sb-thread lispworks)
  (declare (ignore thread function args))
  #+ccl
  (apply #'ccl:process-interrupt thread function args)
  #+sb-thread
  (if args
      (error "Passing arguments to interrupt-thread not supported in SBCL.")
    (sb-thread:interrupt-thread thread function))
  #+lispworks
  (apply #'mp:process-interrupt thread function args)
  #-(or ccl sb-thread lispworks)
  nil)

(defun kill-thread (thread)
  #-(or ccl sb-thread lispworks)
  (declare (ignore thread))
  #+ccl
  (ccl:process-kill thread)
  #+sb-thread
  (sb-thread:terminate-thread thread)
  #+lispworks
  (mp:process-kill thread)
  #-(or ccl sb-thread lispworks)
  nil)

(defun all-threads ()
  #+ccl
  (ccl:all-processes)
  #+sb-thread
  (sb-thread:list-all-threads)
  #+lispworks
  (mp:list-all-processes)
  #-(or ccl sb-thread lispworks)
  (error "We don't know how to list threads in this Lisp."))

(defun current-thread ()
  #+ccl
  ccl:*current-process*
  #+sb-thread
  sb-thread:*current-thread*
  #+lispworks
  mp:*current-process*
  #-(or ccl sb-thread lispworks)
  nil)

(defun thread-wait (fn &rest args)

; Thread-wait provides an inefficient mechanism for the current thread to wait
; until a given condition, defined by the application of fn to args, is true.
; When performance matters, we advise using a signaling mechanism instead of
; this relatively highly-latent function.

  #+ccl
  (apply #'ccl:process-wait "Asynchronously waiting on a condition" fn args)
  #+lispworks
  (apply #'mp:process-wait "Asynchronously waiting on a condition" fn args)
  #-(or ccl lispworks)
  (loop while (not (apply fn args)) do (sleep 0.05)))

#+(or sb-thread lispworks)
(defmacro with-potential-timeout (body &key timeout)

; There is no implicit progn for the body argument.  This is different from
; sb-sys:with-deadline, but we figure the simplicity is more valuable than
; randomly passing in a :timeout value.

  #+sb-thread
  `(if ,timeout
       (handler-case
        (sb-sys:with-deadline
         (:seconds ,timeout)
         ,body)
        (sb-ext:timeout ()))
     ,body)
  #+lispworks
  (lispworks:with-unique-names (process timer)
    `(catch 'lispworks-timeout
       (let* ((,process mp:*current-process*)
              (,timer (mp:make-timer (lambda () 
                                       (mp:process-interrupt
                                        ,process
                                        (lambda () 
                                          (throw 'lispworks-timeout nil)))))))
         (unwind-protect-disable-interrupts-during-cleanup
          (progn
            (mp:schedule-timer-relative ,timer ,timeout)
            ,body)
          (mp:unschedule-timer ,timer))))))

; We would like to find a clean way to provide the user with an implicit progn,
; while still maintaining timeout as a keyword argument.

; #+sb-thread
; (defmacro with-potential-sbcl-timeout (&rest body &key timeout)
; 
; ; The below use of labels is only neccessary because we provide an implicit
; ; progn for the body of with-potential-sbcl-timeout.
; 
;   (let ((correct-body
;          (labels ((remove-keyword-from-list
;                    (lst keyword)
;                    (if (or (atom lst) (atom (cdr lst)))
;                        lst
;                      (if (equal (car lst) :timeout)
;                          (cddr lst)
;                        (cons (car lst) (remove-keyword-from-args (cdr lst)))))))
;                  (remove-keyword-from-args body :timeout))))
; 
; 
;     `(if ,timeout
;          (handler-case
;           (sb-sys:with-deadline
;            (:seconds ,timeout)
;            ,@correct-body)
; 
;           (sb-ext:timeout ()))
;        ,@correct-body)))

; Essay on Condition Variables

; A condition variable is a data structure that can be passed to corresponding
; "wait" and "signal" functions.  When a thread calls the wait function on a
; condition variable, c, the thread blocks until "receiving a signal" from the
; application of the signal function to c.  Only one signal is sent per call of
; the signal function; so, at most one thread will unblock.  (There is a third
; notion for condition variable, namely the broadcast function, which is like
; the signal function except that all threads blocking on the given condition
; variable will unblock.  But we do not support broadcast functions in this
; interface, in part because we use semaphores for CCL, and there's no way
; to broadcast when you're really using a semaphore.)

; The design of our parallelism library is simpler when using condition
; variables for the following reason: Since a worker must wait for two
; conditions before consuming work, it is better to use a condition variable
; and test those two conditions upon waking, rather than try and use two
; semaphores.

; Implementation Note: As of March 2007, our CCL implementation does not
; yield true condition variables.  A condition variable degrades to a
; semaphore, so if one thread first signals a condition variable, then that
; signal has been stored.  Then later (perhaps much later), when another thread
; waits for that signal, that thread will be able to proceed by decrementing
; the count.  As a result the later thread will "receive" the signal, even
; though that signal occurred in the past.  Fortunately, this isn't a
; contradiction of the semantics of condition variables, since with condition
; variables there is no specification of how far into the future the waiting
; thread will receive a signal from the signalling thread.

; Note: Condition variables should not be used to store state.  They are only a
; signaling mechanism, and any state update implied by receiving a condition
; variable's signal should be checked.  This usage is believed to be consistent
; with traditional condition variable semantics.

(defun make-condition-variable ()

; If CCL implements condition variables, we will want to change the CCL
; expansion and remove the implementation note above.

; Because implementing broadcast for condition variables in CCL is much more
; heavyweight than a simple semaphore, we keep it simple until we have a use
; case for a broadcast.  Such simple requirements are satisfied by using a
; semaphore.

  #+ccl
  (ccl:make-semaphore)
  #+sb-thread
  (sb-thread:make-waitqueue)
  #+lispworks
  (mp:make-condition-variable)
  #-(or ccl sb-thread lispworks)

; We may wish to have assertions that evaluation of (make-condition-variable)
; is non-nil.  So we return t, even though as of this writing there are no such
; assertions.

  t)

(defmacro signal-condition-variable (cv)
  #-(or ccl sb-thread lispworks)
  (declare (ignore cv))
  #+ccl
  `(ccl:signal-semaphore ,cv)
  #+sb-thread

; According to an email sent by Gabor Melis, of SBCL help, on 2007-02-25, if
; there are two threads waiting on a condition variable, and a third thread
; signals the condition variable twice before either can receive the signal,
; then both threads should receive the signal.  If only one thread unblocks, it
; is considered a bug.

  `(sb-thread:condition-notify ,cv)
  #+lispworks
  `(mp:condition-variable-signal ,cv)
  #-(or ccl sb-thread lispworks)
  t)

(defmacro broadcast-condition-variable (cv)
  #-(or sb-thread lispworks)
  (declare (ignore cv))
  #+ccl
  (error "Broadcasting condition variables is unsupported in CCL")
  #+sb-thread
  `(sb-thread:condition-broadcast ,cv)
  #+lispworks
  `(mp:condition-variable-broadcast ,cv)
  #-(or ccl sb-thread lispworks)
  t)

(defun wait-on-condition-variable (cv lock &key timeout)

; A precondition to this function is that the current thread "owns" lock.  This
; is a well-known part of how condition variables work.  This is also
; documented in the SBCL manual in section 12.5 entitled "Waitqueue/condition
; variables."

  #-(or sb-thread lispworks)
  (declare (ignore cv lock timeout))
  #+ccl
  (error "Waiting on condition variables with locks is unsupported in CCL")
  #+sb-thread
  (with-potential-timeout
   (sb-thread:condition-wait cv lock)
   :timeout timeout)
  #+lispworks
  (mp:condition-variable-wait cv lock :timeout timeout)
  #-(or ccl sb-thread lispworks)
  nil) ; the default is to never receive a signal

#+sb-thread
(defstruct acl2-semaphore
  (lock (sb-thread:make-mutex))
  (cv (sb-thread:make-waitqueue)) ; condition variable
  (count 0))

#+lispworks
(defstruct acl2-semaphore
  (lock (mp:make-lock))
  (cv (mp:make-condition-variable)) ; condition variable
  (count 0))

(defun make-semaphore (&optional name)

; Make-semaphore, signal-semaphore, and semaphorep work together to implement
; counting semaphores for the threading interface.

; This function creates "counting semaphores", which are data structures that
; include a "count" field, which is a natural number.  A thread can "wait on" a
; counting semaphore, and it will block in the case that the semaphore's count
; is 0.  To "signal" such a semaphore means to increment that field and to
; notify a unique waiting thread (we will discuss a relaxation of this
; uniqueness shortly) that the semaphore's count has been incremented.  Then
; this thread, which is said to "receive" the signal, decrements the
; semaphore's count and is then unblocked.  This mechanism is typically much
; faster than busy waiting.

; In principle more than one waiting thread could be notified (though this
; seems rare in practice).  In this case, only one would be the receiving
; thread, i.e., the one that decrements the semaphore's count and is then
; unblocked.

; If semaphore usage seems to perform inefficiently, could this be due to
; ordering issues?  For example, even though CCL nearly always uses a FIFO
; for blocked threads, it does not guarantee so: no such promise is made by the
; CCL documentation or implementor.  Thus, we make absolutely no guarantees
; about ordering; for example, we do not guarantee that the longest-blocked
; thread for a given semaphore is the one that would receive a signal.
; However, we suspect that this will usually be the case for most
; implementations, so assuming such an ordering property is probably a
; reasonable heuristic.  We would be somewhat surprised to find significant
; performance problems in our own application to ACL2's parallelism primitives
; due to the ordering provided by the underlying system.

; CCL provides us with semaphores for signaling.  SBCL provides condition
; variables for signaling.  Since we want to code for one type of signaling
; between parents and children, we create a semaphore wrapper for SBCL's
; condition variables.  The structure sbcl-semaphore implements the data for
; this wrapper.

; Followup: SBCL has recently (as of November 2010) implemented semaphores, and
; the parallelism code could be changed to reflect this.  However, since SBCL
; does not implement semaphore-nofication-object's, we choose to stick with our
; own implementation of semaphores for now.

  (declare (ignore name))
  #+ccl
  (ccl:make-semaphore)
  #+(or sb-thread lispworks)
  (make-acl2-semaphore)
  #-(or ccl sb-thread lispworks)

; We return nil in the uni-threaded case in order to stay in sync with
; semaphorep.

  nil)

(defun semaphorep (semaphore)

; Make-semaphore, signal-semaphore, and semaphorep work together to implement
; counting semaphores for our threading interface.

; This function recognizes our notion of semaphore structures.

  #+ccl
  (typep semaphore 'ccl::semaphore)
  #+sb-thread
  (and (acl2-semaphore-p semaphore)
       (typep (acl2-semaphore-lock semaphore) 'sb-thread::mutex)
       (typep (acl2-semaphore-cv semaphore) 'sb-thread::waitqueue)
       (integerp (acl2-semaphore-count semaphore)))
  #+lispworks
  (and (acl2-semaphore-p semaphore)
       (typep (acl2-semaphore-lock semaphore) 'mp::lock)
       (typep (acl2-semaphore-cv semaphore) 'mp::condition-variable)
       (integerp (acl2-semaphore-count semaphore)))
  #-(or ccl sb-thread lispworks)

; We return nil in the uni-threaded case in order to stay in sync with
; make-semaphore, which returns nil in this case.  In a sense, we want
; (semaphorep (make-semaphore x)) to be a theorem if there is no error.

  (null semaphore))

(defun make-semaphore-notification ()

; This function returns an object that records when a corresponding semaphore
; has been signaled (for use when wait-on-semaphore is called with that
; semaphore and that object).

  #+ccl
  (ccl:make-semaphore-notification)
  #+(or sb-thread lispworks)
  (make-array 1 :initial-element nil)
  #-(or ccl sb-thread lispworks)
  nil)

(defun semaphore-notification-status (semaphore-notification-object)
  #-(or ccl sb-thread lispworks)
  (declare (ignore semaphore-notification-object))
  #+ccl
  (ccl:semaphore-notification-status semaphore-notification-object)
  #+(or sb-thread lispworks)
  (aref semaphore-notification-object 0)
  #-(or ccl sb-thread lispworks)

; t may be the wrong default, but we don't have a use case for this return
; value yet, so we postpone thinking about the "right" value until we are aware
; of a need.

  t)

(defun clear-semaphore-notification-status (semaphore-notification-object)
  #-(or ccl sb-thread lispworks)
  (declare (ignore semaphore-notification-object))
  #+ccl
  (ccl:clear-semaphore-notification-status semaphore-notification-object)
  #+(or sb-thread lispworks)
  (setf (aref semaphore-notification-object 0) nil)
  #-(or ccl sb-thread lispworks)
  nil)

; We implement this only for SBCL and Lispworks, because even a system-level
; programmer is not expected to use this function.  We use it only from within
; the threading interface to implement wait-on-semaphore for SBCL and
; Lispworks.

(defun set-semaphore-notification-status (semaphore-notification-object)
  #-(or sb-thread lispworks)
  (declare (ignore semaphore-notification-object))
  #+(or sb-thread lispworks)
  (setf (aref semaphore-notification-object 0) t)
  #-(or sb-thread lispworks)
  (error
   "Set-semaphore-notification-status not supported outside SBCL or Lispworks"))

(defun signal-semaphore (semaphore)

; Make-semaphore, signal-semaphore, and semaphorep work together to implement
; counting semaphores for our threading interface.

; This function is executed for side effect; the value returned is irrelevant.

  #-(or ccl sb-thread lispworks)
  (declare (ignore semaphore))
  #+ccl
  (ccl:signal-semaphore semaphore)
  #+(or sb-thread lispworks)
  (with-lock
   (acl2-semaphore-lock semaphore)
   (without-interrupts
    (incf (acl2-semaphore-count semaphore))
    (signal-condition-variable (acl2-semaphore-cv semaphore))))

; Parallelism wart: delete the following commented code.

;  #+lispworks
;  (mp:with-lock
;   ((lispworks-semaphore-lock semaphore))
;   (without-interrupts
;    (incf (lispworks-semaphore-count semaphore))
;    (mp:condition-variable-signal (lispworks-semaphore-cv semaphore))))

  #-(or ccl sb-thread lispworks)
  nil)

; Once upon a time, we optimized the manual allocation and deallocation of
; semaphores so that they could be recycled.  CCL and SBCL have since evolved,
; and as such, we have removed the implementation code and its corresponding
; uses.

(defun wait-on-semaphore (semaphore &key notification timeout)

; This function is guaranteed to return t when it has received the signal.  Its
; return value when the signal has not been received is unspecified.  As such,
; we provide the semaphore notification object as a means for determining
; whether a signal was actually received.

; This function only returns normally after receiving a signal for the given
; semaphore, setting the notification status of notification (if supplied and
; non-nil) to true; see semaphore-notification-status.  But control can leave
; this function abnormally, for example if the thread executing a call of this
; function is interrupted (e.g., with interface function interrupt-thread) with
; code that does a throw, in which case notification is unmodified.

; We need the ability to know whether we received a signal or not.  CCL
; provides this through a semaphore notification object.  SBCL does not provide
; this mechanism currently, so we might "unreceive the signal" in the cleanup
; form of the implementation.  We do this by only decrementing the count of the
; semaphore iff we set the notification object.  This means we have to resignal
; the semaphore if we were interrupted while signaling, but we would have to do
; this anyway.

  #-(or ccl sb-thread lispworks)
  (declare (ignore semaphore notification timeout))

  #+ccl
  (if timeout
      (ccl:timed-wait-on-semaphore semaphore timeout notification)
    (ccl:wait-on-semaphore semaphore notification))

  #+(or sb-thread lispworks)
  (let ((received-signal nil))

; If we did not use a variable like "received-signal", we could have the
; following race condition:

; -- Suppose Thread A waits for the semaphore and is waiting for the
; signal from the CV
; -- Suppose Thread B is in the same state, that is, waiting for the
; semaphore and for the signal from the CV
; -- Then thread C signals the CV
; -- Thread A is awakened by the signal but is immediately interrupted
; by another thread and forced to throw a tag which is caught higher up
; in Thread A's call stack.
; -- The signal is effectively "lost", so while the semaphore count may
; be accurate, Thread B is still waiting on a signal that will never
; come.

; We guard against this lost signal by always re-signaling the condition
; variable (unless we're sure we received the signal, which we would know
; because "received-signal" would be set to t).  

; This signaling during the unwind portion of the unwind protect definitely
; results in some inefficient execution.  This is brought about because now any
; thread that waits on a signal will automatically signal the condition
; variable any time that it doesn't receive the signal (either due to a timeout
; or an interrupt+throw/error).  However, this is the price of liveness for our
; system (which requires we implement semaphores in user space because we need
; semaphore-notification-objects).

    (with-lock
     (acl2-semaphore-lock semaphore)
     (unwind-protect-disable-interrupts-during-cleanup
      (with-potential-timeout
       (progn
         (loop while (<= (acl2-semaphore-count semaphore) 0) do
              
; The current thread missed the chance to decrement and must rewait.  This can
; only occur if another thread grabbed the lock and decremented the 
              
               (wait-on-condition-variable (acl2-semaphore-cv semaphore)
                                           (acl2-semaphore-lock semaphore)))
         (setq received-signal t)
         t) ; if this progn returns, this t is the return value
       :timeout timeout)
      
      (if received-signal
          
; The current thread was able to record the receipt of the signal.  The current
; thread will decrement the count of the semaphore and set the semaphore
; notification object.
          
          (progn
            (decf (acl2-semaphore-count semaphore))
            (when notification
              (set-semaphore-notification-status notification)))

; The current thread may have received the signal but been unable to record it.
; In this case, the current thread will signal the condition variable again, so
; that any other thread waiting on the semaphore can have a chance at acquiring
; the said semaphore.  This results in needlessly signaling the condition
; variable portion of the semaphore every time a timeout occurs.  However, that
; is the cost of a "live" implementation ("live" loosely means "makes progress").

          (signal-condition-variable (acl2-semaphore-cv semaphore))))))
  #-(or ccl sb-thread lispworks)
  t) ; default is to receive a semaphore/lock

;---------------------------------------------------------------------
; Section: Multi-Threading Utility Functions and Macros
;
; These functions and macros could be defined in parallel-raw.lisp, except that
; we also use them in futures-raw.lisp.  Rather than create another file, we
; place them here, at the end of the multi-threading interface.

(defvar *throwable-worker-thread* 

; When we terminate threads due to a break and abort, we need a way to
; terminate all threads.  We implement this by having them throw the
; :worker-thread-no-longer-needed tag.  Unfortunately, sometimes the threads
; are outside the scope of the associated catch, when throwing the tag would
; cause an error.  We avoid this warning by maintaining the dynamically-bound
; variable *throwable-worker-thread*.  When the throwable context is entered,
; we let a new copy of the variable into existence and set it to T.  Now, when
; we throw :worker-thread-no-longer-needed, we only throw it if
; *throwable-worker-thread* is non-nil.

  nil)

(defun throw-all-threads-in-list (thread-list)

; We interrupt each of the given threads with a throw to the catch at the top
; of consume-work-on-work-queue-when-there, which is the function called
; by run-thread in spawn-worker-threads-if-needed.

; Compare with kill-all-threads-in-list, which kills all of the given threads
; (typically all user-produced threads), not just those self-identified as
; being within the associated catch block.

  (if (endp thread-list)
      nil
    (progn
      (interrupt-thread
       (car thread-list)
       #'(lambda () (when *throwable-worker-thread*
                      (throw :worker-thread-no-longer-needed nil))))
      (throw-all-threads-in-list (cdr thread-list)))))

(defun kill-all-threads-in-list (thread-list)

; Compare with throw-all-threads-in-list, which uses throw instead of killing
; threads directly, but only affects threads self identified as being within an
; associated catch block.

  (if (endp thread-list)
      nil
    (progn
      (kill-thread (car thread-list))
      (kill-all-threads-in-list (cdr thread-list)))))

#+lispworks
(defun initial-threads1 (threads)
  (cond ((endp threads)
         nil)
        ((member-equal (mp:process-name (car threads))
                       '("TTY Listener" "The idle process" 
                         "Restart Function Process"))
         (cons (car threads)
               (initial-threads1 (cdr threads))))
        (t (initial-threads1 (cdr threads)))))

(defvar *initial-threads* 

; *Intial-threads* stores a list of threads that are considered to be part of
; the non-threaded part of ACL2.  When terminating parallelism threads, only
; those not appearing in this list will be terminated.  Warning: If ACL2 uses
; parallelism during the build process, this variable could incorrectly record
; parallelism threads as initial threads.

  (all-threads))

(defun initial-threads ()

; We know how to set the *initial-threads* variable reliably in all Lisps
; except Lispworks.  Due to Lispworks' multiprocessing model (where we start a
; tty-listener when lp exits), accurately updating this variable is difficult
; (perhaps infeasiable).  Rather than spend even more time on this problem, we
; simply return the threads that currently exist that match the names of
; threads that we associate with "initial" threads.

; Parallelism wart: we might want to adapt a similar name-based strategy for
; SBCL and CCL.  This would allow us to get rid of *initial-threads*
; altogether.

  #-lispworks
  *initial-threads* 
  #+lispworks
  (initial-threads1 (all-threads)))

(defun all-threads-except-initial-threads-are-dead ()
  #+sbcl
  (<= (length (all-threads)) 1)
  #-sbcl
  (null (set-difference (all-threads) (initial-threads))))

(defun send-die-to-all-except-initial-threads ()

; This function is evaluated only for side effect.

; Parallelism wart: When building ACL2(p), we receive a warning message about
; send-die-to-all-except-initial-threads being undefined.  This warning is
; benign, but it would be nice to remove it.

  (let ((target-threads (set-difference (all-threads)
                                        (initial-threads))))
    (throw-all-threads-in-list target-threads))

; We can't call thread-wait in Lispworks until after multiprocessing is
; enabled.  We therefore conditionalize the call on a condition that should be
; nil when multiprocessing is disabled.

  (when (not (all-threads-except-initial-threads-are-dead))
    (thread-wait 'all-threads-except-initial-threads-are-dead)))

(defun kill-all-except-initial-threads ()

; This function is evaluated only for side effect.

  (let ((target-threads (set-difference (all-threads)
                                        (initial-threads))))
    (kill-all-threads-in-list target-threads))
  (thread-wait 'all-threads-except-initial-threads-are-dead))


;---------------------------------------------------------------------
; Section:  Multi-Threading Constants
;
; These constants could go in parallel-raw.lisp, except that they are also used
; in futures-raw.lisp.  Rather than create another file, we place them here, at
; the end of the multi-threading interface.

(defun core-count-raw (&optional (ctx nil) default)

; If ctx is supplied, then we cause an error using the given ctx.  Otherwise we
; return a suitable default value (see below).

  #+ccl (declare (ignore ctx default))
  #+ccl (ccl:cpu-count)
  #-ccl
  (if ctx
      (error "It is illegal to call cpu-core-count in this Common Lisp ~
              implementation.")

; If the host Lisp does not provide a means for obtaining the number of cores,
; then we simply estimate on the high side.  A high estimate is desired in
; order to make it unlikely that we have needlessly idle cores.  We thus
; believe that 16 cores is a reasonable estimate for early 2011; but we may
; well want to increase this number later.

    (or default 16)))

(defconstant *core-count*
  (core-count-raw)
  "The total number of CPU cores in the system.")

(defconstant *unassigned-and-active-work-count-limit*

; The *unassigned-and-active-work-count-limit* limits work on the *work-queue*
; to what we think the system will be able to process in a reasonable amount of
; time.  Suppose we have 8 CPU cores.  This means that there can be 8 active
; work consumers, and that generally not many more than 24 pieces of
; paralellism work are stored in the *work-queue* to be processed.  This
; provides us the guarantee that if all worker threads were immediately to
; finish their piece of parallelism work, that each of them would immediately
; be able to grab another piece from the work queue.

; We could increase the following coefficient from 4 and further guarantee that
; consumers have parallelism work to process, but this would come at the
; expense of backlogging the *work-queue".  We prefer simply to avoid the
; otherwise parallelized computations in favor of their serial equivalents.

  (* 4 *core-count*))

(defconstant *total-work-limit* ; unassigned, started, resumed AND pending

; The number of pieces of work in the system, *parallelism-work-count*, must be
; less than *total-work-limit* in order to enable creation of new pieces of
; work.  (However, we could go from 49 to 69 pieces of work when encountering a
; pand; just not from 50 to 52.)

; Why limit the amount of work in the system?  :Doc parallelism-how-to
; (subtopic "Another Granularity Issue Related to Thread Limitations") provides
; an example showing how cdr recursion can rapidly create threads.  That
; example shows that if there is no limit on the amount of work we may create,
; then eventually, many successive cdrs starting at the top will correspond to
; waiting threads.  If we do not limit the amount of work that can be created,
; this can exhaust the supply of Lisp threads available to process the elements
; of the list.

  (let ((val

; Warning: It is possible, in principle to create (+ val
; *max-idle-thread-count*) threads.  Presumably you'll get a hard Lisp error
; (or seg fault!) if your Lisp cannot create that many threads.

         50)
        (bound (* 2 *core-count*)))
    (when (< val bound)
      (error "The variable *total-work-limit* needs to be at least ~s, i.e., ~%~
              at least double the *core-count*.  Please redefine ~%~
              *total-work-limit* so that it is not ~s."
             bound
             val))
    val))

(defconstant *max-idle-thread-count* 

; We don't want to spawn more worker threads (which are initially idle) when we
; already have sufficiently many idle worker threads.  We use
; *max-idle-thread-count* to limit this spawning in function
; spawn-worker-threads-if-needed.

(* 2 *core-count*))
