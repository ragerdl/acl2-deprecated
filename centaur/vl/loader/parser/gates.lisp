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
(include-book "strengths")
(include-book "delays")
(include-book "ranges")
(include-book "lvalues")
(include-book "../../mlib/expr-tools")
(local (include-book "../../util/arithmetic"))


(local (in-theory (disable acl2::consp-under-iff-when-true-listp
                           member-equal-when-member-equal-of-cdr-under-iff
                           default-car
                           default-cdr
                           ;consp-when-vl-atomguts-p
                           ;tag-when-vl-ifstmt-p
                           ;tag-when-vl-seqblockstmt-p
                           )))

;                         PARSING GATE INSTANTIATIONS
;
; There are a lot of alternatives for gate_instantiation.  We present the whole
; thing here, then go through each one, individually, below.
;
; gate_instantiation ::=
;    cmos_switchtype                     [delay3] cmos_switch_instance        { ',' cmos_switch_instance        } ';'
;  | enable_gatetype    [drive_strength] [delay3] enable_gate_instance        { ',' enable_gate_instance        } ';'
;  | mos_switchtype                      [delay3] mos_switch_instance         { ',' mos_switch_instance         } ';'
;  | n_input_gatetype   [drive_strength] [delay2] n_input_gate_instance       { ',' n_input_gate_instance       } ';'
;  | n_output_gatetype  [drive_strength] [delay2] n_output_gate_instance      { ',' n_output_gate_instance      } ';'
;  | pass_en_switchtype                  [delay2] pass_enable_switch_instance { ',' pass_enable_switch_instance } ';'
;  | pass_switchtype                              pass_switch_instance        { ',' pass_switch_instance        } ';'
;  | 'pulldown'         [pulldown_strength]       pull_gate_instance          { ',' pull_gate_instance          } ';'
;  | 'pullup'           [pullup_strength]         pull_gate_instance          { ',' pull_gate_instance          } ';'

(defun vl-gatebldr-tuple-p (x)
  (declare (xargs :guard t))
  (and (tuplep 3 x)
       (maybe-stringp (first x)) ;; name
       (vl-maybe-range-p (second x)) ;; range
       (vl-exprlist-p (third x))))   ;; args

(deflist vl-gatebldr-tuple-list-p (x)
  (vl-gatebldr-tuple-p x)
  :elementp-of-nil nil
  :parents nil)

(defund vl-build-gate-instances (loc tuples type strength delay atts)
  (declare (xargs :guard (and (vl-location-p loc)
                              (vl-gatebldr-tuple-list-p tuples)
                              (vl-gatetype-p type)
                              (vl-maybe-gatestrength-p strength)
                              (vl-maybe-gatedelay-p delay)
                              (vl-atts-p atts))))
  (if (consp tuples)
      (cons (make-vl-gateinst :loc loc
                              :type type
                              :name (first (car tuples))
                              :range (second (car tuples))
                              :strength strength
                              :delay delay
                              :args (vl-exprlist-to-plainarglist
                                     (third (car tuples)))
                              :atts atts)
            (vl-build-gate-instances loc (cdr tuples) type strength delay atts))
    nil))

(defthm vl-gateinstlist-p-of-vl-build-gate-instances
  (implies (and (force (vl-location-p loc))
                (force (vl-gatebldr-tuple-list-p tuples))
                (force (vl-gatetype-p type))
                (force (vl-maybe-gatestrength-p strength))
                (force (vl-maybe-gatedelay-p delay))
                (force (vl-atts-p atts)))
           (vl-gateinstlist-p (vl-build-gate-instances loc tuples type strength delay atts)))
  :hints(("Goal" :in-theory (enable vl-build-gate-instances))))






; Gate Types.
;
; cmos_switchtype ::= 'cmos' | 'rcmos'
; enable_gatetype ::= 'bufif0' | 'bufif1' | 'notif0' | 'notif1'
; mos_switchtype ::= 'nmos' | 'pmos' | 'rnmos' | 'rpmos'
; n_input_gatetype ::= 'and' | 'nand' | 'or' | 'nor' | 'xor' | 'xnor'
; n_output_gatetype ::= 'buf' | 'not'
; pass_en_switchtype ::= 'tranif0' | 'tranif1' | 'rtranif1' | 'rtranif0'
; pass_switchtype ::= 'tran' | 'rtran'

(defconst *vl-cmos-switchtype-alist*
  '((:vl-kwd-cmos  . :vl-cmos)
    (:vl-kwd-rcmos . :vl-rcmos)))

(defconst *vl-enable-gatetype-alist*
  '((:vl-kwd-bufif0 . :vl-bufif0)
    (:vl-kwd-bufif1 . :vl-bufif1)
    (:vl-kwd-notif0 . :vl-notif0)
    (:vl-kwd-notif1 . :vl-notif1)))

(defconst *vl-mos-switchtype-alist*
  '((:vl-kwd-nmos  . :vl-nmos)
    (:vl-kwd-pmos  . :vl-pmos)
    (:vl-kwd-rnmos . :vl-rnmos)
    (:vl-kwd-rpmos . :vl-rpmos)))

(defconst *vl-n-input-gatetype-alist*
  '((:vl-kwd-and  . :vl-and)
    (:vl-kwd-nand . :vl-nand)
    (:vl-kwd-or   . :vl-or)
    (:vl-kwd-nor  . :vl-nor)
    (:vl-kwd-xor  . :vl-xor)
    (:vl-kwd-xnor . :vl-xnor)))

(defconst *vl-n-output-gatetype-alist*
  '((:vl-kwd-buf . :vl-buf)
    (:vl-kwd-not . :vl-not)))

(defconst *vl-pass-en-switchtype-alist*
  '((:vl-kwd-tranif0  . :vl-tranif0)
    (:vl-kwd-tranif1  . :vl-tranif1)
    (:vl-kwd-rtranif1 . :vl-rtranif1)
    (:vl-kwd-rtranif0 . :vl-rtranif0)))

(defconst *vl-pass-switchtype-alist*
  '((:vl-kwd-tran  . :vl-tran)
    (:vl-kwd-rtran . :vl-rtran)))

(defconst *vl-pull-gate-alist*
  '((:vl-kwd-pullup   . :vl-pullup)
    (:vl-kwd-pulldown . :vl-pulldown)))

(defconst *vl-gate-type-keywords*
  (append (strip-cars *vl-cmos-switchtype-alist*)
          (strip-cars *vl-enable-gatetype-alist*)
          (strip-cars *vl-mos-switchtype-alist*)
          (strip-cars *vl-n-input-gatetype-alist*)
          (strip-cars *vl-n-output-gatetype-alist*)
          (strip-cars *vl-pass-en-switchtype-alist*)
          (strip-cars *vl-pass-switchtype-alist*)
          (strip-cars *vl-pull-gate-alist*)))




; name_of_gate_instance ::= identifier [ range ]

(defparser vl-parse-optional-name-of-gate-instance ()
  :result (and (consp val)
               (maybe-stringp (car val)) ;; the name
               (vl-maybe-range-p (cdr val))) ;; the range
  :fails gracefully
  :count weak
  ;; Note that even though this is "optional", it can fail, because we assume
  ;; that if there is a bracket after the identifier, then there is supposed to
  ;; be a range.
  (seqw tokens warnings
        (when (vl-is-token? :vl-idtoken)
          (id := (vl-match-token :vl-idtoken))
          (when (vl-is-token? :vl-lbrack)
            (range := (vl-parse-range)))
          (return (cons (vl-idtoken->name id) range)))
        (return (cons nil nil))))





; CMOS Gates.
;
; gate_instantiation ::=
;     cmos_switchtype [delay3] cmos_switch_instance { ',' cmos_switch_instance } ';'
;
; cmos_switch_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' expression ',' expression ',' expression ')'

(defparser vl-parse-cmos-switch-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        (arg1 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (arg2 := (vl-parse-expression))
        (:= (vl-match-token :vl-comma))
        (arg3 := (vl-parse-expression))
        (:= (vl-match-token :vl-comma))
        (arg4 := (vl-parse-expression))
        (rparen := (vl-match-token :vl-rparen))
        (return (list name range (list arg1 arg2 arg3 arg4)))))

(defparser vl-parse-cmos-switch-instances-list ()
  ;; Matches cmos_switch_instance { ',' cmos_switch_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-cmos-switch-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-cmos-switch-instances-list)))
        (return (cons first rest))))

(defconst *vl-cmos-switchtype-type-kwds*
  (strip-cars *vl-cmos-switchtype-alist*))

(defparser vl-parse-cmos-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-cmos-switchtype-type-kwds*))
        ;; No strength on cmos gates.
        (when (vl-is-token? :vl-pound)
          (delay := (vl-parse-delay3)))
        (tuples := (vl-parse-cmos-switch-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-cmos-switchtype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type nil delay atts)))))




; ENABLE and MOS Gates.
;
; gate_instantiation ::=
;    enable_gatetype [drive_strength] [delay3] enable_gate_instance { ',' enable_gate_instance } ';'
;  | mos_switchtype [delay3] mos_switch_instance { ',' mos_switch_instance } ';'
;
; enable_gate_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' expression ',' expression ')'
;
; mos_switch_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' expression ',' expression ')'
;
; Since these instances are the same, we handle them together.

(defparser vl-parse-enable-or-mos-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        (arg1 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (arg2 := (vl-parse-expression))
        (:= (vl-match-token :vl-comma))
        (arg3 := (vl-parse-expression))
        (rparen := (vl-match-token :vl-rparen))
        (return (list name range (list arg1 arg2 arg3)))))

(defparser vl-parse-enable-or-mos-instances-list ()
  ;; Matches enable_gate_instance { ',' enable_gate_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-enable-or-mos-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-enable-or-mos-instances-list)))
        (return (cons first rest))))

(defconst *vl-enable-gatetype-type-kwds* (strip-cars *vl-enable-gatetype-alist*))

(defparser vl-parse-enable-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-enable-gatetype-type-kwds*))
        (strength := (vl-parse-optional-drive-strength))
        (when (vl-is-token? :vl-pound)
          (delay := (vl-parse-delay3)))
        (tuples := (vl-parse-enable-or-mos-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-enable-gatetype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type strength delay atts)))))

(defconst *vl-mos-switchtype-type-kwds* (strip-cars *vl-mos-switchtype-alist*))

(defparser vl-parse-mos-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
       (typekwd := (vl-match-some-token *vl-mos-switchtype-type-kwds*))
       ;; No strength on mos gates.
       (when (vl-is-token? :vl-pound)
         (delay := (vl-parse-delay3)))
       (tuples := (vl-parse-enable-or-mos-instances-list))
       (semi := (vl-match-token :vl-semi))
       (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                          *vl-mos-switchtype-alist*))))
                 (vl-build-gate-instances (vl-token->loc typekwd)
                                          tuples type nil delay atts)))))




; N-INPUT Gates.
;
; gate_instantiation ::=
;    n_input_gatetype [drive_strength] [delay2] n_input_gate_instance { ',' n_input_gate_instance } ';'
;
; n_input_gate_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' expression { ',' expression } ')'

(defparser vl-parse-n-input-gate-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        (arg1 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (others := (vl-parse-1+-expressions-separated-by-commas))
        (rparen := (vl-match-token :vl-rparen))
        (return (list name range (cons arg1 others)))))

(defparser vl-parse-n-input-gate-instances-list ()
  ;; Matches n_input_gate_instance { ',' n_input_gate_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-n-input-gate-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-n-input-gate-instances-list)))
        (return (cons first rest))))

(defconst *vl-n-input-gatetype-type-kwds* (strip-cars *vl-n-input-gatetype-alist*))

(defparser vl-parse-n-input-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-n-input-gatetype-type-kwds*))
        (strength := (vl-parse-optional-drive-strength))
        (when (vl-is-token? :vl-pound)
          (delay := (vl-parse-delay2)))
        (tuples := (vl-parse-n-input-gate-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-n-input-gatetype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type strength delay atts)))))





; N-OUTPUT Gates.
;
; gate_instantiation ::=
;    n_output_gatetype [drive_strength] [delay2] n_output_gate_instance { ',' n_output_gate_instance } ';'
;
; n_output_gate_instance ::=
;    [name_of_gate_instance] '(' lvalue { ',' lvalue } ',' expression ')'
;

; This is slightly tricky because expressions can be lvalues.

; BUG on 2011-07-28.  The parse-0+-lvalues function was buggy, but note that it was
; only used by vl-parse-n-output-gate-instance (immediately below) so we can fix it
; here without impacting the rest of the parser.  Here are examples of the buggy
; behavior we were getting:

#||

(vl-parse-0+-lvalues-separated-by-commas (make-test-tokens "foo, bar, baz)") nil)
;; OK: returns FOO, BAR, BAZ as expected and left the ) in the input stream.

(vl-parse-0+-lvalues-separated-by-commas (make-test-tokens "foo, bar, baz & bar)") nil)
;; WRONG: returns FOO, BAR, and BAZ, leaving the &bar in the input stream.  terrible.

(vl-parse-0+-lvalues-separated-by-commas (make-test-tokens "foo, bar, ~baz)") nil)
;; SORT OF OK: eats the comma, leaves ~baz in the input stream.
;; But previously vl-parse-n-output-gate-instance was expecting the comma to be
;; left there.  It has been updated appropriately.

||#

; Now we are sure to check that we always arrive at a comma or rparen after
; eating an lvalue, and always eat the comma.

(defparser vl-parse-0+-lvalues-separated-by-commas ()
  ;; Uses backtracking to stop; eats as many lvalues, separated by commas, as
  ;; it can find, and returns them as a list.
  :result (vl-exprlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails never
  :count strong-on-value
  (b* (((mv erp first explore new-warnings) (vl-parse-lvalue))

       ((when erp)
        ;; Failed to eat even a single lvalue, go back to where you were before
        ;; you tried.
        (mv nil nil tokens warnings))

       ((unless (mbt (< (len explore) (len tokens))))
        (er hard? 'vl-parse-0+-lvalues-separated-by-commas "termination failure")
        (vl-parse-error "termination failure"))

       ((unless (or (vl-is-token? :vl-comma
                                  :tokens explore)
                    (vl-is-token? :vl-rparen
                                  :tokens explore)))
        ;; Very subtle.  We just ate an lvalue, but something is wrong because
        ;; we should have gotten to a comma or a right-paren.  Probably what has
        ;; happened is we have just eaten part of an expression that looks like
        ;; an lvalue, e.g., "foo" from "foo & bar".  So, we need to backtrack
        ;; and NOT eat this lvalue.
        (mv nil nil tokens warnings))

       ;; Otherwise, we successfully ate an lvalue and arrived at a comma or
       ;; rparen as expected.  Commit to eating this lvalue.
       (tokens explore)
       (warnings new-warnings))
    (seqw tokens warnings
          (when (vl-is-token? :vl-rparen)
            ;; Nothing more to eat.
            (return (list first)))
          ;; Else, it's a comma
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-0+-lvalues-separated-by-commas))
          (return (cons first rest)))))

(defparser vl-parse-n-output-gate-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        ;; First try to eat all the lvalues you see.  This might eat the final
        ;; expression, too!
        (lvalues := (vl-parse-0+-lvalues-separated-by-commas))
        ;; If we are at an RPAREN, the last expression happened to look like an
        ;; lvalue and we already ate it.  Otherwise, we need to match the last
        ;; expression (which can be arbitrary)
        (unless (vl-is-token? :vl-rparen)
          (expr := (vl-parse-expression)))
        (:= (vl-match-token :vl-rparen))
        (return-raw
         (let ((args (if expr
                         (append lvalues (list expr))
                       lvalues)))
           (if (< (len args) 2)
               (vl-parse-error "Expected at least two arguments.")
             (mv nil (list name range args) tokens warnings))))))

;(vl-parse-n-output-gate-instance (make-test-tokens "my_buf (foo, bar)") nil)
;(vl-parse-n-output-gate-instance (make-test-tokens "my_buf (foo, bar, baz)") nil)
;(vl-parse-n-output-gate-instance (make-test-tokens "my_buf (foo, bar & baz)") nil)
;(vl-parse-n-output-gate-instance (make-test-tokens "my_buf (foo, ~bar)") nil)


(defparser vl-parse-n-output-gate-instances-list ()
  ;; Matches n_output_gate_instance { ',' n_output_gate_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-n-output-gate-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-n-output-gate-instances-list)))
        (return (cons first rest))))

(defconst *vl-n-output-gatetype-type-kwds* (strip-cars *vl-n-output-gatetype-alist*))

(defparser vl-parse-n-output-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-n-output-gatetype-type-kwds*))
        (strength := (vl-parse-optional-drive-strength))
        (when (vl-is-token? :vl-pound)
          (delay := (vl-parse-delay2)))
        (tuples := (vl-parse-n-output-gate-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-n-output-gatetype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type strength delay atts)))))





; PASS-ENABLE Gates.
;
; gate_instantiation ::=
;    pass_en_switchtype [delay2] pass_enable_switch_instance { ',' pass_enable_switch_instance } ';'
;
; pass_enable_switch_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' lvalue ',' expression ')'

(defparser vl-parse-pass-enable-switch-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        (arg1 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (arg2 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (arg3 := (vl-parse-expression))
        (rparen := (vl-match-token :vl-rparen))
        (return (list name range (list arg1 arg2 arg3)))))

(defparser vl-parse-pass-enable-switch-instances-list ()
  ;; Matches pass_switch_instnace { ',' pass_switch_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-pass-enable-switch-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-pass-enable-switch-instances-list)))
        (return (cons first rest))))

(defconst *vl-pass-en-switchtype-type-kwds* (strip-cars *vl-pass-en-switchtype-alist*))

(defparser vl-parse-pass-en-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-pass-en-switchtype-type-kwds*))
        ;; No strength.
        (when (vl-is-token? :vl-pound)
          (delay := (vl-parse-delay2)))
        (tuples := (vl-parse-pass-enable-switch-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-pass-en-switchtype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type nil delay atts)))))






; PASS Gates.
;
; gate_instantiation ::=
;    pass_switchtype pass_switch_instance { ',' pass_switch_instance } ';'
;
; pass_switch_instance ::=
;    [name_of_gate_instance] '(' lvalue ',' lvalue ')'

(defparser vl-parse-pass-switch-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        ((name . range) := (vl-parse-optional-name-of-gate-instance))
        (:= (vl-match-token :vl-lparen))
        (arg1 := (vl-parse-lvalue))
        (:= (vl-match-token :vl-comma))
        (arg2 := (vl-parse-lvalue))
        (rparen := (vl-match-token :vl-rparen))
        (return (list name range (list arg1 arg2)))))

(defparser vl-parse-pass-switch-instances-list ()
  ;; Matches pass_switch_instance { ',' pass_switch_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-pass-switch-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-pass-switch-instances-list)))
        (return (cons first rest))))

(defconst *vl-pass-switchtype-type-kwds* (strip-cars *vl-pass-switchtype-alist*))

(defparser vl-parse-pass-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-pass-switchtype-type-kwds*))
        ;; No strength.
        ;; No delay.
        (tuples := (vl-parse-pass-switch-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd)
                                           *vl-pass-switchtype-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type nil nil atts)))))




; PULLUP/PULLDOWN Gates.
;
; gate_instantiation ::=
;    'pulldown'  [pulldown_strength] pull_gate_instance { ',' pull_gate_instance } ';'
;  | 'pullup'    [pullup_strength]   pull_gate_instance { ',' pull_gate_instance } ';'
;
; pull_gate_instance ::=
;    [name_of_gate_instance] '(' lvalue ')'
;
; pulldown_strength ::=
;    '(' strength0, strength1 ')'
;  | '(' strength1, strength0 ')'
;  | '(' strength0 ')'
;
; pullup_strength ::=
;    '(' strength0, strength1 ')'
;  | '(' strength1, strength0 ')'
;  | '(' strength1 ')'

(defconst *strength0s-for-vl-parse-pull-strength* (strip-cars *vl-strength0-alist*))
(defconst *strength1s-for-vl-parse-pull-strength* (strip-cars *vl-strength1-alist*))

(defund vl-strength0-lookup (type)
  (declare (xargs :guard (member-eq type *strength0s-for-vl-parse-pull-strength*)))
  (cdr (assoc-eq type *vl-strength0-alist*)))

(defund vl-strength1-lookup (type)
  (declare (xargs :guard (member-eq type *strength1s-for-vl-parse-pull-strength*)))
  (cdr (assoc-eq type *vl-strength1-alist*)))

(defthm vl-dstrength-p-of-vl-strength0-lookup
  (implies (force (member-eq type *strength0s-for-vl-parse-pull-strength*))
           (vl-dstrength-p (vl-strength0-lookup type))))

(defthm vl-dstrength-p-of-vl-strength1-lookup
  (implies (force (member-eq type *strength1s-for-vl-parse-pull-strength*))
           (vl-dstrength-p (vl-strength1-lookup type))))

(defthm member-eq-of-vl-type-of-matched-token
  ;; Used in certain older-style proofs, such as vl-parse-pull-strength
  (implies (not (member-eq nil types))
           (iff (member-eq (vl-type-of-matched-token types tokens) types)
                (vl-is-some-token? types :tokens tokens)))
  :hints(("Goal" :in-theory (enable vl-type-of-matched-token
                                    vl-is-some-token?))))

(with-output
  :gag-mode :goals
  (defparser vl-parse-pull-strength (downp)
    :guard (booleanp downp)
    :result (vl-gatestrength-p val)
    :resultp-of-nil nil
    :fails gracefully
    :count strong
    (let ((strength0s *strength0s-for-vl-parse-pull-strength*)
          (strength1s *strength1s-for-vl-parse-pull-strength*))
      (seqw tokens warnings
            (:= (vl-match-token :vl-lparen))

            ;; (strength0, strength1)
            (when (and (vl-is-some-token? strength0s)
                       (vl-is-token? :vl-comma
                                     :tokens (cdr tokens))
                       (vl-is-some-token? strength1s
                                          :tokens (cddr tokens)))
              (strength0 := (vl-match-some-token strength0s))
              (:= (vl-match-token :vl-comma))
              (strength1 := (vl-match-some-token strength1s))
              (:= (vl-match-token :vl-rparen))
              (return (make-vl-gatestrength
                       :zero (vl-strength0-lookup (vl-token->type strength0))
                       :one (vl-strength1-lookup (vl-token->type strength1)))))

            ;; (strength1, strength0)
            (when (and (vl-is-some-token? strength1s)
                       (vl-is-token? :vl-comma
                                     :tokens (cdr tokens))
                       (vl-is-some-token? strength0s
                                          :tokens (cddr tokens)))
              (strength1 := (vl-match-some-token strength1s))
              (:= (vl-match-token :vl-comma))
              (strength0 := (vl-match-some-token strength0s))
              (:= (vl-match-token :vl-rparen))
              (return (make-vl-gatestrength
                       :zero (vl-strength0-lookup (vl-token->type strength0))
                       :one (vl-strength1-lookup (vl-token->type strength1)))))

            ;; If downp is set, we're parsing a pulldown_strength and this should
            ;; be (strength0).  Else, a pullup_strength and this should be
            ;; (strength1).  From 7.8, the other component is ignored anyway, and
            ;; we set it to :vl-strong since that's the default for nets.
            (str := (vl-match-some-token (if downp strength0s strength1s)))
            (:= (vl-match-token :vl-rparen))
            (return (if downp
                        (make-vl-gatestrength
                         :zero (vl-strength0-lookup (vl-token->type str))
                         :one :vl-strong)
                      (make-vl-gatestrength
                       :zero :vl-strong
                       :one (vl-strength1-lookup (vl-token->type str)))))))))

(defparser vl-parse-optional-pull-strength (downp)
  :guard (booleanp downp)
  :result (vl-maybe-gatestrength-p val)
  :resultp-of-nil t
  :fails never
  :count strong-on-value
  (mv-let (erp val explore new-warnings)
          (vl-parse-pull-strength downp)
          (if erp
              (mv nil nil tokens warnings)
            (mv nil val explore new-warnings))))

(defparser vl-parse-pull-gate-instance ()
  :result (vl-gatebldr-tuple-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
       ((name . range) := (vl-parse-optional-name-of-gate-instance))
       (:= (vl-match-token :vl-lparen))
       (arg1 := (vl-parse-lvalue))
       (rparen := (vl-match-token :vl-rparen))
       (return (list name range (list arg1)))))

(defparser vl-parse-pull-gate-instances-list ()
  ;; Matches pass_switch_instance { ',' pass_switch_instance }
  :result (vl-gatebldr-tuple-list-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (first := (vl-parse-pull-gate-instance))
        (when (vl-is-token? :vl-comma)
          (:= (vl-match-token :vl-comma))
          (rest := (vl-parse-pull-gate-instances-list)))
        (return (cons first rest))))

(defconst *vl-pull-gate-type-kwds* (strip-cars *vl-pull-gate-alist*))

(defparser vl-parse-pull-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typekwd := (vl-match-some-token *vl-pull-gate-type-kwds*))
        (strength := (vl-parse-optional-pull-strength
                      (eq (vl-token->type typekwd) :vl-kwd-pulldown)))
        ;; No delay
        (tuples := (vl-parse-pull-gate-instances-list))
        (semi := (vl-match-token :vl-semi))
        (return (let ((type (cdr (assoc-eq (vl-token->type typekwd) *vl-pull-gate-alist*))))
                  (vl-build-gate-instances (vl-token->loc typekwd)
                                           tuples type strength nil atts)))))

(defparser vl-parse-gate-instantiation (atts)
  :guard (vl-atts-p atts)
  :result (vl-gateinstlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (cond ((vl-is-some-token? *vl-cmos-switchtype-type-kwds*)
         (vl-parse-cmos-gate-instantiation atts))

        ((vl-is-some-token? *vl-enable-gatetype-type-kwds*)
         (vl-parse-enable-gate-instantiation atts))

        ((vl-is-some-token? *vl-mos-switchtype-type-kwds*)
         (vl-parse-mos-gate-instantiation atts))

        ((vl-is-some-token? *vl-n-input-gatetype-type-kwds*)
         (vl-parse-n-input-gate-instantiation atts))

        ((vl-is-some-token? *vl-n-output-gatetype-type-kwds*)
         (vl-parse-n-output-gate-instantiation atts))

        ((vl-is-some-token? *vl-pass-en-switchtype-type-kwds*)
         (vl-parse-pass-en-gate-instantiation atts))

        ((vl-is-some-token? *vl-pass-switchtype-type-kwds*)
         (vl-parse-pass-gate-instantiation atts))

        ((vl-is-some-token? *vl-pull-gate-type-kwds*)
         (vl-parse-pull-gate-instantiation atts))

        (t
         (vl-parse-error "Invalid type for gate instantiation."))))

