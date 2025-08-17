;;; test-savefold-markdown.el --- savefold-markdown.el tests -*- lexical-binding: t; -*-

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

;; savefold-markdown.el tests

;;; Code:

(require 'savefold-markdown)
(require 'savefold-test-utils)

(describe "savefold-markdown-mode"
  :var* ((source-fpath
          (expand-file-name "fixtures/markdown/lotr.md" savefold-test-utils--dir))
         (attr-fpath
          (expand-file-name "fixtures/markdown/attr-table" savefold-test-utils--dir)))

  (describe "when on"
    (before-all
      (savefold-markdown-mode 1))

    (it "does not recover folds upon file open if file was recently modified"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-utils--set-file-attr 'savefold-modtime '(0 0 0 0) temp-source-fpath)
        (savefold-utils--write-out-file-attrs temp-source-fpath)

        (savefold-test-utils--with-open-file temp-source-fpath
          (expect
           (not (savefold-utils--get-overlays 'savefold-outline--outline-foldp))))))

    (it "recovers folds upon file open"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (expect
           (savefold-test-utils--sets-equalp
            (mapcar
             (lambda (ov) `(,(overlay-start ov) ,(overlay-end ov)))
             (savefold-utils--get-overlays 'savefold-outline--outline-foldp))
            (savefold-utils--get-file-attr savefold-markdown--folds-attr))))))

    (it "saves folds upon file close"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (goto-char 34)
          (markdown-cycle)
          (goto-char 1593)
          (setq last-command t)  ;; simulate interactive control
          (markdown-cycle))

        (expect
         (savefold-test-utils--sets-equalp
          (savefold-utils--get-file-attr savefold-markdown--folds-attr temp-source-fpath)
          '((1097 1592) (452 1065) (111 414) (1620 3733)))))))

  (describe "when turned back off"
    (before-all
      (savefold-markdown-mode -1))

    (it "does not recover folds upon file open"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (expect
           (not (savefold-utils--get-overlays 'savefold-outline--outline-foldp))))))

    (it "does not save folds upon file close"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (ignore))

        (expect
         (savefold-test-utils--sets-equalp
          (savefold-utils--get-file-attr savefold-markdown--folds-attr temp-source-fpath)
          '((73 1592))))))))

;;; test-savefold-outline.el ends here
