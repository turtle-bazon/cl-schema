;;; cl-schema package.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(defpackage :cl-schema
  (:use :cl :iterate)
  (:export #:define-schema
           #:define-accessors
           #:list-schemas
           #:dump-schemas
           #:find-schema
           #:validate
           #:valid-p
           #:assert-valid
           #:validate-file
           #:schema-error
           #:schema-error-path
           #:schema-error-message))
