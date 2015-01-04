;;; dired-fdclone.el --- dired functions and settings to mimic FDclone
;;
;; Copyright (c) 2014, 2015 Akinori MUSHA
;;
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
;; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
;; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
;; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;; SUCH DAMAGE.

;; Author: Akinori MUSHA <knu@iDaemons.org>
;; URL: https://github.com/knu/dired-fdclone.el
;; Created: 25 Dec 2014
;; Version: 1.1
;; Package-Requires: ((helm-fns+ "0"))
;; Keywords: unix, directories, dired

;;; Commentary:
;;
;; dired-fdclone.el provides the following interactive commands:
;;
;; * diredfd-goto-top
;; * diredfd-goto-bottom
;; * diredfd-toggle-mark-here
;; * diredfd-toggle-mark
;; * diredfd-toggle-all-marks
;; * diredfd-mark-or-unmark-all
;; * diredfd-narrow-to-marked-files
;; * diredfd-narrow-to-files-regexp
;; * diredfd-goto-filename
;; * diredfd-do-shell-command
;; * diredfd-do-flagged-delete-or-execute
;; * diredfd-enter
;; * diredfd-enter-directory
;; * diredfd-enter-parent-directory
;; * diredfd-enter-root-directory
;; * diredfd-do-pack
;; * diredfd-do-unpack
;;
;; Run the following line to enable all FDclone mimicking settings for
;; dired.
;;
;;   (dired-fdclone)
;;

;;; Code:

(require 'dired-x)
(require 'dired-aux)
(require 'help-fns+)
(require 'term)

(eval-when-compile
  (require 'cl))

(defgroup dired-fdclone nil
  "Dired functions and settings to mimic FDclone."
  :group 'dired)

(defun diredfd-goto-top ()
  "Go to the top line of the current file list."
  (interactive)
  (while (and (not (bobp))
              (dired-between-files))
    (dired-previous-line 1))
  (unless (bobp)
    (while (not (dired-between-files))
      (dired-previous-line 1))
    (dired-next-line 1)))

(defun diredfd-goto-bottom ()
  "Go to the bottom line of the current file list."
  (interactive)
  (while (and (not (eobp))
              (dired-between-files))
    (dired-next-line 1))
  (unless (eobp)
    (while (not (dired-between-files))
      (dired-next-line 1))
    (dired-previous-line 1)))

;;;###autoload
(defun diredfd-toggle-mark-here ()
  "Toggle the mark on the current line."
  (interactive)
  (beginning-of-line)
  (or (dired-between-files)
      (looking-at-p dired-re-dot)
      (let ((inhibit-read-only t)
            (char (following-char)))
        (funcall 'subst-char-in-region
                 (point) (1+ (point)) char
                 (if (eq char ?\s)
                     dired-marker-char ?\s))))
  (dired-move-to-filename))

;;;###autoload
(defun diredfd-toggle-mark (&optional arg)
  "Toggle the mark on the current line and move to the next line.\nRepeat ARG times if given."
  (interactive "p")
  (loop for n from 1 to arg
        until (eobp) do
        (diredfd-toggle-mark-here)
        (dired-next-line 1)))

;;;###autoload
(defun diredfd-toggle-all-marks ()
  "Toggle all marks."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (beginning-of-line)
      (or (dired-between-files)
          (looking-at-p dired-re-dot)
          (diredfd-toggle-mark-here))
      (dired-next-line 1))))

;;;###autoload
(defun diredfd-mark-or-unmark-all (&optional arg)
  "Unmark all files if there is any file marked, or mark all non-directory files otherwise.
If ARG is given, mark all files including directories."
  (interactive "P")
  (if arg
      (dired-mark-if (not (or (dired-between-files)
                              (looking-at-p dired-re-dot)))
                     "file")
    (if (cdr (dired-get-marked-files nil nil nil t))
        (dired-unmark-all-marks)
      (dired-mark-if (not (or (dired-between-files)
                              (looking-at-p dired-re-dot)
                              (file-directory-p (dired-get-filename nil t))))
                     "non-directory file"))))

;;;###autoload
(defun diredfd-narrow-to-marked-files ()
  "Kill all unmarked lines using `dired-kill-line'."
  (interactive)
  (save-excursion
    (goto-char (point-max))
    (while (not (bobp))
      (beginning-of-line)
      (or (dired-between-files)
          (looking-at-p dired-re-dot)
          (eq dired-marker-char (following-char))
          (dired-kill-line 1))
      (forward-line -1))))

;;;###autoload
(defun diredfd-narrow-to-files-regexp (regexp)
  "Kill all lines except those matching REGEXP using `dired-kill-line'."
  (interactive
   (list (dired-read-regexp "Narrow to files (regexp): ")))
  (save-excursion
    (goto-char (point-max))
    (while (not (bobp))
      (beginning-of-line)
      (or (dired-between-files)
          (looking-at-p dired-re-dot)
          (string-match-p regexp (dired-get-filename nil t))
          (dired-kill-line 1))
      (forward-line -1))))

;;;###autoload
(defun diredfd-goto-filename (filename)
  "Jump to FILENAME."
  (interactive "sGo to filename: ")
  (let ((pos (save-excursion
               (goto-char (point-min))
               (loop until (eobp) do
                     (dired-next-line 1)
                     (and (dired-move-to-filename)
                          (string= (file-name-nondirectory (dired-get-filename nil t))
                                   filename)
                          (return (point)))))))
    (if pos (goto-char pos)
      (error "Filename not found: %s" filename))))

(defun diredfd-do-shell-command (command)
  "Open an ANSI terminal and run a COMMAND in it."
  (interactive
   (list (if current-prefix-arg ""
           (read-shell-command "Shell command: "))))
  (let* ((caller-buffer-name (buffer-name))
         (shell (or explicit-shell-file-name
                    (getenv "ESHELL")
                    (getenv "SHELL")
                    "/bin/sh"))
         (args (if (string= command "") nil
                 (list "-c" command)))
         (buffer (get-buffer
                  (apply 'term-ansi-make-term
                         (generate-new-buffer-name
                          (format "*%s - %s*"
                                  "dired-shell"
                                  default-directory))
                         shell nil args))))
    (with-current-buffer buffer
      (term-mode)
      (term-char-mode))
    (set-process-sentinel
     (get-buffer-process buffer)
     `(lambda (proc msg)
        (let ((buffer (process-buffer proc))
              (return-to-caller-buffer
               (lambda () (interactive)
                 (kill-buffer (current-buffer))
                 (switch-to-buffer ,caller-buffer-name))))
          (term-sentinel proc msg)
          (when (buffer-live-p buffer)
            (with-current-buffer buffer
              (local-set-key "q" return-to-caller-buffer)
              (local-set-key " " return-to-caller-buffer)
              (local-set-key (kbd "RET") return-to-caller-buffer)
              (let ((buffer-read-only))
                (insert "Hit SPC/RET/q to return...")))))))
    (switch-to-buffer buffer)))

;;;###autoload
(defun diredfd-do-flagged-delete-or-execute (&optional arg)
  "Run `dired-do-flagged-delete' if any file is flagged for deletion.
If none is, run a shell command with all marked (or next ARG) files or the current file."
  (interactive "P")
  (if (save-excursion
        (let* ((dired-marker-char dired-del-marker)
               (regexp (dired-marker-regexp))
               case-fold-search)
          (goto-char (point-min))
          (re-search-forward regexp nil t)))
      (dired-do-flagged-delete)
    (let* ((arg (and arg (prefix-numeric-value arg)))
           (files (dired-get-marked-files t arg nil t))
           (file (or (car files)
                     (error "No file to execute")))
           (initial-contents
            (if (and (null (cdr files))
                     (file-regular-p file)
                     (file-executable-p file))
                (concat (file-name-as-directory ".")
                        (file-relative-name file)
                        " ")
              (cons
               (concat " "
                       (mapconcat
                        (lambda (file)
                          (shell-quote-argument
                           (file-relative-name file)))
                        (if (eq file t) (cdr files) files)
                        " "))
               1)))
           (command (read-shell-command "Shell command: "
                                        initial-contents)))
      (diredfd-do-shell-command command))))

;;;###autoload
(defun diredfd-enter ()
  "Visit the current file, or enter if it is a directory."
  (interactive)
  (let* ((file (dired-get-file-for-visit))
         (filename (file-name-nondirectory file)))
    (cond ((file-directory-p file)
           (if (string= filename "..")
               (diredfd-enter-parent-directory)
             (diredfd-enter-directory file "..")))
          (t
           (dired-find-file)))))

;;;###autoload
(defun diredfd-enter-directory (&optional directory filename)
  "Enter DIRECTORY and jump to FILENAME."
  (interactive (list (read-directory-name
                      "Go to directory: "
                      dired-directory nil t)))
  (set-buffer-modified-p nil)
  (find-alternate-file directory)
  (if filename
      (diredfd-goto-filename filename)))

;;;###autoload
(defun diredfd-enter-parent-directory ()
  "Enter the parent directory."
  (interactive)
  (let* ((file (dired-get-filename nil t))
         (dirname (directory-file-name (if file (file-name-directory file) dired-directory))))
    (diredfd-enter-directory (expand-file-name ".." dirname) (file-name-nondirectory dirname))))

;;;###autoload
(defun diredfd-enter-root-directory ()
  "Enter the root directory."
  (interactive)
  (set-buffer-modified-p nil)
  (diredfd-enter-directory "/" "..")
  (dired-next-line 1))

(defcustom diredfd-archive-info-list
  '(["\\.tar\\'"
     "tar cf ? *"
     "tar xf ? *"]
    ["\\.\\(tar\\.Z\\|taZ\\)\\'"
     "tar Zcf ? *"
     "tar Zxf ? *"]
    ["\\.\\(tar\\.g?z\\|t[ga]z\\)\\'"
     "tar cf - * | gzip -9c > ?"
     "tar zxf ? *"]
    ["\\.\\(tar\\.bz2\\|tbz\\)\\'"
     "tar cf - * | bzip2 -9c > ?"
     "tar jxf ? *"]
    ["\\.\\(tar\\.xz\\|txz\\)\\'"
     "tar cf - * | xz -9c > ?"
     "xz -cd ? | tar xf - *"]
    ["\\.a\\'"
     "ar -rc ? *"
     "ar -x ? *"]
    ["\\.lzh\\'"
     "lha aq ? *"
     "lha xq ? *"]
    ["\\.\\(zip\\|jar\\|xpi\\)\\'"
     "zip -qr ? *"
     "unzip -q ? *"]
    ["\\.Z\\'"
     "compress -c * > ?"
     "sh -c 'uncompress -c \"$1\" > \"${1%.Z}\"' . ?"]
    ["\\.gz\\'"
     "gzip -9c * > ?"
     "gzip -dk ?"]
    ["\\.bz2\\'"
     "bzip2 -9c * > ?"
     "bzip2 -dk ?"]
    ["\\.lzma\\'"
     "lzma -9c * > ?"
     "lzma -dk ?"]
    ["\\.xz\\'"
     "xz -9c * > ?"
     "xz -dk ?"]
    ["\\.gem\\'"
     nil
     "tar xf ? *"]
    ["\\.rpm\\'"
     nil
     "rpm2cpio ? | cpio -id *"]
    ["\\.deb\\'"
     nil
     "ar -x ? *"])
  "List of vectors that define how to handle archive formats.

Each element is a vector of the form [REGEXP ARCHIVE-COMMAND
UNARCHIVE-COMMAND], where:

   regexp                is a regexp that matches filenames that are
                         archived with this format.

   archive-command       is a shell command line that creates or
                         adds files to an archive file of this
                         format, where a `?' separated with space
                         will be replaced by the archive filename
                         and a `*' separated with space by the
                         list of files to archive.

                         Nil means you shouldn't need or want to
                         manually do that.

   unarchive-command     is a shell command line that extracts
                         files stored in an archive file of this
                         format, where a `?' separated with space
                         will be replaced by the archive filename
                         and a `*' separated with space by the
                         list of files to extract or an empty
                         string when extracting all files in it.

                         Lack of a `*' indicates that this
                         archive format is for storing a single
                         file.

This list is used by such commands as `diredfd-do-pack' and
`diredfd-do-unpack' to determine the archive format of a
filename.  If a filename matches more than one regexp, the one
with the longest match is adopted so `.tar.gz' is chosen over
`.gz' independent of the order in the list."
  :type '(repeat (vector (regexp :tag "Filename Regexp")
			 (choice :tag "Archive Command"
				 (string :format "%v")
				 (const :tag "No archive command" nil))
                         (string :tag "Unarchive Command")))
  :group 'dired-fdclone)

(defsubst diredfd-archive-info-regexp            (info) (and info (aref info 0)))
(defsubst diredfd-archive-info-archive-command   (info) (and info (aref info 1)))
(defsubst diredfd-archive-info-unarchive-command (info) (and info (aref info 2)))

(defun diredfd-archive-info-for-file (filename)
  (and (or (not (file-exists-p filename))
           (file-regular-p filename))
       (loop for info in diredfd-archive-info-list
             with longest = 0
             with matched = nil
             if (string-match (diredfd-archive-info-regexp info) filename)
             do
             (let ((len (- (match-end 0) (match-beginning 0))))
               (if (< longest len)
                   (setq longest len
                         matched info)))
             finally return matched)))

(defun diredfd-archive-command-for-file (filename)
  (diredfd-archive-info-archive-command
   (diredfd-archive-info-for-file filename)))

(defun diredfd-unarchive-command-for-file (filename)
  (diredfd-archive-info-unarchive-command
   (diredfd-archive-info-for-file filename)))

(defun diredfd-parse-user-input (input)
  (if (string-match "[ \t]*&[ \t]*\\'" input)
      (list (substring input 0 (match-beginning 0)) t)
    (list input nil)))

;;;###autoload
(defun diredfd-do-pack (&optional arg)
  "Pack all marked (or next ARG) files, or the current file into an archive."
  (interactive "P")
  (let* ((arg (and arg (prefix-numeric-value arg)))
         (files (dired-get-marked-files t arg))
         (default (dired-get-filename nil t))
         (directory (if default (file-name-directory default) dired-directory))
         (default (and default
                       (/= (char-after (line-beginning-position))
                           dired-marker-char)
                       (diredfd-archive-command-for-file default)
                       (file-name-nondirectory default)
                       default))
         (parsed (diredfd-parse-user-input
                  (read-file-name
                   (format "Pack %s into%s: "
                           (dired-mark-prompt arg files)
                           (if default
                               (format " (%s)" default) ""))
                   directory default nil nil
                   #'(lambda (file)
                       (or (file-directory-p file)
                           (diredfd-archive-command-for-file file))))))
         (archive (expand-file-name (car parsed)))
         (async (cdr parsed)))
    (diredfd-pack files archive async)))

;;;###autoload
(defun diredfd-pack (files archive &optional async)
  "Pack FILES into ARCHIVE, asynchronously if ASYNC is non-nil."
  (let* ((command-tmpl (or (diredfd-archive-command-for-file archive)
                           (error "Unknown archive format: %s" archive)))
         (command (mapconcat
                   (lambda (token)
                     (cond ((string= token "?")
                            (shell-quote-argument archive))
                           ((string= token "*")
                            (mapconcat #'shell-quote-argument
                                       files " "))
                           (t
                            token)))
                   (split-string command-tmpl " ")
                   " ")))
    (if async
        (async-shell-command command)
      (shell-command command))))

;;;###autoload
(defun diredfd-do-unpack (&optional arg)
  "Unpack all marked (or next ARG) files or the current file."
  (interactive "P")
  (let* ((arg (and arg (prefix-numeric-value arg)))
         (files (dired-get-marked-files t arg))
         (default (dired-get-filename nil t))
         (directory (if default (file-name-directory default) dired-directory))
         (default (and default
                       (/= (char-after (line-beginning-position))
                           dired-marker-char)
                       (file-directory-p default)
                       default))
         (parsed (diredfd-parse-user-input
                  (read-file-name
                   (format "Unpack %s into%s: "
                           (dired-mark-prompt arg files)
                           (if default
                               (format " (%s)" default) ""))
                   directory default nil nil
                   #'file-directory-p)))
         (directory (expand-file-name (car parsed)))
         (async (cdr parsed)))
    (or (file-directory-p directory)
        (if (y-or-n-p (format "Directory %s does not exist; create? " directory))
            (make-directory directory t)
          (error "Unpack aborted.")))
    (dolist (archive files)
      (diredfd-unpack archive directory async))))

(defun diredfd-unpack (archive directory &optional async)
  "Unpack ARCHIVE into DIRECTORY, asynchronously if ASYNC is non-nil."
  (let* ((command-tmpl (or (diredfd-unarchive-command-for-file archive)
                           (error "Unknown archive format: %s" archive)))
         (command (concat
                   (format "cd %s || exit; "
                           (shell-quote-argument
                            (expand-file-name directory)))
                   (mapconcat
                    (lambda (token)
                      (cond ((string= token "?")
                             (shell-quote-argument (expand-file-name archive)))
                            ((string= token "*")
                             "")
                            (t
                             token)))
                    (split-string command-tmpl " ")
                    " "))))
    (if async
        (async-shell-command command)
      (shell-command command))))

(defun diredfd-sort-lines (reverse beg end)
  (interactive "P\nr")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (let ((inhibit-field-text-motion t))
	(sort-subr nil 'forward-line 'end-of-line
                   #'diredfd-get-line-value nil
                   #'diredfd-line-value-<)))))

(defun diredfd-get-line-value ()
  (let* ((filename (dired-get-filename nil t))
         (basename (file-name-nondirectory filename)))
    (if (string-match-p "\\`\\.\\.?\\'" basename)
        (list 0 basename)
      (let ((type (char-after (+ (line-beginning-position) 2))))
        (cond ((= type ?d)
               (list 1 basename))
              ((= type ?l)
               (list (cond ((file-directory-p filename) 1)
                           ((file-exists-p filename) 2)
                           (t 3))
                     basename))
              (t
               (list 2 basename)))))))

(defun diredfd-line-value-< (l1 l2)
  (let ((v1 (car l1))
        (v2 (car l2)))
    (cond ((null v1) (not (null v2)))
          ((null v2) nil)
          ((stringp v1)
           (or (string< v1 v2)
               (and (string= v1 v2)
                    (diredfd-line-value-< (cdr l1) (cdr l2)))))
          (t
           (or (< v1 v2)
               (and (= v1 v2)
                    (diredfd-line-value-< (cdr l1) (cdr l2))))))))

(defun diredfd-sort ()
  "Sort dired listings with directories first."
  (save-excursion
    (let (buffer-read-only)
      (goto-char (point-min))
      (while (loop while (dired-between-files)
                   do (if (eobp)
                          (return nil)
                        (forward-line))
                   finally return t)
        (let ((beg (point)))
          (while (not (dired-between-files))
            (forward-line))
          (diredfd-sort-lines nil beg (point)))))
    (set-buffer-modified-p nil)))

(defcustom diredfd-highlight-line t
  "If non-nil, the current line is highlighted like FDclone."
  :type 'boolean
  :group 'dired-fdclone)

(defcustom diredfd-sort-by-type t
  "If non-nil, directory entries are sorted by file type (directories first)."
  :type 'boolean
  :group 'dired-fdclone)

(defun diredfd-dired-mode-setup ()
  (if diredfd-highlight-line (hl-line-mode 1)))

(defun diredfd-dired-after-readin-setup ()
  (if diredfd-sort-by-type (diredfd-sort)))

(defun diredfd-help ()
  "Show the help window."
  (interactive)
  (describe-keymap 'dired-mode-map))

;;;###autoload
(defun dired-fdclone ()
  "Enable FDclone mimicking settings for dired."
  (define-key dired-mode-map (kbd "TAB") 'diredfd-toggle-mark-here)
  (define-key dired-mode-map (kbd "DEL") 'diredfd-enter-parent-directory)
  (define-key dired-mode-map (kbd "RET") 'diredfd-enter)
  (define-key dired-mode-map " "         'diredfd-toggle-mark)
  (define-key dired-mode-map "*"         'dired-mark-files-regexp)
  (define-key dired-mode-map "+"         'diredfd-mark-or-unmark-all)
  (define-key dired-mode-map "-"         'diredfd-toggle-all-marks)
  (define-key dired-mode-map "/"         'dired-do-search)
  (define-key dired-mode-map "<"         'diredfd-goto-top)
  (define-key dired-mode-map ">"         'diredfd-goto-bottom)
  (define-key dired-mode-map "?"         'diredfd-help)
  (define-key dired-mode-map "D"         'dired-flag-file-deletion)
  (define-key dired-mode-map "\\"        'diredfd-enter-root-directory)
  (define-key dired-mode-map "a"         'dired-do-chmod)
  (define-key dired-mode-map "c"         'dired-do-copy)
  (define-key dired-mode-map "d"         'dired-do-delete)
  (define-key dired-mode-map "f"         'diredfd-narrow-to-files-regexp)
  (define-key dired-mode-map "h"         'diredfd-do-shell-command)
  (define-key dired-mode-map "k"         'dired-create-directory)
  (define-key dired-mode-map "l"         'diredfd-enter-directory)
  (define-key dired-mode-map "m"         'dired-do-rename)
  (define-key dired-mode-map "n"         'diredfd-narrow-to-marked-files)
  (define-key dired-mode-map "p"         'diredfd-do-pack)
  (define-key dired-mode-map "r"         (if (fboundp 'wdired-change-to-wdired-mode)
                                             'wdired-change-to-wdired-mode
                                           'dired-do-rename))
  (define-key dired-mode-map "u"         'diredfd-do-unpack)
  (define-key dired-mode-map "x"         'diredfd-do-flagged-delete-or-execute)

  (set-face-attribute 'dired-directory
                      nil :inherit font-lock-function-name-face :foreground "cyan")
  (set-face-attribute 'dired-symlink
                      nil :inherit font-lock-keyword-face :foreground "yellow")

  (setq dired-deletion-confirmer 'y-or-n-p)

  (add-hook 'dired-mode-hook 'diredfd-dired-mode-setup)
  (add-hook 'dired-after-readin-hook 'diredfd-dired-after-readin-setup))

(provide 'dired-fdclone)

;;; dired-fdclone.el ends here
