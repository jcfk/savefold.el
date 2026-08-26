;;; savefold-hideshow.el --- savefold for hideshow mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Jacob Fong

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the “Software”), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This library implements persistence for hideshow folds.

;;; Code:

(require 'hideshow)
(require 'seq)
(require 'savefold-utils)

(defvar savefold-hideshow--folds-attr 'savefold-hideshow-folds)

(defun savefold-hideshow--adapt-fold-data (fold-data)
  "Return fields from FOLD-DATA supported by the current Hideshow.

Emacs 31 removed the optional block-offset arguments from `hs-make-overlay'."
  (seq-take fold-data (cdr (func-arity #'hs-make-overlay))))

(defun savefold-hideshow--make-overlay (fold-data)
  "Restore a Hideshow overlay from saved FOLD-DATA.

Hideshow removed its optional block-offset arguments in Emacs 31.  Limit the
saved fields to the maximum arity supported by the current implementation, so
five-field data from older Emacs versions remains readable after an upgrade."
  (apply #'hs-make-overlay (savefold-hideshow--adapt-fold-data fold-data)))

(defun savefold-hideshow--recover-folds ()
  "Read and apply saved hideshow fold data for the current buffer."
  (savefold-utils--unless-file-recently-modified
   (mapc #'savefold-hideshow--make-overlay
         (savefold-utils--get-file-attr savefold-hideshow--folds-attr))))

(defun savefold-hideshow--get-fold-data (ov)
  (savefold-hideshow--adapt-fold-data
   `(,(overlay-start ov)
     ,(overlay-end ov)
     ,(overlay-get ov 'hs)
     ,(overlay-get ov 'hs-b-offset)
     ,(overlay-get ov 'hs-e-offset))))

(defun savefold-hideshow--hideshow-foldp (ov)
  "Check whether OV is a hideshow fold overlay."
  (eq (overlay-get ov 'invisible) 'hs))

(defun savefold-hideshow--save-folds ()
  "Save hideshow fold data for the current buffer."
  (unless (buffer-modified-p)
    (savefold-utils--set-file-attr
     savefold-hideshow--folds-attr
     (mapcar
      #'savefold-hideshow--get-fold-data
      (savefold-utils--get-overlays #'savefold-hideshow--hideshow-foldp)))
    (savefold-utils--set-file-attr-modtime)
    (savefold-utils--write-out-file-attrs)))

(defun savefold-hideshow--bufferp ()
  (bound-and-true-p hs-minor-mode))

;;;###autoload
(define-minor-mode savefold-hideshow-mode
  "Toggle global persistence of hideshow folds."
  :global t
  :init-value nil
  :group 'savefold
  (if savefold-hideshow-mode
      (savefold-utils--set-up-standard-hooks
       'hideshow
       '(hs-minor-mode)
       'savefold-hideshow--recover-folds
       'savefold-hideshow--save-folds
       'savefold-hideshow--bufferp)
    (savefold-utils--unhook-standard-hooks
     'hideshow
     '(hs-minor-mode)
     'savefold-hideshow--recover-folds
     'savefold-hideshow--bufferp)))

(provide 'savefold-hideshow)

;;; savefold-hideshow.el ends here
