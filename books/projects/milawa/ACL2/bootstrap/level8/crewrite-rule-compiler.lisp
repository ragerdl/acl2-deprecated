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
(include-book "trace-okp")
(%interactive)

(local (%enable default rw.trace-conclusion-formula rw.trace-formula))

(%autoprove logic.strip-function-names-of-rw.trace-list-conclusion-formulas-when-all-iffp
            (%cdr-induction x)
            (%restrict default rw.trace-list-conclusion-formulas (equal x 'x)))

(%autoprove logic.strip-lens-of-logic.strip-function-args-of-rw.trace-list-conclusion-formulas
            (%cdr-induction x)
            (%restrict default rw.trace-list-conclusion-formulas (equal x 'x)))


;; These have already been introduced
;; (%deftheorem rw.crewrite-rule-lemma)
;; (%defderiv rw.crewrite-rule-lemma-bldr :omit-okp t)
;; (%defderiv rw.disjoined-crewrite-rule-lemma-bldr :omit-okp t)

;; These have already been introduced
;; (%autoadmit rw.crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.appeal-listp-of-rw.crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.strip-conclusions-of-rw.crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.proof-listp-of-rw.crewrite-rule-lemma-list-bldr)

(%autoprove len-of-rw.crewrite-rule-lemma-list-bldr
            (%cdr-induction x)
            (%restrict default rw.crewrite-rule-lemma-list-bldr (equal x 'x)))

;; These has already been introduced
;; (%autoadmit rw.disjoined-crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.appeal-listp-of-rw.disjoined-crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.strip-conclusions-of-rw.disjoined-crewrite-rule-lemma-list-bldr)
;; (%autoprove forcing-logic.proof-listp-of-rw.disjoined-crewrite-rule-lemma-list-bldr)

(%autoprove len-of-rw.disjoined-crewrite-rule-lemma-list-bldr
            (%cdr-induction x)
            (%restrict default rw.disjoined-crewrite-rule-lemma-list-bldr (equal x 'x)))

;; These have already been introduced
;; (%autoadmit rw.compile-crewrite-rule-trace-lemma1)
;; (%autoprove logic.appealp-of-rw.compile-crewrite-rule-trace-lemma1)
;; (%autoprove logic.conclusion-of-rw.compile-crewrite-rule-trace-lemma1)
;; (%autoprove logic.proofp-of-rw.compile-crewrite-rule-trace-lemma1)

;; These have already been introduced
;; (%autoadmit rw.compile-crewrite-rule-trace-lemma2)
;; (%autoprove forcing-logic.appealp-of-rw.compile-crewrite-rule-trace-lemma2)
;; (%autoprove forcing-logic.conclusion-of-rw.compile-crewrite-rule-trace-lemma2)
;; (%autoprove forcing-logic.proofp-of-rw.compile-crewrite-rule-trace-lemma2)



(%autoadmit rw.compile-crewrite-rule-trace)

(local (%enable default
                rw.compile-crewrite-rule-trace
                rw.crewrite-rule-tracep))

(%autoprove lemma-1-for-rw.compile-crewrite-rule-trace)
(%autoprove lemma-2-for-rw.compile-crewrite-rule-trace)
(%autoprove lemma-3-for-rw.compile-crewrite-rule-trace)
(%autoprove lemma-4-for-rw.compile-crewrite-rule-trace)
(%autoprove lemma-5-for-rw.compile-crewrite-rule-trace
            (%fertilize (logic.strip-conclusions proofs) (rw.trace-list-conclusion-formulas subtraces)))
(%autoprove lemma-6-for-rw.compile-crewrite-rule-trace
            (%fertilize (logic.strip-conclusions proofs) (rw.trace-list-conclusion-formulas subtraces)))

(local (%disable default
                 expensive-arithmetic-rules
                 expensive-arithmetic-rules-two
                 type-set-like-rules
                 expensive-subsetp-rules
                 same-length-prefixes-equal-cheap
                 formula-decomposition
                 unusual-consp-rules
                 expensive-term/formula-inference
                 ))

(local (%enable default
                lemma-1-for-rw.compile-crewrite-rule-trace
                lemma-2-for-rw.compile-crewrite-rule-trace
                lemma-3-for-rw.compile-crewrite-rule-trace
                lemma-4-for-rw.compile-crewrite-rule-trace
                lemma-5-for-rw.compile-crewrite-rule-trace
                lemma-6-for-rw.compile-crewrite-rule-trace))

(%autoprove rw.compile-crewrite-rule-trace-under-iff)

;; Speed hint from profile.
(local (%disable default
                 CONSP-WHEN-MEMBERP-OF-LOGIC.SIGMAP
                 CONSP-WHEN-MEMBERP-OF-LOGIC.SIGMA-ATBLP
                 MEMBERP-WHEN-NOT-CONSP
                 MEMBERP-OF-CAR-WHEN-MEMBER-OF-NONEP
                 CDR-WHEN-NOT-CONSP CAR-WHEN-NOT-CONSP
                 MEMBERP-WHEN-MEMBERP-OF-CDR
                 MEMBER-OF-NONEP-WHEN-NOT-CONSP
                 MEMBER-OF-NONEP-OF-CDR-WHEN-MEMBER-OF-NONEP
                 LOOKUP-WHEN-NOT-CONSP
                 TRUE-LISTP-OF-CAR-WHEN-TRUE-LIST-LISTP
                 TRUE-LISTP-WHEN-NOT-CONSP
                 LOGIC.SUBSTITUTE-WHEN-LOGIC.VARIABLEP
                 SUBMAPP-WHEN-UNIQUE-DOMAINS-AND-SUBSETP
                 LOOKUP-WHEN-LOOKUP-IN-SUBMAPP-ONE
                 LOGIC.POR-LIST-WHEN-NOT-CONSP-TWO
                 LOGIC.VARIABLEP-WHEN-LOOKUP-IN-LOGIC.SIGMAP
                 ALL-EQUALP-OF-SUBSETP-WHEN-ALL-EQUALP
                 DOMAIN-WHEN-NOT-CONSP
                 FORCING-LOGIC.SUBSTITUTE-OF-EMPTY-SIGMA
                 RW.HYP-LIST-TERMS-WHEN-NOT-CONSP
                 TRUE-LIST-LISTP-OF-CDR-WHEN-TRUE-LIST-LISTP
                 TRUE-LIST-LISTP-WHEN-NOT-CONSP
                 LOGIC.VRHSES-WHEN-NOT-CONSP
                 LOGIC.=LHSES-WHEN-NOT-CONSP
                 LOGIC.SUBSTITUTE-LIST-WHEN-NOT-CONSP
                 UNIQUEP-WHEN-NOT-CONSP
                 LOGIC.VARIABLEP-WHEN-LOOKUP-IN-LOGIC.SIGMA-ATBLP
                 SUBMAPP-OF-CAR-WHEN-SUBMAP-OF-EACHP
                 LOGIC.STRIP-FUNCTION-ARGS-WHEN-NOT-CONSP
                 SUBMAP-OF-EACHP-WHEN-NOT-CONSP
                 EQUAL-OF-BOOLEANS-REWRITE
                 RW.RULEP-OF-CAR-WHEN-RW.RULE-LISTP
                 TUPLEP-WHEN-NOT-CONSP
                 RW.RULE-LISTP-WHEN-NOT-CONSP
                 LOGIC.VLHSES-WHEN-NOT-CONSP
                 FORCING-LOGIC.SUBSTITUTE-LIST-OF-EMPTY-SIGMA
                 SUBMAP-OF-EACHP-OF-CDR-WHEN-SUBMAP-OF-EACHP
                 LOGIC.SIGMA-LISTP-WHEN-NOT-CONSP
                 LOGIC.ALL-DISJUNCTIONSP-WHEN-NOT-CONSP
                 STRIP-FIRSTS-WHEN-NOT-CONSP
                 LEN-WHEN-NOT-CONSP-OF-CDR-CHEAP
                 LOGIC.SIGMAP-WHEN-NOT-CONSP
                 STRIP-SECONDS-WHEN-NOT-CONSP
                 SUBSETP-WHEN-NOT-CONSP
                 LOGIC.SIGMAP-OF-CAR-WHEN-LOGIC.SIGMA-LISTP
                 LOGIC.=RHSES-WHEN-NOT-CONSP
                 RW.RULE-ATBLP-OF-CAR-WHEN-RW.RULE-LIST-ATBLP
                 RW.RULE-ENV-OKP-OF-CAR-WHEN-RW.RULE-LIST-ENV-OKP
                 SUBSETP-WHEN-NOT-CONSP-TWO
                 RW.RULE-LIST-ATBLP-WHEN-NOT-CONSP
                 RW.RULE-LIST-ENV-OKP-WHEN-NOT-CONSP
                 LOGIC.SIGMA-LIST-ATBLP-WHEN-NOT-CONSP
                 LOGIC.SIGMAP-OF-SECOND-WHEN-LOGIC.SIGMA-LISTP
                 LOGIC.SIGMA-ATBLP-WHEN-NOT-CONSP
                 LOGIC.SIGMA-ATBLP-OF-CAR-WHEN-LOGIC.SIGMA-LIST-ATBLP
                 STRIP-LENS-WHEN-NOT-CONSP
                 LOGIC.STRIP-FUNCTION-NAMES-WHEN-NOT-CONSP
                 LOGIC.ALL-FUNCTIONSP-WHEN-NOT-CONSP
                 LOGIC.ALL-ATOMICP-WHEN-NOT-CONSP
                 LOGIC.SIGMA-ATBLP-OF-SECOND-WHEN-LOGIC.SIGMA-LIST-ATBLP
                 LOGIC.SUBSTITUTE-WHEN-LOGIC.FUNCTIONP-CHEAP
                 RW.TRACE-LIST-CONCLUSION-FORMULAS-WHEN-NOT-CONSP
                 LOGIC.POR-LIST-WHEN-NOT-CONSP-ONE
                 LOGIC.SUBSTITUTE-WHEN-LOGIC.LAMBDAP-CHEAP
                 LOGIC.SUBSTITUTE-WHEN-LOGIC.CONSTANTP
                 LOGIC.SUBSTITUTE-WHEN-MALFORMED-CHEAP
                 LEN-WHEN-NOT-CONSP
                 FORCING-LOGIC.FUNCTIONP-WHEN-LOGIC.BASE-EVALUABLEP
                 LOGIC.SUBSTITUTE-LIST-OF-CONS-GROSS
                 UNIQUEP-WHEN-UNIQUEP-OF-DOMAIN
                 TUPLEP-WHEN-ZP
                 LOGIC.SIGMA-LISTP-OF-CDR-WHEN-LOGIC.SIGMA-LISTP
                 LOGIC.SIGMA-LIST-ATBLP-OF-CDR-WHEN-LOGIC.SIGMA-LIST-ATBLP
                 LOGIC.SIGMA-ATBLP-OF-CONS-GROSS))

(encapsulate
 ()
 (local (%max-proof-size 650000000))
 (%autoprove forcing-logic.appealp-of-rw.compile-crewrite-rule-trace))

(encapsulate
 ()
 (local (%max-proof-size 1300000000))
 (%autoprove forcing-logic.conclusion-of-rw.compile-crewrite-rule-trace))

(encapsulate
 ()
 (local (%max-proof-size 1400000000))
 (%autoprove forcing-logic.proofp-of-rw.compile-crewrite-rule-trace
             (%enable default rw.crewrite-rule-trace-env-okp)))

