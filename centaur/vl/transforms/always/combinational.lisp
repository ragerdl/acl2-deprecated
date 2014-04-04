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
(include-book "util")
(include-book "conditions")
(include-book "../../mlib/delta")
(include-book "../../mlib/stmt-tools")
(include-book "../../mlib/filter")
(include-book "stmttemps")
(local (include-book "../../util/arithmetic"))

(defxdoc cblock
  :parents (always-top)
  :short "Transform simple, purely combinational always blocks into
corresponding @('assign') statements, replacing registers with wiring."

  :long "<p>Some basic criteria for treating an always block as
combinational:</p>

<ul>

<li>Expressions must be sized.</li>

<li>There must be a sensitivity list.  It may not mention any edge-triggered
components (since if it does, this block isn't combinational).  Moreover, the
sensitivity list needs to be \"correct\": either it may be @('always @(*)'), or
else it must correctly mention every net/reg that is used in an rvalue context,
including @('if') conditions and right-hand sides of assignments.</li>

<li>For simplicity, we don't try to handle sensitivity lists that include part-
or bit-selects.  That is, we support things like @('always @(a or b)'), but not
@('always @(a[3] or b[17:0])').</li>

<li>We don't support assignments to variables in the sensitivity list (by which
we really mean the set of right-hand side variables).  This isn't necessarily
<i>wrong</i>, but it is kind of weird because it means that evaluating the
block will potentially trigger another evaluation of the block.  This could
perhaps lead to loops, and is generally confusing.  For instance, consider:

@({
    always @@(a or c)
    begin
       a = 1;
       a = c;
    end
})

If @('c') transitions to 0, then this block can start looping with itself,
forever setting A to 1 and then back to 0.  It might be possible to relax this
restriction if it proves problematic, but this all gets very subtle.</li>

<li>The module may not have initial statements.  We're going to want to convert
each each lvalue @('reg') into a @('wire'), so if @('initial') statements could
be writing to these @('reg')s, then this conversion would produce a malformed
module.  Prohibiting initial statements is an easy way to avoid this.</li>

<li>All assignments must be delay-free, blocking assignments.  Non-blocking
assignments are appropriate for edge-triggered logic, not for combinational
logic.  Delays are not supported for simplicity.</li>

<li>The lvalue registers must never be assigned to by other @('always') blocks.
Having multiple @('always') statements updating the same register is way too
hard to think about.  See @(see vl-always-scary-regs).</li>

<li>Always blocks that update only a portion of a register (even if the
specified range is the entire register) are not supported, since this leaves us
without an easy way to convert the @('reg') into a @('wire').  (The above
parenthetical exception is just a casualty of having limited time.)</li>

<li>Each lvalue register must be assigned to in every branch.  Otherwise we
need to infer a latch, e.g., the following can't be turned into ordinary
@('assign') statements:


@({
      always @@(v1 or v2)
        if (v1)
           r = v2;
})

because @('r') needs to keep its value when @('v1') is false.  It wouldn't be
correct to replace this block with @('assign r = v1 ? v2 : r'), because that's
a combinational loop.</li>

</ul>")

(local (xdoc::set-default-parents cblock))

(define vl-star-control-p ((x vl-delayoreventcontrol-p))
  :short "Recognize Verilog-2001 style @@(*) sensitivity lists."
  :inline t
  (mbe :logic
       (and (vl-eventcontrol-p x)
            (if (vl-eventcontrol->starp x) t nil))
       :exec
       (and (eq (tag x) :vl-eventcontrol)
            (vl-eventcontrol->starp x))))

(define vl-evatomlist-edgefree-p ((x vl-evatomlist-p))
  :parents (vl-evatomlist-p)
  (if (atom x)
      t
    (and (eq (vl-evatom->type (car x)) :vl-noedge)
         (vl-evatomlist-edgefree-p (cdr x)))))

(define vl-classic-control-p ((x vl-delayoreventcontrol-p))
  :short "Recognize Verilog-1995 style @@(a or b or c or ...) sensitivity lists."
  :long "<p>Note that we don't allow @('posedge')s or @('negedge')s, here.</p>"
  (and (mbe :logic (vl-eventcontrol-p x)
            :exec (eq (tag x) :vl-eventcontrol))
       (consp (vl-eventcontrol->atoms x))
       (vl-evatomlist-edgefree-p (vl-eventcontrol->atoms x))
       (vl-idexprlist-p (vl-evatomlist->exprs (vl-eventcontrol->atoms x)))))

(define vl-classic-control->exprs
  :short "Simply get, e.g., @('(a b c ...)') from @(' @@(a or b or c or ...) ')"
  ((x (and (vl-delayoreventcontrol-p x)
           (vl-classic-control-p x))))
  :returns (exprs (and (vl-exprlist-p exprs)
                       (vl-idexprlist-p exprs))
                  :hyp :fguard)
  :inline t
  (vl-evatomlist->exprs (vl-eventcontrol->atoms x))
  :prepwork ((local (in-theory (enable vl-classic-control-p)))))



; -----------------------------------------------------------------------------
;
;                  Basic Syntax for Supported Statements
;
; -----------------------------------------------------------------------------

(define vl-atomicstmt-cblock-p
  :parents (vl-stmt-cblock-p)
  ((x vl-atomicstmt-p))
  :returns (bool booleanp :rule-classes :type-prescription)
  :long "<p>We just support null statements and blocking assignments.</p>"
  (case (tag x)
    (:vl-nullstmt    t)
    (:vl-assignstmt  (and (eq (vl-assignstmt->type x) :vl-blocking)
                          ;; Don't tolerate delays on assignments because
                          ;; then nothing makes sense.
                          (not (vl-assignstmt->ctrl x))
                          (vl-idexpr-p (vl-assignstmt->lvalue x))
                          ;; Insist on sized expressions
                          (vl-expr->finaltype (vl-assignstmt->lvalue x))
                          (vl-expr->finaltype (vl-assignstmt->expr x))
                          (posp (vl-expr->finalwidth (vl-assignstmt->lvalue x)))
                          (posp (vl-expr->finalwidth (vl-assignstmt->expr x)))))
    (otherwise       nil)))

(defines vl-stmt-cblock-p
  :short "Recognizer for very restricted statements that we (potentially)
support in combinational always blocks; i.e., the valid @('guts') for @('always
@@(a or b or ...) guts')."

  :long "<p>We expect to see accept:</p>

<ul>
 <li>Null statements</li>
 <li>Blocking assignments with resolved widths</li>
 <li>If/else statements</li>
 <li>Simple begin/end blocks (with, e.g., no names or declarations)</li>
</ul>

<p>We don't try to support, e.g., @('case') statements, since they can be dealt
with separately; see @(see caseelim).  We don't require that the if have been
flattened or anything like that.</p>"

  :hints(("Goal" :in-theory (disable (force))))

  (define vl-stmt-cblock-p ((x vl-stmt-p))
    :measure (two-nats-measure (acl2-count x) 1)
    :flag :stmt
    (b* (((when (vl-fast-atomicstmt-p x))
          (vl-atomicstmt-cblock-p x))

         ((when (vl-ifstmt-p x))
          (b* (((vl-ifstmt x) x))
            (and (vl-stmt-cblock-p x.truebranch)
                 (vl-stmt-cblock-p x.falsebranch))))

         ((when (vl-blockstmt-p x))
          (b* (((vl-blockstmt x) x))
            (and x.sequentialp  ;; BOZO could we also support fork/join?
                 (not x.name)
                 (not x.decls)
                 (vl-stmtlist-cblock-p x.stmts)))))

      ;; We don't support anything else.
      nil))

  (define vl-stmtlist-cblock-p ((x vl-stmtlist-p))
    :measure (two-nats-measure (acl2-count x) 0)
    :flag :list
    (if (atom x)
        t
      (and (vl-stmt-cblock-p (car x))
           (vl-stmtlist-cblock-p (cdr x)))))

  ///
  (deflist vl-stmtlist-cblock-p (x)
    (vl-stmt-cblock-p x)
    :already-definedp t))


; -----------------------------------------------------------------------------
;
;                      Collecting Lvalues and Rvalues
;
; -----------------------------------------------------------------------------

(define vl-atomicstmt-cblock-rvalexprs
  :parents (vl-stmt-cblock-rvalexprs)
  ((x (and (vl-atomicstmt-p x)
           (vl-atomicstmt-cblock-p x))))
  :returns (exprs vl-exprlist-p :hyp :fguard)
  (case (tag x)
    (:vl-nullstmt nil)
    (:vl-assignstmt (list (vl-assignstmt->expr x)))
    (otherwise nil)))

(defines vl-stmt-cblock-rvalexprs
  :short "Collect expressions used in right-hand side positions (and
  if-statement conditions.)"

  :prepwork ((local (in-theory (enable vl-stmt-cblock-p))))
  :hints(("Goal" :in-theory (disable (force))))

  (define vl-stmt-cblock-rvalexprs ((x (and (vl-stmt-p x)
                                              (vl-stmt-cblock-p x))))
    :returns (exprs vl-exprlist-p :hyp :fguard)
    :measure (two-nats-measure (acl2-count x) 1)
    (b* (((when (vl-fast-atomicstmt-p x))
          (vl-atomicstmt-cblock-rvalexprs x))

         ((when (vl-ifstmt-p x))
          (b* (((vl-ifstmt x) x))
            (cons x.condition
                  (append (vl-stmt-cblock-rvalexprs x.truebranch)
                          (vl-stmt-cblock-rvalexprs x.falsebranch)))))

         ((when (vl-blockstmt-p x))
          (b* (((vl-blockstmt x) x))
            (vl-stmtlist-cblock-rvalexprs x.stmts))))

      nil))

  (define vl-stmtlist-cblock-rvalexprs ((x (and (vl-stmtlist-p x)
                                                  (vl-stmtlist-cblock-p x))))
    :returns (exprs vl-exprlist-p :hyp :fguard)
    :measure (two-nats-measure (acl2-count x) 0)
    (if (atom x)
        nil
      (append (vl-stmt-cblock-rvalexprs (car x))
              (vl-stmtlist-cblock-rvalexprs (cdr x))))))


(define vl-atomicstmt-cblock-lvalexprs
  :parents (vl-stmt-cblock-lvalexprs)
  ((x (and (vl-atomicstmt-p x)
           (vl-atomicstmt-cblock-p x))))
  :returns (exprs (and (vl-exprlist-p exprs)
                       (vl-idexprlist-p exprs)) :hyp :fguard)
  :prepwork ((local (in-theory (enable vl-atomicstmt-cblock-p))))
  (case (tag x)
    (:vl-nullstmt nil)
    (:vl-assignstmt (list (vl-assignstmt->lvalue x)))
    (otherwise nil)))

(defines vl-stmt-cblock-lvalexprs
  :short "Collect expressions used in left-hand side positions."

  :prepwork ((local (in-theory (enable vl-stmt-cblock-p))))
  :hints(("Goal" :in-theory (disable (force))))

  (define vl-stmt-cblock-lvalexprs ((x (and (vl-stmt-p x)
                                              (vl-stmt-cblock-p x))))
    :returns (exprs (and (vl-exprlist-p exprs)
                         (vl-idexprlist-p exprs)) :hyp :fguard)
    :measure (two-nats-measure (acl2-count x) 1)
    (b* (((when (vl-fast-atomicstmt-p x))
          (vl-atomicstmt-cblock-lvalexprs x))

         ((when (vl-ifstmt-p x))
          (b* (((vl-ifstmt x) x))
            (append (vl-stmt-cblock-lvalexprs x.truebranch)
                    (vl-stmt-cblock-lvalexprs x.falsebranch))))

         ((when (vl-blockstmt-p x))
          (b* (((vl-blockstmt x) x))
            (vl-stmtlist-cblock-lvalexprs x.stmts))))

      nil))

  (define vl-stmtlist-cblock-lvalexprs ((x (and (vl-stmtlist-p x)
                                                  (vl-stmtlist-cblock-p x))))
    :returns (exprs (and (vl-exprlist-p exprs)
                         (vl-idexprlist-p exprs))
                    :hyp :fguard)
    :measure (two-nats-measure (acl2-count x) 0)
    (if (atom x)
        nil
      (append (vl-stmt-cblock-lvalexprs (car x))
              (vl-stmtlist-cblock-lvalexprs (cdr x))))))



; -----------------------------------------------------------------------------
;
;                   Checking for Assignments in Every Path
;
; -----------------------------------------------------------------------------

(defsection cblock-path-checking
  :parents (cblock)
  :short "How we check whether all of the variables assigned to in an always
block are, indeed, assigned to in all paths.  In other words: how we know that
we don't need to infer a latch."

  :long "<p>This is a basic criteria for whether we can treat an always block
as combinational.  Some examples of what we want to accept and reject:</p>

@({
   always @(*)                        <---- OK, combinational block because
     if (c1) lhs = rhs1;                    LHS is assigned in every branch.
     else lhs = rhs2;

   always @(*)                        <---- NOT OK, need to infer a latch
     if (c1) lhs = rhs;                     because LHS must hold its value
                                            when C1 is false.

   always @(*)                        <---- OK, combinational block because
     lhs = rhs1;                            LHS is assigned in every branch.
     if (c1) lhs = rhs2;
})

<p>Our implementation is brain-dead simple: we write a function that checks
whether a particular LHS is assigned in every branch.  Then we'll apply that
function to every LHS that is used anywhere in the block.</p>

<p>This approach fails to identify \"arguably\" combinational always blocks
such as:</p>

@({
    always @(*)
      if (c1) lhs = rhs1;
      if (!c1) lhs = rhs2;
})

<p>because our path exploration function stupidly does not consider the
possible relationships between the conditions.</p>

<p>Well, it's not clear that we <i>should</i> try to do anything smarter than
this.  After all, synthesis tools might not do hard work here, either.</p>")

(local (xdoc::set-default-parents cblock-path-checking))

(define vl-atomicstmt-cblock-pathcheck1
  ((varname stringp)
   (x       vl-atomicstmt-p))
  :guard (vl-atomicstmt-cblock-p x)
  :returns (bool booleanp :rule-classes :type-prescription)
  (case (tag x)
    (:vl-nullstmt    nil)
    (:vl-assignstmt  (equal (vl-idexpr->name (vl-assignstmt->lvalue x))
                            varname))
    (otherwise nil))
  :prepwork
  ((local (in-theory (enable vl-atomicstmt-cblock-p)))))

(defines vl-stmt-cblock-pathcheck1
  :prepwork ((local (in-theory (enable vl-stmt-cblock-p))))
  :hints(("Goal" :in-theory (disable (force))))

  (define vl-stmt-cblock-pathcheck1
    :short "Check that a single variable is assigned to in all branches of this
            statement."
    ((varname stringp)
     (x       vl-stmt-p))
    :guard (vl-stmt-cblock-p x)
    :returns (okp booleanp :rule-classes :type-prescription)
    :measure (two-nats-measure (acl2-count x) 1)
    (b* (((when (vl-fast-atomicstmt-p x))
          (vl-atomicstmt-cblock-pathcheck1 varname x))
         ((when (vl-ifstmt-p x))
          (b* (((vl-ifstmt x) x))
            ;; Both branches must assign to varname.
            (and (vl-stmt-cblock-pathcheck1 varname x.truebranch)
                 (vl-stmt-cblock-pathcheck1 varname x.falsebranch))))
         ((when (vl-blockstmt-p x))
          (b* (((vl-blockstmt x) x))
            ;; Some statement in the list must always assign to varname.
            (vl-stmtlist-cblock-pathcheck1 varname x.stmts))))
      nil))

  (define vl-stmtlist-cblock-pathcheck1 ((varname stringp)
                                         (x       vl-stmtlist-p))
    :short "Check that a single variable is always assigned to, in all paths,
            within some statement in a begin/end block list."
    :guard (vl-stmtlist-cblock-p x)
    :returns (okp booleanp :rule-classes :type-prescription)
    :measure (two-nats-measure (acl2-count x) 0)
    (if (atom x)
        nil
      (or (vl-stmt-cblock-pathcheck1 varname (car x))
          (vl-stmtlist-cblock-pathcheck1 varname (cdr x))))))

(define vl-cblock-pathcheck
  :short "Check whether a list of variables are always assigned to in every
          execution of the always block, i.e., whether this really is a purely
          combinational block."
  ((vars string-listp)
   (stmt vl-stmt-p))
  :guard (vl-stmt-cblock-p stmt)
  (if (atom vars)
      t
    (and (vl-stmt-cblock-pathcheck1 (car vars) stmt)
         (vl-cblock-pathcheck (cdr vars) stmt))))


; -----------------------------------------------------------------------------
;
;                     Combinational Block Checking
;
; -----------------------------------------------------------------------------

(define vl-check-sensitivity-list
  :short "Check if the sensitivity list is okay for a combinational block."
  ((ctrl     vl-delayoreventcontrol-p)
   (body     vl-stmt-p)
   (ctx      vl-always-p)
   (warnings vl-warninglist-p))
  :guard (and (or (vl-star-control-p ctrl)
                  (vl-classic-control-p ctrl))
              (vl-stmt-cblock-p body))
  :returns (mv (okp booleanp :rule-classes :type-prescription)
               (warnings vl-warninglist-p))

  (b* (((when (vl-star-control-p ctrl))
        ;; Nothing to check.
        (mv t (ok)))

       (sens-exprs (vl-classic-control->exprs ctrl))
       (sens-names (vl-idexprlist->names sens-exprs))

       ;; This is nothing important, just a lint-like check since having any
       ;; duplicate names would be weird and suggests something may be amiss.
       (warnings
        (if (not (duplicated-members sens-names))
            (ok)
          (warn :type :vl-warn-sensitivity-list
                :msg "~a0: sensitivity list has multiple occurrences of ~&1."
                :args (list ctx (duplicated-members sens-names)))))

       (used-rvals          (vl-stmt-cblock-rvalexprs body))
       (used-names          (vl-exprlist-names used-rvals))
       (sens                (mergesort sens-names))
       (used                (mergesort used-names))
       (unnecessary-in-sens (difference sens used))
       (missing-from-sens   (difference used sens))
       (warnings
        (if (not unnecessary-in-sens)
            (ok)
          (warn :type :vl-warn-sensitivity-list
                :msg "~a0: sensitivity list unnecessarily mentions ~&1."
                :args (list ctx unnecessary-in-sens))))
       (warnings
        (if (not missing-from-sens)
            (ok)
          (fatal :type :vl-sensitivity-list-fail
                 :msg "~a0: sensitivity list omits ~&1."
                 :args (list ctx missing-from-sens))))

       (lvalues (vl-idexprlist->names (vl-stmt-cblock-lvalexprs body)))
       (bad-lvalues (intersect (mergesort lvalues) sens))
       (warnings
        (if (not bad-lvalues)
            (ok)
          (fatal :type :vl-bad-always
                 :msg "~a0: found assignments to registers in the sensitivity ~
                       list; we don't support this and it might indicate loops: ~&1."
                 :args (list ctx bad-lvalues))))

       (okp (and (not bad-lvalues)
                 (not missing-from-sens))))
    (mv okp warnings)))

(define vl-always-check-cblock
  :short "Check whether an always block looks like a combinational block that
          we can support."
  ((always   vl-always-p)
   (regs     vl-regdecllist-p "All the registers in the module.")
   (scary    string-listp     "Names of all scary registers.")
   (warnings vl-warninglist-p "An ordinary @(see warnings) accumulator."))
  :returns
  (mv (okp      booleanp :rule-classes :type-prescription
                "Whether this always block is safe to process.")
      (warnings "Possibly extended with fatal warnings (about signals that are
                 missing in the sensitivity list) or non-fatal warnings
                 (about signals that are unnecessarily included.)"
                vl-warninglist-p))
  (b* ((stmt (vl-always->stmt always))
       ((unless (vl-timingstmt-p stmt))
        ;; Something like "always $display(...)" or "always begin ...", clearly
        ;; not anything we can support.
        (mv nil (ok)))

       (ctrl (vl-timingstmt->ctrl stmt))
       (body (vl-timingstmt->body stmt))
       ((unless (or (vl-star-control-p ctrl)
                    (vl-classic-control-p ctrl)))
        ;; Something like "always @(posedge clk)" or "always #3 ...", clearly
        ;; not anything we can support here.
        (mv nil (ok)))

       ((unless (vl-stmt-cblock-p body))
        ;; Not a simple enough combinational statement for us to target.
        (mv nil (ok)))

       (lvalues (mergesort
                 (vl-idexprlist->names (vl-stmt-cblock-lvalexprs body))))
       ((unless (vl-cblock-pathcheck lvalues body))
        ;; Some reg doesn't get updated in some path, not a combinational
        ;; block, maybe a latch or something.
        (mv nil (ok)))

       ;; Otherwise this pretty strongly seems to be intended to be a
       ;; combinational always block.  At this point it's probably fine to
       ;; start issuing warnings.
       ((mv sens-okp warnings)
        (vl-check-sensitivity-list ctrl body always warnings))
       ((unless sens-okp)
        ;; Some problem with the sensitivity list or lvalues, just too hard.
        ;; Already issued warnings.
        (mv nil warnings))

       (scary-writes (intersect lvalues (redundant-mergesort scary)))
       ((when scary-writes)
        (mv nil (fatal :type :vl-bad-always
                       :msg "~a0: cowardly refusing to synthesize this as a ~
                             combinational always block, because registers ~
                             are written to by other always blocks, which is ~
                             very scary: ~&1."
                       :args (list always scary-writes))))

       (warn (vl-always-check-regs lvalues regs always))
       ((when warn)
        ;; Can't convert the block, it refers to some weird non-register.
        (mv nil (cons warn warnings)))

       (non-regs (difference lvalues
                             (mergesort (vl-regdecllist->names regs))))
       ((when non-regs)
        (mv nil (fatal :type :vl-bad-always
                       :msg "~a0: can't synthesize this always block because ~
                             it writes to non-regs: ~&1."
                       :args (list always non-regs)))))

    ;; Else, all sanity checks pass, it seems okay to convert this block.
    (mv t warnings)))

(define vl-filter-cblocks
  :short "Separate always blocks into supported combinational blocks and others."
  ((x        vl-alwayslist-p)
   (regs     vl-regdecllist-p "All the registers in the module.")
   (scary    string-listp     "Names of all scary registers.")
   (warnings vl-warninglist-p "An ordinary @(see warnings) accumulator."))
  :returns
  (mv (cblocks  vl-alwayslist-p :hyp (force (vl-alwayslist-p x)))
      (others   vl-alwayslist-p :hyp (force (vl-alwayslist-p x)))
      (warnings vl-warninglist-p))
  (b* (((when (atom x))
        (mv nil nil (ok)))
       ((mv okp warnings) (vl-always-check-cblock (car x) regs scary warnings))
       ((mv cblocks others warnings)
        (vl-filter-cblocks (cdr x) regs scary warnings)))
    (if okp
        (mv (cons (car x) cblocks) others warnings)
      (mv cblocks (cons (car x) others) warnings))))



; -----------------------------------------------------------------------------
;
;                     Consolidated Expression Building
;
; -----------------------------------------------------------------------------

(defsection cblock-expression-building
  :parents (cblock)
  :short "Convert a combinational always block into assignments."
  :long "<p>Basic examples of what we're trying to do here:</p>
@({
    always @(*)            ---->   assign lhs = condition1 ? expr1
       if (condition1)                        : condition2 ? expr2
          lhs = expr1;                        : expr3
       else if (condition2)
          lhs = expr2;
       else
          lhs = expr3;

    always @(*)            ---->   assign lhs = condition ? expr2 : expr1
       lhs = expr1;
       if (condition)
          lhs = expr2;
})

<p>Note that this conversion isn't quite right if the widths of the @('expr')s
above can differ.  For instance, in the merged expressions like @('condition ?
expr2 : expr1'), suppose the width of @('expr1') and @('lhs') are 5, but the
width of @('expr2') is 7.  Now the width of the new, combined expression is
also @('7'), and (because of the sizing rules) the new expression would be
wider than @('expr1').</p>

<p>To avoid this, we locally use the @(see stmttemps) transform before trying
to carry out this expression building.  This should ensure that all lhses/rhses
are well-typed and have compatible widths.</p>")

(define vl-atomicstmt-cblock-varexpr
  :short "Update our current expression for @('varname') to account for a new
          atomic statement."
  ((varname  stringp          "Variable we're considering.")
   (x        vl-atomicstmt-p  "Statement that we're now encountering.")
   (curr     vl-maybe-expr-p  "Expression we've built for varname up until now."))
  :guard (vl-atomicstmt-cblock-p x)
  :returns (expr? (and (vl-maybe-expr-p expr?)
                       (implies curr expr?))
                  :hyp :fguard
                  "New expression to assign to varname, after taking this
                   statement into account.")
  (case (tag x)
    (:vl-nullstmt
     ;; Null statement has no effect
     curr)
    (:vl-assignstmt
     (if (equal varname (vl-idexpr->name (vl-assignstmt->lvalue x)))
         ;; Assign a new expression to this var
         (vl-assignstmt->expr x)
       ;; Assignment to some other var doesn't affect var.
       curr))
    (otherwise
     curr))
  :prepwork
  ((local (in-theory (enable vl-atomicstmt-cblock-p
                             vl-atomicstmt-cblock-pathcheck1)))))

(defines vl-stmt-cblock-varexpr
  :prepwork ((local (in-theory (enable vl-stmt-cblock-p
                                       vl-stmt-cblock-pathcheck1
                                       vl-stmtlist-cblock-pathcheck1
                                       vl-maybe-expr-p))))
  :hints(("Goal" :in-theory (disable (force))))

  (define vl-stmt-cblock-varexpr
    :short "Construct the expression for a single variable."
    ((varname  stringp         "Variable we're considering.")
     (x        vl-stmt-p       "Statement we're descending through.")
     (curr     vl-maybe-expr-p "Expression we've built up for varname so far, if any."))
    :guard (vl-stmt-cblock-p x)
    :verify-guards nil
    :returns (expr? (and (implies curr expr?)
                         (vl-maybe-expr-p expr?))
                    :hyp :fguard
                    "New expression for varname, if any")
    :measure (two-nats-measure (acl2-count x) 1)
    (b* (((when (vl-fast-atomicstmt-p x))
          (vl-atomicstmt-cblock-varexpr varname x curr))

         ((when (vl-ifstmt-p x))
          (b* (((vl-ifstmt x) x)
               (true-expr  (vl-stmt-cblock-varexpr varname x.truebranch curr))
               (false-expr (vl-stmt-cblock-varexpr varname x.falsebranch curr))
               ((when (and true-expr false-expr))
                ;; Curr doesn't matter, the new statement overwrites it.
                (vl-safe-qmark-expr x.condition true-expr false-expr))
               ((when (and curr true-expr))
                ;; Something like:
                ;;   var = curr
                ;;   if (condition) var = true
                (vl-safe-qmark-expr x.condition true-expr curr))
               ((when (and curr false-expr))
                ;; Something like:
                ;;   var = curr
                ;;   if (condition) [nothing] else var = false;
                (vl-safe-qmark-expr x.condition curr false-expr)))
            ;; Possibility 1: this is something like:
            ;;    var = curr
            ;;    if (condition) othervar = blah;
            ;; We don't care, just keep our current binding for var.
            ;;
            ;; Possibility 2: this is something like:
            ;;    begin
            ;;      if (condition) var = blah;
            ;;      var = blah2;
            ;;    end
            ;; and we don't even have a binding for var yet.  This is subtle
            ;; but fine.  We don't care that this IF statement binds VAR, because
            ;; we know that VAR is ultimately bound on every path, so something
            ;; later has to overwrite it.
            curr))

         ((when (vl-blockstmt-p x))
          (b* (((vl-blockstmt x) x))
            (vl-stmtlist-cblock-varexpr varname x.stmts curr))))

      (raise "Should not be possible to get here.")
      curr))

  (define vl-stmtlist-cblock-varexpr
    ((varname  stringp         "Variable we're considering.")
     (x        vl-stmtlist-p   "Statement we're descending through.")
     (curr     vl-maybe-expr-p "Expression we've built up for varname so far, if any."))
    :guard (vl-stmtlist-cblock-p x)
    :returns (expr? (and (implies curr expr?)
                         (vl-maybe-expr-p expr?))
                    :hyp :fguard
                    "New expression for varname, if any")
    :measure (two-nats-measure (acl2-count x) 0)
    (b* (((when (atom x))
          curr)
         (curr (vl-stmt-cblock-varexpr varname (car x) curr)))
      (vl-stmtlist-cblock-varexpr varname (cdr x) curr)))

  ///
  (verify-guards vl-stmt-cblock-varexpr))

(define vl-cblock-make-assign ((var   stringp)
                               (regs  vl-regdecllist-p)
                               (body  vl-stmt-p)
                               (ctx   vl-always-p))
  :returns (assigns vl-assignlist-p :hyp :fguard)
  :guard (vl-stmt-cblock-p body)
  (b* ((expr (vl-stmt-cblock-varexpr var body nil))
       ((unless expr)
        (raise "Failed to construct var expr for ~x0??" var))
       (decl (vl-find-regdecl var regs))
       ((unless decl)
        (raise "Failed to find reg decl for ~x0??" var))
       ((vl-regdecl decl) decl)
       ((unless (and (not decl.arrdims)
                     (vl-maybe-range-resolved-p decl.range)))
        (raise "Reg decl too hard for ~x0??" var))
       (size (vl-maybe-range-size decl.range))
       (type (if decl.signedp :vl-signed :vl-unsigned))
       (lhs  (vl-idexpr var size type))
       (assign (make-vl-assign :lvalue lhs
                               :expr expr
                               :atts (acons "VL_COMBINATIONAL_BLOCK" nil nil)
                               :loc (vl-always->loc ctx))))
    (list assign)))

(define vl-cblock-make-assigns ((vars string-listp)
                                (regs vl-regdecllist-p)
                                (body vl-stmt-p)
                                (ctx  vl-always-p))
  :returns (assigns vl-assignlist-p :hyp :fguard)
  :guard (vl-stmt-cblock-p body)
  (if (atom vars)
      nil
    (append (vl-cblock-make-assign (car vars) regs body ctx)
            (vl-cblock-make-assigns (cdr vars) regs body ctx))))

(define vl-cblock-synth ((x     vl-always-p)
                         (regs  vl-regdecllist-p)
                         (delta vl-delta-p))
  :short "Should only be called on good cblocks."
  :returns (mv (delta   vl-delta-p :hyp :fguard)
               (cvtregs string-listp))
  (b* ((stmt (vl-always->stmt x))
       ((unless (vl-timingstmt-p stmt))
        (raise "Not a valid cblock: ~x0." x)
        (mv delta nil))

       (ctrl (vl-timingstmt->ctrl stmt))
       (body (vl-timingstmt->body stmt))
       ((unless (and (or (vl-star-control-p ctrl)
                         (vl-classic-control-p ctrl))
                     (vl-stmt-cblock-p body)))
        (raise "Not a valid cblock: ~x0." x)
        (mv delta nil))

       ;; We assume we've done all the checking above, so we don't need to do
       ;; any more sanity checking on the sensitivity list, lhses, etc.  Since
       ;; we're going to throw away the control, we don't have to worry about
       ;; keeping any names the same.  Moreover, it is desirable to run the
       ;; stmttemps transform now, because it deals with making all of the
       ;; expressions the same width.
       ((mv body delta) (vl-stmt-stmttemps body delta x))
       ((unless (vl-stmt-cblock-p body))
        (raise "Somehow stmttemps screwed up the body?" x)
        (mv delta nil))

       (lvalues (mergesort
                 (vl-idexprlist->names
                  (vl-stmt-cblock-lvalexprs body))))
       (assigns (vl-cblock-make-assigns lvalues regs body x))
       (delta (change-vl-delta delta
                               :assigns (append assigns
                                                (vl-delta->assigns delta)))))
    (mv delta lvalues)))

(define vl-cblocks-synth ((x     vl-alwayslist-p)
                          (regs  vl-regdecllist-p)
                          (delta vl-delta-p))
  :returns (mv (delta vl-delta-p :hyp :fguard)
               (cvtregs string-listp))
  (b* (((when (atom x))
        (mv delta nil))
       ((mv delta cvtregs1) (vl-cblock-synth (car x) regs delta))
       ((mv delta cvtregs2) (vl-cblocks-synth (cdr x) regs delta)))
    (mv delta (append cvtregs1 cvtregs2))))


(define vl-module-combinational-elim ((x vl-module-p))
  :returns (new-x vl-module-p :hyp :fguard)
  (b* (((vl-module x) x)
       ((when (vl-module->hands-offp x))
        x)
       ((unless x.alwayses)
        x)
       ((when x.initials)
        (b* ((w (make-vl-warning
                 :type :vl-programming-error
                 :msg "Trying to eliminate combinational always blocks, but ~
                       the module still has initial blocks?  You should have ~
                       run eliminitial first."
                 :args nil
                 :fatalp nil
                 :fn __function__)))
          (change-vl-module x :warnings (cons w x.warnings))))

       (warnings x.warnings)
       (scary (vl-always-scary-regs x.alwayses))
       ((mv cblocks ?others warnings)
        (vl-filter-cblocks x.alwayses x.regdecls scary warnings))
       ((unless cblocks)
        ;; No supported combinational always blocks to convert
        (change-vl-module x :warnings warnings))

       ;; Found blocks to convert.  Convert them into assigns.
       (delta (vl-starting-delta x))
       (delta (change-vl-delta delta
                               :netdecls x.netdecls
                               :assigns x.assigns))
       ((mv delta cvtregs) (vl-cblocks-synth cblocks x.regdecls delta))
       ;; The delta may have assigns, netdecls, and warnings for us.
       ((vl-delta delta) delta)

       (non-regs (difference (mergesort cvtregs)
                             (mergesort (vl-regdecllist->names x.regdecls))))
       ((when non-regs)
        ;; Should be impossible
        (raise "Trying to convert non-registers: ~x0.~%" non-regs)
        x)

       ((mv regdecls-to-convert new-regdecls)
        (vl-filter-regdecls cvtregs x.regdecls))

       (new-netdecls (append (vl-always-convert-regs regdecls-to-convert)
                             delta.netdecls))
       (new-x (change-vl-module x
                                :alwayses others
                                :netdecls new-netdecls
                                :regdecls new-regdecls
                                :assigns  delta.assigns
                                :warnings delta.warnings)))
    new-x))

(defprojection vl-modulelist-combinational-elim (x)
  (vl-module-combinational-elim x)
  :guard (vl-modulelist-p x)
  :result-type vl-modulelist-p)

(define vl-design-combinational-elim ((x vl-design-p))
  :returns (new-x vl-design-p)
  (b* ((x (vl-design-fix x))
       ((vl-design x) x)
       (new-mods (vl-modulelist-combinational-elim x.mods)))
    (change-vl-design x :mods new-mods)))


