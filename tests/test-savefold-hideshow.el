;;; test-savefold-hideshow.el --- savefold-hideshow.el tests -*- lexical-binding: t; -*-

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

;; savefold-hideshow.el tests

;;; Code:

(require 'savefold-hideshow)
(require 'savefold-test-utils)

(describe "savefold-hideshow-mode"
  :var* ((source-fpath
          (expand-file-name "fixtures/hideshow/sample.el" savefold-test-utils--dir))
         (attr-fpath
          (expand-file-name "fixtures/hideshow/attr-table" savefold-test-utils--dir)))

  (describe "when on"
    (before-all
      (savefold-hideshow-mode 1))

    (it "does not recover folds upon file open if file was recently modified"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-utils--set-file-attr 'savefold-modtime '(0 0 0 0) temp-source-fpath)
        (savefold-utils--write-out-file-attrs temp-source-fpath)

        (savefold-test-utils--with-open-file temp-source-fpath
          (hs-minor-mode)
          (expect
           (not (savefold-utils--get-overlays 'savefold-hideshow--hideshow-foldp))))))

    ;; The fixture uses the pre-Emacs 31 five-field format, including offsets.
    (it "recovers folds saved by older Hideshow versions"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (hs-minor-mode)
          (expect
           (savefold-test-utils--sets-equalp
            (mapcar
             'savefold-hideshow--get-fold-data
             (savefold-utils--get-overlays 'savefold-hideshow--hideshow-foldp))
            (mapcar
             'savefold-hideshow--adapt-fold-data
             (savefold-utils--get-file-attr savefold-hideshow--folds-attr)))))))

    (it "saves folds upon file close"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (hs-minor-mode)
          (goto-char 336)
          (hs-hide-block)
          (goto-char 431)
          (hs-hide-block))

        (expect
         (savefold-test-utils--sets-equalp
          (savefold-utils--get-file-attr savefold-hideshow--folds-attr temp-source-fpath)
          (mapcar
           'savefold-hideshow--adapt-fold-data
           '((475 791 comment 431 791)
             (375 428 code -38 0)
             (231 253 code -26 0))))))))

  (describe "when turned back off"
    (before-all
      (savefold-hideshow-mode -1))

    (it "does not recover folds upon file open"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (hs-minor-mode)
          (expect
           (not (savefold-utils--get-overlays 'savefold-hideshow--hideshow-foldp))))))

    (it "does not save folds upon file close"
      (savefold-test-utils--with-temp-savefold-environment source-fpath attr-fpath
        (savefold-test-utils--with-open-file temp-source-fpath
          (hs-minor-mode))

        (expect
         (savefold-test-utils--sets-equalp
          (savefold-utils--get-file-attr savefold-hideshow--folds-attr temp-source-fpath)
          '((231 253 code -26 0))))))))

;;; test-savefold-outline.el ends here
