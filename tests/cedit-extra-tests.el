;;; cedit-extra-tests.el --- test buffers in documentation with other
;;; cases

;;; Commentary:

;;; Code:
(require 'ert)
(require 'cedit)

(ert-deftest cedit--search-char-forward--extra-1 ()
  (with-temp-buffer
    (insert "foo; (bar;) foobar;")

    (goto-char (point-min))

    (cedit--search-char-forward ?f)
    (should (looking-at-p "oo; (bar;) foobar;$"))

    (cedit--search-char-forward ?f)
    (should (looking-at-p "oobar;$"))))


(provide 'cedit-extra-tests)
;;; cedit-extra-tests.el ends here
