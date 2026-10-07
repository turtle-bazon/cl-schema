;;; cl-schema test runner.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
(in-package :cl-schema-tests)

(defun run-cl-schema-tests ()
  "Run the cl-schema suite. Returns T iff everything passed."
  (let ((ok (fiveam:run! 'cl-schema-tests)))
    (format t "~&cl-schema-tests: ~:[FAILED~;ALL PASSED~]~%" ok)
    (finish-output)
    ok))
