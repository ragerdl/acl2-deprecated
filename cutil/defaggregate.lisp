; CUTIL - Centaur Basic Utilities
; Copyright (C) 2008-2011 Centaur Technology
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
;
; Additional copyright notice:
;
; This file is adapted from Milawa, which is also released under the GPL.

(in-package "CUTIL")
(include-book "xdoc/top" :dir :system)
(include-book "tools/rulesets" :dir :system)
(include-book "xdoc/names" :dir :system)
(include-book "str/cat" :dir :system)
(include-book "misc/definline" :dir :system)
(include-book "support")

(defxdoc defaggregate
  :parents (cutil)
  :short "Introduce a record structure, like a @('struct') in C."

  :long "<p>Defaggregate introduces a recognizer, constructor, and accessors
for a new record-like structure.  It is similar to @('struct') in C or
@('defstruct') in Lisp.</p>

<p>General form:</p>

@({
 (defaggregate prefix
   fields
   &key tag                 ; required
        require             ; nil by default
        legiblep            ; t by default
        hons                ; nil by default
        already-definedp    ; nil by default
        mode                ; current defun-mode by default
        parents             ; '(acl2::undocumented) by default
        short               ; nil by default
        long                ; nil by default
        rest                ; nil by default
        rest        ; nil by default
        )
})

<p>For example,</p>

@({
 (defaggregate employee
   (name salary position)
   :tag :employee)
})

<p>will result in the introduction of:</p>

<ul>
 <li>A recognizer, @('(employee-p x)'),</li>
 <li>A constructor, @('(employee name salary position)'),</li>
 <li>An accessor for each field, e.g., @('(employee->name x)'),</li>
 <li>An extension of @(see b*) to easily destructure these aggregates,</li>
 <li>Macros for making and changing aggregates,
   <ul>
    <li>@('(make-employee :name ... :salary ...)')</li>
    <li>@('(change-employee x :salary ...)')</li>
   </ul></li>
 <li>Basic theorems relating these new functions.</li>
</ul>

<h3>Usage and Options</h3>

<h4>Tags (@(':tag') parameter)</h4>

<p>The @(':tag') of every aggregate must either be:</p>

<ul>

<li>A keyword symbol that typically shares its name with the name of the
aggregate, e.g., in the \"employee\" aggregate the tag is @(':employee');
or</li>

<li><tt>nil</tt>, to indicate that you want a <b>tagless</b> aggregate.</li>

</ul>

<p>How are tags used?  Each instance of a tagged aggregate will be a cons tree
whose car is the tag.  This requires some overhead---one cons for every
instance of the aggregate---but allows us to compare tags to differentiate
between different kinds of aggregates.  A tagless aggregate avoids this
overhead, but you give up the ability to easily distinguish different kinds of
tagless aggregates from one another.</p>

<p>To avoid introducing many theorems about @('car'), we use an alias named
@(see tag).  Each tagged @('defaggregate') results in three tag-related
theorems:</p>

<ol>
<li>Tag of constructor:
@({
 (defthm tag-of-example
   (equal (tag (example field1 ... fieldN))
          :example))
})</li>

<li>Tag when recognized:
@({
 (defthm tag-when-example-p
   (implies (example-p x)
            (equal (tag x) :example))
   :rule-classes ((:rewrite :backchain-limit-lst 0)
                  (:forward-chaining)))
})</li>

<li>Not recognized when tag is wrong:
@({
 (defthm example-p-when-wrong-tag
   (implies (not (equal (tag x) :example))
            (equal (example-p x)
                   nil))
   :rule-classes ((:rewrite :backchain-limit-lst 1)))
})</li>
</ol>

<p>These theorems seem to perform well and settle most questions regarding the
disjointness of different kinds of aggregates.  In case the latter rules become
expensive, we always add them to the @('tag-ruleset'), so you can disable
this ruleset to turn off almost all tag-related reasoning.</p>


<h4>Requirements (@(':require') parameter)</h4>

<p>The @(':require') field allows you to list conditions that must be met
by the fields for the object to be considered well-formed.  These requirements
are used in three places:</p>

<ul>
 <li>As well-formedness checks in the recognizer,</li>
 <li>As guards on the constructor,</li>
 <li>As rewrite rules about the accessors.</li>
</ul>

<p>Here is an example of using @(':require') for the employee structure:</p>

@({
 (defaggregate employee
   (name salary position)
   :tag :employee
   :require ((stringp-of-employee->name
              (stringp name)
              :rule-classes :type-prescription)
             (natp-of-employee->salary
              (natp salary)
              :rule-classes :type-prescription)
             (position-p-of-employee->position
              (position-p position))
             (properly-oppressed-p
              (salary-bounded-by-position-p salary position))))
})

<p>Each requirement has the form @('(name condition [:rule-classes classes])'), where</p>
<ul>
 <li>@('name') is a symbol that will be used to name the theorem introduced
     by this form,</li>
 <li>@('condition') is some requirement about one or more fields of the
     aggregate,</li>
 <li>@('classes') are optionally rule-classes to give to the theorem that
     is introduced, and by default is just :rewrite.</li>
</ul>

<p>By default, the theorems introduced by the requirements mechanism are
ordinary @(':rewrite') rules.  This works well for requirements like:</p>

@({
 (position-p-of-employee->position
  (position-p position))
})

<p>where presumably @('position-p') is some custom recognizer that we've
previously introduced.  The resulting rule is:</p>

@({
 (defthm position-p-of-employee->position
   (implies (force (employee-p x))
            (position-p (patient->position x))))
})

<p>But for other fields like @('name') and @('salary'), the requirement
involves primitive ACL2 types like strings and natural numbers, so you may wish
to use a @(':type-prescription') rule instead.</p>


<h4>Legibility (@(':legiblep') parameter)</h4>

<p>By default, an aggregate is represented in a <i>legible</i> way, which means
the fields of each instance are laid out in an alist.  When such an object is
printed, it is easy to see what the value of each field is.</p>

<p>However, the structure can be made <i>illegible</i>, which means it will be
packed into a cons tree of minimum depth.  For instance, a structure whose
fields are @('(foo bar baz)') might be laid out as @('((tag . foo) . (bar
. baz))').  This can be more efficient because the structure has fewer
conses.</p>

<p>We prefer to use legible structures because they can be easier to understand
when they arise in debugging and proofs.  For instance, compare:</p>

<ul>
 <li>Legible: @('(:point3d (x . 5) (y . 6) (z . 7))')</li>
 <li>Illegible: @('(:point3d 5 6 . 7)')</li>
</ul>

<p>On the other hand, illegible structures have a more consistent structure,
which can occasionally be useful.  It's usually best to avoid reasoning about
the underlying structure of an aggregate.  But, sometimes there are exceptions
to this rule.  With illegible structures, you know exactly how each object will
be laid out, and for instance you can prove that two @('point3d') structures
will be equal exactly when their components are equal (which is not a theorem
for legible structures.)</p>


<h4>Honsed aggregates (@(':hons') parameter)</h4>

<p>By default, @(':hons') is nil and the constructor for an aggregate will
build the object using ordinary conses.  However, when @(':hons') is set to
@('t'), we instead always use @('hons') when building these aggregates.</p>

<p>Honsing is only appropriate for some structures.  It is generally slower
than cons, and should typically not be used for aggregates that will be
constructed and used in an ephemeral manner.</p>

<p>Because honsing is somewhat at odds with the notion of legible structures,
@(':hons t') implies @(':legiblep nil').</p>

<h4>Already defined predicates (@(':already-definedp') parameter)</h4>

<p>Can be set if you have already defined the function.  This can be used to
generate all of the ordinary @('defaggregate') theorems without generating a
@('defund') event, and is useful when you are dealing with mutually recursive
recognizers.</p>


<h4>Defun-mode (@(':mode') parameter)</h4>

<p>Mode for the introduced functions -- must be either @(':program') or
@(':logic').  The current defun-mode by default</p>


<h4>XDOC Integration (@(':parents'), @('short'), and @('long') parameters)</h4>

<p>The @(':parents'), @(':short'), and @(':long') arguments are like those in
@(see xdoc::defxdoc).  Whatever you supply for @(':long') will follow some
automatically generated documentation that lists the fields and requirements
for the aggregate.</p>


<h3>Using Aggregates</h3>


<h3>@('Make') and @('Change') Macros</h3>

<p>Direct use of the constructor is discouraged.  Instead, we introduce two
macros with every aggregate.</p>

<p>The @('make') macro constructs a fresh aggregate when given values for its
fields:</p>

@({
 (make-example :field1 val1 :field2 val2 ...)
    -->
 (example val1 val2 ...)
})

<p>The @('change') macro is similar, but is given an existing object as a
starting point.  It may be thought of as:</p>

@({
 (change-example x :field2 val2)
    -->
 (make-example :field1 (example->field1 x)
               :field2 val2
               :field3 (example->field3 x)
               ...)
})

<p>There are some advantages to using these macros over calling the constructor
directly.  The person writing the code does not need to remember the order of
the fields, and the person reading the code can see what values are being given
to which fields.  Also, any field whose value should be @('nil') may be omitted
from the <i>make</i> macro, and any field whose value should be left alone can
be omitted from the <i>change</i> macro.  These features make it easier to add
new fields to the aggregate later on, or to rearrange fields, etc.</p>


<h4>Integration with @(see b*)</h4>

<p>Defaggregate automatically introduces a pattern binder that integrates into
@('b*').  This provides a concise syntax for destructuring aggregates.  For
instance:</p>

@({
 (b* ((bonus-percent 1/10)
      ((employee x)  (find-employee name db))
      (bonus         (+ (* x.salary bonus-percent)
                        (if (equal x.position :sysadmin)
                            ;; early christmas for me, har har...
                            (* x.salary 2)
                          0))))
   bonus)
})

<p>Can loosely be thought of as:</p>

@({
 (b* ((bonus-percent 1/10)
      (temp          (find-employee name db))
      (x.name        (employee->name temp))
      (x.salary      (employee->salary temp))
      (x.position    (employee->position temp))
      (bonus         (+ (* x.salary bonus-percent)
                        (if (equal x.position :sysadmin)
                            ;; early christmas for me, har har...
                            (* x.salary 2)
                          0))))
   bonus)
})

<p>For greater efficiency in the resulting code, we actually avoid binding
components which do not appear to be used, e.g., we will not actually bind
@('x.name') above.</p>

<p>Detecting whether a variable is needed at macro-expansion time is inherently
broken because we can't truly distinguish between function names, macro names,
variable names, and so forth.  It is possible to trick the binder into
including extra, unneeded variables, or into optimizing away bindings that are
necessary.  In such cases, the ACL2 user will be presented with either \"unused
variable\" or \"unbound variable\" error.  If you can come up with a
non-contrived example where this is really a problem, we might consider
developing some workaround, perhaps extended syntax that lets you suppress the
optimization altogether.</p>


<h3>Examples</h3>

<p>BOZO provide explanations of what these examples do.</p>

@({
  (defaggregate taco
    (shell meat cheese lettuce sauce)
    :tag :taco
    :require ((integerp-of-taco->shell (integerp shell))))

  (taco 5 'beef 'swiss 'iceberg 'green)

  (make-taco :shell 5
	      :meat 'beef
	      :cheese 'swiss
	      :lettuce 'iceberg
	      :sauce 'green)

  ; This fails since :tomatoes isn't given a value.
  (make-taco :shell 5
	      :meat 'beef
	      :cheese 'swiss
	      :lettuce 'iceberg
	      :sauce 'green
	      :tomatoes)

  ; This fails since :tomatoes isn't a valid field.
  (make-taco :shell 5
	      :tomatoes t
	      :meat 'beef
	      :cheese 'swiss
	      :lettuce 'iceberg
	      :sauce 'green)

  ; This fails since it has an extra argument.
  (make-taco :shell 5 3)

  (change-taco (taco 5 'beef 'swiss 'iceberg 'green)
	       :meat 'chicken
	       :cheese 'american)

  (change-taco (taco 5 'beef 'swiss 'iceberg 'green)
	       :shell (+ 3 4))

  ; Fails since it is malformed
  (change-taco (taco 5 'beef 'swiss 'iceberg 'green)
	       :meat 'chicken
	       :tomatoes t
	       :cheese 'american)

  ; Fails since it is malformed
  (change-taco (taco 5 'beef 'swiss 'iceberg 'green)
	       :meat 'chicken
	       :tomatoes)

  (defaggregate taco2
    (shell meat cheese lettuce sauce)
    :tag :taco2
    :legiblep nil
    :require ((integerp-of-taco2->shell (integerp shell))))

  (taco2 5 'beef 'swiss 'iceberg 'green)

  (change-taco2 (taco2 5 'beef 'swiss 'iceberg 'green)
		:cheese 'american
		:sauce 'red)

  (taco-p (change-taco2 (taco2 5 'beef 'swiss 'iceberg 'green)
			:cheese 'american
			:sauce 'red))

  (taco2-p (change-taco2 (taco2 5 'beef 'swiss 'iceberg 'green)
			 :cheese 'american
			 :sauce 'red))

  (thm (implies (and (taco-p taco)
		     (taco2-p taco2))
		(not (equal taco taco2))))

})")



(defsection tag
  :parents (cutil)
  :short "Alias for @('car') used by @(see defaggregate)."

  :long "<p>The types introduced by @('defaggregate') are basically objects of
the form @('(tag . field-data)'), where the tag says what kind of object is
being represented (e.g., \"employee\").</p>

<p>The @('tag') function is an alias for @('car'), and so it can be used to get
the tag from these kinds of objects.  We introduce this alias and keep it
disabled so that reasoning about the tags of objects does not slow down
reasoning about @('car') in general.</p>"

  (definlined tag (x)
    (declare (xargs :guard t))
    (mbe :logic (car x)
         :exec (if (consp x)
                   (car x)
                 nil)))

  (def-ruleset tag-reasoning nil)

  (defthm tag-forward-to-consp
    (implies (tag x)
             (consp x))
    :rule-classes :forward-chaining
    :hints(("Goal" :in-theory (enable tag)))))



;; The remainder of this file just introduces the defaggregate macro.  We never
;; care about reasoning about these functions, so we go ahead and implement
;; them in program mode.

(program)

(table defaggregate)
(table defaggregate 'aggregates
       ;; An alist binding NAME -> INFO structures, see DA-EXTEND-TABLE
       )

(defun get-aggregates (world)
  "Look up the current alist of defined aggregates."
  (cdr (assoc 'aggregates (table-alist 'defaggregate world))))

(defmacro da-extend-table (name fields)
  ;; For now an INFO structure will just have the fields, but we can extend
  ;; this later if desired.
  `(table defaggregate 'aggregates
          (cons (cons ,name (list (cons :fields ,fields)))
                (get-aggregates world))))

(defun get-aggregate-fields (name world)
  "Return the field names for an aggregate."
  (b* ((alist (get-aggregates world))
       (entry (assoc name alist))
       ((unless entry)
        (er hard? 'get-aggregate-fields
            "~x0 was not found in the aggregates alist." name))
       (info (cdr entry))
       (look (and (alistp info)
                  (assoc :fields info)))
       ((unless look)
        (er hard? 'get-aggregate-fields
            "~x0 has a malformed entry in the aggregates alist." name)))
    (cdr look)))

;(da-extend-table 'buffalo '(horns face body legs hooves))
;(da-extend-table 'cat '(eyes ears teeth claws fur))
;(get-aggregate-fields 'buffalo (w state))
;(get-aggregate-fields 'cat (w state))


;; We introduce some functions to generate the nmes of constructors,
;; recognizers, accessors, making macros, changing macros, etc., when given the
;; base name of the aggregate.

(defun da-constructor-name (name)
  name)

(defun da-honsed-constructor-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "HONSED-" (symbol-name name))
   name))

(defun da-accessor-name (name field)
  (intern-in-package-of-symbol
   (concatenate 'string (symbol-name name) "->" (symbol-name field))
   name))

(defun da-recognizer-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string (symbol-name name) "-P")
   name))

(defun da-changer-fn-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "CHANGE-" (symbol-name name) "-FN")
   name))

(defun da-changer-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "CHANGE-" (symbol-name name))
   name))

(defun da-maker-fn-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "MAKE-" (symbol-name name) "-FN")
   name))

(defun da-maker-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "MAKE-" (symbol-name name))
   name))

(defun da-honsed-maker-fn-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "MAKE-HONSED-" (symbol-name name) "-FN")
   name))

(defun da-honsed-maker-name (name)
  (intern-in-package-of-symbol
   (concatenate 'string "MAKE-HONSED-" (symbol-name name))
   name))



;; Format for the :require field.

(defun da-require-p (x)
  (or (and (true-listp x)
           (symbolp (car x))
           (or (= (len x) 2)
               (and (= (len x) 4)
                    (equal (third x) :rule-classes)))
           (consp (second x))
           (pseudo-termp (second x)))
      (er hard? 'da-require-p
          "Ill-formed requirement: ~x0.~%" x)))

(defun da-requirelist-p (x)
  (if (atom x)
      (or (not x)
          (er hard? 'da-requirelist-p
              "Requirements must be a true list."))
    (and (da-require-p (car x))
         (da-requirelist-p (cdr x)))))



;; We can lay out the components of the structure in either "legibly" by using
;; maps with named keys, or "illegibly" by using a tree structure.  Illegible
;; structures are more efficient, but are not very convenient when you are
;; trying to debug your code.  By default, we lay out the structure legibly.


; FIELDS MAP.  A "fields map" is an alist that binds each field name to an
; s-expression that describes how to access it.  For instance, suppose the
; fields are (A B C).  For a legible structure, the fields map will be:
;
;   ((A . (cdr (assoc 'a <body>)))
;    (B . (cdr (assoc 'b <body>)))
;    (C . (cdr (assoc 'c <body>))))
;
; Where <body> is either X or (cdr X), depending on whether the structure is
; tagless or not.  For an illegible structure, the (cdr (assoc ...)) terms just
; get replaced with something horrible like (CAR (CDR (CAR <body>))).

(defun da-illegible-split-fields (fields)
  ;; Convert a linear list of fields into a balanced tree with the same fields
  (let ((length (len fields)))
    (cond ((equal length 1)
           (first fields))
          ((equal length 2)
           (cons (first fields) (second fields)))
          (t
           (let* ((halfway   (floor length 2))
                  (firsthalf (take halfway fields))
                  (lasthalf  (nthcdr halfway fields)))
             (cons (da-illegible-split-fields firsthalf)
                   (da-illegible-split-fields lasthalf)))))))

(defun da-illegible-fields-map-aux (split-fields path)
  ;; Convert the balanced tree into a map from field names to paths, e.g.,
  ;; field1 might be bound to (car (car x)), field2 to (cdr (car x)), etc.
  (if (consp split-fields)
      (append (da-illegible-fields-map-aux (car split-fields) `(car ,path))
              (da-illegible-fields-map-aux (cdr split-fields) `(cdr ,path)))
    (list (cons split-fields path))))

(defun da-x (name)
  (intern-in-package-of-symbol "X" name))

(defun da-body (name tag)
  (if tag
      `(cdr ,(da-x name))
    (da-x name)))

(defun da-illegible-fields-map (name tag fields)
  ;; Convert a linear list of fields into a map from field names to paths.
  (da-illegible-fields-map-aux (da-illegible-split-fields fields)
                               (da-body name tag)))

(defun da-illegible-structure-checks-aux (split-fields path)
  ;; Convert the balanced tree into a list of the consp checks we'll need.
  (if (consp split-fields)
      (cons `(consp ,path)
            (append (da-illegible-structure-checks-aux (car split-fields) `(car ,path))
                    (da-illegible-structure-checks-aux (cdr split-fields) `(cdr ,path))))
    nil))

(defun da-illegible-structure-checks (name tag fields)
  ;; Convert a linear list of fields into the consp checks we'll need.
  (da-illegible-structure-checks-aux (da-illegible-split-fields fields)
                                     (da-body name tag)))

(defun da-illegible-pack-aux (honsp split-fields)
  ;; Convert the tree of split fields into a cons tree for building the struct.
  (if (consp split-fields)
      `(,(if honsp 'hons 'cons)
        ,(da-illegible-pack-aux honsp (car split-fields))
        ,(da-illegible-pack-aux honsp (cdr split-fields)))
    split-fields))

(defun da-illegible-pack-fields (honsp tag fields)
  ;; Convert a linear list of fields into consing code
  (let ((body (da-illegible-pack-aux honsp (da-illegible-split-fields fields))))
    (if tag
        `(,(if honsp 'hons 'cons) ,tag ,body)
      body)))

;; (da-illegible-pack-fields nil :taco '(shell meat cheese lettuce sauce))
;;   ==>
;; (CONS :TACO (CONS (CONS SHELL MEAT)
;;                   (CONS CHEESE (CONS LETTUCE SAUCE))))



(defun da-legible-fields-map (name tag fields)
  ;; Convert a linear list of fields into a map from field names to paths.
  (if (consp fields)
      (cons (cons (car fields) `(cdr (assoc ',(car fields) ,(da-body name tag))))
            (da-legible-fields-map name tag (cdr fields)))
    nil))

(defun da-legible-pack-fields-aux (honsp fields)
  ;; Convert a linear list of fields into the pairs for a list operation
  (if (consp fields)
      `(,(if honsp 'hons 'cons)
        (,(if honsp 'hons 'cons) ',(car fields) ,(car fields))
        ,(da-legible-pack-fields-aux honsp (cdr fields)))
    nil))

(defun da-legible-pack-fields (honsp tag fields)
  ;; Convert a linear list of fields into consing code for a legible map
  (let ((body (da-legible-pack-fields-aux honsp fields)))
    (if tag
        `(,(if honsp 'hons 'cons) ,tag ,body)
      body)))

;; (da-legible-pack-fields nil :taco '(shell meat cheese lettuce sauce))
;;   ==>
;; (CONS :TACO (CONS (CONS 'SHELL SHELL)
;;                   (CONS (CONS 'MEAT MEAT)
;;                         (CONS (CONS 'CHEESE CHEESE)
;;                               (CONS (CONS 'LETTUCE LETTUCE)
;;                                     (CONS (CONS 'SAUCE SAUCE) NIL))))))



(defun da-fields-map (name tag legiblep fields)
  ;; Create a fields map of the appropriate type
  (if legiblep
      (da-legible-fields-map name tag fields)
    (da-illegible-fields-map name tag fields)))

(defun da-pack-fields (honsp legiblep tag fields)
  ;; Create a fields map of the appropriate type
  (if legiblep
      (da-legible-pack-fields honsp tag fields)
    (da-illegible-pack-fields honsp tag fields)))

(defun da-structure-checks (name tag legiblep fields)
  ;; Check that the object's cdr has the appropriate cons structure
  (if legiblep
      `((alistp ,(da-body name tag))
        (consp ,(da-body name tag)))
    (da-illegible-structure-checks name tag fields)))



(defun da-fields-map-let-bindings (map)
  ;; Convert a fields map into a list of let bindings
  (if (consp map)
      (let* ((entry (car map))
             (field (car entry))
             (path  (cdr entry)))
        (cons (list field path)
              (da-fields-map-let-bindings (cdr map))))
    nil))

(defun da-make-constructor (name tag fields require honsp legiblep)
  ;; Previously we allowed construction to be inlined, but we prefer to only
  ;; inline accessors.
  `(defund ,(da-constructor-name name) ,fields
    (declare (xargs :guard (and ,@(strip-cadrs require))))
    ,(da-pack-fields honsp legiblep tag fields)))

(defun da-make-honsed-constructor (name tag fields require legiblep)
  `(defun ,(da-honsed-constructor-name name) ,fields
    (declare (xargs :guard (and ,@(strip-cadrs require))
                    :guard-hints(("Goal" :in-theory (enable ,(da-constructor-name name))))))
    (mbe :logic (,(da-constructor-name name) . ,fields)
         :exec ,(da-pack-fields t legiblep tag fields))))

;; (da-make-constructor 'taco :taco '(shell meat cheese lettuce sauce)
;;                    '((shell-p-of-taco->shell (shellp shell)))
;;                   nil nil)
;;  ==>
;; (DEFUND TACO (SHELL MEAT CHEESE LETTUCE SAUCE)
;;         (DECLARE (XARGS :GUARD (AND (SHELLP SHELL))))
;;         (CONS :TACO (CONS (CONS SHELL MEAT)
;;                           (CONS CHEESE (CONS LETTUCE SAUCE)))))

;; (da-make-honsed-constructor 'taco :taco '(shell meat cheese lettuce sauce)
;;                             '((shell-p-of-taco->shell (shellp shell)))
;;                             nil)
;;  ==>
;; (DEFUN HONSED-TACO
;;        (SHELL MEAT CHEESE LETTUCE SAUCE)
;;        (DECLARE (XARGS :GUARD (AND (SHELLP SHELL))
;;                        :GUARD-HINTS (("Goal" :IN-THEORY (ENABLE TACO)))))
;;        (MBE :LOGIC (TACO SHELL MEAT CHEESE LETTUCE SAUCE)
;;             :EXEC (HONS :TACO (HONS (HONS SHELL MEAT)
;;                                     (HONS CHEESE (HONS LETTUCE SAUCE))))))

(defun da-make-recognizer (name tag fields require legiblep)
  ;; Previously we allowed recognizers to be inlined, but now we prefer to
  ;; only inline accessors.
  `(defund ,(da-recognizer-name name) (,(da-x name))
     (declare (xargs :guard t))
     (and ,@(if tag
                `((consp ,(da-x name))
                  (eq (car ,(da-x name)) ,tag))
              nil)
          ,@(da-structure-checks name tag legiblep fields)
          (let ,(da-fields-map-let-bindings (da-fields-map name tag legiblep fields))
            (declare (ACL2::ignorable ,@fields))
            (and ,@(strip-cadrs require))))))


;; (da-make-recognizer 'taco :taco '(shell meat cheese lettuce sauce)
;;                  '((shell-p-of-taco->shell (shellp shell)))
;;                    t)
;; ==>
;; (DEFUND TACO-P (X)
;;         (DECLARE (XARGS :GUARD T))
;;         (AND (CONSP X)
;;              (EQ (CAR X) :TACO)
;;              (ALISTP (CDR X))
;;              (CONSP (CDR X))
;;              (LET ((SHELL (CDR (ASSOC 'SHELL (CDR X))))
;;                    (MEAT (CDR (ASSOC 'MEAT (CDR X))))
;;                    (CHEESE (CDR (ASSOC 'CHEESE (CDR X))))
;;                    (LETTUCE (CDR (ASSOC 'LETTUCE (CDR X))))
;;                    (SAUCE (CDR (ASSOC 'SAUCE (CDR X)))))
;;                   (DECLARE (IGNORABLE SHELL MEAT CHEESE LETTUCE SAUCE))
;;                   (AND (SHELLP SHELL)))))

(defun da-make-accessor (name field map)
  `(defund-inline
    ,(da-accessor-name name field)
    (,(da-x name)) ;; formals
    (declare (xargs :guard (,(da-recognizer-name name) ,(da-x name))
                    :guard-hints (("Goal" :in-theory (enable ,(da-recognizer-name name))))))
    ,(cdr (assoc field map))))

;; (da-make-accessor 'taco 'meat (da-fields-map t '(shell meat cheese lettuce sauce) ))
;; ==>
;; (DEFUND TACO->MEAT (X)
;;         (DECLARE (XARGS :GUARD (TACO-P X)
;;                         :GUARD-HINTS (("Goal" :IN-THEORY (ENABLE TACO-P)))))
;;         (CDR (ASSOC 'MEAT (CDR X))))

(defun da-make-accessors-aux (name fields map)
  (if (consp fields)
      (cons (da-make-accessor name (car fields) map)
            (da-make-accessors-aux name (cdr fields) map))
    nil))

(defun da-make-accessors (name tag fields legiblep)
  (da-make-accessors-aux name fields (da-fields-map name tag legiblep fields)))

(defun da-make-accessor-of-constructor (name field all-fields)
  `(defthm ,(intern-in-package-of-symbol (concatenate 'string
                                                      (symbol-name (da-accessor-name name field))
                                                      "-OF-"
                                                      (symbol-name (da-constructor-name name)))
                                         name)
     (equal (,(da-accessor-name name field) (,(da-constructor-name name) ,@all-fields))
            ,field)
     :hints(("Goal" :in-theory (enable ,(da-accessor-name name field)
                                       ,(da-constructor-name name))))))

(defun da-make-accessors-of-constructor-aux (name fields all-fields)
  (if (consp fields)
      (cons (da-make-accessor-of-constructor name (car fields) all-fields)
            (da-make-accessors-of-constructor-aux name (cdr fields) all-fields))
    nil))

(defun da-make-accessors-of-constructor (name fields)
  (da-make-accessors-of-constructor-aux name fields fields))


(defun da-fields-recognizer-map (name fields)
  (if (consp fields)
      (cons (cons (car fields) (list (da-accessor-name name (car fields))
                                     (da-x name)))
            (da-fields-recognizer-map name (cdr fields)))
    nil))

(defun da-accessor-names (name fields)
  (if (consp fields)
      (cons (da-accessor-name name (car fields))
            (da-accessor-names name (cdr fields)))
    nil))

(defun da-make-requirement-of-recognizer (name require map accnames)
  (let ((rule-classes (if (eq (third require) :rule-classes)
                          (fourth require)
                        :rewrite)))
    `(defthm ,(first require)
       (implies (force (,(da-recognizer-name name) ,(da-x name)))
                ,(ACL2::sublis map (second require)))
       :rule-classes ,rule-classes
       :hints(("Goal" :in-theory (enable ,(da-recognizer-name name) ,@accnames))))))

(defun da-make-requirements-of-recognizer-aux (name require map accnames)
  (if (consp require)
      (cons (da-make-requirement-of-recognizer name (car require) map accnames)
            (da-make-requirements-of-recognizer-aux name (cdr require) map accnames))
    nil))

(defun da-make-requirements-of-recognizer (name require fields)
  (da-make-requirements-of-recognizer-aux name require
                                          (da-fields-recognizer-map name fields)
                                          (da-accessor-names name fields)))



(defun da-changer-args-to-alist (args valid-fields)
  (cond ((null args)
         nil)
        ((atom args)
         (er hard? 'da-changer-args-to-alist
             "Expected a true-list, but instead it ends with ~x0." args))
        ((atom (cdr args))
         (er hard? 'da-changer-args-to-alist
             "Expected :field val pairs, but found ~x0." args))
        (t
         (let ((field (car args))
               (value (cadr args)))
           (and (or (member-equal field valid-fields)
                    (er hard? 'da-changer-args-to-alist
                        "~x0 is not among the allowed fields, ~&1." field valid-fields))
                (cons (cons field value)
                      (da-changer-args-to-alist (cddr args) valid-fields)))))))

(defun da-make-valid-fields-for-changer (fields)
  (if (consp fields)
      (cons (intern-in-package-of-symbol (symbol-name (car fields)) :keyword)
            (da-make-valid-fields-for-changer (cdr fields)))
    nil))




(defun da-make-changer-fn-aux (name fields)
  (if (consp fields)
      (let ((kwd-name (intern-in-package-of-symbol (symbol-name (car fields)) :keyword))
            (alist (intern-in-package-of-symbol "ALIST" name))
            (x     (da-x name)))
        (cons `(if (assoc ,kwd-name ,alist)
                   (cdr (assoc ,kwd-name ,alist))
                 (list ',(da-accessor-name name (car fields)) ,x))
              (da-make-changer-fn-aux name (cdr fields))))
    nil))

(defun da-make-changer-fn (name fields)
  (let ((alist (intern-in-package-of-symbol "ALIST" name))
        (x     (da-x name)))
    `(defun ,(da-changer-fn-name name) (,x ,alist)
       (declare (xargs :mode :program))
       (cons ',(da-constructor-name name)
             ,(cons 'list (da-make-changer-fn-aux name fields))))))

(defun da-make-changer (name fields)
  `(defmacro ,(da-changer-name name) (,(da-x name) &rest args)
     (,(da-changer-fn-name name) ,(da-x name)
      (da-changer-args-to-alist args ',(da-make-valid-fields-for-changer fields)))))





(defun da-make-maker-fn-aux (name fields)
  (if (consp fields)
      (let ((kwd-name (intern-in-package-of-symbol (symbol-name (car fields)) :keyword))
            (alist    (intern-in-package-of-symbol "ALIST" name)))
        (cons `(if (assoc ,kwd-name ,alist)
                   (cdr (assoc ,kwd-name ,alist))
                 nil)
              (da-make-maker-fn-aux name (cdr fields))))
    nil))

(defun da-make-maker-fn (name fields)
  (let ((alist (intern-in-package-of-symbol "ALIST" name)))
    `(defun ,(da-maker-fn-name name) (,alist)
       (declare (xargs :mode :program))
       (cons ',(da-constructor-name name)
             ,(cons 'list (da-make-maker-fn-aux name fields))))))

(defun da-make-maker (name fields)
  `(defmacro ,(da-maker-name name) (&rest args)
     (,(da-maker-fn-name name)
      (da-changer-args-to-alist args ',(da-make-valid-fields-for-changer fields)))))


(defun da-make-honsed-maker-fn (name fields)
  (let ((alist (intern-in-package-of-symbol "ALIST" name)))
    `(defun ,(da-honsed-maker-fn-name name) (,alist)
       (declare (xargs :mode :program))
       (cons ',(da-honsed-constructor-name name)
             ,(cons 'list (da-make-maker-fn-aux name fields))))))

(defun da-make-honsed-maker (name fields)
  `(defmacro ,(da-honsed-maker-name name) (&rest args)
     (,(da-honsed-maker-fn-name name)
      (da-changer-args-to-alist args ',(da-make-valid-fields-for-changer fields)))))




;; Support for B* Integration...

(defun da-patbind-make-field-vars-alist (var fields)
  ;; Given var = 'foo and fields = '(a b c),
  ;; Constructs '((a . foo.a) (b . foo.b) (c . foo.c))
  (if (atom fields)
      nil
    (acons (car fields)
           (intern-in-package-of-symbol
            (concatenate 'string (symbol-name var) "." (symbol-name (car fields)))
            var)
          (da-patbind-make-field-vars-alist var (cdr fields)))))

(defun da-patbind-find-unused-vars (form vars)
  ;; Return all vars not used in form.  We do this completely stupidly, not
  ;; even avoiding quoted constants.  We can try to improve this if it's a
  ;; problem, but at some level what we're trying to do is inherently broken
  ;; anyway -- we just hope it's useful most of the time anyway.
  (if (atom form)
      (if (symbolp form)
          (remove1 form vars)
        vars)
    (da-patbind-find-unused-vars (car form)
                                 (da-patbind-find-unused-vars (cdr form) vars))))

;; (da-patbind-find-unused-vars '(foo (+ 1 a) c) '(a b c d)) --> '(b d)

(defun da-patbind-remove-unused-vars (valist unused)
  (cond ((atom valist)
         nil)
        ((member (cdar valist) unused)
         (da-patbind-remove-unused-vars (cdr valist) unused))
        (t
         (cons (car valist)
               (da-patbind-remove-unused-vars (cdr valist) unused)))))

(defun da-patbind-alist-to-bindings (name valist target)
  (if (atom valist)
      nil
    (let* ((accessor (da-accessor-name name (caar valist)))
           (call     (list accessor target))     ;; (taco->shell foo)
           (binding  (list (cdar valist) call))) ;; (x.foo (taco->shell foo))
      (cons binding
            (da-patbind-alist-to-bindings name (cdr valist) target)))))


(defun da-patbind-fn (name fields args forms rest-expr)
  (b* ((- (or (and (tuplep 1 args)
                   (tuplep 1 forms)
                   (symbolp (car args))
                   (not (booleanp (car args))))

              (er hard? 'da-patbind-fn "B* bindings for ~x0 aggregates must have the ~
form ((~x0 <name>) <expr>), where <name> is a symbol and <expr> is a single ~
term.  The attempted binding of~|~% ~p1~%~%is not of this form."
                  name (cons (cons name args) forms))))

       (var             (car args))
       (full-vars-alist (da-patbind-make-field-vars-alist var fields))
       (field-vars      (strip-cdrs full-vars-alist))
       (unused-vars     (da-patbind-find-unused-vars rest-expr field-vars))
       (vars-alist      (da-patbind-remove-unused-vars full-vars-alist unused-vars))
       ((unless vars-alist)
        (progn$
         (cw "Note: not introducing any ~x0 field bindings for ~x1, since ~
              none of its fields appear to be used.~%" name var)
         rest-expr))

       ;;(- (cw "Var is ~x0.~%" var))
       ;;(- (cw "Full vars alist is ~x0.~%" full-vars-alist))
       ;;(- (cw "Unnecessary field vars are ~x0.~%" unused-vars))
       ;;(- (cw "Optimized vars alist is ~x0.~%" vars-alist))

       ;; The below is adapted from patbind-nth.  Sol is using (pack binding)
       ;; to generate a name that is probably unused.  We'll do the same.

       (binding  (if forms (car forms) var))
       (evaledp  (or (atom binding) (eq (car binding) 'quote)))
       (target   (if evaledp binding (acl2::pack binding)))
       (bindings (da-patbind-alist-to-bindings name vars-alist target))

       ;;(- (cw "Binding is ~x0.~%" var))
       ;;(- (cw "Evaledp is ~x0.~%" var))
       ;;(- (cw "Target is ~x0.~%" target))
       ;;(- (cw "New bindings are ~x0.~%" bindings))

       )

      (if evaledp
          `(b* ,bindings ,rest-expr)
        `(let ((,target ,binding))
           (b* ,bindings
               (check-vars-not-free (,target) ,rest-expr))))))

(defun da-make-binder (name fields)
  `(defmacro ,(intern-in-package-of-symbol
               (concatenate 'string "PATBIND-" (symbol-name name))
               name)
     (args forms rest-expr)
     (da-patbind-fn ',name ',fields args forms rest-expr)))



;; Autodoc support for aggregates:
;; Ugh.  Generating these strings is nasty.  Hard to get the escaping right.

(defun da-main-autodoc-for-requirements-aux (require acc)
  (if (atom require)
      acc
    (let* ((name   (caar require))
           (acc    (str::revappend-chars "@(gthm " acc))
           ;; This isn't right, in general.  Need to properly get the name
           ;; into escaped format.
           (acc    (str::revappend-chars (symbol-package-name name) acc))
           (acc    (str::revappend-chars "::" acc))
           (acc    (str::revappend-chars (symbol-name name) acc))
           (acc    (str::revappend-chars ")" acc))
           (acc    (cons #\Newline acc)))
      (da-main-autodoc-for-requirements-aux (cdr require) acc))))

(defun da-main-autodoc-for-requirements (require acc)
  (let* ((acc (str::revappend-chars "<h3>Field Requirements</h3>" acc))
         (acc (cons #\Newline acc))
         (acc (str::revappend-chars "<dl>" acc))
         (acc (da-main-autodoc-for-requirements-aux require acc))
         (acc (str::revappend-chars "</dl>" acc))
         (acc (cons #\Newline acc)))
    acc))

(defun da-main-autodoc-for-fields-aux (fields acc)
  (if (atom fields)
      acc
    (let* ((acc  (str::revappend-chars "<li><tt>" acc))
           (acc  (xdoc::sym-mangle (car fields) (car fields) acc))
           (acc  (str::revappend-chars "</tt></li>" acc))
           (acc  (cons #\Newline acc)))
      (da-main-autodoc-for-fields-aux (cdr fields) acc))))

(defun da-main-autodoc-for-fields (fields acc)
  (let* ((acc (str::revappend-chars "<ul>" acc))
         (acc (cons #\Newline acc))
         (acc (da-main-autodoc-for-fields-aux fields acc))
         (acc (str::revappend-chars "</ul>" acc))
         (acc (cons #\Newline acc)))
    acc))

(defun da-main-autodoc (name fields require parents short long)
  (let* (;; We begin by constructing the :long string
         (acc  nil)
         (foop (da-recognizer-name name))
         (acc  (str::revappend-chars "<p>@(call " acc))
         ;; This isn't right, in general.  Need to properly get the name
         ;; into escaped format.
         (acc  (str::revappend-chars (symbol-package-name foop) acc))
         (acc  (str::revappend-chars "::" acc))
         (acc  (str::revappend-chars (symbol-name foop) acc))
         (acc  (str::revappend-chars ") is a @(see vl::defaggregate) of the following fields.</p>" acc))
         (acc  (da-main-autodoc-for-fields fields acc))
         (acc  (str::revappend-chars "<p>Source link: @(srclink " acc))
         (acc  (str::revappend-chars (string-downcase (symbol-name name)) acc))
         (acc  (str::revappend-chars ")</p>" acc))
         (acc  (str::revappend-chars (or long "") acc))
         (acc  (da-main-autodoc-for-requirements require acc))
         (long (coerce (reverse acc) 'string)))
    `(defxdoc ,foop
       :parents ,parents
       :short ,short
       :long ,long)))

(defun da-field-autodoc (name field)
  (let* ((foop     (da-recognizer-name name))
         (accessor (da-accessor-name name field))
         (short    (str::cat "Access the <tt>" (string-downcase (symbol-name field))
                             "</tt> field of a @(see "
                             (symbol-package-name foop) "::" (symbol-name foop)
                             ") structure.")))
    `(defxdoc ,accessor
       :parents (,foop)
       :short ,short)))

(defun da-fields-autodoc (name fields)
  (if (consp fields)
      (cons (da-field-autodoc name (car fields))
            (da-fields-autodoc name (cdr fields)))
    nil))

(defun da-autodoc (name fields require parents short long)
  (cons (da-main-autodoc name fields require parents short long)
        (da-fields-autodoc name fields)))

(defun defaggregate-fn (name fields tag require honsp legiblep
                             already-definedp mode parents short long
                             rest)
  (and (or (symbolp name)
           (er hard 'defaggregate "Name must be a symbol."))
       (or (symbol-listp fields)
           (er hard 'defaggregate "Fields must be a list of symbols."))
       (or (not tag)
           (and (symbolp tag)
                (equal (symbol-package-name tag) "KEYWORD"))
           (er hard 'defaggregate "Tag must be a keyword symbol or NIL."))
       (or (no-duplicatesp fields)
           (er hard 'defaggregate "Fields must be unique."))
       (or (consp fields)
           (er hard 'defaggregate "There must be at least one field."))
       (or (da-requirelist-p require)
           (er hard 'defaggregate "Malformed requirements."))
       (or (no-duplicatesp (strip-cars require))
           (er hard 'defaggregate "The names given to :require must be unique."))
       (or (member mode '(:logic :program))
           (er hard 'defaggregate "The mode must be :logic or :program."))
       (or (eq mode :logic)
           (not already-definedp)
           (er hard 'defaggregate ":mode :program and already-definedp cannot ~
                                   be used together."))
       (or (symbol-listp parents)
           (er hard 'defaggregate "The :parents must be a list of symbols."))
       (or (stringp short)
           (not short)
           (er hard 'defaggregate ":short must be a string (or nil)"))
       (or (stringp long)
           (not long)
           (er hard 'defaggregate ":long must be a string (or nil)"))

       (let* ((foop             (da-recognizer-name name))
              (make-foo         (da-constructor-name name))
              (legiblep         (and legiblep (not honsp)))
              ;(accessors        (da-accessor-names name fields))
              ;(maker            (da-maker-name name))
              ;(maker-fn         (da-maker-fn-name name))
              ;(changer          (da-changer-name name))
              ;(changer-fn       (da-changer-fn-name name))
              (foop-of-make-foo (intern-in-package-of-symbol (concatenate 'string
                                                                          (symbol-name foop)
                                                                          "-OF-"
                                                                          (symbol-name make-foo))
                                                             name))
              (x                (da-x name)))
         `(progn

            (da-extend-table ',name ',fields)
            ,@(da-autodoc name fields require parents short long)

            ,(if (eq mode :logic)
                 '(logic)
               '(program))

            ,@(if already-definedp
                 nil
                (list (da-make-recognizer name tag fields require legiblep)))
            ,(da-make-constructor name tag fields require honsp legiblep)
            ,(da-make-honsed-constructor name tag fields require legiblep)
            ,@(da-make-accessors name tag fields legiblep)

            ,@(and
               (eq mode :logic)
               `((defthm ,(intern-in-package-of-symbol
                           (concatenate 'string (symbol-name make-foo) "-UNDER-IFF")
                           name)
                   (iff (,make-foo ,@fields)
                        t)
                   :hints(("Goal" :in-theory (enable ,make-foo))))

                 (defthm ,(intern-in-package-of-symbol
                           (concatenate 'string "BOOLEANP-OF-" (symbol-name foop))
                           name)
                   (equal (booleanp (,foop ,x))
                          t)
                   :rule-classes :type-prescription
                   :hints(("Goal" :in-theory (enable ,foop))))

                 ,(if (consp require)
                      `(defthm ,foop-of-make-foo
                         (implies (force (and ,@(strip-cadrs require)))
                                  (equal (,foop (,make-foo ,@fields))
                                         t))
                         :hints(("Goal" :in-theory (enable ,foop ,make-foo))))
                    `(defthm ,foop-of-make-foo
                       (equal (,foop (,make-foo ,@fields))
                              t)
                       :hints(("Goal" :in-theory (enable ,foop ,make-foo)))))

                 ,@(and tag
                        `((defthm ,(intern-in-package-of-symbol
                                    (str::cat "TAG-OF-" (symbol-name make-foo))
                                    name)
                            (equal (tag (,make-foo ,@fields))
                                   ,tag)
                            :hints(("Goal" :in-theory (enable tag ,make-foo))))

                          (defthm ,(intern-in-package-of-symbol
                                    (str::cat "TAG-WHEN-" (symbol-name foop))
                                    name)
                            (implies (,foop ,x)
                                     (equal (tag ,x)
                                            ,tag))
                            :rule-classes ((:rewrite :backchain-limit-lst 0)
                                           (:forward-chaining))
                            :hints(("Goal" :in-theory (enable tag ,foop))))

                          (defthm ,(intern-in-package-of-symbol
                                    (str::cat (symbol-name foop) "-WHEN-WRONG-TAG")
                                    name)
                            (implies (not (equal (tag ,x) ,tag))
                                     (equal (,foop ,x)
                                            nil))
                            :rule-classes ((:rewrite :backchain-limit-lst 1)))

                          (add-to-ruleset tag-reasoning
                                          '(,(intern-in-package-of-symbol
                                              (str::cat "TAG-WHEN-" (symbol-name foop))
                                              name)
                                            ,(intern-in-package-of-symbol
                                              (str::cat (symbol-name foop) "-WHEN-WRONG-TAG")
                                              name)))))

                 (defthm ,(intern-in-package-of-symbol
                           (concatenate 'string "CONSP-WHEN-" (symbol-name foop))
                           name)
                   (implies (,foop ,x)
                            (consp ,x))
                   :rule-classes :compound-recognizer
                   :hints(("Goal" :in-theory (enable ,foop))))

                 ,@(da-make-accessors-of-constructor name fields)
                 ,@(da-make-requirements-of-recognizer name require fields)))


            ,(da-make-binder name fields)

            ,(da-make-changer-fn name fields)
            ,(da-make-changer name fields)

            ,(da-make-maker-fn name fields)
            ,(da-make-maker name fields)

            ,(da-make-honsed-maker-fn name fields)
            ,(da-make-honsed-maker name fields)

            . ,rest

            ))))

(defmacro defaggregate (name fields &key
                             tag
                             require
                             (legiblep ''t)
                             hons
                             already-definedp
                             mode
                             (parents '(acl2::undocumented))
                             short
                             long
                             rest)
  `(make-event (let ((mode (or ',mode (default-defun-mode (w state)))))
                 (defaggregate-fn ',name ',fields ',tag ',require ',hons ',legiblep
                   ',already-definedp mode ',parents ',short ',long
                   ',rest))))

