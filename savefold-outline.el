;;; savefold-outline.el --- savefold for outline mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Jacob Fong
;; Author: Jacob Fong <jacobcfong@gmail.com>
;; Version: 0.1
;; Homepage:

;; Package-Requires: ((emacs "28.2"))

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

 ;; Some of this logic is redundant across backends...
(defun savefold-outline--mapc-buffers (fun)
  "Over all outline buffers, call FUN with `with-current-buffer'."
  (mapc
   (lambda (buf)
     (with-current-buffer buf
       (when (or (derived-mode-p 'outline-mode)
                 (bound-and-true-p outline-minor-mode))
         (funcall fun))))
   (buffer-list)))

(defun savefold-outline--recover-folds ()
  "Read and apply saved outline fold data for the current buffer."
  ;; Maybe find away to abstract out this recency check
  (if (not (savefold-utils-file-recently-modifiedp))
      (mapc
       (lambda (fold-data)
         (outline-flag-region (car fold-data) (cadr fold-data) t))
       (savefold-utils-get-file-attr savefold-outline--folds-attr))
    (message
     "savefold: Buffer contents newer than fold data for buffer '%s'. Not applying."
     (current-buffer))))

(defun savefold-outline--setup-save-on-kill-buffer ()
  (add-hook 'kill-buffer-hook 'savefold-outline--save-folds nil t))

(defun savefold-outline--unhook-save-on-kill-buffer ()
  (remove-hook 'kill-buffer-hook 'savefold-outline--save-folds t))

(defun savefold-outline--outline-foldp (ov)
  "Checks whether OV is an outline-mode/outline-minor-mode fold overlay."
  (eq (overlay-get ov 'invisible) 'outline))

(defun savefold-outline--save-folds ()
  "Save outline fold data for the current buffer.

This also saves the modification time of the file."
  ;; Assume this means the buffer reflects the actual file state
  (when (not (buffer-modified-p))
    (savefold-utils-set-file-attr
     savefold-outline--folds-attr
     (mapcar
      (lambda (ov) `(,(overlay-start ov) ,(overlay-end ov)))
      (seq-filter 'savefold-outline--outline-foldp
                  ;; overlays-in does not necessarily return overlays in order
                  (overlays-in (point-min) (point-max)))))
    (savefold-utils-set-file-attr-modtime)
    (savefold-utils-write-out-file-attrs)))

(defun savefold-outline--save-all-buffers-folds ()
  "Save outline fold data for all buffers."
  (savefold-org--mapc-buffers 'savefold-outline--save-folds))

(defun savefold-outline--setup-save-on-kill-for-existing-buffers ()
  "Setup save on kill across all existing outline buffers."
  (savefold-outline--mapc-buffers 'savefold-outline--setup-save-on-kill-buffer))

(defun savefold-outline--unhook-save-on-kill-for-existing-buffers ()
  "Remove the save on kill hook across all existing outline buffers."
  (savefold-outline--mapc-buffers 'savefold-outline--unhook-save-on-kill-buffer))

;;;###autoload
(define-minor-mode savefold-outline-mode
  "Toggle global persistence for outline-mode/outline-minor-mode folds."
  :global t
  :init-value nil
  (if savefold-outline-mode
      (progn
        ;; Recover folds upon file open
        (add-hook 'outline-mode-hook 'savefold-outline--recover-folds)
        (add-hook 'outline-minor-mode-hook 'savefold-outline--recover-folds)

        ;; Save folds on file close
        (add-hook 'outline-mode-hook 'savefold-outline--setup-save-on-kill-buffer)
        (add-hook 'outline-minor-mode-hook 'savefold-outline--setup-save-on-kill-buffer)
        (add-hook 'kill-emacs-hook 'savefold-outline--save-all-buffers-folds)

        ;; Set up save folds on existing buffers
        (savefold-outline--setup-save-on-kill-for-existing-buffers))

    (remove-hook 'outline-mode-hook 'savefold-outline--recover-folds)
    (remove-hook 'outline-minor-mode-hook 'savefold-outline--recover-folds)

    (remove-hook 'outline-mode-hook 'savefold-outline--setup-save-on-kill-buffer)
    (remove-hook 'outline-minor-mode-hook 'savefold-outline--setup-save-on-kill-buffer)
    (remove-hook 'kill-emacs-hook 'savefold-outline--save-all-buffers-folds)

    (savefold-outline--unhook-save-on-kill-for-existing-buffers)))

(provide 'savefold-outline)

;;; savefold-outline.el ends here
