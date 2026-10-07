;;; cl-schema tests.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(defsystem "cl-schema-tests"
  :description "Test suite for cl-schema"
  :version "0.0.1.0"
  :author "Azamat S. Kalimoulline <turtle@bazon.ru>"
  :license "GPL-3.0-or-later"
  :depends-on ("cl-schema"
               "fiveam"
               "iterate")
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "schema-tests")
                             (:file "run")))))
