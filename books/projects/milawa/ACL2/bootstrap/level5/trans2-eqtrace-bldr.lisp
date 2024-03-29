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
(include-book "trans1-eqtrace-bldr")
(%interactive)

(local (%max-proof-size 700000000))

(defsection rw.trans2-eqtrace-bldr

  (%autoadmit rw.trans2-eqtrace-bldr)

  (local (%enable default
                  rw.eqtrace-formula
                  rw.trans2-eqtrace-bldr
                  rw.trans2-eqtrace-okp))
  (%autoprove rw.trans2-eqtrace-bldr-under-iff)
  (local (%enable default
                  lemma-1-for-forcing-logic.appealp-of-rw.trans1-eqtrace-bldr
                  lemma-2-for-forcing-logic.appealp-of-rw.trans1-eqtrace-bldr
                  lemma-3-for-forcing-logic.appealp-of-rw.trans1-eqtrace-bldr
                  lemma-4-for-forcing-logic.appealp-of-rw.trans1-eqtrace-bldr))

  ;; this is looping with one of the recent rewriter changes
  (local (%disable default RW.EQTRACE->LHS-OF-SUB1-WHEN-RW.TRANS2-EQTRACE-OKP))

  (%autoprove forcing-logic.appealp-of-rw.trans2-eqtrace-bldr)
  (%autoprove forcing-logic.conclusion-of-rw.trans2-eqtrace-bldr)
  (%autoprove forcing-logic.proofp-of-rw.trans2-eqtrace-bldr))

(%ensure-exactly-these-rules-are-missing "../../rewrite/assms/trans2-eqtrace-bldr")

