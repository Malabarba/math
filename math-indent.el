(defun math-union-re (regexps)
  "Create a regular expression that is the union of the regular
  expressions in the given list."
  (mapconcat 'copy-sequence regexps " \\| "))

(defconst math-comment-start-re
  "(\*"
  "The regular expression for a Mathematica start comment delimiter.")

(defconst math-comment-end-re
  "\*)"
  "The regular expression for a Mathematica end comment delimiter.")

(defconst math-user-ident-re
  "[a-zA-Z0-9_]+"
  "The regular expression for a Mathmatica user identifier.")

(defconst math-sys-ident-re
  "[A-Z][a-zA-Z]*"
  "The regular expression for a Mathmatica system identifier.")

(defconst math-symbol-re
  "\\\\\\[\\([A-Z][A-Za-z0-9]*\\)]"
  "The regular expresion for a Mathematica syntax character.")

(defconst math-string-re
  "\"[^\"\\\\]*\\(?:\\\\.[^\"\\\\]*\\)*\""
  "The regular expression for the start of a Mathematica string.")

(defconst math-open-brace-re
  "\\[\\|(\\|{"
  "The regular expression for a Mathematica open brace.")

(defconst math-close-brace-re
  "\\]\\|)\\|}"
  "The regular expression for a Mathematica close brace.")

(defconst math-number-re
  ;; Taken from http://reference.wolfram.com/mathmatica/tutorial/InputSyntax.html#7977
  ;;     digits                - integer
  ;;     digits.digits         - approximate number
  ;;     base^^digits          - integer in base
  ;;     base^^digits.digits   - approximate number in base
  ;;     mantissa*^n           - scientific notation
  ;;     base^^mantissa*^n     - scientific notation in base
  ;;     number`               - number in machine precision
  ;;     number`s              - number in precision s
  ;;     number``s             - number in precision s
  ;;
  "[+-]?[0-9]*\\.?[0-9]+"
  "The regular expression for a Mathmatica number.")

(defconst math-operator-re
  (regexp-opt '("=" ":=" "," ";" ":" "::" "|" "-" "+" "*" "/"))
  "The regular expression for a Mathmatica operator.")

(defconst math-token-re-alist
  `((:user-ident . ,math-user-ident-re)
   (:sys-ident . ,math-sys-ident-re)
   (:number . ,math-number-re)
   (:string . ,math-string-re)
   (:open . ,math-open-brace-re)
   (:close . ,math-close-brace-re)
   (:operator . ,math-operator-re))
  "Association list of token-class and regular expressions for
  matching each type of token.")

(defun math-forward-string (&optional backward)
  "Move point to the end of the string. If backward is not nil,
move to the beginning of he string.

Assumes point is within a string.
"
  ;; Move to the beginning of the string.
  (goto-char (nth 8 (syntax-ppss)))

  ;; If we are not moving to the beginning of the string, move to the
  ;; end of the string.
  (unless backward
    (forward-sexp)))

(defun math-forward-comment (&optional backward)
  "Move point to the end of the comment. If backward is not nil,
move to the beginning of he comment.

Assumes point is within a comment.
"
  ;; Move to the beginning of the comment.
  (goto-char (nth 8 (syntax-ppss)))

  ;; If we are not moving to the beginning of the comment, move to the
  ;; end of the comment.
  (unless backward
    (forward-comment 1))
)

(defun math-forward-token (&optional count)
  "Move forward across COUNT lexical tokens. Argument -COUNT
means move backwards across COUNT lexical tokens.

Return the cons (token-class . value) where token-class is one
of: `:comment-start', `:comment-end', `:symbol', `:number', `:string',
`:user-ident', `:sys-ident', `:operator', `:open', `:close'.

The point is assumed not to be within a comment or string.
"
  ;; If case-fold search is true, then upper and lower cases are not
  ;; distinguishable in regular expressions. We set it to false
  ;; locally so that upper and lower cases can be distinguished. This
  ;; does not have any impact outside of this function.
  (let ((case-fold-search nil)) 
    ;; Move past any white space.
    (forward-comment (if (> count 0) (point-max) (-(point-max))))

    ;; The point is just before a token. Match the token to one of
    ;; the token classes described in the math-token-re-alist.
    (catch 're-match
      (let ((looking (if (> count 0) 'looking-at (lambda (re) (looking-back re (point-min) t))))
	    (match (if (> count 0) 'match-end 'match-beginning)))
	(dolist (pair math-token-re-alist)
	  (if (funcall looking (cdr pair))
	      (progn
		(goto-char (funcall match 0))
		(throw 're-match (cons (car pair) (match-string-no-properties 0))))))
	(cons :unknown "?")))))

(defun math-context ()
  "The context at point: `:comment-context', `:string-context', `:code-context'"
  (let ((ppss (syntax-ppss)))
    (cond ((nth 3 ppss) :string-context)
	  ((nth 4 ppss) :comment-context)
	  (t :code-context))))

(defun math-indent-line ()
  (interactive)
  (save-excursion
    (forward-line 0)
    (let ((context (math-context)))
      (cond ((eq context :comment-context) (message "comment"))
	    ((eq context :string-context) (message "string"))
	    ((eq context :code-context) (message "code"))))))

(defun scan-region ()
  (save-excursion
    (with-output-to-temp-buffer "*tokens"
      (let ((start (region-beginning))
	    (end (region-end)))
	(goto-char start)
	(set-mark end)
	(if (> (point) (mark))
	    (exchange-point-and-mark))
	(while (< (point) (mark))
	  (setq token (math-forward-token))
	  (if (and token (> (length token) 0))
	      (princ (format "<%s> " token))
	    (let ((start (point)))
	      (forward-char)
	      (princ (format " %s " (buffer-substring-no-properties start (point)))))))))))

(defun math-forward-token-command ()
  (interactive)
  (let ((pair (math-forward-token 1)))
    (message "%s" pair)))

(defun math-backward-token-command ()
  (interactive)
  (let ((pair (math-forward-token -1)))
    (message "%s" pair)))

(provide 'math-indent)
