; VL Verilog Toolkit
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

(in-package "VL")
(include-book "eventctrl")
(include-book "blockitems")
(include-book "lvalues")
(include-book "../../mlib/stmt-tools")
(local (include-book "../../util/arithmetic"))

;; Dumb accumulated persistence hacking
(local (in-theory (disable acl2::consp-under-iff-when-true-listp
                           member-equal-when-member-equal-of-cdr-under-iff
                           default-car
                           default-cdr
                           )))

(local (in-theory (disable character-listp
                           string-append
                           string-append-lst
                           append)))



; blocking_assignment ::=
;    lvalue '=' [delay_or_event_control] expression
;
; nonblocking_assignment ::=
;     lvalue '<=' [delay_or_event_control] expression

(defparser vl-parse-blocking-or-nonblocking-assignment (atts)
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
       (loc := (vl-current-loc))
       (lvalue := (vl-parse-lvalue))
       (type := (vl-match-some-token '(:vl-equalsign :vl-lte)))
       (when (vl-is-some-token? '(:vl-pound :vl-atsign :vl-kwd-repeat))
         (delay := (vl-parse-delay-or-event-control)))
       (expr := (vl-parse-expression))
       (return (vl-assignstmt (if (eq (vl-token->type type) :vl-equalsign)
                                  :vl-blocking
                                :vl-nonblocking)
                              lvalue expr delay atts loc))))

; procedural_continuous_assignments ::=
;    'assign' assignment
;  | 'deassign' lvalue
;  | 'force' assignment
;  | 'release' lvalue
;
; The verilog grammar makes it look worse than this, but with our treatment of
; assignment and lvalue, that's all there is to it.
;
; Curiously named production, given that only one can be returned.

(defparser vl-parse-procedural-continuous-assignments (atts)
  ;; Returns a vl-assignstmt-p or a vl-deassignstmt-p
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (when (vl-is-some-token? '(:vl-kwd-assign :vl-kwd-force))
          (type := (vl-match))
          ((lvalue . expr) := (vl-parse-assignment))
          (return (vl-assignstmt (if (eq (vl-token->type type) :vl-kwd-assign)
                                     :vl-assign
                                   :vl-force)
                                 lvalue expr nil atts
                                 (vl-token->loc type))))
        (type := (vl-match-some-token '(:vl-kwd-deassign :vl-kwd-release)))
        (lvalue := (vl-parse-lvalue))
        (return (vl-deassignstmt (if (eq (vl-token->type type) :vl-kwd-deassign)
                                     :vl-deassign
                                   :vl-release)
                                 lvalue atts))))


; task_enable ::=
;   hierarchical_task_identifier [ '(' expression { ',' expression } ')' ] ';'

(defparser vl-parse-task-enable (atts)
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (hid := (vl-parse-hierarchical-identifier nil))
        (when (vl-is-token? :vl-lparen)
          (:= (vl-match))
          (args := (vl-parse-1+-expressions-separated-by-commas))
          (:= (vl-match-token :vl-rparen)))
        (:= (vl-match-token :vl-semi))
        (return (vl-enablestmt hid args atts))))


; system_task_enable ::=
;    system_identifier [ '(' [expression] { ',' [expression] } ')' ] ';'

(defparser vl-parse-system-task-enable (atts)
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (id := (vl-match-token :vl-sysidtoken))
        (when (vl-is-token? :vl-lparen)
          (:= (vl-match))
          (args := (vl-parse-1+-expressions-separated-by-commas))
          (:= (vl-match-token :vl-rparen)))
        (:= (vl-match-token :vl-semi))
        (return
         (vl-enablestmt (make-vl-atom
                         :guts (make-vl-sysfunname
                                :name (vl-sysidtoken->name id)))
                        args atts))))


; disable_statement ::=
;    'disable' hierarchical_identifier ';'

(defparser vl-parse-disable-statement (atts)
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (:= (vl-match-token :vl-kwd-disable))
        (id := (vl-parse-hierarchical-identifier nil))
        (:= (vl-match-token :vl-semi))
        (return (vl-disablestmt id atts))))


; event_trigger ::=
;   '->' hierachial_identifier { '[' expression ']' } ';'

(defparser vl-parse-event-trigger (atts)
  :guard (vl-atts-p atts)
  :result (vl-stmt-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (:= (vl-match-token :vl-arrow))
        (hid := (vl-parse-hierarchical-identifier nil))
        (bexprs := (vl-parse-0+-bracketed-expressions))
        (:= (vl-match-token :vl-semi))
        (return (vl-eventtriggerstmt
                 (vl-build-indexing-nest hid bexprs) atts))))




; PARSING CASE STATEMENTS.
;
; The syntax of the case statement is essentially:
;
;    case_kwd (expr) case_item { case_item } endcase
;
; Where case_kwd is either 'case', 'casez', or 'casex', and where case_item is:
;
; case_item ::=
;    | expr { , expr } : stmt/null
;    | default [ : ] stmt/null
;
; Since we allow the null statement as an atomic statement, we can simplify
; this to:
;
;  case_item ::=
;     expr { , expr } : stmt
;   | default [ : ] stmt
;
; A basic note is that a case item such as
;
;    expr1, expr2, expr3 : stmt1
;
; Is semantically equivalent to three case items,
;
;    expr1 : stmt1
;    expr2 : stmt2
;    expr3 : stmt3
;
; According to Section 9.5 (page 127) the default statement is optional but at
; most one default statement is permitted.

(defaggregate vl-parsed-caseitem
  ;; Intermediate form for an individual case item.
  ;;   - Expr is NIL if this is a default case.
  ;;   - Expr is an expression otherwise.
  ((expr vl-maybe-expr-p)
   (stmt vl-stmt-p))
  :tag :vl-parsed-caseitem
  :parents (parser))

(deflist vl-parsed-caseitemlist-p (x)
  ;; Each case_item turns into a list of vl-parsed-caseitems.  This lets
  ;; us handle "expr1, expr2, expr3 : stmt;" by just building a list of the
  ;; for "expr1 : stmt; expr2 : stmt; expr3 : stmt;"
  (vl-parsed-caseitem-p x)
  :guard t
  :elementp-of-nil nil)

(defprojection vl-parsed-caseitemlist->exprs (x)
  (vl-parsed-caseitem->expr x)
  :guard (vl-parsed-caseitemlist-p x))

(defprojection vl-parsed-caseitemlist->stmts (x)
  (vl-parsed-caseitem->stmt x)
  :guard (vl-parsed-caseitemlist-p x)
  :result-type vl-stmtlist-p)

(define vl-make-parsed-caseitems ((stmt vl-stmt-p)
                                  (x vl-exprlist-p))
  ;; Given a stmt and a list of expressions, this builds the caseitemlist
  ;; corresponding to "expr1, expr2, ..., exprN : stmt".
  :returns (caseitemlist vl-parsed-caseitemlist-p :hyp :fguard)
  (if (atom x)
      nil
    (cons (make-vl-parsed-caseitem :stmt stmt :expr (car x))
          (vl-make-parsed-caseitems stmt (cdr x)))))

(define vl-filter-parsed-caseitemlist ((x vl-parsed-caseitemlist-p))
  ;; Given a list of case items, we walk over the list and gather up any
  ;; items with NIL expressions (i.e., any "default" cases) into one list,
  ;; and any items with non-default expressions into the other list.
  :returns (mv (defaults vl-parsed-caseitemlist-p :hyp :fguard)
               (non-defaults vl-parsed-caseitemlist-p :hyp :fguard))
  (b* (((when (atom x))
        (mv nil nil))
       ((mv defaults non-defaults)
        (vl-filter-parsed-caseitemlist (cdr x)))
       ((when (vl-parsed-caseitem->expr (car x)))
        (mv defaults (cons (car x) non-defaults))))
    (mv (cons (car x) defaults) non-defaults))
  ///
  (defmvtypes vl-filter-parsed-caseitemlist (true-listp true-listp))

  (defthm vl-exprlist-p-of-vl-parsed-caseitemlist->exprs-of-vl-filter-parsed-caseitemlist-1
    (implies (force (vl-parsed-caseitemlist-p x))
             (vl-exprlist-p
              (vl-parsed-caseitemlist->exprs
               (mv-nth 1 (vl-filter-parsed-caseitemlist x)))))))

; Additional statement constructors
;
; We now provide constructor functions for other kinds of statements, so we can
; take care of all the guard proofs, etc., without having to complicate the
; mutual recursion.

(define vl-make-case-statement
  ((type  (member type '(:vl-kwd-case :vl-kwd-casez :vl-kwd-casex)))
   (expr  vl-expr-p)
   (items vl-parsed-caseitemlist-p)
   (atts  vl-atts-p))
  ;; This either returns a STMT or NIL for failure.  The only reason it can
  ;; fail is that more than one "default" statement was provided.
  :returns (stmt? (equal (vl-stmt-p stmt?)
                         (if stmt? t nil))
                  :hyp :fguard)
  (b* (((mv defaults non-defaults)
        (vl-filter-parsed-caseitemlist items))
       ((when (> (len defaults) 1))
        ;; More than one default statement, fail!
        nil)
       (match-exprs (vl-parsed-caseitemlist->exprs non-defaults))
       (match-stmts (vl-parsed-caseitemlist->stmts non-defaults))
       (default     (if defaults
                        (vl-parsed-caseitem->stmt (car defaults))
                      (make-vl-nullstmt))))
      (make-vl-casestmt :casetype (case type
                                    (:vl-kwd-case  nil)
                                    (:vl-kwd-casex :vl-casex)
                                    (:vl-kwd-casez :vl-casez))
                        :test expr
                        :default default
                        :cases (pairlis$ match-exprs match-stmts)
                        :atts atts)))

(local (in-theory (disable

                   (:t acl2-count)
                   (:t vl-is-some-token?)
                   (:t vl-is-token?)
                   (:t vl-tokenlist-p)
                   acl2-count-positive-when-consp
                   acl2::acl2-count-when-member
                   acl2::cancel_plus-equal-correct
                   acl2::cancel_plus-lessp-correct
                   acl2::cancel_times-equal-correct
                   acl2::consp-by-len
                   acl2::consp-under-iff-when-true-listp
                   acl2::subsetp-member
                   acl2::true-listp-when-character-listp-rewrite
                   acl2::true-listp-when-string-listp-rewrite
                   acl2::true-listp-when-symbol-listp-rewrite
                   car-when-all-equalp
                   consp-when-member-equal-of-cons-listp
                   default-<-1
                   default-<-2
                   double-containment
                   first-under-iff-when-vl-exprlist-p
                   integerp-when-natp
                   member-equal-when-member-equal-of-cdr-under-iff
                   natp-when-posp
                   not
                   rationalp-implies-acl2-numberp
                   rationalp-when-integerp
                   set::sets-are-true-lists
                   vl-stmt-p-when-member-equal-of-vl-stmtlist-p
                   vl-tokenlist-p-when-subsetp-equal
                   vl-tokenlist-p-when-member-equal-of-vl-tokenlistlist-p
                   ;; new ones
                   acl2::len-when-prefixp
                   acl2::lower-bound-of-len-when-sublistp
                   ;acl2::member-of-cons
                   acl2::prefixp-when-equal-lengths
                   acl2::sublistp-when-prefixp
                   acl2::subsetp-member
                   car-when-all-equalp
                   consp-when-member-equal-of-vl-defines-p
                   default-+-2
                   member-equal-when-all-equalp
                   member-equal-when-member-equal-of-cdr-under-iff
                   )))


(defparsers parse-statements

; case_statement ::=
;    'case' '(' expression ')' case_item { case_item } 'endcase'
;  | 'casez' '(' expression ')' case_item { case_item } 'endcase'
;  | 'casex' '(' expression ')' case_item { case_item } 'endcase'
;
; case_item ::=
;    expression { ',' expression } ':' statement_or_null
;  | 'default' [ ':' ] statement_or_null

  :flag-local nil
 (defparser vl-parse-case-item ()
   ;; Returns a vl-parsed-caseitemlist-p
   :measure (two-nats-measure (len tokens) 0)
   :verify-guards nil
   (seqw tokens warnings
         (when (vl-is-token? :vl-kwd-default)
           (:= (vl-match))
           (when (vl-is-token? :vl-colon)
             (:= (vl-match)))
           (stmt := (vl-parse-statement-or-null))
           (return (list (make-vl-parsed-caseitem :expr nil
                                                  :stmt stmt))))
         (exprs :s= (vl-parse-1+-expressions-separated-by-commas))
         (:= (vl-match-token :vl-colon))
         (stmt := (vl-parse-statement-or-null))
         (return (vl-make-parsed-caseitems stmt exprs))))

 (defparser vl-parse-1+-case-items ()
   :measure (two-nats-measure (len tokens) 1)
   ;; Returns a vl-parsed-caseitemlist-p
   ;; We keep reading until 'endcase' is encountered
   (seqw tokens warnings
         (first :s= (vl-parse-case-item))
         (when (vl-is-token? :vl-kwd-endcase)
           (return first))
         (rest := (vl-parse-1+-case-items))
         (return (append first rest))))

 (defparser vl-parse-case-statement (atts)
   ;; Returns a vl-stmt-p
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (type := (vl-match-some-token '(:vl-kwd-case :vl-kwd-casez :vl-kwd-casex)))
         (:= (vl-match-token :vl-lparen))
         (test :s= (vl-parse-expression))
         (:= (vl-match-token :vl-rparen))
         (items := (vl-parse-1+-case-items))
         (:= (vl-match-token :vl-kwd-endcase))
         (return-raw
          (let ((stmt (vl-make-case-statement (vl-token->type type) test items atts)))
            (if (not stmt)
                (vl-parse-error "Multiple defaults cases in case statement.")
              (mv nil stmt tokens warnings))))))


; conditional_statement ::=
;    'if' '(' expression ')' statement_or_null
;      { 'else' 'if' '(' expression ')' statement_or_null }
;      [ 'else' statement_or_null ]
;
; This suffers from the dangling else problem.  Per 9.4, an "else" should be
; bound to the closest if which does not have an else, which is good because
; that's easy to write.

; BOZO test this extensively.  I think it's right but it seems somehow subtle.

 (defparser vl-parse-conditional-statement (atts)
   ;; Returns a vl-stmt-p
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (iftok := (vl-match-token :vl-kwd-if))
         (:= (vl-match-token :vl-lparen))
         (expr :s= (vl-parse-expression))
         (:= (vl-match-token :vl-rparen))
         (then :s= (vl-parse-statement-or-null))
         (when (vl-is-token? :vl-kwd-else)
           (:= (vl-match))
           (else := (vl-parse-statement-or-null)))
         (return (make-vl-ifstmt :condition expr
                                 :truebranch then
                                 :falsebranch (or else (vl-nullstmt nil))
                                 :atts atts))))


; loop_statement ::=
;    'forever' statement
;  | 'repeat' '(' expression ')' statement
;  | 'while' '(' expression ')' statement
;  | 'for' '(' variable_assignment ';' expression ';' variable_assignment ')'
;      statement

 (defparser vl-parse-loop-statement (atts)
   ;; Returns a vl-foreverstmt-p, vl-repeatstmt-p, vl-whilestmt-p, or vl-forstmt-p
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings

         (when (vl-is-token? :vl-kwd-forever)
           (:= (vl-match-token :vl-kwd-forever))
           (stmt :s= (vl-parse-statement))
           (return (make-vl-foreverstmt :body stmt
                                        :atts atts)))

         (when (vl-is-some-token? '(:vl-kwd-repeat :vl-kwd-while))
           (type := (vl-match))
           (:= (vl-match-token :vl-lparen))
           (expr :s= (vl-parse-expression))
           (:= (vl-match-token :vl-rparen))
           (stmt :s= (vl-parse-statement))
           (return (case (vl-token->type type)
                     (:vl-kwd-repeat (make-vl-repeatstmt :condition expr
                                                         :body stmt
                                                         :atts atts))
                     (:vl-kwd-while  (make-vl-whilestmt :condition expr
                                                        :body stmt
                                                        :atts atts)))))

         (:= (vl-match-token :vl-kwd-for))
         (:= (vl-match-token :vl-lparen))
         ((initlhs . initrhs) :s= (vl-parse-assignment))
         (:= (vl-match-token :vl-semi))
         (test :s= (vl-parse-expression))
         (:= (vl-match-token :vl-semi))
         ((nextlhs . nextrhs) :s= (vl-parse-assignment))
         (:= (vl-match-token :vl-rparen))
         (body := (vl-parse-statement))
         (return (make-vl-forstmt :initlhs initlhs
                                  :initrhs initrhs
                                  :test test
                                  :nextlhs nextlhs
                                  :nextrhs nextrhs
                                  :body body
                                  :atts atts))))


; par_block ::=
;   'fork' [ ':' identifier { block_item_declaration } ]
;      { statement }
;   'join'

 (defparser vl-parse-par-block (atts)
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (:= (vl-match-token :vl-kwd-fork))
         (when (vl-is-token? :vl-colon)
           (:= (vl-match))
           (id := (vl-match-token :vl-idtoken))
           (items :w= (vl-parse-0+-block-item-declarations)))
         (stmts := (vl-parse-statements-until-join))
         (:= (vl-match-token :vl-kwd-join))
         (return (make-vl-blockstmt :sequentialp nil
                                    :name (and id (vl-idtoken->name id))
                                    :decls items
                                    :stmts stmts
                                    :atts atts))))


; seq_block ::=
;    'begin' [ ':' identifier { block_item_declaration } ]
;       { statement }
;    'end'

 (defparser vl-parse-seq-block (atts)
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (:= (vl-match-token :vl-kwd-begin))
         (when (vl-is-token? :vl-colon)
           (:= (vl-match))
           (id := (vl-match-token :vl-idtoken))
           (items :w= (vl-parse-0+-block-item-declarations)))
         (stmts := (vl-parse-statements-until-end))
         (:= (vl-match-token :vl-kwd-end))
         (return (make-vl-blockstmt :sequentialp t
                                    :name (and id (vl-idtoken->name id))
                                    :decls items
                                    :stmts stmts
                                    :atts atts))))


; procedural_timing_control_statement ::=
;    procedural_timing_control statement_or_null
;
; procedural_timing_control ::=
;    delay_control
;  | event_control

 (defparser vl-parse-procedural-timing-control-statement (atts)
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (ctrl :s= (if (vl-is-token? :vl-atsign)
                       (vl-parse-event-control)
                     (vl-parse-delay-control)))
         (stmt := (vl-parse-statement-or-null))
         (return (make-vl-timingstmt :ctrl ctrl
                                     :body stmt
                                     :atts atts))))



; wait_statement ::=
;    'wait' '(' expression ')' statement_or_null

 (defparser vl-parse-wait-statement (atts)
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 0)
   (seqw tokens warnings
         (:= (vl-match-token :vl-kwd-wait))
         (:= (vl-match-token :vl-lparen))
         (expr :s= (vl-parse-expression))
         (:= (vl-match-token :vl-rparen))
         (stmt := (vl-parse-statement-or-null))
         (return (make-vl-waitstmt :condition expr
                                   :body stmt
                                   :atts atts))))


; statement ::=                                                      ;;; starts with
;    {attribute_instance} blocking_assignment ';'                    ;;; variable_lvalue
;  | {attribute_instance} case_statement                             ;;; 'case', 'casez', 'casex'
;  | {attribute_instance} conditional_statement                      ;;; 'if'
;  | {attribute_instance} disable_statement                          ;;; 'disable'
;  | {attribute_instance} event_trigger                              ;;; '->'
;  | {attribute_instance} loop_statement                             ;;; 'forever', 'repeat', 'while', 'for'
;  | {attribute_instance} nonblocking_assignment ';'                 ;;; variable_lvalue
;  | {attribute_instance} par_block                                  ;;; 'fork'
;  | {attribute_instance} procedural_continuous_assignments ';'      ;;; 'assign', 'deassign', 'force', 'release'
;  | {attribute_instance} procedural_timing_control_statement        ;;; '#', '@'
;  | {attribute_instance} seq_block                                  ;;; 'begin'
;  | {attribute_instance} system_task_enable                         ;;; sysidtoken
;  | {attribute_instance} task_enable                                ;;; hierarchical_identifier
;  | {attribute_instance} wait_statement                             ;;; 'wait'
;
; statement_or_null ::=
;    statement
;  | {attribute_instance} ';'

 (defparser vl-parse-statement-aux (atts)
   :guard (vl-atts-p atts)
   :measure (two-nats-measure (len tokens) 1)
   (if (not (consp tokens))
       (vl-parse-error "Unexpected EOF.")
     (case (vl-token->type (car tokens))
       ;; Blocking assignment handled below.
       ((:vl-kwd-case :vl-kwd-casez :vl-kwd-casex)
        (vl-parse-case-statement atts))
       (:vl-kwd-if
        (vl-parse-conditional-statement atts))
       (:vl-kwd-disable
        (vl-parse-disable-statement atts))
       (:vl-arrow
        (vl-parse-event-trigger atts))
       ((:vl-kwd-forever :vl-kwd-repeat :vl-kwd-while :vl-kwd-for)
        (vl-parse-loop-statement atts))
       ;; Nonblocking assignment handled below.
       (:vl-kwd-fork
        (vl-parse-par-block atts))
       ((:vl-kwd-assign :vl-kwd-deassign :vl-kwd-force :vl-kwd-release)
        (seqw tokens warnings
              (ret := (vl-parse-procedural-continuous-assignments atts))
              (:= (vl-match-token :vl-semi))
              (return ret)))
       ((:vl-pound :vl-atsign)
        (vl-parse-procedural-timing-control-statement atts))
       (:vl-kwd-begin
        (vl-parse-seq-block atts))
       (:vl-sysidtoken
        (vl-parse-system-task-enable atts))
       ;; Task enable handled below
       (:vl-kwd-wait
        (vl-parse-wait-statement atts))
       (t
        ;; At this point, we can have either a blocking assignment, nonblocking
        ;; assignment, or task enable.  We will backtrack.  It doesn't matter
        ;; which order we try these, because the assignment will only think it
        ;; is successful when it sees an equal sign after the lvalue, while the
        ;; enable looks for a semicolon after the identifier, so there are no
        ;; inputs for which they both believe they are successful.
        (mv-let (erp val explore new-warnings)
                (seqw tokens warnings
                     (ret := (vl-parse-blocking-or-nonblocking-assignment atts))
                     (:= (vl-match-token :vl-semi))
                     (return ret))
                (if erp
                    (vl-parse-task-enable atts)
                  (mv erp val explore new-warnings)))))))

 (defparser vl-parse-statement ()
   :measure (two-nats-measure (len tokens) 2)
   ;; Returns a vl-stmt-p.
   (seqw tokens warnings
         (atts :w= (vl-parse-0+-attribute-instances))
         (ret := (vl-parse-statement-aux atts))
         (return ret)))

 (defparser vl-parse-statement-or-null ()
   ;; Returns a vl-stmt-p.  (This is possible because we allow nullstmt as a
   ;; valid vl-stmt-p.)
   :measure (two-nats-measure (len tokens) 2)
   (seqw tokens warnings
         (atts :w= (vl-parse-0+-attribute-instances))
         (when (vl-is-token? :vl-semi)
           (:= (vl-match-token :vl-semi))
           (return (make-vl-nullstmt :atts atts)))
         (ret := (vl-parse-statement-aux atts))
         (return ret)))

 (defparser vl-parse-statements-until-join ()
   :measure (two-nats-measure (len tokens) 3)
   ;; Returns a list of vl-stmt-p's.
   ;; Tries to read until the keyword "join"
   (seqw tokens warnings
         (when (vl-is-token? :vl-kwd-join)
           (return nil))
         (first :s= (vl-parse-statement))
         (rest := (vl-parse-statements-until-join))
         (return (cons first rest))))

 (defparser vl-parse-statements-until-end ()
   :measure (two-nats-measure (len tokens) 3)
   ;; Returns a list of vl-stmt-p's.
   ;; Tries to read until the keyword "end"
   (seqw tokens warnings
         (when (vl-is-token? :vl-kwd-end)
           (return nil))
         (first :s= (vl-parse-statement))
         (rest := (vl-parse-statements-until-end))
         (return (cons first rest)))))


(defsection error

  (with-output
    :off prove :gag-mode :goals
    (make-event
     `(defthm-parse-statements-flag vl-parse-statement-val-when-error
        ,(vl-val-when-error-claim vl-parse-case-item)
        ,(vl-val-when-error-claim vl-parse-1+-case-items)
        ,(vl-val-when-error-claim vl-parse-case-statement
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-conditional-statement
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-loop-statement
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-par-block
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-seq-block
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-procedural-timing-control-statement
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-wait-statement
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-statement-aux
                                  :args (atts))
        ,(vl-val-when-error-claim vl-parse-statement)
        ,(vl-val-when-error-claim vl-parse-statement-or-null)
        ,(vl-val-when-error-claim vl-parse-statements-until-end)
        ,(vl-val-when-error-claim vl-parse-statements-until-join)
        :hints('(:do-not '(simplify))
               (flag::expand-calls-computed-hint
                acl2::clause
                ',(flag::get-clique-members 'vl-parse-statement-fn
                                            (w state)))
               (and stable-under-simplificationp
                    '(:do-not nil)))))))


(defsection progress

  (with-output
    :off prove :gag-mode :goals
    (make-event
     `(defthm-parse-statements-flag vl-parse-statement-progress
        ,(vl-progress-claim vl-parse-case-item)
        ,(vl-progress-claim vl-parse-1+-case-items)
        ,(vl-progress-claim vl-parse-case-statement :args (atts))
        ,(vl-progress-claim vl-parse-conditional-statement :args (atts))
        ,(vl-progress-claim vl-parse-loop-statement :args (atts))
        ,(vl-progress-claim vl-parse-par-block :args (atts))
        ,(vl-progress-claim vl-parse-seq-block :args (atts))
        ,(vl-progress-claim vl-parse-procedural-timing-control-statement :args (atts))
        ,(vl-progress-claim vl-parse-wait-statement :args (atts))
        ,(vl-progress-claim vl-parse-statement-aux :args (atts))
        ,(vl-progress-claim vl-parse-statement)
        ,(vl-progress-claim vl-parse-statement-or-null)

        (vl-parse-statements-until-end
         (and (<= (len (mv-nth 2 (vl-parse-statements-until-end)))
                  (len tokens))
              (implies (and (not (mv-nth 0 (vl-parse-statements-until-end)))
                            (mv-nth 1 (vl-parse-statements-until-end)))
                       (< (len (mv-nth 2 (vl-parse-statements-until-end)))
                          (len tokens))))
         :rule-classes ((:rewrite) (:linear)))

        (vl-parse-statements-until-join
         (and (<= (len (mv-nth 2 (vl-parse-statements-until-join)))
                  (len tokens))
              (implies (and (not (mv-nth 0 (vl-parse-statements-until-join)))
                            (mv-nth 1 (vl-parse-statements-until-join)))
                       (< (len (mv-nth 2 (vl-parse-statements-until-join)))
                          (len tokens))))
         :rule-classes ((:rewrite) (:linear)))

        :hints((flag::expand-calls-computed-hint
                acl2::clause
                ',(flag::get-clique-members 'vl-parse-statement-fn (w state))))))))


(defsection tokenlist

  (with-output
    :off prove :gag-mode :goals
    (make-event
     `(defthm-parse-statements-flag vl-parse-statement-tokenlist
        ,(vl-tokenlist-claim vl-parse-case-item)
        ,(vl-tokenlist-claim vl-parse-1+-case-items)
        ,(vl-tokenlist-claim vl-parse-case-statement :args (atts))
        ,(vl-tokenlist-claim vl-parse-conditional-statement :args (atts))
        ,(vl-tokenlist-claim vl-parse-loop-statement :args (atts))
        ,(vl-tokenlist-claim vl-parse-par-block :args (atts))
        ,(vl-tokenlist-claim vl-parse-seq-block :args (atts))
        ,(vl-tokenlist-claim vl-parse-procedural-timing-control-statement :args (atts))
        ,(vl-tokenlist-claim vl-parse-wait-statement :args (atts))
        ,(vl-tokenlist-claim vl-parse-statement-aux :args (atts))
        ,(vl-tokenlist-claim vl-parse-statement)
        ,(vl-tokenlist-claim vl-parse-statement-or-null)
        ,(vl-tokenlist-claim vl-parse-statements-until-end)
        ,(vl-tokenlist-claim vl-parse-statements-until-join)
        :hints((and acl2::stable-under-simplificationp
                    (flag::expand-calls-computed-hint
                     acl2::clause
                     ',(flag::get-clique-members 'vl-parse-statement-fn (w state)))))))))


(defsection warninglist

  (with-output
    :off prove :gag-mode :goals
    (make-event
     `(defthm-parse-statements-flag vl-parse-statement-warninglist
        ,(vl-warninglist-claim vl-parse-case-item)
        ,(vl-warninglist-claim vl-parse-1+-case-items)
        ,(vl-warninglist-claim vl-parse-case-statement :args (atts))
        ,(vl-warninglist-claim vl-parse-conditional-statement :args (atts))
        ,(vl-warninglist-claim vl-parse-loop-statement :args (atts))
        ,(vl-warninglist-claim vl-parse-par-block :args (atts))
        ,(vl-warninglist-claim vl-parse-seq-block :args (atts))
        ,(vl-warninglist-claim vl-parse-procedural-timing-control-statement :args (atts))
        ,(vl-warninglist-claim vl-parse-wait-statement :args (atts))
        ,(vl-warninglist-claim vl-parse-statement-aux :args (atts))
        ,(vl-warninglist-claim vl-parse-statement)
        ,(vl-warninglist-claim vl-parse-statement-or-null)
        ,(vl-warninglist-claim vl-parse-statements-until-end)
        ,(vl-warninglist-claim vl-parse-statements-until-join)
        :hints((and acl2::stable-under-simplificationp
                    (flag::expand-calls-computed-hint
                     acl2::clause
                     ',(flag::get-clique-members 'vl-parse-statement-fn (w state)))))))))


(defsection result

  (defun vl-stmt-claim-fn (name args extra-hyps type true-listp)
    (let* ((claim     (ACL2::substitute `(mv-nth 1 (,name . ,args)) 'val type)))
      `'(,name (implies (and (force (not (mv-nth 0 (,name . ,args))))
                             ,@extra-hyps)
                        ,(if true-listp
                             `(and ,claim
                                   (true-listp (mv-nth 1 (,name . ,args))))
                           claim)))))

  (defmacro vl-stmt-claim (name type &key args extra-hyps true-listp)
    (vl-stmt-claim-fn name args extra-hyps type true-listp))

  (with-output
    :off prove :gag-mode :goals
    (make-event
     `(defthm-parse-statements-flag vl-parse-statement-type

        ,(vl-stmt-claim vl-parse-case-item
                        (vl-parsed-caseitemlist-p val)
                        :true-listp t)
        ,(vl-stmt-claim vl-parse-1+-case-items
                        (vl-parsed-caseitemlist-p val)
                        :true-listp t)
        ,(vl-stmt-claim vl-parse-case-statement
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-conditional-statement
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-loop-statement
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-par-block
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-seq-block
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-procedural-timing-control-statement
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-wait-statement
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-statement-aux
                        (vl-stmt-p val)
                        :args (atts)
                        :extra-hyps ((force (vl-atts-p atts))))
        ,(vl-stmt-claim vl-parse-statement
                        (vl-stmt-p val))
        ,(vl-stmt-claim vl-parse-statement-or-null
                        (vl-stmt-p val))
        ,(vl-stmt-claim vl-parse-statements-until-end
                        (vl-stmtlist-p val)
                        :true-listp t)
        ,(vl-stmt-claim vl-parse-statements-until-join
                        (vl-stmtlist-p val)
                        :true-listp t)
        :hints((and acl2::stable-under-simplificationp
                    (flag::expand-calls-computed-hint
                     acl2::clause
                     ',(flag::get-clique-members 'vl-parse-statement-fn (w state)))))))))


(local (defthm vl-parse-event-control-value-under-iff
         ;; BOZO not sure why I suddenly need this
         (implies (and (not (mv-nth 0 (vl-parse-event-control))))
                  (mv-nth 1 (vl-parse-event-control)))
         :hints(("Goal"
                 :in-theory (disable vl-parse-event-control-result)
                 :use ((:instance vl-parse-event-control-result))))))

(local (defthm vl-parse-delay-control-value-under-iff
         ;; BOZO not sure why I suddenly need this
         (implies (and (not (mv-nth 0 (vl-parse-delay-control))))
                  (mv-nth 1 (vl-parse-delay-control)))
         :hints(("Goal"
                 :in-theory (disable vl-parse-delay-control-result)
                 :use ((:instance vl-parse-delay-control-result))))))

(with-output
 :off prove
 :gag-mode :goals
 (verify-guards vl-parse-statement-fn))

