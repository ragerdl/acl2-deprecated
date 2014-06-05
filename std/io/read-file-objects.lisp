; Standard IO Library
; read-file-objects.lisp -- originally part of the Unicode library
; Copyright (C) 2005-2013 by Jared Davis <jared@cs.utexas.edu>
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

(in-package "ACL2")
(include-book "file-measure")
(include-book "std/lists/list-defuns" :dir :system)
(local (include-book "base"))
(local (include-book "std/lists/rev" :dir :system))
(local (include-book "std/lists/append" :dir :system))
(local (include-book "std/lists/revappend" :dir :system))
(local (include-book "tools/mv-nth" :dir :system))
(set-state-ok t)


(defsection read-object-all
  :parents (read-file-objects)
  :short "@(call read-object-all) reads all remaining objects from a file."

  :long "<p>This is the main loop inside @(see read-file-objects).  It reads
everything in the file, but doesn't handle opening or closing the file.</p>"

  (defund tr-read-object-all (channel state acc)
    (declare (xargs :guard (and (state-p state)
                                (symbolp channel)
                                (open-input-channel-p channel :object state))
                    :measure (file-measure channel state)))
    (b* (((unless (mbt (state-p state)))
          (mv acc state))
         ((mv eofp obj state) (read-object channel state))
         ((when eofp)
          (mv acc state)))
      (tr-read-object-all channel state (cons obj acc))))

  (defund read-object-all (channel state)
    (declare (xargs :guard (and (state-p state)
                                (symbolp channel)
                                (open-input-channel-p channel :object state))
                    :measure (file-measure channel state)
                    :verify-guards nil))
    (mbe :logic (b* (((unless (state-p state))
                      (mv nil state))
                     ((mv eofp obj state) (read-object channel state))
                     ((when eofp)
                      (mv nil state))
                     ((mv rest state)
                      (read-object-all channel state)))
                  (mv (cons obj rest) state))
         :exec (b* (((mv acc state)
                     (tr-read-object-all channel state nil)))
                 (mv (reverse acc) state))))

  (local (in-theory (enable tr-read-object-all read-object-all)))

  (local (defthm lemma-decompose-impl
           (equal (tr-read-object-all channel state acc)
                  (list (mv-nth 0 (tr-read-object-all channel state acc))
                        (mv-nth 1 (tr-read-object-all channel state acc))))
           :rule-classes nil))

  (local (defthm lemma-decompose-spec
           (equal (read-object-all channel state)
                  (list (mv-nth 0 (read-object-all channel state))
                        (mv-nth 1 (read-object-all channel state))))
           :rule-classes nil))

  (local (defthm lemma-data-equiv
           (equal (mv-nth 0 (tr-read-object-all channel state acc))
                  (revappend (mv-nth 0 (read-object-all channel state)) acc))))

  (local (defthm lemma-state-equiv
           (equal (mv-nth 1 (tr-read-object-all channel state acc))
                  (mv-nth 1 (read-object-all channel state)))))

  (defthm tr-read-object-all-removal
    (equal (tr-read-object-all channel state nil)
           (mv (rev (mv-nth 0 (read-object-all channel state)))
               (mv-nth 1 (read-object-all channel state))))
    :hints(("Goal" :in-theory (disable tr-read-object-all read-object-all)
            :use ((:instance lemma-decompose-impl (acc nil))
                  (:instance lemma-decompose-spec)
                  (:instance lemma-data-equiv (acc nil))))))

  (defthm true-listp-of-read-object-all
    (true-listp (mv-nth 0 (read-object-all channel state)))
    :rule-classes :type-prescription)

  (verify-guards read-object-all)

  (defthm state-p1-of-read-object-all
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :object state)))
             (state-p1 (mv-nth 1 (read-object-all channel state)))))

  (defthm open-input-channel-p1-of-read-object-all
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :object state)))
             (open-input-channel-p1 channel :object
                                    (mv-nth 1 (read-object-all channel state))))))





(defsection read-file-objects
  :parents (std/io)
  :short "Read an entire file into a list of ACL2 objects."

  :long "<p><b>Signature:</b> @(call read-file-objects) returns @('(mv contents state)').</p>

<p>On success, @('contents') is a @(see true-listp) of ACL2 objects that have
were found in the file, obtained by repeatedly calling @(see read-object).</p>

<p>On failure, e.g., perhaps @('filename') does not exist, @('contents') will
be a @(see stringp) saying that we failed to open the file.</p>"

  (defund read-file-objects (filename state)
    "Returns (MV ERRMSG/OBJECTS STATE)"
    (declare (xargs :guard (and (state-p state)
                                (stringp filename))))
    (b* ((filename (mbe :logic (if (stringp filename) filename "")
                        :exec filename))
         ((mv channel state)
          (open-input-channel filename :object state))
         ((unless channel)
          (mv (concatenate 'string "Error opening file " filename)
              state))
         ((mv data state)
          (read-object-all channel state))
         (state (close-input-channel channel state)))
      (mv data state)))

  (local (in-theory (enable read-file-objects)))

  (defthm state-p1-of-read-file-objects
    (implies (force (state-p1 state))
             (state-p1 (mv-nth 1 (read-file-objects filename state)))))

  (defthm true-listp-of-read-file-objects
    (equal (true-listp (mv-nth 0 (read-file-objects filename state)))
           (not (stringp (mv-nth 0 (read-file-objects filename state))))))

  (defthm type-of-read-file-objects
    (or (stringp (mv-nth 0 (read-file-objects filename state)))
        (true-listp (mv-nth 0 (read-file-objects filename state))))
    :rule-classes :type-prescription))

