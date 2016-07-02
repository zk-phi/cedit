;;; cedit-example-tests.el --- test examples in documentation

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

;;; Commentary:
;; The point of these tests are to ensure the behavior of the
;; documentation is actually true.  This will probably be split in
;; the future into multiple modules.

;;; Code:
(require 'ert)
(require 'cedit)

(ert-deftest cedit--search-char-forward--example-1 ()
  (with-temp-buffer
    (insert "foo; (bar;) foobar;")

    (goto-char 3)
    (should (looking-at-p "o; (bar;) foobar;$"))

    (cedit--search-char-forward ?r)
    (should (looking-at-p ";$"))

    (should-error (cedit--search-char-forward ?r))))

(ert-deftest cedit--search-char-forward--example-2 ()
  (with-temp-buffer
    (insert "bar; foobar;")

    (goto-char 4)
    (should (looking-at-p "; foobar;$"))

    (cedit--search-char-forward ?r)
    (should (looking-at-p ";$"))))



(ert-deftest cedit--search-char-backward--example-1 ()
  (with-temp-buffer
    (insert "foo; (bar;) foobar;")

    (goto-char 13)
    (should (looking-at-p "foobar;$"))

    (cedit--search-char-backward ?f)
    (should (looking-at-p "foo; (bar;) foobar;"))

    (should-error (cedit--search-char-backward ?f))))

(ert-deftest cedit--search-char-backward--example-2 ()
  (with-temp-buffer
    (insert "foo; foobar;")

    (goto-char 6)
    (should (looking-at-p "foobar;$"))

    (cedit--search-char-backward ?f)
    (should (looking-at-p "foo; foobar;$"))
    (should (= (point) (point-min)))))



(ert-deftest cedit-forward-char--example-1 ()
  (with-temp-buffer
    (insert "foo; {bar;} baz;")

    (goto-char 4)
    (should (looking-at-p "; {bar;} baz;$"))

    (cedit-forward-char)
    (should (looking-at-p " {bar;} baz;$"))

    (cedit-forward-char)
    (should (looking-at-p " baz;$"))

    (cedit-forward-char)
    (should (looking-at-p "az;$"))

    ;; now it will step forward a char at a time
    (let ((p (point)))
      (while (not (eolp))
        (setq p (1+ p))
        (cedit-forward-char)
        (should (= (point) p))))

    (goto-char 11)
    (should (looking-at-p "} baz;$"))
    (should-error (cedit-forward-char))

    (end-of-line)
    (should-error (cedit-forward-char))))



(ert-deftest cedit-backward-char--example-1 ()
  (with-temp-buffer
    (insert "foo; {bar;} baz;")

    (goto-char 12)
    (should (looking-at-p " baz;$"))

    (cedit-backward-char)
    (should (looking-at-p "{bar;} baz;$"))

    (cedit-backward-char)
    (should (looking-at-p "; {bar;} baz;$"))

    ;; now it will step backward a char at a time
    (let ((p (point)))
      (while (not (bolp))
        (setq p (- p 1))
        (cedit-backward-char)
        (should (= (point) p))))

    (goto-char 7)
    (should-error (cedit-backward-char))

    (goto-char (point-min))
    (should-error (cedit-backward-char))))



(ert-deftest cedit-end-of-statement--example-1 ()
  (with-temp-buffer
    (insert "foo; {bar;} baz;")

    (goto-char 5)
    (should (looking-at-p " {bar;} baz;$"))

    (cedit-end-of-statement)
    (should (looking-at-p " baz;$"))

    (cedit-end-of-statement)
    (should (eolp))

    (should-error (cedit-end-of-statement))

    (goto-char 11)
    (should (looking-at-p "} baz;$"))

    (should-error (cedit-end-of-statement))))



(ert-deftest cedit-beginning-of-statement--example-1 ()
  (with-temp-buffer
    (insert "foo; {bar;} baz;")

    (goto-char 13)
    (should (looking-at-p "baz;$"))

    (cedit-beginning-of-statement)
    (should (looking-at-p "{bar;} baz;$"))

    (cedit-beginning-of-statement)
    (should (bolp))

    (should-error (cedit-beginning-of-statement))

    (goto-char 7)
    (should (looking-at-p "bar;} baz;$"))

    (should-error (cedit-beginning-of-statement))))



(ert-deftest cedit-down-block--example-1 ()
  (with-temp-buffer
    (insert "else{foo; bar;}")

    (goto-char (point-min))

    (cedit-down-block)
    (should (looking-at-p "foo; bar;}$"))

    (should-error (cedit-down-block))))

(ert-deftest cedit-down-block--example-2 ()
  (with-temp-buffer
    (insert "foo;")

    (goto-char (point-min))

    (should-error (cedit-down-block))))



(ert-deftest cedit-up-block-backward--example-1 ()
  (with-temp-buffer
    (insert "do{foo; bar; baz;}")

    (goto-char 15)
    (should (looking-at-p "az;}$"))

    (cedit-up-block-backward)
    (should (bolp))))

(ert-deftest cedit-up-block-backward--example-2 ()
  (with-temp-buffer
    (insert "foo; bar; baz;")

    (goto-char 12)
    (should (looking-at-p "az;$"))

    (cedit-up-block-backward)
    (should (bolp))))



(ert-deftest cedit-up-block-forward--example-1 ()
  (with-temp-buffer
    (insert "do{foo; bar; baz;}")

    (goto-char 15)
    (should (looking-at-p "az;}$"))

    (cedit-up-block-forward)
    (should (eolp))))

(ert-deftest cedit-up-block-forward--example-2 ()
  (with-temp-buffer
    (insert "foo; bar; baz;")

    (goto-char 12)
    (should (looking-at-p "az;$"))

    (cedit-up-block-forward)
    (should (eolp))))



(ert-deftest cedit--slurp-semi--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz;}")

    (goto-char 3)
    (should (looking-at-p "oo; bar, baz;}$"))

    (cedit--slurp-semi)
    (should (looking-at-p "oo, bar, baz;}$"))

    (should-error (cedit--slurp-semi))))



(ert-deftest cedit--slurp-brace--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar;} baz;")
    ;; slurp braces requires c++ mode for indentation correction
    (c++-mode)

    (goto-char 4)
    (should (looking-at-p "o; bar;} baz;$"))

    (cedit--slurp-brace)
    (should (looking-at-p "o; bar; baz;}$"))

    (should-error (cedit--slurp-brace))))



(ert-deftest cedit-slurp--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar;} baz;")
    ;; slurp braces requires c++ mode for indentation correction
    (c++-mode)

    (goto-char 4)
    (should (looking-at-p "o; bar;} baz;$"))

    (cedit-slurp)
    (should (looking-at-p "o, bar;} baz;$"))

    (cedit-slurp)
    (should (looking-at-p "o, bar; baz;}$"))

    (cedit-slurp)
    (should (looking-at-p "o, bar, baz;}$"))))



(ert-deftest cedit-wrap-brace--example-1 ()
  (with-temp-buffer
    (insert "foo;\nbar;\n")
    (c++-mode)

    (goto-char 7)
    (should (looking-at-p "ar;\n"))

    (cedit-wrap-brace)
    ;; indentation scheme is unknown so use \\s-+ to match 1+
    ;; spaces/tabs
    (should (looking-at-p "{\n\\s-+bar;\n}"))))



(ert-deftest cedit--barf-semi--example-1 ()
  (with-temp-buffer
    (insert "foo, bar, baz;")
    (c++-mode)

    (goto-char 3)
    (should (looking-at-p "o, bar, baz;$"))

    (cedit--barf-semi)
    (should (looking-at-p "o, bar;\nbaz;$"))

    (cedit--barf-semi)
    (should (looking-at-p "o;\nbar;\nbaz;$"))))



(ert-deftest cedit--barf-brace--example-1 ()
  (with-temp-buffer
    (insert "{\nfoo;\nbar;\nbaz;\n}")
    (c++-mode)
    (indent-region (point-min) (point-max))

    (goto-char (point-min))
    (should (looking-at-p "{\n\\s-+foo;\n\\s-+bar;\n\\s-+baz;\n}$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n\\s-+foo;\n\\s-+bar;\n}\nbaz;$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n\\s-+foo;\n}\nbar;\nbaz;$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n}\nfoo;\nbar;\nbaz;$"))))



(ert-deftest cedit-barf--example-1 ()
  (with-temp-buffer
    (insert "{\nfoo;\nbar;\nbaz;\n}")
    (c++-mode)
    (indent-region (point-min) (point-max))

    (goto-char (point-min))
    (should (looking-at-p "{\n\\s-+foo;\n\\s-+bar;\n\\s-+baz;\n}$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n\\s-+foo;\n\\s-+bar;\n}\nbaz;$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n\\s-+foo;\n}\nbar;\nbaz;$"))

    (cedit--barf-brace)
    (should (looking-at-p "{\n}\nfoo;\nbar;\nbaz;$"))))



(ert-deftest cedit--splice-killing-backward-semi--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit--splice-killing-backward-semi)
    (should (looking-at-p "baz, foobar;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; baz, foobar;}$")))

    ;; no change here
    (should-error (cedit--splice-killing-backward-semi))

    (goto-char 12)
    (should (looking-at-p "foobar;}$"))

    (cedit--splice-killing-backward-semi)
    (should (looking-at-p "foobar;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; foobar;}$")))

    (should-error (cedit--splice-killing-backward-semi))))



(ert-deftest cedit--splice-killing-backward-semi--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit--splice-killing-backward-semi)
    (should (looking-at-p "baz, foobar;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; baz, foobar;}$")))))

(ert-deftest cedit--splice-killing-backward-semi--example-2 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 17)
    (should (looking-at-p "foobar;}$"))

    (cedit--splice-killing-backward-semi)
    (should (looking-at-p "foobar;}$"))

    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; foobar;}$")))))



(ert-deftest cedit--splice-killing-backward-brace--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar; asdf, kappa;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar; asdf, kappa;}$"))

    (cedit--splice-killing-backward-brace)
    (should (looking-at-p "bar, baz, foobar; asdf, kappa;$"))
    (should (= (point) (point-min)))))

(ert-deftest cedit--splice-killing-backward-brace--example-2 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar; asdf, kappa;}")

    (goto-char 28)
    (should (looking-at-p "f, kappa;}$"))

    (cedit--splice-killing-backward-brace)
    (should (looking-at-p "asdf, kappa;$"))
    (should (= (point) (point-min)))))



(ert-deftest cedit-splice-killing-backward--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit-splice-killing-backward)
    (should (looking-at-p "baz, foobar;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; baz, foobar;}$")))

    (cedit-splice-killing-backward)
    (should (looking-at-p "baz, foobar;$"))
    (should (= (point) (point-min)))))



(ert-deftest cedit--raise-semi--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit--raise-semi)
    (should (looking-at-p "baz;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; baz;}$")))))



(ert-deftest cedit--raise-brace--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit--raise-brace)
    (should (looking-at-p "bar, baz, foobar;$"))
    (should (= (point) (point-min)))))



(ert-deftest cedit-raise--example-1 ()
  (with-temp-buffer
    (insert "{foo; bar, baz, foobar;}")

    (goto-char 13)
    (should (looking-at-p "az, foobar;}$"))

    (cedit-raise)
    (should (looking-at-p "baz;}$"))
    (save-excursion
      (goto-char (point-min))
      (should (looking-at-p "{foo; baz;}$")))

    (cedit-raise)
    (should (looking-at-p "baz;$"))
    (should (= (point) (point-min)))))

(provide 'cedit-example-tests)
;;; cedit-example-tests.el ends here
