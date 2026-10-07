;;; cl-schema -- declarative data schemas with validation.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
;;; Standalone library (lives in internal-libs until extracted).
;;; Depends only on iterate.
;;;
(defsystem "cl-schema"
  :description "Declarative data schemas with validation and defaults"
  :version "0.0.1.0"
  :author "Azamat S. Kalimoulline <turtle@bazon.ru>"
  :license "GPL-3.0-or-later"
  :depends-on ("iterate")
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "schema")))))
