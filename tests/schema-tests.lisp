;;; cl-schema core tests.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(in-package :cl-schema-tests)

(def-suite schema-tests :in cl-schema-tests)
(in-suite schema-tests)

(test scalars
  (is (cl-schema:valid-p :string "x"))
  (is (not (cl-schema:valid-p :string 1)))
  (is (cl-schema:valid-p :integer 7))
  (is (cl-schema:valid-p '(:integer 1 10) 5))
  (is (not (cl-schema:valid-p '(:integer 1 10) 11)))
  (is (cl-schema:valid-p '(:integer 1 nil) 999999))
  (is (cl-schema:valid-p :boolean t))
  (is (cl-schema:valid-p :boolean nil))
  (is (not (cl-schema:valid-p :boolean 1)))
  (is (cl-schema:valid-p :sexpr (list 1 "x")))
  (is (cl-schema:valid-p :sexpr 42))
  (is (cl-schema:valid-p :sexpr nil))
  (is (cl-schema:valid-p :keyword :foo))
  (is (cl-schema:valid-p :symbol 'foo)))

(test lists-and-vectors
  (is (cl-schema:valid-p '(:list :string) (list "a" "b")))
  (is (not (cl-schema:valid-p '(:list :string) (list "a" 1))))
  (is (not (cl-schema:valid-p '(:list :string) "nope")))
  (is (cl-schema:valid-p '(:vector :string) #("a" "b")))
  (is (not (cl-schema:valid-p '(:vector :string) #("a" 1)))))

(test tuples
  (is (cl-schema:valid-p '(:tuple :string :integer) (list "a" 1)))
  (is (not (cl-schema:valid-p '(:tuple :string :integer) (list 1 "a"))))
  (is (not (cl-schema:valid-p '(:tuple :string :integer) (list "a"))))
  (is (not (cl-schema:valid-p '(:tuple :string :integer) (list "a" 1 2)))))

(test cons-cells
  (is (cl-schema:valid-p '(:cons :string :integer) (cons "a" 1)))
  (is (not (cl-schema:valid-p '(:cons :string :integer) (cons 1 "a"))))
  (is (not (cl-schema:valid-p '(:cons :string :integer) (list "a" 1)))))

(test enums-and-unions
  (is (cl-schema:valid-p '(:one-of :a :b) :a))
  (is (not (cl-schema:valid-p '(:one-of :a :b) :c)))
  (is (cl-schema:valid-p '(:or :null :string) nil))
  (is (cl-schema:valid-p '(:or :null :string) "x"))
  (is (not (cl-schema:valid-p '(:or :null :string) 3))))

(test objects-plist-and-alist
  (let ((schema '(:object :keys ((:name :string :required t)
                                 (:port (:integer 1 65535))))))
    (is (cl-schema:valid-p schema (list :name "h" :port 53)))
    (is (cl-schema:valid-p schema (list (cons :name "h"))))
    (is (not (cl-schema:valid-p schema (list :port 53))))
    (is (not (cl-schema:valid-p schema (list :name "h" :port 0))))
    (is (not (cl-schema:valid-p schema (list :name "h" :zzz 1))))
    (is (not (cl-schema:valid-p schema "nope")))))

(test defaults-and-multiple
  (let ((schema '(:object :keys ((:ttl :integer :default 300)
                                 (:text :string :multiple t)))))
    (multiple-value-bind (normal errors)
        (cl-schema:validate schema (list (cons :text "a") (cons :text "b")))
      (is (null errors))
      (is (= 300 (cdr (assoc :ttl normal))))
      (is (equal (list "a" "b") (cdr (assoc :text normal))))))
  (let ((schema '(:object :keys ((:a :string :required t)))))
    (multiple-value-bind (normal errors)
        (cl-schema:validate schema nil)
      (declare (ignore normal))
      (is (= 1 (length errors))))))

(test satisfies-and-registry
  (cl-schema:define-schema :test/even
    '(:satisfies evenp "an even number"))
  (is (eq '(:satisfies evenp "an even number")
           (cl-schema:find-schema :test/even)))
  (is (cl-schema:valid-p (cl-schema:find-schema :test/even) 4))
  (is (not (cl-schema:valid-p (cl-schema:find-schema :test/even) 5)))
  (signals cl-schema:schema-error
    (cl-schema:assert-valid :string 42)))

(test recursive-schema
  (cl-schema:define-schema :test/tree
    '(:object :keys ((:value :integer :required t)
                     (:children (:list :test/tree)))))
  (is (cl-schema:valid-p
       :test/tree
       (list :value 1
             :children (list (list :value 2 :children nil)
                             (list :value 3 :children nil)))))
  (is (not (cl-schema:valid-p
            :test/tree
            (list :value "x" :children nil)))))

(test error-paths
  (multiple-value-bind (normal errors)
      (cl-schema:validate
       '(:object :keys ((:port (:integer 1 100) :required t)))
       (list :port 101) (list :config))
    (declare (ignore normal))
    (is (= 1 (length errors)))
    (is (search ":CONFIG" (first errors)))
    (is (search ":PORT" (first errors))))
  (multiple-value-bind (normal errors)
      (cl-schema:validate
       '(:tuple :string :integer)
       (list "a" "b") nil)
    (declare (ignore normal))
    (is (= 1 (length errors)))
    (is (search "1" (first errors)))))

(test validate-file
  (let ((tmp #p"/tmp/cl-schema-test.sexp"))
    (unwind-protect
         (progn
           (with-open-file (s tmp :direction :output
                                  :if-exists :supersede)
             (write '((:name . "example") (:port . 53)) :stream s))
           (multiple-value-bind (normal errors)
               (cl-schema:validate-file
                '(:object :allow-extra t
                  :keys ((:name :string) (:port :integer)))
                tmp)
             (is (null errors))
             (is (string= "example" (cdr (assoc :name normal)))))
           (multiple-value-bind (normal errors)
               (cl-schema:validate-file
                '(:object :allow-extra t
                  :keys ((:name :string) (:port :integer)))
                "/nonexistent/cl-schema-test.sexp")
             (declare (ignore normal))
             (is (= 1 (length errors)))))
      (ignore-errors (delete-file tmp)))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (cl-schema:define-schema :test-accessors
    '(:object :keys ((:host :string) (:port :integer)))))

(cl-schema:define-accessors test-acc- :test-accessors)

(test define-accessors
  (is (string= "example.com" (test-acc-host '(:host "example.com"))))
  (is (= 53 (test-acc-port '(:host "example.com" :port 53))))
  (is (null (test-acc-port '(:host "example.com")))))

(test dump-schemas-roundtrip
  (let ((tmp #p"/tmp/cl-schema-dump.sexp"))
    (unwind-protect
         (progn
           (cl-schema:dump-schemas tmp)
           (let ((names nil))
             (with-open-file (s tmp :direction :input)
               (iter (for form = (read s nil nil))
                 (while form)
                 (when (and (listp form) (eq :schema (first form)))
                   (push (second form) names))))
             (is (member :test-accessors names))))
      (ignore-errors (delete-file tmp)))))
