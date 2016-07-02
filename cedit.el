;;; cedit.el --- paredit-like commands for c-like languages

;; Copyright (C) 2013-2015 zk_phi
;; Copyright (C) 2016 Chris Gregory czipperz@gmail.com

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

;; Author: zk_phi
;; URL: http://hins11.yu-yake.com/
;; Version: 0.1.0

;;; Commentary:

;; Following commands are defined.  Call them with "M-x foo", or bind
;; some keys.

;; o cedit-forward-char / cedit-backward-char
;;   (in following examples, "|" are cursors)
;;
;;       fo|o; {bar;} baz;
;;   =>  foo|; {bar;} baz;
;;   =>  foo;| {bar;} baz;
;;   =>  foo; {bar;}| baz;
;;   =>  foo; {bar;} b|az;

;; o cedit-beginning-of-statement / cedit-end-of-statement
;;
;;       else{f|oo;}
;;   =>  else{|foo;} / else{foo;|}
;;
;;       els|e{bar;}
;;   =>  |else{bar;} / else{bar;}|

;; o cedit-down-block
;;
;;       wh|ile(cond){foo;}
;;   =>  while(cond){|foo;}

;; o cedit-up-block-forward / cedit-up-block-backward
;;
;;       if(cond){fo|o;}
;;   =>  |if(cond){foo;} / if(cond){foo;}|

;; o cedit-slurp
;;
;;       fo|o; bar;
;;   =>  fo|o, bar;
;;
;;       {fo|o;} bar;
;;   =>  {fo|o; bar;}

;; o cedit-wrap-brace
;;
;;       fo|o;
;;   =>  {fo|o;}

;; o cedit-barf
;;
;;       fo|o, bar;
;;   =>  fo|o; bar;
;;
;;       {fo|o; bar;}
;;   =>  {fo|o;} bar;

;; o cedit-splice-killing-backward
;;
;;       foo, ba|r, baz;
;;   =>  |bar, baz;
;;
;;       {foo; ba|r; baz;}
;;   =>  |bar; baz;

;; o cedit-raise
;;
;;       foo, ba|r, baz;
;;   =>  |bar;
;;
;;       {foo; ba|r; baz;}
;;   =>  |bar;

;; In addition, if "paredit.el" is installed on your Emacs, the
;; following commands are also defined.

;; o cedit-or-paredit-slurp
;; o cedit-or-paredit-barf
;; o cedit-or-paredit-splice-killing-backward
;; o cedit-or-paredit-raise

;; They are "dwim" commands that call one of cedit-xxx or paredit-xxx.

;;; Change Log:

;; 0.0.0 test release
;; 0.0.1 use require instead of autoload
;; 0.0.2 allow cedit-down-block to go down parens
;; 0.1.0 add a bunch of tests, fix behavior of some functions to match
;;       their supposed behavior.  Make functions behave consistently

;;; Code:

(eval-when-compile (require 'cl))

;; * constants

(defconst cedit-version "0.1.0")

;; * utilities

(defmacro cedit--move-iff-possible (&rest sexps)
  "Eval SEXPS, restoring the point if an error occured."
  `(let ((old-point (point)))
     (condition-case err (progn ,@sexps)
       (error (goto-char old-point) (error (cadr err))))))

(defmacro cedit--save-excursion (&rest sexps)
  "Eval SEXPS, not moving the point even when an error occured."
  `(cedit--move-iff-possible
    (let ((val (progn ,@sexps)))
      (goto-char old-point)
      val)))

(defmacro cedit--orelse (fst snd)
  "Try to eval FST and return the result.  If it threw an error,
SND is evaled and returned."
  `(condition-case err ,fst (error ,snd)))

(defmacro cedit--dowhile (prop &rest sexps)
  "Eval SEXPS in order then repeat while PROP is truthy."
  `(progn ,@sexps
          (while ,prop (progn ,@sexps))))

(defmacro cedit--assert (exp)
  "Assert EXP is truthy, throwing an error if it didn't."
  `(unless ,exp
     (error ,(format "assertion failed: %s" exp))))

(defun cedit--count-statements (beg end)
  "Get number of statements in the region BEG END."
  (cedit--save-excursion
   (goto-char beg)
   (let ((cnt 0))
     (while (ignore-errors (cedit-end-of-statement))
       (setq cnt (1+ cnt)))
     cnt)))

(defun cedit--search-char-forward (chars)
  "Run `cedit-forward-char' until the character before the point is in CHARS.

CHARS will be made into `(list CHARS)' if it is not a list.

CHARS = ?r:
fo|o; (bar;) foobar;  =>  foo; (bar;) foobar|;
foo; (bar;) foobar|;  =>  ERROR
bar|; foobar;  =>  bar; foobar|;"
  (when (not (listp chars)) (setq chars (list chars)))
  (cedit--dowhile (not (member (char-before) chars))
                  (cedit--orelse (cedit-forward-char)
                                 (error "not found %s" chars)))
  (point))

(defun cedit--search-char-backward (chars)
  "Run `cedit-backward-char' until the character after the point is in CHARS.

CHARS will be made into `(list CHARS)' if it is not a list.

CHARS = ?f:
foo; (bar;) |foobar;  =>  |foo; (bar;) foobar;
|foo; (bar;) foobar;  =>  ERROR
foo; |foobar;  =>  |foo; foobar;"
  (when (not (listp chars)) (setq chars (list chars)))
  (cedit--dowhile (not (member (char-after) chars))
                  (cedit--orelse (cedit-backward-char)
                                 (error "not found %s" chars)))
  (point))

(defun cedit--this-statement-type ()
  "Get the type of the statement at point.

Based on where `cedit-end-of-statement' takes us.

If the end of the statement is `;', then return atom `statement'.
If the end of the statement is `}', then return atom `block'.
Else return nil."
  (cedit--save-excursion
   (cedit-end-of-statement 'this)
   (let ((ch (char-before)))
     (cond ((= ch ?\;) 'statement)
           ((= ch ?\}) 'block)))))

;; * motion commands

(defconst cedit--opening-parens '(?\{ ?\( ?\[))
(defconst cedit--closing-parens '(?\} ?\) ?\]))

;;;###autoload
(defun cedit-forward-char (&optional nest)
  "Balanced `forward-char'.  Returns point.

NEST defaults to 0.

foo|; {bar;} baz;  =>  foo;| {bar;} baz;
foo;| {bar;} baz;  =>  foo; {bar;}| baz;
foo; {bar;|} baz;  =>  ERROR
foo; {bar;} baz;|  =>  ERROR"
  (interactive)
  (if (null nest) (setq nest 0))
  (cedit--move-iff-possible
   (skip-chars-forward "\s\t\n")
   (cond ((member (char-after) cedit--opening-parens)
          (setq nest (1+ nest)))
         ((member (char-after) cedit--closing-parens)
          (setq nest (1- nest))))
   (cond ((= (point) (point-max))
          (error "reached to EOF"))
         ((< nest 0)
          (error "reached to closing paren")))
   (forward-char)
   (when (> nest 0) (cedit-forward-char nest))
   (point)))

;;;###autoload
(defun cedit-backward-char (&optional nest)
  "Balanced `backward-char'.  Returns point.

foo; {bar;}| baz;  =>  foo; |{bar;} baz;
foo;| {bar;} baz;  =>  foo|; {bar;} baz;
foo; {|bar;} baz;  =>  ERROR
|foo; {bar;} baz;  =>  ERROR"
  (interactive)
  (if (null nest) (setq nest 0))
  (cedit--move-iff-possible
   (skip-chars-backward "\s\t\n")
   (cond ((member (char-before) cedit--closing-parens)
          (setq nest (1+ nest)))
         ((member (char-before) cedit--opening-parens)
          (setq nest (1- nest))))
   (cond ((= (point) (point-min))
          (error "reached to BOF"))
         ((< nest 0)
          (error "reached to opening paren")))
   (backward-char)
   (when (> nest 0) (cedit-backward-char nest))
   (point)))

;;;###autoload
(defun cedit-end-of-statement (&optional dont-continue)
  "Go to end of the statement.

When DONT-CONTINUE is non-nil, only move to the end of the current
statement (do nothing if already there).
When ERROR, point is never moved.

foo;| {bar;} baz;  =>  foo; {bar;}| baz;
foo; {bar;}| baz;  =>  foo; {bar;} baz;|
foo; {bar;} baz;|  =>  ERROR
foo; {bar;|} baz;  =>  ERROR"
  (interactive)
  (if (and dont-continue (member (char-before) '(?\; ?\})))
      ;; if dont-continue, and the point is EOS, just return point
      (point)
    ;; otherwise, search for next EOS
    (cedit--move-iff-possible
     (cedit--search-char-forward '(?\; ?\})))))

;;;###autoload
(defun cedit-beginning-of-statement (&optional dont-continue)
  "Go to beginning of the statement.

When DONT-CONTINUE is non-nil, only move to the beginning of the
current statement (do nothing if already there).
When ERROR, point is never moved.

foo; {bar;} |baz;  =>  foo; |{bar;} baz;
foo; |{bar;} baz;  =>  |foo; {bar;} baz;
|foo; {bar;} baz;  =>  ERROR
foo; {|bar;} baz;  =>  ERROR"
  (interactive)
  (cedit--move-iff-possible
   ;; goto end of this statement so back will work correctly
   (when dont-continue (cedit-end-of-statement t))
   ;; goto previous BOS
   (cedit-backward-char)          ; fail if no statements are backward
   (when (ignore-errors
           (cedit--search-char-backward '(?\; ?\{)))
     (cedit-forward-char))
   (skip-chars-forward "\s\t\n"))
  (point))

;;;###autoload
(defun cedit-down-block ()
  "Go down into the code block after cursor.

|else{foo; bar;}  =>  else{|foo; bar;}
|foo;  =>  ERROR"
  (interactive)
  ;; Down into (), [] ---- 2013 / 12 / 25
  (if (and (called-interactively-p 'any)
           (or (and (looking-back "\\s)")
                    (backward-sexp 1))
               (looking-at "\\s(")))
      (progn (forward-char 1) (skip-chars-forward "\s\t\n"))
    ;; the original behavior
    (cedit--move-iff-possible
     (when (not (eq (cedit--this-statement-type) 'block))
       (error "this statement is not a block"))
     (cedit-beginning-of-statement 'this)
     (search-forward "{")
     (skip-chars-forward "\s\t\n"))))

;;;###autoload
(defun cedit-up-block-backward ()
  "Go backward out of block.

If called at the top level, go to the beginning of the first statement.

do{foo; bar; b|az;}  =>  |do{foo; bar; baz;}
foo; bar; b|az;  =>  |foo; bar; baz;"
  (interactive)
  ;; goto beginning of the first statement
  (ignore-errors
    (while t (cedit-beginning-of-statement)))
  ;; go backward out of block if possible
  (ignore-errors
    (skip-chars-backward "\s\t\n")
    (backward-char)
    (cedit-beginning-of-statement 'this))
  (point))

;;;###autoload
(defun cedit-up-block-forward ()
  "go forward out of block

If called at top-level, go to the end of the last statement.

do{foo; bar; b|az;}  =>  do{foo; bar; baz;}|
foo; bar; b|az;  =>  foo; bar; baz;|"
  (interactive)
  ;; goto end of the last statement
  (ignore-errors
    (while t (cedit-end-of-statement)))
  ;; go forward out of block if possible
  (ignore-errors
    (skip-chars-forward "\s\t\n")
    (forward-char)
    (cedit-end-of-statement 'this))
  (point))

;; * slurp command

(defun cedit--slurp-semi ()
  "slurp statement after semicolon

{f|oo; bar, baz;}  =>  f|oo, bar, baz;
{foo, bar, baz;|}  =>  ERROR
"
  (cedit--save-excursion
   ;; foo;| bar;
   (cedit-end-of-statement 'this)
   (cedit--assert (= (char-before) ?\;))
   ;; foo|; bar;
   (let ((beg (1- (point))))
     ;; foo; bar;|
     (cedit-end-of-statement)
     (cedit--assert (= (char-before) ?\;))
     ;; foo; |bar;
     (cedit-beginning-of-statement 'this)
     ;; foo|bar;
     (delete-region beg (point))
     ;; foo, |bar;
     (insert ", "))))

(defun cedit--slurp-brace ()
  "slurp statement after brace

{fo|o; bar;} baz;  =>  {fo|o; bar; baz;}

do {
  fo|o;
  bar;
}
baz;
==>>
do {
  fo|o;
  bar;
  baz;
}
"
  (cedit--save-excursion
   ;; get in front of }
   (backward-up-list)
   (forward-list)
   ;; }|
   (let* ((end-yank (point))
          (begin-yank
           (save-excursion
             (backward-char)
             (cedit-beginning-of-statement)
             (cedit-end-of-statement)
             ;; foo;|   }| bar;
             ;; second bar is end-yank
             ;; first bar is point below
             (point))))
     ;; get region begin-yank to end-yank as yank
     (let ((yank
            ;; store to register then restore register
            (let ((reg (get-register ?r)))
              (copy-to-register ?r begin-yank end-yank)
              (prog1
                  (get-register ?r)
                (set-register ?r reg)))))
       ;; point is at }| bar;
       (cedit-end-of-statement)
       ;; point is at } bar;|
       ;; remove |   }|
       (delete-region begin-yank end-yank)
       ;; indent newly slurped expression
       (indent-for-tab-command)
       ;; and put it after bar;
       (insert yank)))))

;;;###autoload
(defun cedit-slurp ()
  "slurp statement

Calls `cedit--slurp-semi' or `cedit--slurp-brace' based on
context of the cursor.

{fo|o; bar;} baz;  =>  {fo|o, bar;} baz;
                   =>  {fo|o, bar; baz;}
                   =>  {fo|o, bar, baz;}"
  (interactive)
  (if (eq (cedit--this-statement-type) 'block)
      (cedit--slurp-brace)
    (cedit--orelse (cedit--slurp-semi)
                   (cedit--slurp-brace))))

;; * wrap command

;;;###autoload
(defun cedit-wrap-brace ()
  "wrap statement with brace

Wraps a region (mark and point) if the mark is active instead of the
current statement.

foo;
b|ar;
=>
foo;
|{
  bar;
}

(bar is correctly indented based on the indentation settings)"
  (interactive)
  (if (and transient-mark-mode mark-active)
      (let ((beg (region-beginning))
            (end (region-end)))
        (deactivate-mark)
        (goto-char beg)
        (insert "{\n")
        (goto-char (+ 2 end))
        (insert "\n}")
        (indent-region beg (point)))
    (cedit-beginning-of-statement 'this)
    (let ((beg (point)))
      (insert "{\n")
      (cedit-end-of-statement 'this)
      (insert "\n}")
      (indent-region beg (point))))
  (backward-list))

;; * barf command

(defun cedit--barf-semi ()
  "Turn a comma into a semicolon, ejecting an expression.

f|oo, bar, baz;
=>
f|oo, bar;
baz;"
  (cedit--save-excursion
   ;; f|oo, bar;
   (let ((beg (cedit-beginning-of-statement 'this))
         ;; foo, bar;|
         (end (cedit-end-of-statement 'this)))
     (cedit--assert (= (char-before) ?\;))
     ;; foo|, bar;
     (cedit--search-char-backward ?,)
     (when (< (point) beg)
       (error "no expressions to barf"))
     ;; foo| bar;
     (delete-char 1)
     ;; foo| bar;
     (delete-region (point)
                    (save-excursion (skip-chars-forward "\s\t\n")
                                    (point)))
     ;; foo|bar;
     (insert ";\n")
     ;; foo; bar;
     (indent-region beg (cedit-end-of-statement)))))

(defun cedit--barf-brace ()
  "Eject expression from braces.

{
  foo;
  bar;
  baz;
}
==>>
{
  foo;
  bar;
}
baz;
==>>
{
  foo;
}
bar;
baz;
==>>
{
}
foo;
bar;
baz;"
  (cedit--save-excursion
   (when (eq (cedit--this-statement-type) 'block)
     (cedit-down-block))
   ;; fo|o; bar; }
   (let* ((beg (point))
          ;; foo; bar; }|
          (end (cedit-up-block-forward))
          ;; foo; bar;| }
          (stmt-end (progn (cedit--assert (= (char-before) ?\}))
                           (backward-char)
                           (1+ (cedit--search-char-backward ?\;))))
          ;; foo; |bar; }
          (stmt-beg (cedit-beginning-of-statement 'this)))
     ;; foo; |bar;
     (delete-region stmt-end end)
     ;; foo; }|bar;
     (insert "}\n")
     (indent-region beg (cedit-end-of-statement)))))

;;;###autoload
(defun cedit-barf ()
  "Barf statement from its context.

Prioritizes `cedit--barf-semi' over `cedit--barf-brace'.

{fo|o, bar; baz;}  =>  {fo|o; bar; baz;}
                   =>  {fo|o; bar;} baz;
                   =>  {fo|o;} bar; baz;"
  (interactive)
  (if (eq (cedit--this-statement-type) 'block.)
      (cedit--barf-brace)
    (cedit--orelse (cedit--barf-semi)
                   (cedit--barf-brace))))

;; * splice command

(defun cedit--splice-killing-backward-semi ()
  "Kill toward begging of statement in comma operator statement.

{foo; bar, b|az, foobar;}  =>  {foo; |baz, foobar;}
{foo; bar, baz, |foobar;}  =>  {foo; |foobar;}"
  (let* ((beg
          (save-excursion
            (when (>
                   (save-excursion
                     (cedit-beginning-of-statement 'this))
                   (cedit--search-char-backward ?,)) ; may fail
              (error
               "this is the first expression"))
            (forward-char)
            (skip-chars-forward "\s\t\n")
            (point)))
         (end (save-excursion
                (cedit-end-of-statement 'this)
                (cedit--assert (= (char-before) ?\;))
                (point))))
    (delete-region (cedit-beginning-of-statement 'this) beg)))

(defun cedit--splice-killing-backward-brace ()
  "Kill statements before that at the point and raise the result out of the block.

{foo; bar, b|az, foobar; asdf, kappa;}
=>  |bar, baz, foobar; asdf, kappa;

{foo; bar, baz, foobar; asd|f, kappa;}
=>  |asdf, kappa;"
  (let* ((beg (save-excursion
                (cedit-beginning-of-statement 'this)))
         (end (save-excursion
                ;; end of the last statement in this block
                (ignore-errors (while t (cedit-end-of-statement)))
                (point)))
         (str (buffer-substring beg end))
         (cnt (cedit--count-statements beg end)))
    (delete-region (save-excursion (cedit-up-block-backward))
                   (save-excursion (cedit-up-block-forward)))
    (indent-region (point)
                   (save-excursion (insert str) (point)))))

;;;###autoload
(defun cedit-splice-killing-backward ()
  "Splice statements killing preceding statements.

Run `cedit--splice-killing-backward-semi' then
`cedit--splice-killing-backward-brace'.

{foo; bar, b|az, foobar;}  =>  {foo; |baz, foobar;}
                           =>  baz, foobar;"
  (interactive)
  (cedit--orelse (cedit--splice-killing-backward-semi)
                 (cedit--splice-killing-backward-brace)))

;; * raise command

(defun cedit--raise-semi ()
  "Raise part of a comma operator list.

{foo; bar, b|az, foobar;}  =>  {foo; |baz;}"
  (let* ((beg (save-excursion
                (when (ignore-errors (cedit--search-char-backward '(?, ?\; ?\})))
                  (forward-char))
                (skip-chars-forward "\s\t\n")
                (point)))
         (end (save-excursion
                (cedit--search-char-forward '(?\; ?,))
                (1- (point))))
         (str (buffer-substring beg end)))
    (when (and (= beg (save-excursion (cedit-beginning-of-statement 'this)))
               (= end (1- (save-excursion (cedit-end-of-statement 'this)))))
      (error "cannot raise single expression"))
    (delete-region (save-excursion (cedit-end-of-statement 'this))
                   (cedit-beginning-of-statement 'this))
    (save-excursion (insert str ";"))))

(defun cedit--raise-brace (&optional beg end)
  "Raise a statement of a braced list of statements.

BEG and END default to the beginning and end of the current statement.

{foo; bar, b|az, foobar;}  =>  |bar, baz, foobar;"
  (let* ((beg (or beg
                  (save-excursion (cedit-beginning-of-statement 'this))))
         (end (or end
                  (save-excursion (cedit-end-of-statement 'this))))
         (str (buffer-substring beg end)))
    (delete-region (save-excursion (cedit-up-block-backward))
                   (save-excursion (cedit-up-block-forward)
                                   (cedit--assert (= (char-before) ?\}))
                                   (point)))
    (indent-region (point)
                   (save-excursion (insert str) (point)))))

;;;###autoload
(defun cedit-raise ()
  "raise statement
{foo; bar, b|az, foobar;}  =>  {foo; |baz;}
                           =>  baz;
to raise statement, in case comma-expr is also able to be raise, mark it."
  (interactive)
  (if (and (called-interactively-p 'any)
           transient-mark-mode mark-active)
      (let ((beg (region-beginning))
            (end (region-end)))
        (deactivate-mark)
        (cedit--raise-brace beg end))
    (cedit--orelse (cedit--raise-semi)
                   (cedit--raise-brace))))

;; * paredit

(when (require 'paredit nil t)

  ;; suppress byte-compiler
  (declare-function paredit-raise-sexp "paredit")
  (declare-function paredit-forward-up "paredit")
  (declare-function paredit-forward-slurp-sexp "paredit")
  (declare-function paredit-backward-barf-sexp "paredit")
  (declare-function paredit-splice-sexp-killing-backward "paredit")

;;;###autoload
  (defun cedit-or-paredit-slurp ()
    "call cedit-slurp or paredit-forward-slurp-sexp"
    (interactive)
    (let ((pare (save-excursion
                  (ignore-errors (paredit-forward-up) (point))))
          (c (save-excursion
               (ignore-errors (cedit-end-of-statement 'this)))))
      (cond ((null c) (paredit-forward-slurp-sexp))
            ((null pare) (cedit-slurp))
            ((< pare c) (cedit--orelse (paredit-forward-slurp-sexp)
                                       (cedit-slurp)))
            (t (cedit--orelse (cedit-slurp)
                              (paredit-forward-slurp-sexp))))))

;;;###autoload
  (defun cedit-or-paredit-barf ()
    "call cedit-barf or paredit-backward-barf-sexp"
    (interactive)
    (let ((pare (save-excursion
                  (ignore-errors (paredit-forward-up) (point))))
          (c (save-excursion
               (ignore-errors (cedit-end-of-statement 'this)))))
      (cond ((null c) (paredit-forward-barf-sexp))
            ((null pare) (cedit-barf))
            ((< pare c) (cedit--orelse (paredit-forward-barf-sexp)
                                       (cedit-barf)))
            (t (cedit--orelse (cedit-barf)
                              (paredit-forward-barf-sexp))))))

;;;###autoload
  (defun cedit-or-paredit-splice-killing-backward ()
    "call cedit-splice-killing or paredit-splice-sexp-killing-backward"
    (interactive)
    (let ((pare (save-excursion
                  (ignore-errors (paredit-forward-up) (point))))
          (c (save-excursion
               (ignore-errors (cedit-end-of-statement 'this)))))
      (cond ((null c) (paredit-splice-sexp-killing-backward))
            ((null pare) (cedit-splice-killing-backward))
            ((< pare c) (cedit--orelse
                         (paredit-splice-sexp-killing-backward)
                         (cedit-splice-killing-backward)))
            (t (cedit--orelse
                (cedit-splice-killing-backward)
                (paredit-splice-sexp-killing-backward))))))

;;;###autoload
  (defun cedit-or-paredit-raise ()
    "call cedit-raise or paredit-raise-sexp"
    (interactive)
    (let ((pare (save-excursion
                  (ignore-errors (paredit-forward-up) (point))))
          (c (save-excursion
               (ignore-errors (cedit-end-of-statement 'this)))))
      (cond ((null c) (paredit-raise-sexp))
            ((null pare) (cedit-raise))
            ((< pare c) (cedit--orelse (paredit-raise-sexp)
                                       (cedit-raise)))
            (t (cedit--orelse (cedit-raise)
                              (paredit-raise-sexp)))))))

;; * provide

(provide 'cedit)

;;; cedit.el ends here
