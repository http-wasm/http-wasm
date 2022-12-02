+++
title = "Notable rationale for http-wasm"
layout = "single"
+++

## Why is this not defined in the WebAssembly Component Model?

A concrete ABI must be defined in a way that doesn't break signatures or
constant value mappings (such as flags or enums). The most precise way to
define host and guest ABI is in WebAssembly itself. For example,
[WebAssembly Text Format][1] (`%.wat`). However, this format was not defined
as an IDL. `%.wat` not only defines interfaces (imports and exports), but
also implementations (function definitions, etc.).

It seems that [WebAssembly Component Model][2] (`%.wit.md`) is a better choice,
as it includes a [wit-bindgen][3] code generator. However, it cannot be relied
on for ABI compatability.

There are problems with the current draft of the WebAssembly Component Model
which makes it unusable as a concrete ABI specification format. Here are some
of them:

* Component Model is not yet a standard is in flux. The same is true for
  `wit-bindgen`. This can result in different signatures, which can result in
  guests having incompatible signatures. For example, `wit-bindgen` changed
  their representation of [64-bit flags][4] from i64 to a pair of i32s. This
  would render guests incompatible and complicate signatures that pass flags.

* Component model has a [Canonical Encoding for strings][5], but it isn't the
  way most compilers work. For example, it has three encoding hints, where most
  compilers use a simple bytestring (offset/len pair) and defer any UTF-8 or
  otherwise decoding in standard library code. There are also objections in the
  community on how strings are treated, notably [AssemblyScript][6]. To allow
  the existing ecosystem to function, we cannot use component model's canonical
  string encoding.

* Component Model is inflexible in ways that matter. For example, most wasm
  functions are defined as lower_snake_case, but Component Model requires them
  as lower-hyphen case. This has knock-on problems including many languages
  don't support the hyphen character in function definitions. Concretely, this
  leads to functions exported like "log-enabled", but defined like
  "log_enabled." Other inflexibility involve constants, particularly enums. If
  you run code generators, you'll notice conventionally zero is chosen for the
  first enum. However, this is not due to spec as defining it was considered
  [out-of-scope][7]: the task of the "concrete ABI". Take for example,
  `body_kind`. If a guest suddenly starts using 1 instead of zero, they will be
  affecting the response instead of the request! These opinions may change over
  time, but as of late 2022, these make the format nearly unusable for brown
  field work.

## Why is everything lower_snake_case instead of lower-hyphen-case?

Module, function and parameter names are defined in lower_snake_case instead
of lower-hyphen-case to follow de facto practice and make the ABI less work to
implement.

For example, the most commonly imported host module name is
"wasi_snapshot_preview1". Even modules which are single-word tend to use
lower_snake_case more often than other case formats. For example,
[proxy-wasm][8] uses "env" as the module name, and lower_snake_case for
functions, such as "proxy_log".

There are other benefits to doing this. For example, a hyphen is not a valid
character for function names in many languages, and compilers like rust default
to the function name as the wasm function name. Using lower_snake_case is less
work for programmers as they can follow conventions as opposed to needing
overriding annotations. Moreover, observability benefits by a consistent case
format, as it allows lookup keys to work the same way regardless of language.

These things said, lower_snake_case is not universally adopted. For example,
[AssemblyScript special imports][9] define parameter names in lowerCamelCase.
That said its function names are single words like "trace" so have no case
format problems. The emerging [wasi-filesytem][10] currently defines both
module and function names in lower-hyphen-case. However, this isn't implemented
and could change later. As of mid-2022, [wit-bindgen][3] takes the file name as
the module name and retains function names in the case format they are declared
in. Parameters names are inconsistently mapped, preferring the case format of
the language.

## Why are the query parameters URI encoded?

Query parameters can contain characters that act as values or as delimiters in the syntax (see <https://datatracker.ietf.org/doc/html/rfc3986#section-2.2>). A query string like `?name=chip&dale` can represent two things depending if it was encoded or not:

* encoded: `name` equals `chip` and `dale` is empty.
* raw: `name` equals `chip&dale`

To remove this ambiguity we require guest to pass the URI encoded to the host as the host
has no deterministic means to determine whether a URI is encoded or not. For example, if guest passes `chip&dale` as `name` the URI will be `/disney?name=chip%26dale` whereas if it is the case where `name` is `chip` and an additional query parameter called `dale` as empty the URI would be `/disney?name=chip&dale`. Requiring the guest to encode the URI MAY involve an overhead in the size of the binary.

## Logging

### Levels

The log level ordinals are in order where the lower the number the more detail
is logged. These levels are a subset of the popular [zap][11] library's levels.

The most voluminous level, DEBUG is -1 to prevent users from accidentally
defaulting to it. This is the same rationale as zap who uses the same ordinal.

### Why expose `log_enabled`

Logging is expensive in WebAssembly as it often implies garbage collection
which cannot be offloaded to a separate thread. Exposing `log_enabled` allows
handlers to avoid overhead when processing a request.

## Features

### Why limit to i32 (32 flags)?

WebAssembly Core Specification 1.0 supports i64, but we only use i32 to
represent features flags. As we reserve zero to indicate no features, this
allows up to 30 feature flags. Unlike WebAssembly's feature proposals which can
easily get into dozens, we don't expect that many feature flags for the
http-wasm host. Notably, the initial version only uses three.

[1]: https://www.w3.org/TR/wasm-core-1/#text-format%E2%91%A0
[2]: https://github.com/WebAssembly/component-model
[3]: https://github.com/bytecodealliance/wit-bindgen
[4]: https://github.com/bytecodealliance/wit-bindgen/pull/209
[5]: https://github.com/WebAssembly/component-model/blob/main/design/mvp/CanonicalABI.md
[6]: https://www.assemblyscript.org/standards-objections.html
[7]: https://github.com/WebAssembly/component-model/issues/119
[8]: https://github.com/proxy-wasm/spec
[9]: https://www.assemblyscript.org/concepts.html#special-imports
[10]: https://github.com/WebAssembly/wasi-filesystem
[11]: https://github.com/uber-go/zap
