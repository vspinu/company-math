;;; company-math.el --- Completion backends for unicode math symbols and latex tags
;;
;; Copyright (C) 2015 Free Software Foundation, Inc.
;; Author: Vitalie Spinu
;; URL: https://github.com/vspinu/company-math
;; Keywords:  Unicode, symbols, completion
;; Version: 1.0.1
;; Package-Requires: ((company "0.8.0") (math-symbol-lists "1.0"))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This file is part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:

(require 'math-symbol-lists)
(require 'company)
(require 'cl-lib)

(defgroup company-math nil
  "Completion back-ends for math symbols Unicode symbols and LaTeX tags."
  :group 'company
  :prefix "company-math-")

(defcustom company-math-prefix-regexp "\\\\\\([^ \t]+\\)"
  "Regexp matching the prefix of the company-math symbol.
First subgroup must match the actual symbol to be used in the
completion."
  :group 'company-math
  :type 'string)

(defcustom company-math-allow-unicode-symbols-in-faces t
  "List of faces to allow the insertion of Unicode symbols.
When set to special value t, allow on all faces except those in
`company-math-disallow-unicode-symbols-in-faces'."
  :group 'company-math
  :type '(choice (const t)
		 (repeat :tag "Faces" symbol)))

(defcustom company-math-allow-latex-symbols-in-faces '(font-latex-math-face)
  "List of faces to disallow the insertion of latex mathematical symbols.
When set to special value t, allow on all faces except those in
`company-math-disallow-latex-symbols-in-faces'."
  :group 'company-math
  :type '(choice (const t)
		 (repeat :tag "Faces" symbol)))

(defcustom company-math-disallow-unicode-symbols-in-faces '(font-latex-math-face)
  "List of faces to disallow the insertion of Unicode symbols."
  :group 'company-math
  :type '(repeat symbol))

(defcustom company-math-disallow-latex-symbols-in-faces '()
  "List of faces to disallow the insertion of latex mathematical symbols."
  :group 'company-math
  :type '(repeat symbol))


;;; INTERNALS

(defun company-math--make-candidates (alist)
  "Build a list of math symbols ready to be used in ac source.
ALIST is one of the defined alist in package `symbols'. Return a
list of LaTeX symbols with text property :symbol being the
corresponding unicode symbol."
  (delq nil
        (mapcar
         #'(lambda (el)
	     (let* ((tex (substring (nth 1 el) 1))
		    (ch (and (nth 2 el) (decode-char 'ucs (nth 2 el))))
		    (symb (and ch (char-to-string ch))))
	       (propertize tex :symbol symb)))
         alist)))

(defconst company-math--symbols
  (delete-dups
   (append (company-math--make-candidates math-symbol-list-basic)
           (company-math--make-candidates math-symbol-list-extended)))
  "List of math completion candidates.")

(defun company-math--prefix (allow-faces disallow-faces)
  (let* ((face (get-text-property (point) 'face))
	 (face (or (car-safe face) face))
	 (insertp (and (not (memq face disallow-faces))
		       (or (eq t allow-faces)
			   (memq face allow-faces)))))
    (when insertp
      (save-excursion
	(when (looking-back company-math-prefix-regexp (point-at-bol))
	  (match-string 1))))))

(defun company-math--substitute-unicode (symbol)
  "Substitute preceding latex command with with SYMBOL."
  (let ((pos (point))
	(inhibit-point-motion-hooks t))
    (when (re-search-backward company-math-prefix-regexp)
      (delete-region (match-beginning 0) pos)
      (insert symbol))))
      
      ;Zorgoth's new function
(defun company-math-manual-substitute-unicode () (interactive)
  "Substitute preceding latex command with its symbol interactively."
    (let* ((pos (point))
	   (inhibit-point-motion-hooks t) ; not sure if/why necessary 
	    (matchpos (progn              ;^included because in the orig.
	      (re-search-backward company-math-prefix-regexp)
	      (match-beginning 1)))
	   (delpos (match-beginning 0))
	   (astring (buffer-substring matchpos pos)) ;string to check
           (bstring (car (member astring company-math--symbols))) ;returns propertized string or nil
           (symbol (if bstring (nth 1 (text-properties-at 0 bstring)))) )
      (if symbol ;do nothing if symbol is nil
	(progn (delete-region delpos pos) (insert symbol))
        (goto-char pos)) ))


;;; BACKENDS

;;;###autoload
(defun company-latex-commands (command &optional arg &rest ignored)
  "Company backend for latex commands."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-latex-commands))
    (prefix (unless (company-in-string-or-comment)
	      (company-math--prefix t '())))
    (candidates (all-completions arg math-symbol-list-latex-commands))
    (sorted t)))

;;;###autoload
(defun company-math-symbols-latex (command &optional arg &rest ignored)
  "Company backend for LaTeX mathematical symbols."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-math-symbols-latex))
    (prefix (unless (company-in-string-or-comment)
	      (company-math--prefix company-math-allow-latex-symbols-in-faces
				    company-math-disallow-latex-symbols-in-faces)))
    (annotation (concat " " (get-text-property 0 :symbol arg)))
    (candidates (all-completions arg company-math--symbols))))

;;;###autoload
(defun company-math-symbols-unicode (command &optional arg &rest ignored)
  "Company backend for LaTeX mathematical symbols."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-math-symbols-unicode))
    (prefix (company-math--prefix company-math-allow-unicode-symbols-in-faces
				  company-math-disallow-unicode-symbols-in-faces))
    (annotation (concat " " (get-text-property 0 :symbol arg)))
    (candidates
     (let* ((completions (all-completions arg company-math--symbols)) ;changes start here
	    (symbol (if (equal arg (car completions))
			(get-text-property 0 :symbol (pop completions)))) ;pop to check if list has other elts
	    (newelt (if symbol (if (car completions) ;elt to add to list, nil if list not popped
			(propertize arg :symbol symbol)
			(propertize (concat arg "--" symbol) :symbol symbol)))))
	 (cons newelt completions))) ;changes end here
    (post-completion (company-math--substitute-unicode
		      (get-text-property 0 :symbol arg)))))


(provide 'company-math)

;;; company-math.el ends here
