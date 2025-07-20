;;; savefold-org.el --- savefold for org mode -*- lexical-binding: t; -*-

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

;; This package implements persistence for org-mode visibility.
;;
;; There are many types of folds in an org file that should be persisted:
;;
;; - section/outline folds
;; - blocks
;; - drawers
;; - babel results
;;
;; Under the traditional overlay-based ("old-fashioned") folding system, all of
;; these are folded as overlays. Section/outline overlays can be made to
;; identical effect with either outline-mode commands (ex
;; `outline-hide-subtree') or org commands (ex `org-hide-entry'); they identify
;; themselves via 'invisible spec as 'outline overlays. So do drawer folds. Thus
;; we defer to existing savefold-outline logic for recovering those. A separate,
;; org-specific system is built for persisting blocks and babel results.
;;
;; In the new text property based folding regime (org 9.6+), sections, blocks,
;; and drawers are folded with text properties, while babel results are still
;; overlay-based.

;;; Code:

(require 'org)
(require 'savefold-utils)
(require 'savefold-outline)

(defvar org-fold-core-style)  ;; Missing in Emacs 28
(defalias 'savefold-org--org-fold-get-regions #'org-fold-get-regions)  ;: Missing in Emacs 28
(defalias 'savefold-org--org-fold-region #'org-fold-region)  ;; Missing in Emacs 28
(defalias 'savefold-org--org-flag-region #'org-flag-region)  ;; Obsolete in Emacs 29+

;;;; Old-fashioned folding

(defcustom savefold-org-inhibit-outline-integration nil
  "If non-nil, do not automatically run `outline-mode' backend functions.

By default, the outline backend is manually integrated with the org backend at
some points, due to the special relationship between org-mode and
outline-mode.

A value of nil is required for folds created with `org-flag-region' with an
\\='outline invisibility spec to be saved, for example. There is not really any
reason for this to be non-nil."
  :type 'boolean
  :group 'savefold)

(defvar savefold-org--old-fashioned-folds-attr 'savefold-org-old-fashioned-folds)

(defvar savefold-org--old-fashioned-fold-specs '(org-hide-block org-babel-hide-result))

(defun savefold-org--using-old-fashioned-foldsp ()
  "Check whether using org<9.6 overlay-based folds or new text prop folds."
  (or (version< org-version "9.6") (eq org-fold-core-style 'overlays)))

(defun savefold-org--old-fashioned-make-overlay-fold (fold-data)
  "For old-fashioned folds: make overlay-based org fold from FOLD-DATA."
  (let ((start (car fold-data))
        (end (cadr fold-data))
        (spec (caddr fold-data)))
    (cond
     ((eq spec 'org-babel-hide-result)
      (save-excursion
        (goto-char start)
        (org-babel-hide-result-toggle-maybe)))
     (t (savefold-org--org-flag-region start end t spec)))))

(defun savefold-org--old-fashioned-recover-folds ()
  ;; Get outline folds manually if necessary
  (when (and (not savefold-org-inhibit-outline-integration)
             (not savefold-outline-mode))
    (savefold-outline--recover-folds))

  ;; Overlay folds
  (mapc
   #'savefold-org--old-fashioned-make-overlay-fold
   (savefold-utils--get-file-attr savefold-org--old-fashioned-folds-attr)))

(defun savefold-org--old-fashioned-foldp (ov)
  "For old-fashioned folds: check whether OV is an overlay for an `org-mode' fold.

This does not include folds made with `org-flag-region' with an \\='outline
invisibility spec, but only the invisibility specs exclusive to org-mode:
`savefold-org--old-fashioned-fold-specs'."
  (memq (overlay-get ov 'invisible) savefold-org--old-fashioned-fold-specs))

(defun savefold-org--old-fashioned-save-folds ()
  ;; Save outline folds manually if necessary
  (when (and (not savefold-org-inhibit-outline-integration)
             (not savefold-outline-mode))
    (savefold-outline--save-folds))

  ;; Save overlays
  (savefold-utils--set-file-attr
   savefold-org--old-fashioned-folds-attr
   (mapcar
    (lambda (ov)
      `(,(overlay-start ov) ,(overlay-end ov) ,(overlay-get ov 'invisible)))
    (savefold-utils--get-overlays #'savefold-org--old-fashioned-foldp)))

  (savefold-utils--set-file-attr-modtime)
  (savefold-utils--write-out-file-attrs))

;;;; Current folding

(defvar savefold-org--text-prop-folds-attr 'savefold-org-text-prop-folds)

(defvar savefold-org--overlay-folds-attr 'savefold-org-overlay-folds)

(defvar savefold-org--text-prop-fold-specs
  '(org-fold-outline org-fold-block org-fold-drawer))

(defvar savefold-org--overlay-fold-specs '(org-babel-hide-result))

(defun savefold-org--make-overlay-fold (fold-data)
  "Make overlay fold from FOLD-DATA."
  (cl-destructuring-bind (start _ spec) fold-data  ;; Change "_" to "end" if needed
    (cond
     ((eq spec 'org-babel-hide-result)
      (save-excursion
        (goto-char start)
        (org-babel-hide-result-toggle-maybe))))))

(defun savefold-org--recover-folds ()
  "Read and apply saved org fold data for the current buffer."
  (savefold-utils--unless-file-recently-modified
   (if (savefold-org--using-old-fashioned-foldsp)
       (savefold-org--old-fashioned-recover-folds)
     ;; Recover text prop folds
     (mapc
      (lambda (fold)
        (let ((start (car fold))
              (end (cadr fold))
              (spec (caddr fold)))
          (savefold-org--org-fold-region start end t spec)))
      (savefold-utils--get-file-attr savefold-org--text-prop-folds-attr))

     ;; Recover overlay folds
     (mapc
      #'savefold-org--make-overlay-fold
      (savefold-utils--get-file-attr savefold-org--overlay-folds-attr)))))

(defun savefold-org--overlay-foldp (ov)
  "Check whether OV is an overlay for an `org-mode' fold."
  (memq (overlay-get ov 'invisible) savefold-org--overlay-fold-specs))

(defun savefold-org--save-folds ()
  "Save org fold data for the current buffer."
  (when (not (buffer-modified-p))
    (if (savefold-org--using-old-fashioned-foldsp)
        (savefold-org--old-fashioned-save-folds)

      ;; Save text property folds
      (savefold-utils--set-file-attr
       savefold-org--text-prop-folds-attr
       (savefold-org--org-fold-get-regions :specs savefold-org--text-prop-fold-specs))

      ;; Save overlay folds
      (savefold-utils--set-file-attr
       savefold-org--overlay-folds-attr
       (mapcar
        (lambda (ov)
          `(,(overlay-start ov) ,(overlay-end ov) ,(overlay-get ov 'invisible)))
        (savefold-utils--get-overlays #'savefold-org--overlay-foldp)))

      (savefold-utils--set-file-attr-modtime)
      (savefold-utils--write-out-file-attrs))))

(defun savefold-org--bufferp ()
  (derived-mode-p 'org-mode))

;;;###autoload
(define-minor-mode savefold-org-mode
  "Toggle global persistence for `org-mode' folds."
  :global t
  :init-value nil
  :group 'savefold
  (if savefold-org-mode
      (savefold-utils--set-up-standard-hooks 'org
                                             '(org-mode)
                                             'savefold-org--recover-folds
                                             'savefold-org--save-folds
                                             'savefold-org--bufferp)
    (savefold-utils--unhook-standard-hooks 'org
                                           '(org-mode)
                                           'savefold-org--recover-folds
                                           'savefold-org--bufferp)))

(provide 'savefold-org)

;;; savefold-org.el ends here
