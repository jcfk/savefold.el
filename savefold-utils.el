;;; savefold-utils.el --- shared utilities for savefold -*- lexical-binding: t; -*-

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

;; Shared utilities for savefold

;;; Code:

(require 'compat)
(require 'savefold)

(defvar savefold-utils--fpath-to-attr-table (make-hash-table :test #'equal)
  "Hash table mapping file paths to file attribute hash tables.")

(defun savefold-utils--get-attr-table-fpath (fpath)
  "Return the fpath of the attribute table file for FPATH.

This naively replaces path slashes with ! (/a/b/c -> !a!b!c) leading to a chance
of collision."
  (let* ((fpath (expand-file-name fpath))
         (fpath (string-replace "/" "!" fpath))
         (fpath (string-replace ":" "!" fpath)))  ; For windows
    (expand-file-name fpath savefold-directory)))

(defun savefold-utils--get-file-attr-table (fpath)
  "Get the attribute hash table for file FPATH.

If no attr table file exists, return a new hash table."
  (let ((attr-table (gethash fpath savefold-utils--fpath-to-attr-table)))
    (unless attr-table
      (let ((attr-table-fpath (savefold-utils--get-attr-table-fpath fpath)))
        (if (file-exists-p attr-table-fpath)
            (setq attr-table
                  (with-temp-buffer
                    (insert-file-contents attr-table-fpath)
                    (goto-char (point-min))
                    (read (current-buffer))))
          (setq attr-table (make-hash-table))))
      (puthash fpath attr-table savefold-utils--fpath-to-attr-table))
    attr-table))

(defun savefold-utils--get-file-attr (attr &optional fpath)
  "Return attribute ATTR for the current file.

Use FPATH instead if non-nil."
  (when-let* ((fpath
               (or fpath (and (buffer-file-name) (expand-file-name (buffer-file-name))))))
    (gethash attr (savefold-utils--get-file-attr-table fpath))))

(defun savefold-utils--set-file-attr (attr value &optional fpath)
  "Set attribute ATTR for VALUE in the current file's hash table.

Make sure to `savefold-utils--write-out-file-attrs' after each batch of changes
to save them to the disk.

Use FPATH instead of the current buffer file if non-nil."
  (when-let* ((fpath
               (or fpath (and (buffer-file-name) (expand-file-name (buffer-file-name))))))
    (when (not (readablep value))
      (error "savefold: File attr value must be readablep"))
    (puthash attr value (savefold-utils--get-file-attr-table fpath))))

(defun savefold-utils--write-out-file-attrs (&optional fpath)
  "Write attr hash table for the current file to the disk.

Use FPATH instead if non-nil."
  (when-let* ((fpath
               (or fpath (and (buffer-file-name) (expand-file-name (buffer-file-name))))))
    (when (not (file-exists-p savefold-directory))
      (make-directory savefold-directory))
    (with-temp-file (savefold-utils--get-attr-table-fpath fpath)
      (prin1
       (gethash fpath savefold-utils--fpath-to-attr-table)
       (current-buffer)))))

(defun savefold-utils--set-file-attr-modtime ()
  "Set the current file's modtime as a file attribute.

Must `savefold-utils--write-out-file-attrs' afterwards."
  (savefold-utils--set-file-attr 'savefold-modtime (visited-file-modtime)))

(defun savefold-utils--file-recently-modifiedp ()
  "The current file has modtime recenter than the \\='savefold-modtime attr.

False if the current file doesn't have a \\='savefold-modtime attr."
  (when-let* ((saved-modtime (savefold-utils--get-file-attr 'savefold-modtime)))
    (< (float-time saved-modtime) (float-time (visited-file-modtime)))))

(defun savefold-utils--mapc-buffers (fun pred)
  "For all buffers, inside `with-current-buffer', if PRED, do FUN."
  (mapc
   (lambda (buf)
     (with-current-buffer buf
       (when (funcall pred)
         (funcall fun))))
   (buffer-list)))

(defun savefold-utils--get-overlays (pred)
  "Return all overlays in the current buffer for which PRED is non-nil."
  ;; overlays-in does not necessarily return overlays in order
  (seq-filter pred (overlays-in (point-min) (point-max))))

(defmacro savefold-utils--unless-file-recently-modified (&rest body)
  "Evaluate BODY unless current file recently modified, per file attrs."
  `(if (not (savefold-utils--file-recently-modifiedp))
       ,@body
     (message
      "savefold: Buffer contents newer than fold data for buffer '%s'. Not applying."
      (current-buffer))))

(defmacro savefold-utils--with-standard-functions (backend modes &rest body)
  "Eval BODY with generic standard func symbols bound for BACKEND and MODES.

BACKEND should be the quoted backend symbol and MODES should be a quoted list of
the modes to which this backend should be hooked."
  (declare (indent 2))
  `(let ((mode-hooks
          (mapcar
           (lambda (mode)
             (intern
              (format "%s-hook" mode)))
           ,modes))
         (set-up-save-on-kill-buffer
          (intern
           (format "savefold-%s--set-up-save-on-kill-buffer" ,backend)))
         (unhook-save-on-kill-buffer
          (intern
           (format "savefold-%s--unhook-save-on-kill-buffer" ,backend)))
         (save-all-buffers-folds
          (intern
           (format "savefold-%s--save-all-buffers-folds" ,backend))))
     ,@body))

(defmacro savefold-utils--set-up-standard-hooks (backend
                                                 modes
                                                 recover-folds
                                                 save-folds
                                                 backend-bufferp)
  "Set up the standard hooks for BACKEND, given MODES and essential functions.

Essential functions are: RECOVER-FOLDS, which recovers folds for the current
buffer. SAVE-FOLDS, which saves fold data to disk for the current buffer.
BACKEND-BUFFERP, which checks whether the backend should be active in the
current buffer."
  (savefold-utils--with-standard-functions (eval backend) (eval modes)
    `(progn
       (defun ,set-up-save-on-kill-buffer ()
         "Helper func from `savefold-utils--set-up-standard-hooks'."
         (add-hook 'kill-buffer-hook ,save-folds nil t))

       (defun ,unhook-save-on-kill-buffer ()
         "Helper func from `savefold-utils--set-up-standard-hooks'."
         (remove-hook 'kill-buffer-hook ,save-folds t))

       (defun ,save-all-buffers-folds ()
         "Helper func from `savefold-utils--set-up-standard-hooks'."
         (savefold-utils--mapc-buffers ,save-folds ,backend-bufferp))

       (declare-function
        ,set-up-save-on-kill-buffer (format "savefold-%s" ,backend))
       (declare-function
        ,unhook-save-on-kill-buffer (format "savefold-%s" ,backend))
       (declare-function
        ,save-all-buffers-folds (format "savefold-%s" ,backend))

       (mapc
        (lambda (mode-hook)
          ;; Recover folds on file open
          (add-hook mode-hook ,recover-folds)

          ;; Save folds on file close
          (add-hook mode-hook #',set-up-save-on-kill-buffer))
        ',mode-hooks)

       ;; Save folds on emacs shutdown
       (add-hook 'kill-emacs-hook #',save-all-buffers-folds)

       ;; Set up save folds on file close for existing buffers
       (savefold-utils--mapc-buffers
        #',set-up-save-on-kill-buffer ,backend-bufferp))))

(defmacro savefold-utils--unhook-standard-hooks (backend
                                                 modes
                                                 recover-folds
                                                 backend-bufferp)
  "Undo the standard hooks for BACKEND."
  (savefold-utils--with-standard-functions (eval backend) (eval modes)
    `(progn
       (mapc
        (lambda (mode-hook)
          (remove-hook mode-hook ,recover-folds)
          (remove-hook mode-hook #',set-up-save-on-kill-buffer))
        ',mode-hooks)

       (remove-hook 'kill-emacs-hook #',save-all-buffers-folds)
       (savefold-utils--mapc-buffers
        #',unhook-save-on-kill-buffer ,backend-bufferp))))

(defmacro savefold-utils--require (feature)
  "Require FEATURE, giving error if it's not present."
  `(unless (require ,feature nil t)
     (error "savefold: Feature '%s' required, not present" ,feature)))

(provide 'savefold-utils)

;;; savefold-utils.el ends here
