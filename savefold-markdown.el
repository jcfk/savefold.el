;;; savefold-markdown.el --- savefold for markdown-mode -*- lexical-binding: t; -*-

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

;; This package implements persistence for
;; https://github.com/jrblevin/markdown-mode folds.
;;
;; markdown-mode folding is implemented via outline-mode.

;;; Code:

(require 'savefold-utils)
(require 'savefold-outline)

(defvar savefold-markdown--folds-attr 'savefold-markdown-folds)

;; What is the story with these guys?
;; (defvar savefold-markdown--cycle-global-status 'savefold-markdown-cycle-global-status)
;; (defvar savefold-markdown--cycle-subtree-status 'savefold-markdown-cycle-subtree-status)

(defun savefold-markdown--recover-folds ()
  "Read and apply saved markdown fold data for the current buffer."
  (savefold-utils--unless-file-recently-modified
   (mapc
    #'savefold-outline--make-fold
    (savefold-utils--get-file-attr savefold-markdown--folds-attr))))

(defun savefold-markdown--save-folds ()
  "Save markdown-mode fold data for the current buffer."
  (when (not (buffer-modified-p))
    (savefold-utils--set-file-attr
     savefold-markdown--folds-attr
     (mapcar
      (lambda (ov) `(,(overlay-start ov) ,(overlay-end ov)))
      (savefold-utils--get-overlays #'savefold-outline--outline-foldp)))
    (savefold-utils--set-file-attr-modtime)
    (savefold-utils--write-out-file-attrs)))

(defun savefold-markdown--bufferp ()
  (derived-mode-p 'markdown-mode))

;;;###autoload
(define-minor-mode savefold-markdown-mode
  "Toggle global persistence for `markdown-mode' folds."
  :global t
  :init-value nil
  :group 'savefold
  (if savefold-markdown-mode
      (savefold-utils--set-up-standard-hooks 'markdown
                                             '(markdown-mode)
                                             'savefold-markdown--recover-folds
                                             'savefold-markdown--save-folds
                                             'savefold-markdown--bufferp)
    (savefold-utils--unhook-standard-hooks 'markdown
                                           '(markdown-mode)
                                           'savefold-markdown--recover-folds
                                           'savefold-markdown--bufferp)))

(provide 'savefold-markdown)

;;; savefold-markdown.el ends here
