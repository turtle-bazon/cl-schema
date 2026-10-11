;;; cl-schema core: s-expression schema language and validator.
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;; License GPL-3.0-or-later. See LICENSE.
;;;
;;; Schema spec:
;;;   :any :null :string :integer :number :boolean :keyword :symbol :sexpr
;;;   (:integer min max)          ; nil bound = unbounded
;;;   :list                      ; any proper list
;;;   (:list item-schema)         ; proper list of items
;;;   (:vector item-schema)       ; vector of items
;;;   (:tuple s1 s2 ...)          ; fixed-length list by position
;;;   (:cons car-schema cdr-schema) ; cons cell
;;;   (:object [:allow-extra t] :keys (key-spec ...))
;;;   (:one-of v1 v2 ...)         ; eql
;;;   (:or schema ...)            ; first match wins
;;;   (:satisfies fn description)
;;;   schema-name                 ; named schema from registry
;;;
;;; key-spec: (key schema &key :required :default :multiple)
;;; Objects accept plists or alists with keyword keys; validate returns
;;; (values normalized-alist errors).  Named schemas can be recursive.
;;;
;;; Paths are lists of segments: (:file "/x.sexp" :root 0 :car 1).
;;;
(in-package :cl-schema)

(define-condition schema-error (error)
  ((path :initarg :path :reader schema-error-path)
   (message :initarg :message :reader schema-error-message))
  (:report (lambda (condition stream)
             (format stream "schema error at ~a: ~a"
                     (schema-error-path condition)
                     (schema-error-message condition)))))

(defvar *schemas* (make-hash-table :test 'equal)
  "Named schema registry: name -> spec.")

(defun define-schema (name spec)
  "Register SPEC under NAME. Returns NAME."
  (setf (gethash name *schemas*) spec)
  name)

(defun find-schema (name)
  "Spec registered under NAME, or NIL."
  (gethash name *schemas*))

(defmacro define-accessors (prefix schema-name &key (package *package*))
  "Define PREFIX-KEY reader functions for every key of the :object
schema SCHEMA-NAME (a plain GETF each; defaults and merging stay
hand-written). The schema must exist at macroexpansion time — wrap
its DEFINE-SCHEMA in (eval-when (:compile-toplevel :load-toplevel
:execute) ...)."
  (let ((spec (find-schema schema-name)))
    (unless spec
      (error "cl-schema: unknown schema ~s (define it in eval-when)" schema-name))
    (unless (and (listp spec) (eq :object (first spec)))
      (error "cl-schema: accessors need an :object schema, got ~s" schema-name))
    `(progn
       ,@(iter (for key-spec in (getf (rest spec) :keys))
           (for key = (first key-spec))
           (for fname = (intern (format nil "~a~a" prefix (string key))
                                package))
           (collect `(defun ,fname (object)
                       ,(format nil "Reader for ~s in ~s (generated)."
                                key schema-name)
                       (getf object ,key)))))))

(defun normalize-path (path)
  "PATH as a segment list: NIL stays NIL, lists pass through,
anything else (e.g. a string) becomes a single segment."
  (cond ((null path) nil)
        ((listp path) path)
        (t (list path))))

(defun path-push (path segment)
  (append (normalize-path path) (list segment)))

(defun format-segment (segment)
  (if (symbolp segment)
      (format nil "~s" segment)
      (format nil "~a" segment)))

(defun format-path (path)
  (let ((segments (normalize-path path)))
    (if (null segments)
        "value"
        (let ((out (format-segment (first segments))))
          (iter (for segment in (rest segments))
            (setf out (concatenate 'string out " "
                                   (format-segment segment))))
          out))))

(defun fail (path expected value)
  (values nil (list (format nil "~a: expected ~a, got ~s"
                            (format-path path) expected value))))

(defun fail-many (errors)
  (values nil errors))

(defun deref (schema)
  "Resolve a named schema through the registry, else return as-is."
  (if (symbolp schema)
      (or (find-schema schema) schema)
      schema))

(defun validate (schema value &optional (path nil))
  "Validate VALUE against SCHEMA. Returns (values normalized errors);
errors is NIL when valid. Normalized applies :defaults and groups
:multiple keys. PATH is a segment list, or a plain string."
  (setf schema (deref schema))
  (setf path (normalize-path path))
  (cond
    ((eq schema :any) (values value nil))
    ((eq schema :null)
     (if (null value) (values value nil) (fail path "null" value)))
    ((eq schema :string)
     (if (stringp value) (values value nil) (fail path "a string" value)))
    ((eq schema :integer)
     (if (integerp value) (values value nil) (fail path "an integer" value)))
    ((eq schema :number)
     (if (numberp value) (values value nil) (fail path "a number" value)))
    ((eq schema :boolean)
     (if (or (eq value t) (null value))
         (values value nil)
         (fail path "a boolean" value)))
    ((eq schema :keyword)
     (if (keywordp value) (values value nil) (fail path "a keyword" value)))
    ((eq schema :symbol)
     (if (symbolp value) (values value nil) (fail path "a symbol" value)))
    ((eq schema :sexpr)
     (if (or (atom value) (consp value)) (values value nil)
         (fail path "an s-expression" value)))
    ((eq schema :list)
     (if (listp value)
         (values value nil)
         (fail path "a list" value)))
    ((and (consp schema) (eq (first schema) :integer))
     (validate-range (second schema) (third schema) value path))
    ((and (consp schema) (eq (first schema) :list))
     (validate-list (second schema) value path))
    ((and (consp schema) (eq (first schema) :vector))
     (validate-vector (second schema) value path))
    ((and (consp schema) (eq (first schema) :tuple))
     (validate-tuple (rest schema) value path))
    ((and (consp schema) (eq (first schema) :cons))
     (validate-cons (second schema) (third schema) value path))
    ((and (consp schema) (eq (first schema) :object))
     (validate-object schema value path))
    ((and (consp schema) (eq (first schema) :one-of))
     (validate-enum (rest schema) value path))
    ((and (consp schema) (eq (first schema) :or))
     (validate-union (rest schema) value path))
    ((and (consp schema) (eq (first schema) :satisfies))
     (destructuring-bind (fn description) (rest schema)
       (if (funcall fn value)
           (values value nil)
           (fail path description value))))
    (t (error "cl-schema: bad schema ~s" schema))))

(defun validate-range (lo hi value path)
  (if (and (integerp value)
           (or (null lo) (>= value lo))
           (or (null hi) (<= value hi)))
      (values value nil)
      (fail path (format nil "an integer ~a..~a" (or lo "*") (or hi "*"))
            value)))

(defun validate-list (item-schema value path)
  (unless (listp value)
    (return-from validate-list (fail path "a list" value)))
  (let ((out nil) (errors nil) (index 0))
    (iter (for item in value)
      (multiple-value-bind (normal item-errors)
          (validate item-schema item (path-push path index))
        (if item-errors
            (setf errors (append errors item-errors))
            (push normal out)))
      (incf index))
    (if errors
        (fail-many errors)
        (values (nreverse out) nil))))

(defun validate-vector (item-schema value path)
  (unless (vectorp value)
    (return-from validate-vector (fail path "a vector" value)))
  (multiple-value-bind (items errors)
      (validate-list item-schema (coerce value 'list) path)
    (if errors
        (fail-many errors)
        (values (coerce items 'vector) nil))))

(defun validate-tuple (schemas value path)
  (unless (listp value)
    (return-from validate-tuple (fail path "a tuple (proper list)" value)))
  (unless (= (length schemas) (length value))
    (return-from validate-tuple
      (fail path (format nil "a tuple of ~d elements" (length schemas))
            value)))
  (labels ((walk (rest-schemas rest-values index out errors)
             (if (null rest-schemas)
                 (if errors
                     (fail-many errors)
                     (values (nreverse out) nil))
                 (multiple-value-bind (normal item-errors)
                     (validate (first rest-schemas) (first rest-values)
                               (path-push path index))
                   (if item-errors
                       (walk (rest rest-schemas) (rest rest-values) (1+ index)
                             out (append errors item-errors))
                       (walk (rest rest-schemas) (rest rest-values) (1+ index)
                             (cons normal out) errors))))))
    (walk schemas value 0 nil nil)))

(defun validate-cons (car-schema cdr-schema value path)
  (unless (consp value)
    (return-from validate-cons (fail path "a cons cell" value)))
  (multiple-value-bind (car-normal car-errors)
      (validate car-schema (car value) (path-push path :car))
    (if car-errors
        (fail-many car-errors)
        (multiple-value-bind (cdr-normal cdr-errors)
            (validate cdr-schema (cdr value) (path-push path :cdr))
          (if cdr-errors
              (fail-many cdr-errors)
              (values (cons car-normal cdr-normal) nil))))))

(defun plist-p (value)
  (and (listp value)
       (evenp (length value))
       (iter (for (key ignored) on value by #'cddr)
         (declare (ignore ignored))
         (always (keywordp key)))))

(defun alist-p (value)
  (and (listp value)
       (iter (for pair in value)
         (always (and (consp pair) (keywordp (car pair)))))))

(defun object-alist (value)
  "VALUE as an alist, or (values nil nil) when it is no object."
  (cond ((plist-p value)
         (let ((out nil))
           (iter (for (key item) on value by #'cddr)
             (push (cons key item) out))
           (values (nreverse out) t)))
        ((alist-p value) (values value t))
        (t (values nil nil))))

(defun validate-key (spec pairs path)
  "Validate one key-spec against PAIRS. Returns (values entry errors)
where entry is nil, one (key . value), or one (key . values) pair."
  (let* ((key (first spec))
         (subschema (deref (second spec)))
         (opts (cddr spec))
         (required (getf opts :required))
         (has-default (member :default opts))
         (multiple (getf opts :multiple))
         (hits (iter (for pair in pairs)
                 (when (eq (car pair) key) (collect pair)))))
    (cond ((null hits)
           (cond (required
                  (values nil (list (format nil "~a: misses ~s"
                                            (format-path path) key))))
                 (has-default
                  (values (list (cons key (getf opts :default))) nil))
                 (t (values nil nil))))
          (multiple
           (validate-many subschema hits path key))
          ((rest hits)
           (values nil (list (format nil "~a: duplicate ~s"
                                     (format-path path) key))))
          (t (multiple-value-bind (normal errors)
                 (validate subschema (cdr (first hits))
                           (path-push path key))
               (if errors
                   (values nil errors)
                   (values (list (cons key normal)) nil)))))))

(defun validate-many (subschema hits path key)
  (let ((out nil) (errors nil))
    (iter (for pair in hits)
      (multiple-value-bind (normal item-errors)
          (validate subschema (cdr pair) (path-push path key))
        (if item-errors
            (setf errors (append errors item-errors))
            (push normal out))))
    (if errors
        (fail-many errors)
        (values (list (cons key (nreverse out))) nil))))

(defun validate-object (schema value path)
  (multiple-value-bind (pairs ok) (object-alist value)
    (unless ok
      (return-from validate-object
        (fail path "an object (plist or alist)" value)))
    (let ((specs (getf (rest schema) :keys))
          (allow-extra (getf (rest schema) :allow-extra))
          (out nil) (errors nil) (known nil))
      (iter (for spec in specs)
        (push (first spec) known)
        (multiple-value-bind (entry entry-errors)
            (validate-key spec pairs path)
          (setf errors (append errors entry-errors))
          (setf out (append out entry))))
      (unless allow-extra
        (iter (for pair in pairs)
          (unless (member (car pair) known)
            (push (format nil "~a: unknown key ~s"
                          (format-path path) (car pair))
                  errors))))
      (if errors
          (fail-many (nreverse errors))
          (values out nil)))))

(defun validate-enum (choices value path)
  (if (iter (for c in choices) (thereis (eql c value)))
      (values value nil)
      (fail path (format nil "one of ~s" choices) value)))

(defun validate-union (schemas value path)
  (iter (for subschema in schemas)
    (multiple-value-bind (normal errors)
        (validate subschema value path)
      (when (null errors)
        (return-from validate-union (values normal nil)))))
  (fail path "any of the union members" value))

(defun valid-p (schema value)
  "True when VALUE satisfies SCHEMA."
  (null (nth-value 1 (validate schema value nil))))

(defun assert-valid (schema value &optional (path "value"))
  "Normalized VALUE, or signal a schema-error."
  (multiple-value-bind (normal errors)
      (validate schema value (list path))
    (if errors
        (error 'schema-error :path (format-path (list path))
                             :message (format nil "~{~a~^; ~}" errors))
        normal)))

(defun list-schemas ()
  "Sorted schema names in the registry."
  (let ((out nil))
    (maphash (lambda (k v) (declare (ignore v)) (push k out))
             *schemas*)
    (sort out (function string<) :key (function string))))

(defun dump-schemas (path)
  "Write the registry to PATH as readable data: a plist of
\(:schema NAME SPEC) entries. External generators consume this
instead of parsing Lisp source; specs are quoted data, except
:satisfies predicates, which dump as opaque symbols."
  (with-open-file (s path :direction :output :if-exists :supersede)
    (iter (for name in (list-schemas))
      (write (list :schema name (find-schema name)) :stream s)
      (terpri s)))
  path)

(defun validate-file (schema file)
  "Read FILE with *READ-EVAL* NIL and validate the top-level form
against SCHEMA. Returns (values normalized errors)."
  (unless (probe-file file)
    (return-from validate-file
      (values nil (list (format nil "file not found: ~a" file)))))
  (let ((*read-eval* nil)
        (stream (open file :direction :input)))
    (unwind-protect
         (handler-case
             (let ((form (read stream)))
               (validate schema form (list :file file :root)))
           (end-of-file ()
             (values nil (list (format nil "~a: empty or truncated" file)))))
      (when stream (close stream)))))
