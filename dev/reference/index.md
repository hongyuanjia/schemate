# Package index

## Infer And Compact

- [`schema_infer()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_infer.md)
  : Infer a conservative schema from example data
- [`schema_compact()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_compact.md)
  : Compact a schema document

## Parse And JSON IO

- [`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md)
  : Parse schema documents
- [`schema_write()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md)
  [`schema_read()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md)
  : Read and write schema JSON

## Validate

Validate data directly, or flatten a schema once and reuse it for
repeated validation.

- [`schema_validate()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_validate.md)
  : Validate input against a schema
- [`schema_flatten()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_flatten.md)
  : Flatten a schema for repeated validation

## Modify Schema

Edit verbs return modified copies of schema objects. Paths use `$` for
the root node and bare field segments such as `$id` for container
fields. Backtick-quote field names that contain path operators. Use
`$fields$id` when you want the explicit field path.

### Query And Batch Edit

- [`schema_paths()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_paths.md)
  [`schema_find()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_paths.md)
  : Query schema paths and matching nodes
- [`schema_modify_where()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_modify_where.md)
  [`schema_replace_where()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_modify_where.md)
  : Modify schema nodes selected by a predicate
- [`schema_where_path()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_where_path.md)
  [`schema_where_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_where_path.md)
  : Create schema query predicates

### Edit Nodes

- [`schema_replace()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_replace.md)
  : Replace a schema node
- [`schema_set_desc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_set_desc.md)
  : Set or remove a schema node description

### Edit Fields And Groups

- [`schema_add_field()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_add_field.md)
  : Add a field schema to a container node
- [`schema_del_field()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_field.md)
  : Delete a field schema from a container node
- [`schema_add_group()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_add_group.md)
  : Add a schema group to a container node
- [`schema_del_group()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_group.md)
  : Delete a schema group from a container node

### Edit Keys, Rest, And Positions

- [`schema_set_keys()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_set_keys.md)
  : Set a schema node keys rule
- [`schema_del_keys()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_keys.md)
  : Delete a schema node keys rule
- [`schema_set_rest()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_set_rest.md)
  : Set or replace a container rest schema
- [`schema_del_rest()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_rest.md)
  : Delete a container rest schema
- [`schema_add_position()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_add_position.md)
  : Add a position schema to an unnamed container node
- [`schema_del_position()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_position.md)
  : Delete a position schema from an unnamed container node

### Edit Definitions

- [`schema_add_def()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_add_def.md)
  : Add a schema definition
- [`schema_del_def()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_del_def.md)
  : Delete a schema definition

## Author Fragments

Fragment helpers create raw schema DSL fragments that can be passed to
[`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md)
or the edit verbs. They are convenient for authoring schema documents
without hand-writing nested lists.

- [`schema_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_check.md)
  : Create a schema check fragment

- [`schema_ref()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_ref.md)
  : Create a schema reference fragment

- [`schema_group()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_group.md)
  : Create a schema group fragment

- [`schema_all()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_all.md)
  :

  Create an `all` schema combinator fragment

- [`schema_any()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_any.md)
  :

  Create an `any` schema combinator fragment

- [`schema_one()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_one.md)
  :

  Create a `one` schema combinator fragment

- [`schema_not()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_not.md)
  :

  Create a `not` schema combinator fragment
