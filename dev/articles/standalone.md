# Standalone Use

Some packages want `schemate` functionality without taking a runtime
dependency on `schemate`. For that use case, the project publishes a
generated standalone bundle on the `standalone` branch.

## Import

Run this from the target package:

``` r

usethis::use_standalone("hongyuanjia/schemate", "schema", ref = "standalone")
```

The imported file contains the same core `schema_` API used by the
package:
[`schema_infer()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_infer.md),
the edit helpers,
[`schema_write()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md),
[`schema_read()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md),
and
[`schema_validate()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_validate.md).

The target package must still declare the standalone imports. Core
schema inference, editing, printing, and validation need `checkmate` and
`S7`.
[`schema_read()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md)
and
[`schema_write()`](https://hongyuanjia.github.io/schemate/dev/reference/schema-json.md)
use `jsonlite` at runtime, so packages that call those functions should
list `jsonlite` in `Suggests` or `Imports`.

``` r
Imports:
    checkmate (>= 2.0.0),
    S7
Suggests:
    jsonlite
```

When `jsonlite` is not installed, JSON IO fails with an installation
hint. Printing still works through a small base R fallback.

## Register S7 classes and methods

Next, create a `.onLoad()` in `zzz.R` that calls
[`S7::methods_register()`](https://rconsortium.github.io/S7/reference/methods_register.html):

``` r

.onLoad <- function(libname, pkgname) {
    S7::methods_register()
}
```

This is S7’s way of registering methods.
