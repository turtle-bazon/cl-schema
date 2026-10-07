# cl-schema

Declarative data schemas with validation and defaults for Common Lisp.

`cl-schema` lets you describe the shape of a value as a s-expression and
validate (and normalize) data against that description. It is intended
for config files, zone-record payloads, API payloads, and anywhere you
would otherwise write hand-rolled type and arity checks.

## Features

- Scalar types: `:any`, `:null`, `:string`, `:integer`, `:number`,
  `:boolean`, `:keyword`, `:symbol`, `:sexpr` (any atom or cons).
- Ranged integers: `(:integer min max)` — `nil` bounds are unbounded.
- Lists: `:list` (any proper list) or `(:list item-schema)`.
- Vectors: `(:vector item-schema)`.
- Tuples: `(:tuple s1 s2 ...)` — fixed-length, one schema per position.
- Cons cells: `(:cons car-schema cdr-schema)`.
- Objects: `(:object [:allow-extra t] :keys (key-spec ...))` accepts
  plists and alists with keyword keys, applies `:default`, enforces
  `:required`, and groups `:multiple` keys into a list.
- Enums: `(:one-of v1 v2 ...)` — `eql`-based membership test.
- Unions: `(:or schema ...)` — first match wins.
- Custom predicates: `(:satisfies fn description)`.
- Named registry: `define-schema` / `find-schema` so you can register
  schemas once and refer to them by keyword (may be recursive).
- Whole-file validation: `validate-file` reads a file with
  `*read-eval*` bound to NIL and validates the top-level form.
- Two return conventions: `validate` returns `(values normalized errors)`
  with `errors = nil` when valid, and `assert-valid` raises a
  `schema-error` on failure. Error strings carry a path such as
  `:CONFIG :PORT` or `:FILE "/x.sexp" :ROOT 1`.

## Setup

```lisp
;; quicklisp local project
(ql:quickload :cl-schema)

;; or ASDF
(asdf:load-system :cl-schema)
```

## Usage

```lisp
(cl-schema:valid-p :string "hello")                   ;; => T
(cl-schema:valid-p '(:integer 1 10) 5)               ;; => T
(cl-schema:valid-p '(:list :string) (list "a" "b"))  ;; => T

;; objects with required / default / multiple
(validate '(:object :keys ((:name :string :required t)
                          (:port (:integer 1 65535) :required t)
                          (:tags :string :multiple t)
                          (:ttl :integer :default 300)))
          (list :name "example.com" :port 53 :tags "a" :tags "b"))
;; => ((:NAME . "example.com") (:PORT . 53) (:TAGS . ("a" "b")) (:TTL . 300)) ; NIL

;; named registry (recursive tree)
(cl-schema:define-schema :my/tree
  '(:object :keys ((:value :integer :required t)
                   (:children (:list :my/tree)))))
(cl-schema:assert-valid :my/tree '(:value 1 :children ((:value 2)))))

;; whole s-expression files, XSD-style
(cl-schema:validate-file '(:object :keys ((:name :string :required t)))
                         "/etc/cardamines/zones/example.sexp")
```

## Running the tests

```sh
make tests-schema   # fiveam suite, 35/35 checks
make tests          # cl-schema-tests + cardamines-tests (uv + ev)
make compliance     # dig-based compliance suite
```

## Dependencies

- Common Lisp
- `iterate`
- `fiveam` (tests only)

## License

GPL-3.0-or-later. See `LICENSE`.
