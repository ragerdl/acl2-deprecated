; Centaur Miscellaneous Books
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
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>


(in-package "ACL2")

(include-book "tools/bstar" :dir :system)

(defun with-fast-alists-fn (alists form)
  (if (atom alists)
      form
    `(with-fast-alist ,(car alists)
                      ,(with-fast-alists-fn (cdr alists) form))))

(defmacro with-fast-alists (alists form)
  ":Doc-Section Hons-and-Memoization

Concisely call ~ilc[with-fast-alist] on multiple alists.~/~/

Example:
~bv[]
 (with-fast-alists (a b c) form)
~ev[]
is just shorthand for:
~bv[]
 (with-fast-alist a
  (with-fast-alist b
   (with-fast-alist c
    form)))
~ev[]"

  (with-fast-alists-fn alists form))

(def-b*-binder with-fast
  (declare (xargs :guard (not forms))
           (ignorable forms))
  `(with-fast-alists ,args ,rest-expr))



#||

(b* ((a '((1 . a) (2 . b) (3 . c)))
     (b '((1 . a) (2 . b) (3 . d)))
     (- (cw "Before with-fast-alists:~%"))
     (- (fast-alist-summary)))

    (with-fast-alists
     (a b)
     (b* ((- (cw "After with-fast-alists:~%"))
          (- (fast-alist-summary))
          (x (hons-get 2 a))
          (a ())
          (y (hons-get 3 b)))
       (list (cdr x) (cdr y) a))))

(fast-alist-summary)

(b* ((a '((1 . a) (2 . b) (3 . c)))
     (b '((1 . a) (2 . b) (3 . d)))
     (- (cw "Before with-fast:~%"))
     (- (fast-alist-summary))
     ((with-fast a b))      ;; a and b become fast until the end of the b*.
     (- (cw "After with-fast:~%"))
     (- (fast-alist-summary))
     (x (hons-get 2 a))
     (a ())
     (y (hons-get 3 b)))
  (list (cdr x) (cdr y) a))

(fast-alist-summary)

||#

(defun alist-of-alistsp (lst)
  (declare (xargs :guard t))
  (cond ((atom lst)
         (null lst))
        ((and (consp (car lst))
              (alistp (cdar lst)))
         (alist-of-alistsp (cdr lst)))
        (t nil)))

(defun make-fast-alist-of-alists (lst)

; Perhaps a tail recursive definition would be better, but this is simpler (so
; long as we don't overflow the stack).

  (declare (xargs :guard (alist-of-alistsp lst)
                  :mode :logic))
  (cond 
   ((atom lst)
    lst)
   (t 
    (let* ((current-entry (car lst)))
      (cond ((atom current-entry)
             (prog2$ (er hard 'make-fast-alist-of-alists
                         "Guard of alist-of-alistp not met.  ~x0 was an atom ~
                          when it needed to be an [inner] alist."
                         current-entry)
                     lst))
            (t (let* ((current-entry-key (car current-entry))
                      (current-entry-val (cdr current-entry))
                      (new-current-entry-val (make-fast-alist current-entry-val)))
                 (hons-acons current-entry-key
                             new-current-entry-val
                             (make-fast-alist-of-alists (cdr lst))))))))))

(defthm make-fast-alist-of-alists-identity
  (equal (make-fast-alist-of-alists lst) lst))

(in-theory (disable make-fast-alist-of-alists))
 
(defun with-stolen-alists-fn (alists form)
  (if (atom alists)
      form
    `(with-stolen-alist ,(car alists)
                      ,(with-stolen-alists-fn (cdr alists) form))))

(defmacro with-stolen-alists (alists form)
  ":Doc-Section Hons-and-Memoization

Concisely call ~ilc[with-stolen-alist] on multiple alists.~/~/

Example:
~bv[]
 (with-stolen-alists (a b c) form)
~ev[]
is just shorthand for:
~bv[]
 (with-stolen-alist a
  (with-stolen-alist b
   (with-stolen-alist c
    form)))
~ev[]"

  (with-stolen-alists-fn alists form))

(def-b*-binder with-stolen
  (declare (xargs :guard (not forms))
           (ignorable forms))
  `(with-stolen-alists ,args ,rest-expr))



#||

(b* ((a '((1 . a) (2 . b) (3 . c)))
     (b '((1 . a) (2 . b) (3 . d)))
     (- (cw "Before with-stolen-alists:~%"))
     (- (fast-alist-summary))
     (res (with-stolen-alists
            (a b)
            (b* ((- (cw "Inside with-stolen-alists:~%"))
                 (- (fast-alist-summary))
                 (x (hons-get 2 a))
                 (a ())
                 (y (hons-get 3 b)))
              (list (cdr x) (cdr y) a)))))
  (cw "After with-stolen-alists:~%")
  (fast-alist-summary)
  res)

(b* ((a '((1 . a) (2 . b) (3 . c)))
     (b (make-fast-alist '((1 . a) (2 . b) (3 . d))))
     (- (cw "Before with-stolen-alists:~%"))
     (- (fast-alist-summary))
     (res (with-stolen-alists
            (a b)
            (b* ((- (cw "Inside with-stolen-alists:~%"))
                 (- (fast-alist-summary))
                 (x (hons-get 2 a))
                 (a ())
                 (b (hons-acons 5 'f b))
                 (y (hons-get 5 b)))
              (fast-alist-free b)
              (list (cdr x) (cdr y) a))))
     (b (hons-acons 4 'e b)))
  (cw "After with-stolen-alists:~%")
  (fast-alist-summary)
  (fast-alist-free b)
  res)

||#


(defun fast-alists-free-on-exit-fn (alists form)
  (if (atom alists)
      form
    `(fast-alist-free-on-exit ,(car alists)
                              ,(fast-alists-free-on-exit-fn (cdr alists) form))))

(defmacro fast-alists-free-on-exit (alists form)
  ":Doc-Section Hons-and-Memoization
Concisely call ~ilc[fast-alist-free-on-exit] for several alists.~/

For example:
~bv[]
 (fast-alists-free-on-exit (a b c) form)
~ev[]
is just shorthand for:
~bv[]
 (fast-alist-free-on-exit a
  (fast-alist-free-on-exit b
   (fast-alist-free-on-exit c
    form)))
~ev[]~/~/"
  (fast-alists-free-on-exit-fn alists form))

(def-b*-binder free-on-exit
  (declare (xargs :guard (not forms))
           (ignorable forms))
  `(fast-alists-free-on-exit ,args ,rest-expr))


#|

(fast-alist-summary)

(let ((a (hons-acons 'a 1 'a-alist)))
  (fast-alist-free-on-exit a            ;; a is still fast until the end of the
    (hons-get 'a a)))                   ;; fast-alist-free-on-exit form

(fast-alist-summary)

(let ((a (hons-acons 'a 1 'a-alist))    ;; a and b are still fast until the
      (b (hons-acons 'b 2 'b-alist)))   ;; exit of the fast-alists-free-on-exit
  (fast-alists-free-on-exit             ;; form.
   (a b)
   (+ (cdr (hons-get 'a a))
      (cdr (hons-get 'b b)))))

(fast-alist-summary)



(b* ((- (fast-alist-summary))

     (a (hons-acons 'a 1 'a-alist))
     (b (hons-acons 'b 2 'b-alist))
     (- (cw "After creating a and b.~%"))
     (- (fast-alist-summary))

     ((free-on-exit a b))           ;; a and b are still fast until the end of

     (c (hons-acons 'c 3 'c-alist))
     (- (cw "After creating c.~%"))
     (- (fast-alist-summary))
     (- (fast-alist-free c)))

  (+ (cdr (hons-get 'a a))
     (cdr (hons-get 'b b))))

(fast-alist-summary) ;; all alists freed

|#
