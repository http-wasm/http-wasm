# HTTP handler ABI

The "http-handler" ABI defines the functions that the host makes available to
middleware. Frameworks adding support for http-handler middleware must export
the functions defined in the ABI to guest Wasm binaries for them to function.
Meanwhile, guests must minimally export memory as "memory". Further details are
described below.

## Guest exports

The http-handler guest is wasm that takes action on an incoming server request.
For example, `handle` could add a header or perform an authorization check.

### `handle`

"handle" is the entrypoint guest export called by the host when processing a
request. Its signature is nullary, with neither parameters nor results.

`handle` must dispatch to either "next" or "send_response" possibly
manipulating HTTP properties before or after. A default guest should call
"next".

Note: A guest who fails to handle the request will trap (aka panic,
"unreachable" instruction).

### `memory`

"memory" is required for string parameters as they are passed as a memory
offset and size (in bytes). It is also used for message bodies, which are
parameterized the same way.

## Host Exports

Host exports are bound to HTTP server middleware, possibly called by the guest
during `handle`. Most commonly, host functions allow the guest to read or write
HTTP message properties in a portable way, regardless of the backend server
libraries or even host language.

### `log`

```wit
/// logs a message to the host's logs.
///
/// Note: A host who fails to log the message will trap (aka panic,
/// "unreachable" instruction).
log: func(
    /// The memory offset of the UTF-8 encoded message to log.
    message: u32,
    /// The possibly zero length of the message in bytes.
    message-len: u32,
) -> ()
```

For example, if parameters are message=8, message-len=2, this function
would log the message "error".
```
	              message-len
	           +--------------+
	           |              |
	[]byte{?, 'e', 'r', 'o', 'r', ?}
     message --^
```
