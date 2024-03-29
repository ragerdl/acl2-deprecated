; XDOC Documentation System for ACL2
; Copyright (C) 2009-2013 Centaur Technology
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
(include-book "display")

(defmacro xdoc-autodebug ()
  '(local (make-event
           (b* ((topics (get-xdoc-table (w state)))
                ((unless (consp topics))
                 (er soft 'xdoc-autodebug "No topics after defxdoc form?"))
                (new-topic (car topics))
                (name      (cdr (assoc :name new-topic)))
                (state (princ$
"-------------------------------- xdoc preview ---------------------------------
" *standard-co* state))
                ((mv ?er ?val state)
                 (colon-xdoc-fn name topics state))
                (state (princ$ "
-------------------------------------------------------------------------------
" *standard-co* state)))
             (value '(value-triple :invisible))))))

(table xdoc 'post-defxdoc-event '(xdoc-autodebug))

