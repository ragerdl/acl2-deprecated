; XDOC Documentation System for ACL2
; Copyright (C) 2009-2011 Centaur Technology
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

(in-package "XDOC")
(include-book "parse-xml")
(include-book "save-classic")
(set-state-ok t)
(program)

(defun make-key (x)
  (declare (type symbol x))
  (str::rchars-to-string (file-name-mangle x nil)))

(defun make-keys (x)
  (declare (xargs :guard (symbol-listp x)))
  (if (atom x)
      nil
    (cons (make-key (car x))
          (make-keys (cdr x)))))


; importance.lisp
;
; Apparently a way that real search engines produce useful results is to give
; pages "importance" scores/ranks.  This lets them put the results of a query
; into a good order, with important pages coming first.  In XDOC we can get a
; lot of clues about a topic's importance, for instance,
;
;   - How far from the root is it?
;   - How many other pages link to it? (if it's worth mentioning from other
;     pages then it's likely to be important)
;   - How many children does it have (a section with lots of subtopics is
;     likely to be more major than a leaf topic.)
;   - How much (preferably non-generated) content is there?  (a real www
;     search engine wouldn't want to consider that because it could be
;     easily gamed, but in our controlled environment it's probably a
;     good indicator of how much content there is.)
;
; Our top level function is
;
;  (order-topics-by-importance all-topics state) --> (mv all-topics state)
;
; It just permutes the input topics into a "good" order so that "more
; important" topics come first.  The goal is to improve the relevance of
; results produced by search features, by allowing the search feature to assume
; that the earlier topics are more important.
;
; Design decision: we target the post-preprocessing XML version of the data.
; This way we can reuse our XML parser.  An alternative would be to target the
; pre-preprocessing code; this might have some advantages in terms of being
; able to identify generated versus typed-in content.  But maybe just looking
; at <code> tags is enough to avoid those kinds of problems.
;
; Quick and dirty: We'll do all the preprocessing and XML parsing ahead of time
; so that we can just have straight up token lists to deal with.  We'll call
; these post-preprocessing, pure XML topics "XTOPICS".  While we collect these,
; we'll collect up some heuristically interesting data, e.g., all of the links
; to other topics that are NOT in <code> tags (to avoid counting generated
; autolinks) while we generate these xtopics.

(std::def-primitive-aggregate xtopic
  (name         ; copy of :name from normal topic
   base-pkg     ; copy of base-pkg from normal topic
   parents      ; copy of parents from normal topic
   short-tokens ; already preprocessed
   long-tokens  ; already preprocessed
   links        ; collected up links (short+long combined) keys (i.e., "ACL2____FOO")
   size         ; heuristic for how much content there is
   ))

(defun xtopiclist->names (x)
  (if (atom x)
      nil
    (cons (xtopic->name (car x))
          (xtopiclist->names (cdr x)))))

(defun xtopiclist->sizes (x)
  (if (atom x)
      nil
    (cons (xtopic->size (car x))
          (xtopiclist->sizes (cdr x)))))

(defun find-xtopic (name xtopics)
  (cond ((atom xtopics)
         nil)
        ((equal name (xtopic->name (car xtopics)))
         (car xtopics))
        (t
         (find-xtopic name (cdr xtopics)))))

(defun extract-links
  (ctx       ; Context for warnings about malformed XML
   tokens    ; Tokens (see parse-xml.lisp) we are processing
   open-tags ; Stack of currently open tags (so we can see if we're in <code>)
   )
  ; Returns the list of "file names" / "keys" / "topic urls" that we have
  ; found, i.e., if the tokens contain <see topic="ACL2____CAR">, then our
  ; results list will include ACL2____CAR.
  (b* (((when (atom tokens))
        nil)

       (token1 (car tokens))
       ((when (closetok-p token1))
        (extract-links ctx (cdr tokens) (cdr open-tags)))
       ((unless (opentok-p token1))
        (extract-links ctx (cdr tokens) open-tags))

       (tagname (opentok-name token1))
       (open-tags (cons tagname open-tags))

       ((unless (equal tagname "see"))
        (extract-links ctx (cdr tokens) open-tags))

       (atts  (opentok-atts token1))
       (topic (cdr (assoc-equal "topic" atts)))
       ((unless topic)
        (cw "Warning: missing 'topic' in <see> tag, in ~x0, before ~x1."
            ctx (take (min (len tokens) 10) tokens))
        (extract-links ctx (cdr tokens) open-tags))

       (in-code-p (member-equal "code" open-tags))
       (rest (extract-links ctx (cdr tokens) open-tags)))
    (if in-code-p
        rest
      (cons topic rest))))


; Broken link reports.
;
; BOZO.  This really doesn't belong here at all.  But it's convenient to reuse
; xtopics for this, since we already have gone to the work of extracting the
; links from topic to topic, from both preprocessor and manually entered
; <see topic='...'> tags.
;
; Terminology: if page A has a link to page B, then A is the "source" of the
; link and B is the "target" of the link.
;
; Below, a LINKS-FAL is a fast alist that binds
;
;          TARGET (key) -> SOURCE LIST (names) 
;
; For instance, the LINKS-FAL might bind:
;
;       "ACL2____FOO" -> (ACL2::BAR ACL2::BAZ)
;
; When both ACL2::BAR and ACL2::BAZ have links to ACL2::FOO.

(defun extend-links-fal
  (source    ; symbol, name of the page we're processing
   targets   ; string list, keys of the pages linked to from source
   links-fal ; the fal being constructed
   )
  (declare (xargs :guard (and (stringp source)
                              (symbol-listp targets))))
  (b* (((when (atom targets))
        links-fal)
       (target1      (car targets))
       (prev-sources (cdr (hons-get target1 links-fal)))
       ((when (member source prev-sources))
        (extend-links-fal source (cdr targets) links-fal))
       (new-sources (cons source prev-sources))
       (links-fal   (hons-acons target1 new-sources links-fal)))
    (extend-links-fal source (cdr targets) links-fal)))

(defun make-links-fal-aux (xtopics links-fal)
  (b* (((when (atom xtopics))
        links-fal)
       (xtopic    (car xtopics))
       (source    (xtopic->name xtopic))
       (targets   (xtopic->links xtopic))
       (links-fal (extend-links-fal source targets links-fal)))
    (make-links-fal-aux (cdr xtopics) links-fal)))

(defun make-links-fal (xtopics)
  (b* ((links-fal (make-links-fal-aux xtopics nil))
       (ans       (hons-shrink-alist links-fal nil)))
    (fast-alist-free links-fal)
    (fast-alist-free ans)
    ans))

(defun find-broken-links
  (links-al   ; The (shrunk) links al we constructed above
   keys-fal   ; Fast alist binding KEY to NIL for every defined topic
   )
  ;; returns a broken-links-al, which is a links-al but that only has entries
  ;; for the topics that don't exist
  (b* (((when (atom links-al))
        nil)
       ((cons target-key ?sources) (car links-al))
       (look (hons-get target-key keys-fal))
       ((when look)
        ;; This is a defined topic, so nothing to report
        (find-broken-links (cdr links-al) keys-fal)))
    ;; This is NOT a defined topic, so keep it.
    (cons (car links-al)
          (find-broken-links (cdr links-al) keys-fal))))

(defun sum-lengths (x)
  (if (atom x)
      0
    (+ (length (car x))
       (sum-lengths (cdr x)))))

(defun report-broken-links-more-sources (sources)
  (if (atom sources)
      (cw ";;; ~%")
    (progn$ (cw ";;; ~t0~s1~%" 12 (car sources))
            (report-broken-links-more-sources (cdr sources)))))

(defun report-broken-links-aux (links-al)
  (b* (((when (atom links-al))
        nil)
       ((cons target sources) (car links-al)))
    (cw ";;; ~s0:~%" target)
    (cw ";;; ~t0 from ~s1~%" 6 (car sources))
    (report-broken-links-more-sources (cdr sources))
    (report-broken-links-aux (cdr links-al))))

(defun report-broken-links (xtopics state)
  (declare (xargs :stobjs state))
  (b* ((links-fal (make-links-fal xtopics))
       (keys-fal  (make-fast-alist
                   (pairlis$ (make-keys (xtopiclist->names xtopics))
                             nil)))
       (broken (find-broken-links links-fal keys-fal))
       (- (fast-alist-free links-fal))
       (- (fast-alist-free keys-fal))
       ((unless broken)
        state)
       (soft (acl2::fmt-soft-right-margin state))
       (hard (acl2::fmt-hard-right-margin state))
       (state (set-fmt-soft-right-margin 10000 state))
       (state (set-fmt-hard-right-margin 10000 state))
       (num (sum-lengths (strip-cdrs broken)))
       (- (cw "~%;;; WARNING: Found ~x0 broken topic links: ~%" num)
          (cw ";;;~%")
          (report-broken-links-aux broken)
          (cw ";;;~%"))
       (state (set-fmt-soft-right-margin soft state))
       (state (set-fmt-hard-right-margin hard state)))
    state))


; Size ranking.  Perhaps the simplest way to measure if a topic is "important"
; is to just see how much content is has.  We'll regard the topic as more
; important if it has more content.


; Original attempt -- this didn't work well because converted defdoc topics
; don't have any kind of sensible <p></p> structure, so even big topics like
; set-gag-mode ended up with quite low scores.

;; (defun text-length-through-close-paragraph (tokens acc)
;;   (b* (((when (atom tokens))
;;         acc)
;;        (tok (car tokens))
;;        (type (first tok))
;;        ((when (equal type :close))
;;         (let ((str (second tok)))
;;           (if (equal str "p")
;;               acc
;;             (text-length-through-close-paragraph (cdr tokens) acc))))
;;        ((when (equal type :text))
;;         (let ((text (second tok)))
;;           (text-length-through-close-paragraph (cdr tokens)
;;                                                (+ acc (length text)))))
;;        ((when (equal type :entity))
;;         (text-length-through-close-paragraph (cdr tokens) (+ 1 acc))))
;;     (text-length-through-close-paragraph (cdr tokens) acc)))

;; (defun rough-size (tokens acc)
;;   ;; Score for how much content a topic contains, just based on tags...
;;   (b* (((when (atom tokens))
;;         acc)
;;        (type (caar tokens))
;;        ((unless (eq type :open))
;;         (rough-size (cdr tokens) acc))
;;        (tagname (second (car tokens)))
;;        ;; Don't use fractions smaller than 1/20 unless you adjust the size-int
;;        ;; computation below.
;;        (acc (cond ((member-equal tagname '("h1" "h2" "h3" "h4" "h5" "a"))
;;                    ;; Structural tags indicate there is enough content to need
;;                    ;; to be structured.  I also want links to external
;;                    ;; resources to weigh heavily since they presumably lead to
;;                    ;; additional information that's not in the manual.
;;                    (+ 2 acc))
;;                   ((member-equal tagname '("ul" "dl" "ol" "img"))
;;                    (+ 1 acc))
;;                   ((member-equal tagname '("li" "dt" "dd" "see" "code"))
;;                    ;; Including code here helps cut down on automatically
;;                    ;; generated stuff.
;;                    (+ 1/10 acc))
;;                   ((member-equal tagname '("tt" "b" "u" "i" "color" "sf" ))
;;                    (+ 1/20 acc))
;;                   ((member-equal tagname '("p"))
;;                    (let ((len (text-length-through-close-paragraph (cdr tokens) 0)))
;;                      (if (< len 50)
;;                          ;; A very short paragraph.  Don't give this much credit.  This
;;                          ;; helps to avoid inflating article scores just because they
;;                          ;; have a long list of "Definition:", etc., as are generated
;;                          ;; by defsection, etc.
;;                          1/20
;;                        1)))
;;                   (t
;;                    acc))))
;;     (rough-size (cdr tokens) acc)))

; The version below seems to work much better.  It could perhaps be tuned a
; bit, but by rough inspection it does a pretty good job.

(defun rough-size
  (tokens    ; Tokens (see parse-xml.lisp) we are processing
   open-tags ; Stack of currently open tags (so we can see if we're in <code>)
   acc       ; Natural-number accumulator, the dumb heuristic weight we're assigning
   )
  ;; Returns the accumulated weight of the topic.  Note that we'll scale this
  ;; down before installing it into the xtopic.
  (b* (((when (atom tokens))
        acc)

       (tok  (car tokens))
       (type (car tok))

       ((when (eq type :close))
        (rough-size (cdr tokens) (cdr open-tags) acc))

       ((when (eq type :open))
        (b* ((tagname (opentok-name tok))
             (acc
              ;; Extra bonuses for certain tags
              (cond ((member-equal tagname '("h1" "h2" "h3" "h4" "h5" "a"))
                     ;; Heading tags indicate there is enough content to need
                     ;; to be structured.  I also want links to external
                     ;; resources to weigh heavily since they presumably lead
                     ;; to additional information that's not in the manual.
                     ;; That is, pointers to papers, etc., may be very
                     ;; valuable.
                     (+ 50 acc))
                    ((member-equal tagname '("ul" "dl" "ol" "img"))
                     (+ 10 acc))
                    ((member-equal tagname '("li" "dt" "dd" "see" "code" "p" "box"))
                     ;; Including code here helps cut down on automatically
                     ;; generated stuff.
                     (+ 2 acc))
                    ((member-equal tagname '("tt" "b" "u" "i" "color" "sf" ))
                     (+ 1 acc))
                    (t acc))))
          (rough-size (cdr tokens) (cons tagname open-tags) acc)))

       (len (if (eq type :text)
                (length (texttok-text tok))
              ;; An entity token is just one character
              1))
       (points (if (member-equal "code" open-tags)
                   ;; Count anything in <code> tags for something, but not very
                   ;; much, because it's often automatically generated.
                   (floor len 5)
                 len)))

    (rough-size (cdr tokens) open-tags (+ points acc))))

(defun xtopic-from-topic
  (topic      ; ordinary xdoc topic to convert
   topics-fal ; for the preprocessor
   state      ; for the preprocessor
   )
  ; returns the corresponding xtopic
  (b* ((name     (cdr (assoc :name topic)))
       (base-pkg (cdr (assoc :base-pkg topic)))
       (short    (or (cdr (assoc :short topic)) ""))
       (long     (or (cdr (assoc :long topic)) ""))
       (parents  (cdr (assoc :parents topic)))

       ((mv long-rchars state) (preprocess-main long nil topics-fal base-pkg state nil))
       (long-str (str::rchars-to-string long-rchars))
       ((mv err long-tokens) (parse-xml long-str))
       (state
        (if err
            (pprogn
             (fms "~|~%WARNING: problem with :long in topic ~x0:~%"
                  (list (cons #\0 name))
                    *standard-co* state nil)
             (princ$ err *standard-co* state)
             (fms "~%~%" nil *standard-co* state nil))
          state))
       ((when err)
        (mv nil state))

       ((mv short-rchars state) (preprocess-main short nil topics-fal base-pkg state nil))
       (short-str (str::rchars-to-string short-rchars))
       ((mv err short-tokens) (parse-xml short-str))
       (state
        (if err
            (pprogn
               (fms "~|~%WARNING: problem with :short in topic ~x0:~%"
                    (list (cons #\0 name))
                    *standard-co* state nil)
               (princ$ err *standard-co* state)
               (fms "~%~%" nil *standard-co* state nil))
          state))
       ((when err)
        (mv nil state))

       (short-links (extract-links (list name :short) short-tokens nil))
       (long-links  (extract-links (list name :long) long-tokens nil))

       (raw-size (+ (rough-size short-tokens nil 0)
                    (rough-size long-tokens nil 0)
                    ;; Basic bonuses for having short/long sections
                    (if (equal short "") 0 10)
                    (if (equal long "")  0 30)))

       (capped-size
        ;; Just by rough inspection, it seems like topics that rack up 4000+
        ;; points seem to be pretty good.  To avoid giving too much weight to
        ;; very long topics, cap things at 4000 and then normalize down to a
        ;; 1-100 scale.
        (if (< raw-size 4000)
            raw-size
          4000))

       (normalized-size
        (floor capped-size 40))

       (xtopic (make-xtopic :name name
                            :base-pkg base-pkg
                            :parents parents
                            :short-tokens short-tokens
                            :long-tokens long-tokens
                            :links (append short-links long-links)
                            :size normalized-size)))
    (mv xtopic state)))

(defun xtopics-from-topics-aux (topics topics-fal state)
  (b* (((when (atom topics))
        (mv nil state))
       ((mv first state)
        (xtopic-from-topic (car topics) topics-fal state))
       ((mv rest state)
        (xtopics-from-topics-aux (cdr topics) topics-fal state))
       (ret (if first
                (cons first rest)
              rest)))
    (mv ret state)))

(defun xtopics-from-topics (topics state)
  (b* ((topics-fal (topics-fal topics))
       ((mv xtopics state)
        (xtopics-from-topics-aux topics topics-fal state)))
    (fast-alist-free topics-fal)
    (mv xtopics state)))

; Cross-reference/subtopic scoring.

(defun dumb-increment-ranks
  (keys      ; Keys whose rank should be incremented
   rank-fal  ; Fast alist binding keys to their current ranks
   by        ; Amount to increment the rank of each key in keys
   )
  (b* (((when (atom keys))
        rank-fal)
       (key      (car keys))
       (curr     (nfix (cdr (hons-get key rank-fal))))
       (rank-fal (hons-acons key (+ by curr) rank-fal)))
    (dumb-increment-ranks (cdr keys) rank-fal by)))

(defun dumb-rank-pages-aux
  (xtopics     ; List of topics, which we iterate through
   rank-fal    ; Fast alist binding keys to ranks, which we update
   )
  ;; This is our main routine for calculating linkage scores.  The weights here
  ;; are somewhat arbitrary but seem (by some inspection) to produce reasonably
  ;; good results
  (b* (((when (atom xtopics))
        rank-fal)
       (rank-fal
        ;; You get a point for existing at all.
        (dumb-increment-ranks 
         (list (make-key (xtopic->name (car xtopics))))
         rank-fal
         1))
       ;; You get some points for every @(see foo) link pointed at you.
       (rank-fal (dumb-increment-ranks (xtopic->links (car xtopics)) rank-fal 2))
       ;; You get some points for every child topic you have.
       (rank-fal (dumb-increment-ranks
                  (make-keys (xtopic->parents (car xtopics))) rank-fal 5)))
    (dumb-rank-pages-aux (cdr xtopics) rank-fal)))

(defun rescale-page-ranks (rank-fal)
  ;; Assumes rank-fal has been shrunk already.
  (b* (((when (atom rank-fal))
        nil)
       ((cons name rank) (car rank-fal))
       ;; By inspection, it seems that quite few pages rack up more than around
       ;; 250 points.  But some pages get way more points than that.  To avoid
       ;; letting extremely heavily linked pages racking up too many points, we
       ;; cut off at 250 and then rescale down to 100.
       (scaled-rank (floor (* 2 (min 250 rank)) 5)))
    (cons (cons name scaled-rank)
          (rescale-page-ranks (cdr rank-fal)))))

(defun dumb-rank-pages (xtopics)
  ;; Returns an alist mapping each KEY to its (rescaled) linkage weight.
  (b* ((rank-fal (dumb-rank-pages-aux xtopics (len xtopics)))
       (ans      (hons-shrink-alist rank-fal nil)))
    (fast-alist-free rank-fal)
    (fast-alist-free ans)
    (rescale-page-ranks ans)))










; Now we have two different sets of ranks: the size rank for the amount of
; content, and the linkage rank for the number of cross-references/children.
; We want to merge these into a unified score.

(defun merge-ranks
  (keys        ; list of keys that should typically be bound in the rank fals
   ranks-fal1  ; fast alist mapping keys to ranks (of some kind)
   ranks-fal2  ; fast alist mapping keys to ranks (of some other kind)
   )
  ;; Returns a new alist where each key is bound to the sum of its ranks in the
  ;; two alists.  This is an especially simple and naive merge.  We *could*
  ;; alter how these are merged to, e.g., say that size counts for 70% of your
  ;; score and linkage only 30%, or similar.  Alternately, we could adjust the
  ;; scaling factors above to achieve the same effect -- e.g., in
  ;; rescale-page-ranks we could just change the scaled-rank to be between 1-70
  ;; instead of 1-100, and so on.  For now, scoring things 50/50 doesn't seem
  ;; too bad.
  (b* (((when (atom keys))
        nil)
       (key1 (car keys))
       (r1   (nfix (cdr (hons-get key1 ranks-fal1))))
       (r2   (nfix (cdr (hons-get key1 ranks-fal2)))))
    (cons (cons key1 (+ r1 r2))
          (merge-ranks (cdr keys) ranks-fal1 ranks-fal2))))

(defun rank-xtopics
  (keys     ; all keys to consider (may differ from xtopics keys if there are bad
            ; topics for which we didn't compute xtopics.
   xtopics  ; list of all xtopics
   )
  ;; returns a slow alist binding keys to ranks
  (b* (;(names       (xtopiclist->names xtopics))
       (ranks-fal1  (make-fast-alist (dumb-rank-pages xtopics)))
       (ranks-fal2  (make-fast-alist (pairlis$ (make-keys (xtopiclist->names xtopics))
                                               (xtopiclist->sizes xtopics))))
       (keys->ranks (merge-ranks keys ranks-fal1 ranks-fal2))
       (-           (fast-alist-free ranks-fal1))
       (-           (fast-alist-free ranks-fal2))
       (- (or (equal (mergesort (strip-cars keys->ranks))
                     (mergesort keys))
              (er hard? 'rank-topics "Blah, wrong keys!")))
                                
       ;; keys->ranks binds keys to ranks and should have unique keys.  invert
       ;; it and sort it to order the keys by their ranks
       (ranks->keys (pairlis$ (strip-cdrs keys->ranks)
                              (strip-cars keys->ranks)))
       (keys-lo-to-hi (strip-cdrs (mergesort ranks->keys)))
       ;(- (cw "Length of keys->ranks ~x0~%" (len keys->ranks)))
       ;(- (cw "Length of ranks->keys ~x0~%" (len ranks->keys)))
       ;(- (cw "Length of keys-lo-to-hi ~x0~%" (len keys-lo-to-hi)))
       (- (or (equal (mergesort keys-lo-to-hi)
                     (mergesort keys))
              (er hard? 'rank-topics "Blah, wrong keys 2")))
       (keys-hi-to-lo (reverse keys-lo-to-hi))
       (- (or (equal (mergesort keys-hi-to-lo)
                     (mergesort keys))
              (er hard? 'rank-topics "Blah, wrong keys 3"))))
    keys-hi-to-lo))

(defun collect-topics-by-importance
  (keys         ; list of keys for all topics in most-important-first order
   keymap       ; fast alist mapping keys to topic names (for fast lookups)
   topics-fal   ; alist of xdoc topic names to topics (for fast lookups)
   )
  ;; Returns a list of ordinary xdoc topics in most-important-first order
  (b* (((when (atom keys))
        nil)
       (key1        (car keys))
       (name1-look  (hons-get key1 keymap))
       (- (or name1-look
              (er hard? 'collect-topics-by-importance
                  "Error looking up key ~x0 in keymap!" key1)))
       (name1 (cdr name1-look))
       (topic1-look (hons-get name1 topics-fal))
       (- (or topic1-look
              (er hard? 'collect-topics-by-importance
                  "Error looking up topic ~x0 in topics-fal!" name1)))
       (topic1 (cdr topic1-look)))
    (cons topic1
          (collect-topics-by-importance (cdr keys) keymap topics-fal))))

(defun order-topics-by-importance (all-topics state)
  (b* ((topics-fal   (topics-fal all-topics))
       ;(- (cw "First 3 of topics-fal: ~x0.~%" (take 3 topics-fal)))
       ;(- (cw "Length of topics-fal: ~x0.~%" (len topics-fal)))
       (topics-names (strip-cars topics-fal))
       (topics-keys  (make-keys topics-names))
       ((mv xtopics state) (xtopics-from-topics all-topics state))
       (state        (report-broken-links xtopics state))
       (ordered-keys (rank-xtopics topics-keys xtopics))

       ;(- (cw "First 3 ordered-keys: ~x0.~%" (take 3 ordered-keys)))
       ;(- (cw "First 3 topics-keys: ~x0.~%" (take 3 topics-keys)))
       ;(- (cw "Number of ordered keys: ~x0.~%" (len ordered-keys)))
       ;(- (or (equal (mergesort ordered-keys)
       ;              (mergesort topics-keys))
       ;       (cw "Diff ordered-keys, topic-keys: ~x0.~%"
       ;           (mergesort (set-difference-equal ordered-keys topics-keys)))
       ;       (cw "Diff topic-keys, ordered-keys: ~x0.~%"
       ;           (mergesort (set-difference-equal topics-keys ordered-keys)))
       ;       (er hard? 'order-topics-by-importance "Don't have the same keys!")))
       (keymap       (make-fast-alist (pairlis$ topics-keys topics-names)))
       ;(- (cw "Keymap is ~x0.~%" keymap))
       (result       (collect-topics-by-importance ordered-keys keymap topics-fal))
       ;(- (cw "First 3 results: ~x0.~%" (take 3 result)))
       ;(- (cw "Length of result: ~x0.~%" (length result)))
       ;(- (cw "Names of result: ~x0.~%" (strip-cars (fast-alist-free (topics-fal result)))))
       )
    (fast-alist-free topics-fal)
    (fast-alist-free keymap)
    (or (equal (mergesort topics-names)
               (mergesort (strip-cars (fast-alist-free (topics-fal result)))))
        (er hard? 'order-topics-by-importance
            "Screwed up the database!"))
    (mv result state)))       



#||

For testing, get documentation loaded.  Newlines to avoid dependency scanner
picking these up.

(ld
 "importance.lisp")

(include-book
 "tools/defconsts" :dir :system)
(include-book
 "centaur/aignet/portcullis" :dir :system)
(include-book
 "centaur/getopt/portcullis" :dir :system)
(include-book
 "centaur/vl/portcullis" :dir :system)
(include-book
 "centaur/gl/portcullis" :dir :system)
(include-book
 "centaur/clex/portcullis" :dir :system)
(ld
 "cgen/package.lsp" :dir :system)

(acl2::defconsts (*xdoc.sao* state)
  (serialize-read "../centaur/xdoc.sao" :verbosep t))

(table xdoc 'doc
       (clean-topics *xdoc.sao*))

(acl2::defconsts *all-topic-names*
                 (gather-topic-names (get-xdoc-table (w state))))

(xdoc-quiet)
(make-event
 (b* (((mv xtopics state)
       (xtopics-from-topics (get-xdoc-table (w state)) state)))
   (value
    `(defconst *xtopics* ',xtopics))))

;; (trace$ (dumb-rank-pages-aux :entry
;;                              (if (xtopic-p (car xtopics))
;;                                  (change-xtopic (car xtopics)
;;                                                 :short-tokens "..."
;;                                                 :long-tokens "...")
;;                                (car xtopics))
;;                              :exit nil))

(defconst *page-ranks*
  (make-fast-alist (dumb-rank-pages *xtopics*)))

(defconst *size-ranks*
  (make-fast-alist (pairlis$ (make-keys (xtopiclist->names *xtopics*))
                             (xtopiclist->sizes *xtopics*))))

(defconst *final-ranks*
  (make-fast-alist
   (merge-ranks (make-keys *all-topic-names*)
                *page-ranks* *size-ranks*)))

(defun report (keys)
  (b* (((when (atom keys))
        nil)
       (key   (car keys))
       (final (cdr (hons-get key *final-ranks*)))
       (page  (cdr (hons-get key *page-ranks*)))
       (size  (cdr (hons-get key *size-ranks*))))
    (cons (list final key page size)
          (report (cdr keys)))))

(make-event
 (b* ((keys   (make-keys *all-topic-names*))
      (result (rank-xtopics keys *xtopics*)))
   `(defconst *keys-in-order-of-importance*
      ',result)))

(report *keys-in-order-of-importance*)


(acl2::defconsts (*new-topics* state)
  (b* ((all-topics (get-xdoc-table (w state)))
       ((mv new-topics state)
        (time$ (order-topics-by-importance all-topics state))))
    (mv new-topics state)))

(report (make-keys (gather-topic-names *new-topics*)))

||#
