(defvar ralph-mode-font-lock-keywords
  `(,(regexp-opt
	  '("#rest" "#key"
		"method" "block"
		"define-function" "define-method"
        "define-class" "define-module"
		"define-generic" "define-macro" "define"
		"bind-properties" "bind-methods" "bind" "destructuring-bind"
		"set!" "get" "inc!" "dec!"
		"when" "if" "unless" "if-bind" "select" "cond"
		"and" "or" "not"
		"while" "until" "dotimes" "for" "for-each")
	  'words)
	("\\<<\\(\\sw\\|\\s_\\)+>\\>" . font-lock-type-face)
	("\\<define\\>\\s-+\\(\\(\\sw\\|\\s_\\)+\\)"
	 1 font-lock-variable-name-face)
	("\\<define-\\(function\\|method\\|generic\\)\\>\\s-+\\(\\(\\sw\\|\\s_\\)+\\)"
	 2 font-lock-function-name-face)
	("\\<define-module\\>\\s-+\\(\\(\\sw\\|\\s_\\)+\\)"
	 1 font-lock-function-name-face)
	(,(regexp-opt
	   '("bind-method" "signal")
	   'words)
	 . font-lock-warning-face)))

(defvar ralph-mode-syntax-table
  (let ((table (copy-syntax-table lisp-mode-syntax-table)))
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table))

(define-derived-mode
  ralph-mode lisp-mode "Ralph"
  "Major mode"
  (setq font-lock-defaults '((ralph-mode-font-lock-keywords) nil nil))
  (set (make-local-variable 'lisp-indent-function)
	   'ralph-indent-function)
  (set-syntax-table ralph-mode-syntax-table))

;; indentation offsets
(put 'when 'ralph-indent-function 1)
(put 'unless 'ralph-indent-function 1)
(put 'while 'ralph-indent-function 1)
(put 'until 'ralph-indent-function 1)
(put 'dotimes 'ralph-indent-function 1)
(put 'bind 'ralph-indent-function 1)
(put 'bind-methods 'ralph-indent-function 1)
(put 'if 'ralph-indent-function nil)
(put 'if-bind 'ralph-indent-function 1)
(put 'for 'ralph-indent-function 2)
(put 'for-each 'ralph-indent-function 2)
(put 'select 'ralph-indent-function 2)
(put 'method 'ralph-indent-function 1)
(put 'block 'ralph-indent-function 1)
(put 'bind 'ralph-indent-function 2)
(put 'bind-properties 'ralph-indent-function 2)
(put 'destructuring-bind 'ralph-indent-function 2)

(defun ralph-indent-function (indent-point state)
  "Same as 'lisp-indent-function but uses 'ralph-indent-function symbol

This function is the normal value of the variable `ralph-indent-function'.
It is used when indenting a line within a function call, to see if the
called function says anything special about how to indent the line.

INDENT-POINT is the position where the user typed TAB, or equivalent.
Point is located at the point to indent under (for default indentation);
STATE is the `parse-partial-sexp' state for that position.

If the current line is in a call to a Lisp function
which has a non-nil property `ralph-indent-function',
that specifies how to do the indentation.  The property value can be
* `defun', meaning indent `defun'-style;
* an integer N, meaning indent the first N arguments specially
  like ordinary function arguments and then indent any further
  arguments like a body;
* a function to call just as this function was called.
  If that function returns nil, that means it doesn't specify
  the indentation.

This function also returns nil meaning don't specify the indentation."
  (let ((normal-indent (current-column)))
    (goto-char (1+ (elt state 1)))
    (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
    (if (and (elt state 2)
             (not (looking-at "\\sw\\|\\s_")))
        ;; car of form doesn't seem to be a symbol
        (progn
          (if (not (> (save-excursion (forward-line 1) (point))
                      calculate-lisp-indent-last-sexp))
              (progn (goto-char calculate-lisp-indent-last-sexp)
                     (beginning-of-line)
                     (parse-partial-sexp (point)
                                         calculate-lisp-indent-last-sexp 0 t)))
          ;; Indent under the list or under the first sexp on the same
          ;; line as calculate-lisp-indent-last-sexp.  Note that first
          ;; thing on that line has to be complete sexp since we are
          ;; inside the innermost containing sexp.
          (backward-prefix-chars)
          (current-column))
      (let ((function (buffer-substring (point)
                                        (progn (forward-sexp 1) (point))))
            method)
        (setq method (or (get (intern-soft function) 'ralph-indent-function)
                         (get (intern-soft function) 'lisp-indent-hook)))
        (cond ((or (eq method 'defun)
                   (and (null method)
                        (> (length function) 3)
                        (string-match "\\`def" function)))
               (lisp-indent-defform state indent-point))
              ((integerp method)
               (lisp-indent-specform method state
                                     indent-point normal-indent))
              (method
               (funcall method indent-point state)))))))

(provide 'ralph)
