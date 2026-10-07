LISP ?= sbcl
QUICKLISP_SETUP ?= $(HOME)/quicklisp/setup.lisp
CURDIR := $(dir $(lastword $(MAKEFILE_LIST)))

.PHONY: tests

tests:
	@$(LISP) --noinform --non-interactive \
	    --load $(QUICKLISP_SETUP) \
	    --eval '(push #p"$(CURDIR)" asdf:*central-registry*)' \
	    --eval '(ql:register-local-projects)' \
	    --eval '(ql:quickload :cl-schema-tests :silent t)' \
	    --eval '(unless (cl-schema-tests:run-cl-schema-tests) (uiop:quit 1))'
