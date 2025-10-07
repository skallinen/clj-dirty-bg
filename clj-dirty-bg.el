;;; clj-dirty-bg.el --- Dirty background until CIDER buffer eval  -*- lexical-binding: t; -*-
;;
;; Author: You
;; Version: 0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: languages, tools
;; URL: https://example.invalid/clj-dirty-bg
;;
;; This is free and unencumbered software released into the public domain.
;;
;;; Commentary:
;;
;; Highlights a Clojure buffer’s background whenever it has un-evaluated edits,
;; and clears the highlight only after a whole-buffer eval/load via CIDER.
;;
;; What it does:
;; - On any edit: mark buffer "dirty" and tint background.
;; - On `cider-eval-buffer` / `cider-load-buffer` / `cider-load-file`: mark clean.
;;
;; Quick start:
;;   (require 'clj-dirty-bg)
;;   (add-hook 'clojure-mode-hook #'clj-dirty-bg-mode)
;;   ;; Optional for treesitter:
;;   (add-hook 'clojure-ts-mode-hook #'clj-dirty-bg-mode)
;;
;; Customize with:  M-x customize-group RET clj-dirty-bg RET
;;
;;; Code:

(require 'face-remap)

(defgroup clj-dirty-bg nil
  "Change background when a Clojure buffer has un-evaluated edits."
  :group 'tools
  :prefix "clj-dirty-bg-")

(defcustom clj-dirty-bg-dirty-color "#332f2f"
  "Background color when buffer has edits not yet evaluated."
  :type 'string)

(defcustom clj-dirty-bg-clean-color nil
  "Background color when buffer is clean.
If nil, remove the remap entirely (use theme default)."
  :type '(choice (const :tag "Theme default (no remap)" nil) string))

(defcustom clj-dirty-bg-following-modes
  '(clojure-mode clojurec-mode clojurescript-mode clojure-ts-mode)
  "Major modes where `clj-dirty-bg-mode' makes sense."
  :type '(repeat symbol))

(defcustom clj-dirty-bg-clean-commands
  '(cider-eval-buffer cider-load-buffer cider-load-file)
  "Commands that should mark the buffer as clean after running.
By default these are whole-buffer eval/load commands in CIDER."
  :type '(repeat function))

(defvar clj-dirty-bg--advice-installed nil
  "Non-nil when global advices for `clj-dirty-bg' are installed.")

(defvar-local clj-dirty-bg--cookie nil
  "Face remap cookie for the current buffer.")

(defvar-local clj-dirty-bg--dirty-p nil
  "Non-nil when buffer has edits not yet evaluated.")

(defun clj-dirty-bg--apply (color)
  "Apply a background COLOR via face remap, replacing any prior remap."
  (when clj-dirty-bg--cookie
    (face-remap-remove-relative clj-dirty-bg--cookie)
    (setq clj-dirty-bg--cookie nil))
  (when color
    (setq clj-dirty-bg--cookie
          (face-remap-add-relative 'default `(:background ,color)))))

(defun clj-dirty-bg--update ()
  "Refresh background based on `clj-dirty-bg--dirty-p'."
  (clj-dirty-bg--apply (if clj-dirty-bg--dirty-p
                           clj-dirty-bg-dirty-color
                         clj-dirty-bg-clean-color)))

(defun clj-dirty-bg--mark-dirty (_beg _end _len)
  "Mark buffer dirty after any edit (for `after-change-functions')."
  (setq clj-dirty-bg--dirty-p t)
  (clj-dirty-bg--update))

(defun clj-dirty-bg-mark-clean (&rest _)
  "Mark buffer clean (used after CIDER eval/load)."
  (when (boundp 'clj-dirty-bg--dirty-p) ; run safely even if mode isn't active
    (setq clj-dirty-bg--dirty-p nil)
    (clj-dirty-bg--update)))

(defun clj-dirty-bg--ensure-advices ()
  "Install global advices on `clj-dirty-bg-clean-commands' once."
  (unless clj-dirty-bg--advice-installed
    (dolist (fn clj-dirty-bg-clean-commands)
      (when (fboundp fn)
        (advice-add fn :after #'clj-dirty-bg-mark-clean)))
    (setq clj-dirty-bg--advice-installed t))
  ;; Also install later when CIDER loads.
  (with-eval-after-load 'cider
    (unless clj-dirty-bg--advice-installed
      (dolist (fn clj-dirty-bg-clean-commands)
        (when (fboundp fn)
          (advice-add fn :after #'clj-dirty-bg-mark-clean)))
      (setq clj-dirty-bg--advice-installed t))))

;;;###autoload
(define-minor-mode clj-dirty-bg-mode
  "Toggle dirty-background highlight for Clojure buffers with CIDER.

When enabled:
- Any edit sets a “dirty” flag and applies `clj-dirty-bg-dirty-color`.
- Running a command in `clj-dirty-bg-clean-commands` clears the flag/background.

Advices are installed globally once; the mark-clean code is harmless
in buffers where this mode isn't active."
  :init-value nil
  :lighter " DirtyBG"
  (if clj-dirty-bg-mode
      (progn
        (setq clj-dirty-bg--dirty-p t)
        (clj-dirty-bg--update)
        (add-hook 'after-change-functions #'clj-dirty-bg--mark-dirty nil t)
        (clj-dirty-bg--ensure-advices))
    (remove-hook 'after-change-functions #'clj-dirty-bg--mark-dirty t)
    (setq clj-dirty-bg--dirty-p nil)
    (clj-dirty-bg--update)))

;;;###autoload
(defun clj-dirty-bg-setup ()
  "Enable `clj-dirty-bg-mode' in relevant Clojure buffers."
  (when (apply #'derived-mode-p clj-dirty-bg-following-modes)
    (clj-dirty-bg-mode 1)))

;;;###autoload
(add-hook 'clojure-mode-hook #'clj-dirty-bg-setup)

;;;###autoload
(add-hook 'clojure-ts-mode-hook #'clj-dirty-bg-setup)

(provide 'clj-dirty-bg)
;;; clj-dirty-bg.el ends here
