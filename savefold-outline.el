;;; savefold-outline.el --- savefold for outline mode -*- lexical-binding: t; -*-

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

;; This package implements persistence for outline-mode and outline-minor-mode
;; folds.

;;; Code:

(require 'outline)
(require 'savefold-utils)

(defvar savefold-outline--folds-attr 'savefold-outline-folds)

(defun savefold-outline--make-fold (fold-data)
  "Make markdown fold from FOLD-DATA."
  (cl-destructuring-bind (start end) fold-data
    (outline-flag-region start end t)))

(defun savefold-outline--recover-folds ()
  "Read and apply saved outline fold data for the current buffer."
  ;; Maybe find away to abstract out this recency check
  (savefold-utils--unless-file-recently-modified
   (mapc
    #'savefold-outline--make-fold
    (savefold-utils--get-file-attr savefold-outline--folds-attr))))

(defun savefold-outline--outline-foldp (ov)
  "Check whether OV is an outline-mode/outline-minor-mode fold overlay."
  (eq (overlay-get ov 'invisible) 'outline))

(defun savefold-outline--save-folds ()
  "Save outline fold data for the current buffer.

This also saves the modification time of the file."
  ;; Assume this means the buffer reflects the actual file state
  (unless (buffer-modified-p)
    (savefold-utils--set-file-attr
     savefold-outline--folds-attr
     (mapcar
      (lambda (ov) `(,(overlay-start ov) ,(overlay-end ov)))
      (savefold-utils--get-overlays #'savefold-outline--outline-foldp)))
    (savefold-utils--set-file-attr-modtime)
    (savefold-utils--write-out-file-attrs)))

(defun savefold-outline--bufferp ()
  (or (derived-mode-p 'outline-mode)
      (bound-and-true-p outline-minor-mode)))

;;;###autoload
(define-minor-mode savefold-outline-mode
  "Toggle global persistence for outline-mode/outline-minor-mode folds."
  :global t
  :init-value nil
  :group 'savefold
  (if savefold-outline-mode
      (savefold-utils--set-up-standard-hooks 'outline
                                             '(outline-mode outline-minor-mode)
                                             'savefold-outline--recover-folds
                                             'savefold-outline--save-folds
                                             'savefold-outline--bufferp)
    (savefold-utils--unhook-standard-hooks 'outline
                                           '(outline-mode outline-minor-mode)
                                           'savefold-outline--recover-folds
                                           'savefold-outline--bufferp)))

(provide 'savefold-outline)

;;; savefold-outline.el ends here
