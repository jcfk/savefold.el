;;; savefold-yafolding.el --- savefold for yafolding mode -*- lexical-binding: t; -*-

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

;; This library implements persistence for yafolding folds.

;;; Code:

(require 'savefold-utils)

(declare-function yafolding-hide-element "ext:yafolding.el")  ;; Provided by yafolding

(defvar savefold-yafolding--folds-attr 'savefold-yafolding-folds)

(defun savefold-yafolding--recover-folds ()
  "Read and apply saved yafolding fold data for the current buffer."
  (savefold-utils--unless-file-recently-modified
   (mapc
    (lambda (start)
      (save-excursion
        (goto-char start)
        (yafolding-hide-element)))
    (savefold-utils--get-file-attr savefold-yafolding--folds-attr))))

(defun savefold-yafolding--yafolding-foldp (ov)
  "Check whether OV is a yafolding fold overlay."
  (eq (overlay-get ov 'category) 'yafolding))

(defun savefold-yafolding--save-folds ()
  "Save yafolding fold data for the current buffer."
  (unless (buffer-modified-p)
    (savefold-utils--set-file-attr
     savefold-yafolding--folds-attr
     (mapcar
      ;; This is the line-end-position of the line before the yafolding element
      #'overlay-start
      (savefold-utils--get-overlays #'savefold-yafolding--yafolding-foldp)))
    (savefold-utils--set-file-attr-modtime)
    (savefold-utils--write-out-file-attrs)))

(defun savefold-yafolding--bufferp ()
  (bound-and-true-p yafolding-mode))

;;;###autoload
(define-minor-mode savefold-yafolding-mode
  "Toggle global persistence for `yafolding-mode' folds."
  :global t
  :init-value nil
  :group 'savefold
  (if savefold-yafolding-mode
      (progn
        (savefold-utils--require 'yafolding)
        (savefold-utils--set-up-standard-hooks 'yafolding
                                               '(yafolding-mode)
                                               'savefold-yafolding--recover-folds
                                               'savefold-yafolding--save-folds
                                               'savefold-yafolding--bufferp))
    (savefold-utils--unhook-standard-hooks 'yafolding
                                           '(yafolding-mode)
                                           'savefold-yafolding--recover-folds
                                           'savefold-yafolding--bufferp)))

(provide 'savefold-yafolding)

;;; savefold-yafolding.el ends here

