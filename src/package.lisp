;;; cl-schema package.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(defpackage :cl-schema
  (:use :cl :iterate)
  (:export #:define-schema
           #:find-schema
           #:validate
           #:valid-p
           #:assert-valid
           #:validate-file
           #:schema-error
           #:schema-error-path
           #:schema-error-message))
