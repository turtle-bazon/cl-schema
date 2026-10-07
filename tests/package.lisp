;;; cl-schema-tests package.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(in-package #:cl-user)

(defpackage :cl-schema-tests
  (:use #:cl #:fiveam #:iterate)
  (:export #:run-cl-schema-tests))

(in-package :cl-schema-tests)

(def-suite cl-schema-tests
  :description "Root suite for cl-schema tests.")
