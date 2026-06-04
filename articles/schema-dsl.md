# Schema DSL

This vignette documents the JSON DSL used by `schemate`. Most users
should start with
[`schema_infer()`](https://hongyuanjia.github.io/schemate/reference/schema_infer.md)
and the edit helpers; hand-written DSL is useful for package fixtures,
configuration files, and stable schemas reviewed outside R.

## schemate JSON DSL

### Goal

This DSL is a human-centric, checkmate-first schema format for
hand-written JSON. It is designed to describe the structure of an
existing R object and to be parsed into a `schemate` `SchemaDoc` object.

This DSL is **not** a JSON Schema implementation. Its semantics are
derived from `checkmate::assert_*()` and a small set of schema
combinators.

### Minimum mental model

Most schema documents are nested combinations of a few keywords:

| DSL key | Use it for |
|----|----|
| `check` | the checkmate constraint for the current node |
| `fields` | exact field-name schemas for named containers |
| `groups` | multiple sibling fields that share the same schema |
| `patterns` | regex field-name schemas for otherwise unspecified fields |
| `positions` | position-specific schemas for unnamed lists |
| `rest` | otherwise unspecified fields or remaining unnamed-list positions |
| `$defs` / `$ref` | manually named reusable schema components |
| `all`, `any`, `one`, `not` | schema combinators |

For most workflows, start with
[`schema_infer()`](https://hongyuanjia.github.io/schemate/reference/schema_infer.md),
inspect `as.list(schema)`, then use edit verbs to add the few rules
inference cannot know.

### Common schema shapes

A scalar schema is just a `check` node:

``` json
{
  "check": { "kind": "string", "min.chars": 1 }
}
```

A named container uses `fields` for exact child names and can use `rest`
for the remaining fields:

``` json
{
  "check": { "kind": "list" },
  "keys": { "type": "named" },
  "fields": {
    "id": { "check": { "kind": "int", "lower": 1 } }
  },
  "rest": { "check": { "kind": "string" } }
}
```

An unnamed JSON-like array uses `keys.type = "unnamed"`. Use `rest` for
a homogeneous array and `positions` when the first positions have
tuple-like meaning:

``` json
{
  "check": { "kind": "list" },
  "keys": { "type": "unnamed" },
  "rest": { "check": { "kind": "string" } }
}
```

The rest of this article is a reference for the same building blocks.
The container-child sections explain `fields`, `groups`, `patterns`,
`positions`, and `rest`; the formal-rule sections explain reserved keys,
shorthand syntax, validation order, and serialization order.

### When to write DSL JSON by hand

Most users should start from
[`schema_infer()`](https://hongyuanjia.github.io/schemate/reference/schema_infer.md),
edit the result with
[`schema_add_field()`](https://hongyuanjia.github.io/schemate/reference/schema_add_field.md),
[`schema_set_desc()`](https://hongyuanjia.github.io/schemate/reference/schema_set_desc.md),
[`schema_set_keys()`](https://hongyuanjia.github.io/schemate/reference/schema_set_keys.md),
and related helpers, then save with
[`schema_write()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md).
Hand-written JSON is useful when:

- a schema is part of a package or analysis configuration;
- a non-R workflow needs to review or patch the schema text;
- you want stable schema fixtures for tests;
- you are translating an existing input contract into a compact R
  schema.

Prefer small, explicit schemas. Use `$defs` and `$ref` when the same
child schema appears repeatedly, and use `groups` when several sibling
fields share one rule.

### Helper mapping

The R helpers create the same JSON shapes documented below:

| R helper | DSL keyword |
|----|----|
| [`schema_check()`](https://hongyuanjia.github.io/schemate/reference/schema_check.md) | `check` |
| [`schema_ref()`](https://hongyuanjia.github.io/schemate/reference/schema_ref.md) | `$ref` |
| [`schema_all()`](https://hongyuanjia.github.io/schemate/reference/schema_all.md) | `all` |
| [`schema_any()`](https://hongyuanjia.github.io/schemate/reference/schema_any.md) | `any` |
| [`schema_one()`](https://hongyuanjia.github.io/schemate/reference/schema_one.md) | `one` |
| [`schema_not()`](https://hongyuanjia.github.io/schemate/reference/schema_not.md) | `not` |
| [`schema_group()`](https://hongyuanjia.github.io/schemate/reference/schema_group.md) | `groups[]` |

### Formal reference

#### Core principles

1.  Each schema node has exactly one **primary operator**.
2.  The primary operator must be one of:
    - `check`
    - `all`
    - `any`
    - `one`
    - `not`
    - `$ref`
3.  A `check` node uses `check.kind` to select a supported
    `checkmate::assert_*()` suffix.
4.  All keys inside `check` other than `kind` are passed directly to
    `assert_<kind>()`.
5.  There is no `checks` keyword in this grammar; use `all` for
    conjunction.
6.  Container kinds are:
    - `list`
    - `data_frame`
    - `data_table`
    - `tibble`
7.  `fields`, `groups`, `patterns`, `positions`, `rest`, and `keys` are
    only valid on `check` nodes whose `check.kind` is a container kind.
8.  `positions` maps 1-based positions to child schemas for unnamed
    lists.
9.  `rest` is the child schema for otherwise unspecified object fields
    or unnamed list elements.
10. `patterns` maps regular expressions to child schemas for otherwise
    unspecified object fields whose names match those patterns.
11. `groups` can batch-assign multiple field names to one shared child
    schema node.
12. A top-level schema document may optionally declare `version` as a
    non-empty string representing the document version.
13. Root-level `$defs` can store reusable schema nodes and `$ref` can
    reuse them.
14. Inside `all` / `any` / `one` / `not`, a branch may use shorthand
    check syntax without an explicit `check` wrapper.

#### Reserved schema DSL keys

The following keys are reserved by the schema DSL:

- `check`
- `all`
- `any`
- `one`
- `not`
- `fields`
- `groups`
- `patterns`
- `positions`
- `rest`
- `keys`
- `description`
- `$defs`
- `$ref`
- `version`

`$defs` and `version` are document-level keys. They are only valid on
the top-level schema document and must not appear inside nested schema
nodes or shorthand combinator branches.

Field names and field-name rules from the validated data do **not**
appear at the node top level. They appear inside:

- `fields`
- `groups[].names`
- `patterns`
- `$defs` definition names

#### Top-level schema document

A schema document contains:

- an optional `version` string
- an optional `$defs` object
- exactly one root schema node

Example:

``` json
{
  "version": "1.0.0",
  "$defs": {
    "text": { "check": { "kind": "string" } }
  },
  "description": "root alias",
  "$ref": "#/$defs/text"
}
```

`version` is document metadata only. It describes the schema document
version and does not alter node parsing or validation semantics.

For canonical serialization via
[`as.list()`](https://rdrr.io/r/base/list.html), top-level keys are
emitted in this order when present:

1.  `version`
2.  `$defs`
3.  the root schema node keys

### Container check nodes

Only the following `check.kind` values are treated as container checks:

- `list`
- `data_frame`
- `data_table`
- `tibble`

Only these container checks may carry:

- `keys`
- `fields`
- `groups`

All non-container `check.kind` values must reject these keys.

### Node forms

#### Check node

A check node has the form:

``` json
{
  "check": {
    "kind": "string",
    "pattern": "^[0-9]+$",
    "null.ok": true
  }
}
```

Rules:

- `check` must be an object.
- `check.kind` must be a non-empty string.
- `check.kind` must name a supported `checkmate::assert_*()` suffix.
- All other keys inside `check` are forwarded to `assert_<kind>()`.

Examples:

- `"string"` -\> `assert_string()`
- `"list"` -\> `assert_list()`
- `"choice"` -\> `assert_choice()`
- `"int"` -\> `assert_int()`
- `"number"` -\> `assert_number()`
- `"flag"` -\> `assert_flag()`
- `"data_frame"` -\> `assert_data_frame()`

Unknown `kind` values should be rejected during schema parsing.

#### `all`

`all` is a non-empty array of child schemas.

The node is valid only if **all** child schemas validate successfully.

Example:

``` json
{
  "all": [
    { "kind": "string" },
    { "kind": "choice", "choices": ["a", "b", "c"] }
  ]
}
```

#### `any`

`any` is a non-empty array of child schemas.

The node is valid if **at least one** child schema validates
successfully.

Example:

``` json
{
  "any": [
    { "kind": "int", "lower": 0 },
    { "kind": "string", "pattern": "^[0-9]+$" }
  ]
}
```

#### `one`

`one` is a non-empty array of child schemas.

The node is valid if **exactly one** child schema validates
successfully.

Example:

``` json
{
  "one": [
    { "kind": "flag" },
    { "kind": "choice", "choices": ["true", "false"] }
  ]
}
```

#### `not`

`not` is a single child schema.

The node is valid only if the child schema does **not** validate
successfully.

Example:

``` json
{
  "not": { "kind": "null" }
}
```

#### `$ref`

`$ref` is a local definition reference.

Rules:

- `$ref` must be a string.
- Only local references of the form `#/$defs/name` are supported.
- A `$ref` node may optionally include `description`.
- Other node-level schema keys must not appear alongside `$ref`.

Example:

``` json
{
  "$ref": "#/$defs/scalar_text",
  "description": "user-facing label"
}
```

### Shorthand check syntax inside combinators

Inside the child positions of:

- `all`
- `any`
- `one`
- `not`

the DSL allows a shorthand form for a `check` node:

``` json
{ "kind": "string", "pattern": "^[0-9]+$" }
```

This is equivalent to:

``` json
{
  "check": {
    "kind": "string",
    "pattern": "^[0-9]+$"
  }
}
```

Rules for shorthand check objects:

- They must contain `kind`.
- They may use any supported `check.kind`, including container kinds
  such as `list`, `data_frame`, `data_table`, and `tibble`.
- They must not contain any explicit primary operator keys:
  - `check`
  - `all`
  - `any`
  - `one`
  - `not`
  - `$ref`
- They must not contain any node-level adjunct keys:
  - `fields`
  - `groups`
  - `keys`
  - `description`
  - `$defs`
- They are only valid inside combinator child positions.

If a combinator branch needs node-level metadata or adjunct schema
features, write it as a full node instead of shorthand.

Allowed examples:

``` json
{ "kind": "string", "pattern": "^[0-9]+$" }
```

``` json
{ "kind": "list" }
```

``` json
{ "kind": "data_frame", "min.rows": 1 }
```

Disallowed examples:

``` json
{ "kind": "list", "keys": { "type": "unique" } }
```

``` json
{ "kind": "list", "fields": { "value": { "check": { "kind": "string" } } } }
```

``` json
{ "kind": "string", "description": "metadata is not allowed in shorthand" }
```

``` json
{ "kind": "string", "$ref": "#/$defs/text" }
```

Example:

``` json
{
  "any": [
    { "kind": "string" },
    {
      "check": { "kind": "list" },
      "fields": {
        "value": { "check": { "kind": "string" } }
      }
    }
  ]
}
```

### `$defs` and `$ref`

The DSL supports a minimal, local-reference reuse mechanism inspired by
JSON Schema.

#### `$defs`

- `$defs` is only allowed at the root schema document.
- `$defs` must be an object whose values are complete schema nodes.
- `$defs` entries do not participate in validation directly; they are
  only targets for `$ref`.

Example:

``` json
{
  "$defs": {
    "scalar_text": {
      "check": { "kind": "string" }
    }
  },
  "check": { "kind": "list" },
  "fields": {
    "name": { "$ref": "#/$defs/scalar_text" }
  },
  "rest": { "$ref": "#/$defs/scalar_text" }
}
```

#### `$ref`

- A `$ref` node is replaced by the referenced schema node during
  parsing.
- A `$ref` node may optionally include `description`, which overrides
  the target node’s description.

### `fields`

`fields` is only valid on nodes where:

- the primary operator is `check`
- `check.kind` is a container kind

`fields` must be a JSON object whose values are complete schema nodes.
The field name `"*"` has no special meaning; it is treated like any
other literal field name. Use `rest` for otherwise unspecified fields.

Example:

``` json
{
  "check": { "kind": "list" },
  "fields": {
    "field1": { "check": { "kind": "string" } },
    "field2": { "check": { "kind": "int" } }
  }
}
```

#### Pattern fields

`patterns` maps regular expressions to schema nodes. Patterns are
applied only to fields that are not already covered by `fields` or
`groups`.

Example:

``` json
{
  "check": { "kind": "list" },
  "patterns": {
    "^meta_": { "check": { "kind": "string" } },
    "_count$": { "check": { "kind": "int" } }
  }
}
```

If a field matches multiple patterns, it must satisfy every matching
schema.

#### Rest schema

`rest` is the child schema for otherwise unspecified fields.

Example:

``` json
{
  "check": { "kind": "list" },
  "rest": { "check": { "kind": "string" } }
}
```

This means that any field not covered by `fields`, `groups`, or
`patterns` must satisfy the `rest` schema.

#### Closed schema rule

If a container-check node has `fields`, `groups`, or `patterns` but no
`rest`, then the node is treated as a closed schema: unspecified fields
are not allowed.

#### Precedence rule

Container child schemas are applied in this order:

1.  exact `fields` and `groups`
2.  `patterns` for fields not covered by exact rules
3.  `rest` for fields not covered by exact or pattern rules

### `positions`

`positions` is only valid on unnamed container nodes:

- the primary operator is `check`
- `check.kind` is a container kind
- `keys.type` is `"unnamed"`

`positions` is an unnamed array of schema nodes. It follows JSON Schema
`prefixItems` semantics: a declared position is validated only when the
input actually has that position. Missing positions do not fail by
themselves; use `len`, `min.len`, or `max.len` inside the `check` rule
when length matters.

Example, similar to a CrossRef `date-parts` item:

``` json
{
  "check": { "kind": "list", "min.len": 1, "max.len": 3 },
  "keys": { "type": "unnamed" },
  "positions": [
    { "check": { "kind": "int", "lower": 0 } },
    { "check": { "kind": "int", "lower": 1, "upper": 12 } },
    { "check": { "kind": "int", "lower": 1, "upper": 31 } }
  ]
}
```

When `positions` is combined with `rest`, declared positions are
validated first and all remaining positions are validated with `rest`:

``` json
{
  "check": { "kind": "list" },
  "keys": { "type": "unnamed" },
  "positions": [
    { "check": { "kind": "string" } },
    { "check": { "kind": "int" } }
  ],
  "rest": { "check": { "kind": "number" } }
}
```

With `keys.type = "unnamed"`, `positions` and `rest` are allowed.
`fields`, `groups`, and `patterns` are named-object constraints and must
not be mixed with unnamed array semantics.

### `groups`

`groups` is an optional array available only on nodes where:

- the primary operator is `check`
- `check.kind` is a container kind

Each group item must be a named object with:

- `names`: a non-empty character vector of field names
- a complete schema node written directly beside `names`

`groups` is expanded during parsing into ordinary named fields that
behave exactly like entries written explicitly in `fields`.

Rules:

- group names must be unique within a group
- group names must not overlap across groups
- group names must not overlap with explicit `fields`
- each group item must contain exactly one primary operator in addition
  to `names`
- a group item must not wrap its target node inside an anonymous nested
  list
- a group item must not contain both `$ref` and `check` at the same
  level
- if present, `description` must be a non-empty string

If a group item provides `description`, it is copied to every expanded
field in that group and overrides the referenced node’s own description.

Valid examples:

``` json
{
  "names": ["name", "label"],
  "$ref": "#/$defs/text"
}
```

``` json
{
  "names": ["name", "label"],
  "all": [
    { "$ref": "#/$defs/text" },
    { "check": { "kind": "string" } }
  ]
}
```

Groups can also share a container schema. This is useful after
compacting API payload schemas where several fields have the same nested
structure:

``` json
{
  "names": ["issued", "created", "published-print"],
  "check": { "kind": "list" },
  "fields": {
    "date-parts": {
      "check": { "kind": "list" },
      "keys": { "type": "unnamed" },
      "rest": {
        "check": { "kind": "list" },
        "keys": { "type": "unnamed" },
        "rest": { "check": { "kind": "int" } }
      }
    }
  }
}
```

Invalid example (R-list shape):

``` r

list(
  names = c("name", "label"),
  list(`$ref` = "#/$defs/text", check = list(kind = "string"))
)
```

The invalid form above is rejected because:

- the target node is wrapped in an anonymous nested list
- the inner object contains more than one primary operator

Example:

``` json
{
  "$defs": {
    "flag_param": {
      "check": { "kind": "list" }
    }
  },
  "check": { "kind": "list" },
  "groups": [
    {
      "names": ["latest", "distrib", "replica"],
      "$ref": "#/$defs/flag_param",
      "description": "boolean control parameters"
    }
  ],
  "rest": { "$ref": "#/$defs/flag_param" }
}
```

### `keys`

`keys` is only valid on container `check` nodes.

`keys` encodes arguments for:

``` r

checkmate::check_names(names(x), ...)
```

#### Scalar form

If `keys` is a scalar value, it is shorthand for:

``` json
{ "type": "..." }
```

That scalar value is therefore interpreted as the `type` argument of
[`checkmate::check_names()`](https://mllg.github.io/checkmate/reference/checkNames.html).

Example:

``` json
{
  "check": { "kind": "list" },
  "keys": "unique"
}
```

#### Object form

If `keys` is an object:

- all keys are passed directly to
  `checkmate::check_names(names(x), ...)`
- `keys.type` is the only way to specify the name-check type

Example:

``` json
{
  "check": { "kind": "list" },
  "keys": {
    "type": "unique",
    "must.include": ["kind", "value"],
    "subset.of": ["kind", "value", "negate"]
  }
}
```

This represents:

``` r

checkmate::check_names(
  names(x),
  type = "unique",
  must.include = c("kind", "value"),
  subset.of = c("kind", "value", "negate")
)
```

### `description`

`description` is metadata only.

It does not affect validation and may be used for documentation,
debugging, or pretty-printing.

`description` may appear on any full schema node and on `$ref` nodes.

For canonical serialization via
[`as.list()`](https://rdrr.io/r/base/list.html), `description` is
emitted first inside ordinary schema nodes. At the top-level document,
`version` remains first when present, then root `description`, then
`$defs`, then the root operator keys.

### Validation order for one node

Validation depends on the node’s primary operator.

#### `check` node

Validation of a `check` node proceeds in this order:

1.  run the primary `assert_<kind>()`
2.  apply optional `keys` handling
3.  if `check.kind` is a named container, recursively validate exact
    fields, pattern fields, and rest fields
4.  if `check.kind` is an unnamed container, recursively validate
    positions, then rest positions

#### `all`

Validate each child schema in order.

- If any child fails, the `all` node fails immediately.
- If all children pass, the `all` node passes.

#### `any`

Validate child schemas until one succeeds.

- If a child succeeds, the `any` node passes immediately.
- If all children fail, the `any` node fails.

#### `one`

Validate child schemas while counting successful branches.

- If exactly one child succeeds, the `one` node passes.
- If zero children succeed, the `one` node fails.
- If more than one child succeeds, the `one` node fails.

#### `not`

Validate the child schema and invert the result.

- If the child passes, the `not` node fails.
- If the child fails, the `not` node passes.

#### `$ref`

Resolve the reference and validate against the target schema.

### Formal validation rules

When parsing the JSON DSL itself, the following should be enforced:

1.  Every node must contain exactly one primary operator from `check`,
    `all`, `any`, `one`, `not`, `$ref`.
2.  `check` must be an object when present.
3.  `check.kind` must be a non-empty string.
4.  `check.kind` must name a supported `checkmate::assert_*()` suffix.
5.  `all`, `any`, and `one` must be non-empty arrays when present.
6.  `not` must be a single schema node.
7.  Child entries of `all`, `any`, `one`, and `not` must be either:
    - a complete schema node, or
    - a shorthand check object.
8.  A shorthand check object must contain `kind`.
9.  A shorthand check object may use any supported `check.kind`.
10. A shorthand check object must not contain explicit primary operator
    keys.
11. A shorthand check object must not contain node-level adjunct keys.
12. `fields` is only allowed when the node is a `check` node and
    `check.kind` is a container kind.
13. `groups` is only allowed when the node is a `check` node and
    `check.kind` is a container kind.
14. `fields` must be an object when present.
15. `groups` must be an array when present.
16. `patterns` must be an object when present.
17. `positions` must be an unnamed array when present.
18. `positions` requires `keys.type = "unnamed"`.
19. If `keys.type = "unnamed"`, `fields`, `groups`, and `patterns` must
    not be present.
20. `keys` is only allowed on container `check` nodes.
21. `keys` must be either a scalar or an object.
22. If `keys` is an object, all of its arguments are forwarded to
    [`checkmate::check_names()`](https://mllg.github.io/checkmate/reference/checkNames.html).
23. `keys.check` is invalid.
24. Each `groups[]` item must contain `names` plus a complete schema
    node.
25. The schema node inside `groups[]` follows the same primary-operator
    and keyword rules as any other schema node.
26. `groups[]` items must not wrap the target node inside an anonymous
    nested list.
27. `version` is only allowed at the root schema document.
28. `version` must be a non-empty string when present.
29. `$defs` is only allowed at the root schema document.
30. `$defs` must be an object whose values are complete schema nodes.
31. `$ref` must be a local string reference of the form `#/$defs/name`.
32. A `$ref` target must exist in the current document’s `$defs`.
33. A `$ref` node must not contain other schema keys except
    `description`.
34. `description` must be a non-empty string when present.

### Additional examples

#### Simple scalar schema

``` json
{
  "check": {
    "kind": "string",
    "pattern": "^[0-9]+$"
  }
}
```

#### `any` with shorthand checks

``` json
{
  "any": [
    { "kind": "int", "lower": 0 },
    { "kind": "string", "pattern": "^[0-9]+$" },
    { "kind": "list" }
  ]
}
```

#### Closed list schema

``` json
{
  "check": { "kind": "list" },
  "keys": {
    "type": "unique",
    "must.include": ["field1", "field2"]
  },
  "fields": {
    "field1": { "check": { "kind": "string" } },
    "field2": { "check": { "kind": "int" } }
  }
}
```

#### Rest list schema

``` json
{
  "check": { "kind": "list" },
  "rest": { "check": { "kind": "string" } }
}
```

#### Parameter-like schema

``` json
{
  "check": { "kind": "list" },
  "keys": {
    "type": "unique",
    "subset.of": ["project", "activity_id", "experiment_id"]
  },
  "rest": {
    "check": { "kind": "list" },
    "keys": {
      "type": "unique",
      "must.include": ["kind", "value"],
      "subset.of": ["kind", "value", "negate"]
    },
    "fields": {
      "kind": {
        "check": {
          "kind": "choice",
          "choices": ["facet", "datetime_start", "datetime_stop"]
        }
      },
      "value": {
        "check": {
          "kind": "atomic",
          "any.missing": false
        }
      },
      "negate": {
        "check": {
          "kind": "flag",
          "null.ok": true
        }
      }
    }
  }
}
```

### Common mistakes

- Do not mix primary operators in one node. A node cannot contain both
  `check` and `all`, for example.
- Do not put field names directly beside `check`. Field names belong
  under `fields` or `groups`.
- Do not use JSON Schema keywords such as `type`, `properties`,
  `required`, or `additionalProperties` unless they are checkmate
  arguments inside `check` or `keys`.
- Do not expect `fields` to imply required fields. Add a `keys` rule
  such as `"must.include": ["id", "name"]` when fields must be present.
- Do not use `$defs` inside nested nodes. Definitions live at the
  document root.
