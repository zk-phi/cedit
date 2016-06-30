EMACS := $(shell which "$${EMACS}" 2> /dev/null || which "emacs")
EMACS_VERSION := $(shell "$(EMACS)" -Q --batch --eval '(princ emacs-version)')

EFLAGS = --eval "(when (boundp 'load-prefer-newer) (setq load-prefer-newer t))" \
-L ../elpa

BATCH = $(EMACS) $(EFLAGS) --batch -Q -L .

ELFILES := $(wildcard *.el)
ELCHECKS := $(wildcard tests/*-tests.el)

.PHONY: all compile clean check

all: compile

compile: build-$(EMACS_VERSION)/build-flag

build-$(EMACS_VERSION):
	mkdir $@

build-$(EMACS_VERSION)/%.elc: %.el $(ELFILES)
	$(BATCH) --eval "(defun byte-compile-dest-file (filename)					\
	               	       (concat (file-name-directory filename) \"build-\" emacs-version \"/\"	\
	                      	    (file-name-nondirectory filename) \"c\"))'"				\
	         -f batch-byte-compile $<								\
#	         --eval '(setq byte-compile-error-on-warn t)'						\
#	         --eval "(when (check-declare-file \"$<\") (kill-emacs 2))" \

build-$(EMACS_VERSION)/build-flag : build-$(EMACS_VERSION) $(patsubst %.el,build-$(EMACS_VERSION)/%.elc,$(ELFILES))
	touch $@

check-%: tests/%-tests.el
	$(BATCH) -l "$<" -f ert-run-tests-batch-and-exit;

check: compile $(AUTOLOADS) check-ert

check-ert: $(ELCHECKS)
	$(BATCH) -L tests $(patsubst %,-l %,$(ELCHECKS)) \
                 -f ert-run-tests-batch-and-exit
	@echo "checks passed!"

clean:
	$(RM) -r build-$(EMACS_VERSION)
