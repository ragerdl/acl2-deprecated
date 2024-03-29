; OSLIB -- Operating System Utilities
; Copyright (C) 2013 Centaur Technology
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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "OSLIB")

(defun getpid-fn (state)

  (unless (live-state-p state)
    (er hard? 'getpid "Getpid can only be called on a live state.")
    (mv nil state))

  (let ((pid (handler-case (iolib.syscalls::getpid)
                           (error (condition)
                                  (format nil "getpid: ~a" condition)))))
    (if (natp pid)
        (mv pid state)
      (progn
        (format t "getpid error: (iolib.syscalls::getpid) returned ~a." pid)
        (mv nil state)))))

