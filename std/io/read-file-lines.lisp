; Standard IO Library
; read-file-lines.lisp -- originally part of the Unicode library
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
(include-book "std/strings/cat" :dir :system)
(local (include-book "base"))
(local (include-book "std/lists/revappend" :dir :system))
(local (include-book "std/lists/append" :dir :system))
(local (include-book "std/lists/rev" :dir :system))
(local (include-book "tools/mv-nth" :dir :system))
(set-state-ok t)


(defsection read-file-lines-aux
  :parents (read-file-lines)
  :short "Tail recursive implementation of @(see read-file-lines)."
  :long "<p>@(call read-file-lines-aux) returns @('(mv lines state)')</p>
<ul>
<li>@('line') is a character list, the current line in reverse order</li>
<li>@('lines') are a string list, the previously read lines in reverse order</li>
<li>@('channel') is the @(':byte') channel we're reading from</li>
</ul>"

  (defund read-file-lines-aux (line lines channel state)
    (declare (xargs :guard (and (character-listp line)
                                (string-listp lines)
                                (symbolp channel)
                                (open-input-channel-p channel :byte state))
                    :stobjs state
                    :measure (file-measure channel state)))
    (b* (((unless (mbt (state-p state)))
          (mv lines state))
         ((mv byte state)
          (read-byte$ channel state))
         ((unless byte)
          (let ((lines (cons (str::rchars-to-string line) lines)))
            (mv lines state)))
         ((the character char) (code-char (the (unsigned-byte 8) byte)))
         (line (cons char line))
         ((when (eql char #\Newline))
          (let ((lines (cons (str::rchars-to-string line) lines)))
            (read-file-lines-aux nil lines channel state))))
      (read-file-lines-aux line lines channel state)))

  (local (in-theory (enable read-file-lines-aux)))

  (defthm state-p1-of-read-file-lines-aux
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (b* (((mv ?lines state)
                   (read-file-lines-aux line lines channel state)))
               (state-p1 state))))

  (defthm open-input-channel-p1-of-read-file-lines-aux
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (b* (((mv ?lines state)
                   (read-file-lines-aux line lines channel state)))
               (open-input-channel-p1 channel :byte state))))

  (defthm string-listp-of-read-file-lines-aux
    (implies (force (string-listp lines))
             (string-listp
              (mv-nth 0 (read-file-lines-aux line lines channel state)))))

  (defthm true-listp-of-read-file-lines-aux
    (equal (true-listp (mv-nth 0 (read-file-lines-aux line lines channel state)))
           (true-listp lines))))



(defsection read-file-lines
  :parents (std/io)
  :short "Read an entire file into a list of lines (strings)."
  :long "<p><b>Signature:</b> @(call read-file-lines) returns @('(mv contents state)').</p>

<p>On success, @('contents') is a @(see string-listp) that contains each line
of the file.</p>

<p>On failure, e.g., perhaps @('filename') does not exist, @('contents') will
be a @(see stringp) saying that we failed to open the file.</p>

<p><b>BOZO</b> This currently just looks for individual newline characters,
i.e., @('#\\Newline'), sometimes called @('\\n').  It might be desirable to
change how it works to somehow support @('\\r\\n') or whatever other
carriage-return stuff people use on platforms like Windows.</p>"

  (defund read-file-lines (filename state)
    "Returns (MV ERRMSG/LINES STATE)"
    (declare (xargs :guard (stringp filename)
                    :stobjs state))
    (b* ((filename (mbe :logic (if (stringp filename) filename "")
                        :exec filename))
         ((mv channel state)
          (open-input-channel filename :byte state))
         ((unless channel)
          (mv (concatenate 'string "Error opening file " filename) state))
         ((mv data state)
          (read-file-lines-aux nil nil channel state))
         (state (close-input-channel channel state)))
      (mv (reverse data) state)))

  (local (in-theory (enable read-file-lines)))

  (defthm state-p1-of-read-file-lines
    (implies (force (state-p1 state))
             (state-p1 (mv-nth 1 (read-file-lines filename state)))))

  (local (defthm crock
           (implies (string-listp x)
                    (string-listp (rev x)))))

  (defthm string-listp-of-read-file-lines
    (equal (string-listp (mv-nth 0 (read-file-lines filename state)))
           (not (stringp (mv-nth 0 (read-file-lines filename state)))))))
