;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           __    __        __    __                                        ;;
;;          /  \  /  \      (__)  |  |    ____   ___      __    ____         ;;
;;         /    \/    \      __   |  |   / _  |  \  \ __ /  /  / _  |        ;;
;;        /  /\    /\  \    |  |  |  |  / / | |   \  '  '  /  / / | |        ;;
;;       /  /  \__/  \  \   |  |  |  |  \ \_| |    \  /\  /   \ \_| |        ;;
;;      /__/          \__\  |__|  |__|   \____|     \/  \/     \____|        ;;
;; ~ ~~ \  ~ ~  ~_~~ ~/~ /~ | ~|~ | ~| ~ /~_ ~|~ ~  ~\  ~\~ ~  ~ ~  |~~    ~ ;;
;;  ~ ~  \~ \~ / ~\~ / ~/ ~ |~ | ~|  ~ ~/~/ | |~ ~~/ ~\/ ~~ ~ / / | |~   ~   ;;
;; ~ ~  ~ \ ~\/ ~  \~ ~/ ~~ ~__|  |~ ~  ~ \_~  ~  ~  .__~ ~\ ~\ ~_| ~  ~ ~~  ;;
;;  ~~ ~  ~\  ~ /~ ~  ~ ~  ~ __~  |  ~ ~ \~__~| ~/__~   ~\__~ ~~___~| ~ ~    ;;
;; ~  ~~ ~  \~_/  ~_~/ ~ ~ ~(__~ ~|~_| ~  ~  ~~  ~  ~ ~~    ~  ~   ~~  ~  ~  ;;
;;                                                                           ;;
;;            A   R e f l e c t i v e   P r o o f   C h e c k e r            ;;
;;                                                                           ;;
;;       Copyright (C) 2005-2009 by Jared Davis <jared@cs.utexas.edu>        ;;
;;                                                                           ;;
;; This program is free software; you can redistribute it and/or modify it   ;;
;; under the terms of the GNU General Public License as published by the     ;;
;; Free Software Foundation; either version 2 of the License, or (at your    ;;
;; option) any later version.                                                ;;
;;                                                                           ;;
;; This program is distributed in the hope that it will be useful, but       ;;
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABIL-  ;;
;; ITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public      ;;
;; License for more details.                                                 ;;
;;                                                                           ;;
;; You should have received a copy of the GNU General Public License along   ;;
;; with this program (see the file COPYING); if not, write to the Free       ;;
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA    ;;
;; 02110-1301, USA.                                                          ;;
;;                                                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MILAWA")
(include-book "fast-crewrite")
(include-book "crewrite-clause")
(%interactive)

(%autoadmit rw.fast-ccstepp)
(%autoadmit rw.fast-ccstep)
(%autoadmit rw.fast-ccstep->contradictionp)
(%autoadmit rw.fast-ccstep->ftrace)

(%autoprove rw.fast-ccstep->contradictionp-of-rw.fast-ccstep
            (%enable default
                     rw.fast-ccstep
                     rw.fast-ccstep->contradictionp))

(%autoprove rw.fast-ccstep->ftrace-of-rw.fast-ccstep
            (%enable default rw.fast-ccstep
                     rw.fast-ccstep->ftrace))

(%autoprove booleanp-of-rw.fast-ccstepp
            (%enable default rw.fast-ccstepp))

(%autoprove rw.fast-ccstepp-of-rw.fast-ccstep
            (%enable default rw.fast-ccstepp rw.fast-ccstep))

(%autoprove booleanp-of-rw.fast-ccstep->contradictionp
            (%enable default
                     rw.fast-ccstepp
                     rw.fast-ccstep->contradictionp))

(%autoprove rw.ftracep-of-rw.fast-ccstep->ftrace
            (%enable default
                     rw.fast-ccstepp
                     rw.fast-ccstep->contradictionp
                     rw.fast-ccstep->ftrace))


(%autoadmit rw.ccstep-fast-image)

(%autoprove rw.fast-ccstepp-of-rw.ccstep-fast-image
            (%enable default rw.ccstep-fast-image))

(%autoprove rw.fast-ccstep->contradictionp-of-rw.ccstep-fast-image
            (%enable default rw.ccstep-fast-image))

(%autoprove rw.fast-ccstep->ftrace-of-rw.ccstep-fast-image
            (%enable default rw.ccstep-fast-image))



(%autoadmit rw.fast-crewrite-take-step)

(%autoprove rw.fast-ccstepp-of-rw.fast-crewrite-take-step
            (%enable default rw.fast-crewrite-take-step))


(%autoprove rw.ccstep-fast-image-of-rw.crewrite-take-step

            (%enable default
                     rw.ccstep-fast-image
                     rw.crewrite-take-step
                     rw.fast-crewrite-take-step)
            (%disable default
                      rw.fast-assms->contradiction-of-rw.assms-fast-image
                      [outside]rw.fast-assms->contradiction-of-rw.assms-fast-image
                      )
            (%use (%instance
                   (%thm rw.fast-assms->contradiction-of-rw.assms-fast-image)
                   (assms (rw.assume-right-list
                           done
                           (rw.assume-left-list (cdr todo)
                                                (rw.empty-assms (rw.control->assmctrl control)))))))

            (%auto :strategy (cleanup split crewrite))

            ;; Very gross.  We don't pattern match literal conses...
            (%enable default rw.fast-ccstep)
            (%use (%instance (%thm equal-of-cons-rewrite)
                             (x '(t))
                             (a (RW.FAST-ASSMS->CONTRADICTION
                                 (RW.FAST-ASSUME-RIGHT-LIST
                                  DONE
                                  (RW.FAST-ASSUME-LEFT-LIST
                                   (CDR TODO)
                                   (RW.EMPTY-FAST-ASSMS (RW.CONTROL->ASSMCTRL CONTROL))))))
                             (b 'nil)))
            (%auto))

(%autoprove rw.fast-ccstep->contradictionp-of-rw.fast-crewrite-take-step
            (%disable default
                      rw.fast-ccstep->contradictionp-of-rw.ccstep-fast-image
                      [outside]rw.fast-ccstep->contradictionp-of-rw.ccstep-fast-image)
            (%use (%instance (%thm rw.fast-ccstep->contradictionp-of-rw.ccstep-fast-image)
                             (x (rw.crewrite-take-step todo done blimit rlimit control n)))))

(%autoprove rw.fast-ccstep->ftrace-of-rw.fast-crewrite-take-step
            (%enable default
                     rw.fast-crewrite-take-step
                     rw.crewrite-take-step)
            (%disable default
                      rw.fast-assms->contradiction-of-rw.assms-fast-image
                      [outside]rw.fast-assms->contradiction-of-rw.assms-fast-image)
            (%use (%instance
                   (%thm rw.fast-assms->contradiction-of-rw.assms-fast-image)
                   (assms (rw.assume-right-list
                           done
                           (rw.assume-left-list (cdr todo)
                                                (rw.empty-assms (rw.control->assmctrl control))))))))


(%autoadmit rw.fast-ccstep->provedp)

(%autoprove rw.fast-ccstep->provedp-of-rw.ccstep-fast-image
            (%enable default
                     rw.fast-ccstep->provedp
                     rw.ccstep->provedp))

(%autoprove rw.fast-ccstep->contradictionp-when-not-rw.fast-ccstep->provedp
            (%enable default rw.fast-ccstep->provedp))

(%autoprove rw.fast-ccstep->provedp-of-rw.fast-crewrite-take-step
            (%disable default
                      rw.fast-ccstep->provedp-of-rw.ccstep-fast-image
                      [outside]rw.fast-ccstep->provedp-of-rw.ccstep-fast-image
                      )
            (%use (%instance (%thm rw.fast-ccstep->provedp-of-rw.ccstep-fast-image)
                             (x (rw.crewrite-take-step todo done blimit rlimit control n)))))



(%autoadmit rw.fast-ccstep->t1prime)

(%autoprove rw.fast-ccstep->t1prime-of-rw.ccstep-fast-image
            (%enable default rw.fast-ccstep->t1prime rw.ccstep->t1prime))

(%autoprove logic.termp-of-rw.fast-ccstep->t1prime
            (%enable default rw.fast-ccstep->t1prime))

(%autoprove rw.fast-ccstep->t1prime-of-rw.fast-crewrite-take-step
            (%enable default rw.ccstep->provedp)
            (%disable default
                      rw.fast-ccstep->t1prime-of-rw.ccstep-fast-image)
            (%use (%instance (%thm rw.fast-ccstep->t1prime-of-rw.ccstep-fast-image)
                             (x (rw.crewrite-take-step todo done blimit rlimit control n)))))






;; Fast clause crewriting.
;;
;; This has been kind of tricky.  We don't really care about building any
;; intermediate steps.  All we want to know is (1) whether the clause gets
;; proved, (2) what is clause-prime, if the clause wasn't proved, and (2) what
;; goals were forced?  We begin by introducing three functions to compute
;; exactly these answers.  We won't run these functions, we just use them to do
;; the reasoning.

(%autoadmit rw.crewrite-clause-aux-provedp)
(%autoadmit rw.crewrite-clause-aux-todo-primes)
(%autoadmit rw.crewrite-clause-aux-fgoals)

(%autoadmit rw.crewrite-clause-aux-noacc)

(%autoprove consp-of-rw.crewrite-clause-aux-noacc
            (%autoinduct rw.crewrite-clause-aux-noacc)
            (%restrict default rw.crewrite-clause-aux-noacc (equal todo 'todo)))

;; (defthm true-listp-of-rw.crewrite-clause-aux
;;   (implies (true-listp acc)
;;            (true-listp (rw.crewrite-clause-aux todo done blimit rlimit control n acc)))
;;   :hints(("Goal" :in-theory (enable rw.crewrite-clause-aux))))

;; (%autoprove true-listp-of-rw.crewrite-clause-aux
;;             (%autoinduct rw.crewrite-clause-aux)
;;             (%restrict default rw.crewrite-clause-aux (equal todo 'todo)))

(%autoprove rw.crewrite-clause-aux-removal
            (%autoinduct rw.crewrite-clause-aux)
            (%restrict default rw.crewrite-clause-aux (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-noacc (equal todo 'todo)))

(%autoprove car-of-app)
(%autoprove cdr-of-app)
(local (%enable default car-of-app))
(local (%enable default cdr-of-app))


(%autoprove rw.crewrite-clause-aux-provedp-correct
            (%autoinduct rw.crewrite-clause-aux-noacc)
            (%restrict default rw.crewrite-clause-aux-noacc (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-provedp (equal todo 'todo)))

(%autoprove consp-of-rw.crewrite-clause-aux-todo-primes
            (%autoinduct rw.crewrite-clause-aux-todo-primes)
            (%restrict default rw.crewrite-clause-aux-todo-primes (equal todo 'todo)))

(%autoprove rw.ccstep->clause-prime-of-rw.crewrite-take-step
            (%enable default
                     rw.ccstep->clause-prime
                     rw.ccstep->provedp
                     rw.ccstep->t1prime
                     rw.crewrite-take-step))

(%autoprove rw.crewrite-clause-aux-todo-primes-correct
            (%autoinduct rw.crewrite-clause-aux-noacc todo done blimit rlimit control n)
            (%restrict default rw.crewrite-clause-aux-todo-primes (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-provedp (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-noacc (equal todo 'todo)))

(%autoprove true-listp-of-rw.crewrite-clause-aux-fgoals
            (%autoinduct rw.crewrite-clause-aux-fgoals)
            (%restrict default rw.crewrite-clause-aux-fgoals (equal todo 'todo)))

(%autoprove rw.crewrite-clause-aux-fgoals-correct
            (%autoinduct rw.crewrite-clause-aux-noacc)
            (%restrict default rw.crewrite-clause-aux-fgoals (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-noacc (equal todo 'todo)))



(%autoadmit rw.fast-crewrite-clause-aux)

(%autoprove provedp-of-rw.fast-crewrite-clause-aux
            (%autoinduct rw.fast-crewrite-clause-aux)
            (%disable default rw.crewrite-clause-aux-provedp-correct)
            (%restrict default rw.crewrite-clause-aux-provedp (equal todo 'todo))
            (%restrict default rw.fast-crewrite-clause-aux (equal todo 'todo)))

(%autoprove clause-prime-of-rw.fast-crewrite-clause-aux
            (%autoinduct rw.fast-crewrite-clause-aux)
            (%restrict default rw.crewrite-clause-aux-provedp (equal todo 'todo))
            (%restrict default rw.crewrite-clause-aux-todo-primes (equal todo 'todo))
            (%restrict default rw.fast-crewrite-clause-aux (equal todo 'todo)))

(%autoprove forced-goals-of-rw.fast-crewrite-clause-aux
            (%autoinduct rw.fast-crewrite-clause-aux)
            (%restrict default rw.crewrite-clause-aux-fgoals (equal todo 'todo))
            (%restrict default rw.fast-crewrite-clause-aux (equal todo 'todo))
            (%enable default rw.ccstep-forced-goals))



(%autoadmit rw.fast-crewrite-clause)

(%autoprove first-of-rw.fast-crewrite-clause
            (%enable default
                     rw.fast-crewrite-clause
                     rw.crewrite-clause
                     rw.crewrite-clause-aux-removal))

(%autoprove second-of-rw.fast-crewrite-clause
            (%enable default
                     rw.fast-crewrite-clause
                     rw.crewrite-clause
                     rw.crewrite-clause-aux-removal))

(%autoprove third-of-rw.fast-crewrite-clause
            (%enable default
                     rw.fast-crewrite-clause
                     rw.crewrite-clause
                     rw.crewrite-clause-aux-removal))

(%ensure-exactly-these-rules-are-missing "../../rewrite/fast-crewrite-clause")
