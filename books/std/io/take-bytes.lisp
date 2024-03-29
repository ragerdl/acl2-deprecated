; Standard IO Library
; take-bytes.lisp -- originally part of the Unicode library
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
(include-book "read-file-bytes")
(include-book "nthcdr-bytes")
(local (include-book "base"))
(local (include-book "arithmetic/top" :dir :system))
(local (include-book "tools/mv-nth" :dir :system))
(set-state-ok t)

(defsection take-bytes
  :parents (std/io)
  :short "Read the first @('n') bytes from an open file."
  :long "<p>@(call take-bytes) is like @(see take) for an @(':byte') input
channel.  That is, it just reads @('n') bytes and returns them as a list,
and also returns the updated state.</p>"

  (defund take-bytes (n channel state)
    (declare (xargs :guard (and (natp n)
                                (state-p state)
                                (symbolp channel)
                                (open-input-channel-p channel :byte state))))
    (b* (((when (zp n))
          (mv nil state))
         ((mv a state)
          (read-byte$ channel state))
         ((mv x state)
          (take-bytes (1- n) channel state)))
      (mv (cons a x) state)))

  (local (in-theory (enable take-bytes nthcdr-bytes)))

  (defthm state-p1-of-take-bytes
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (state-p1 (mv-nth 1 (take-bytes n channel state)))))

  (defthm open-input-channel-p1-of-take-bytes
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (open-input-channel-p1 channel :byte
                                    (mv-nth 1 (take-bytes n channel state)))))

  (defthm mv-nth0-of-take-bytes
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (equal (mv-nth 0 (take-bytes n channel state))
                    (take n (mv-nth 0 (read-byte$-all channel state)))))
    :hints(("Goal"
            :in-theory (enable take-redefinition read-byte$-all replicate)
            :induct (take-bytes n channel state))))

  (defthm mv-nth1-of-take-bytes$
    (implies (and (force (state-p1 state))
                  (force (symbolp channel))
                  (force (open-input-channel-p1 channel :byte state)))
             (equal (mv-nth 1 (take-bytes n channel state))
                    (nthcdr-bytes n channel state)))))
