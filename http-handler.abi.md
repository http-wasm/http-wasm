# Types

## <a href="#buf_limit" name="buf_limit"></a> `buf-limit`: `u32`

  The possibly zero maximum length of a result value to write in bytes.
  If the actual value is larger than this, nothing is written to memory.

Size: 4, Alignment: 4

## <a href="#maybe_len" name="maybe_len"></a> `maybe-len`: `u64`

  maybe-len expresses a possibly nil length in bytes. To retain signature
  compatability with WebAssembly Core Specification 1.0, two u32 values are
  represented as a single u64 in the following order:
  
  - ok: zero if the value does not exist and one if it does.
  - len: possibly zero length in bytes of the value.
  
  If the result is zero, there is no value. Otherwise, the lower 32-bits are
  `len`. For example, in WebAssembly `i32.wrap_i64` unpacks the lower 32-bits
  as would casting in most languages (ex `uint32(maybe-len)` in Go).

Size: 8, Alignment: 8

# Functions

----

#### <a href="#log" name="log"></a> `log` 

  logs a message to the host's logs.
  
  Note: A host who fails to log the message will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#log.message" name="log.message"></a> `message`: `u32`
- <a href="#log.message_len" name="log.message_len"></a> `message-len`: `u32`

----

#### <a href="#get_request_header" name="get_request_header"></a> `get-request-header` 

  writes a header value to memory if it exists and isn't larger than
  `buf-limit`. The result is `1<<32|len`, where `len` is the bytes written,
  or zero if the header doesn't exist.
  
  Note: A host who fails to get the request header will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#get_request_header.name" name="get_request_header.name"></a> `name`: `u32`
- <a href="#get_request_header.name_len" name="get_request_header.name_len"></a> `name-len`: `u32`
- <a href="#get_request_header.buf" name="get_request_header.buf"></a> `buf`: `u32`
- <a href="#get_request_header.buf_limit" name="get_request_header.buf_limit"></a> `buf-limit`: [`buf-limit`](#buf_limit)
##### Results

- [`maybe-len`](#maybe_len)

----

#### <a href="#get_path" name="get_path"></a> `get-path` 

  writes the path to memory if it exists and isn't larger than `buf-limit`.
  The result is length of the path in bytes.
  
  Note: The path does not include query parameters.
  
  Note: A host who fails to get the path will trap (aka panic, "unreachable"
  instruction).
##### Params

- <a href="#get_path.buf" name="get_path.buf"></a> `buf`: `u32`
- <a href="#get_path.buf_limit" name="get_path.buf_limit"></a> `buf-limit`: [`buf-limit`](#buf_limit)
##### Results

- `u32`

----

#### <a href="#set_path" name="set_path"></a> `set-path` 

  Overwrites the request path with one read from memory.
  
  Note: The path does not include query parameters.
  
  Note: A host who fails to set the path will trap (aka panic, "unreachable"
  instruction).
##### Params

- <a href="#set_path.path" name="set_path.path"></a> `path`: `u32`
- <a href="#set_path.path_len" name="set_path.path_len"></a> `path-len`: `u32`

----

#### <a href="#next" name="next"></a> `next` 

  calls a downstream handler and blocks until it is finished processing the
  response. This is an alternative to `send_response`.
  
  Note: A host who fails to dispatch to or invoke the next handler will trap
  (aka panic, "unreachable" instruction).

----

#### <a href="#set_response_header" name="set_response_header"></a> `set-response-header` 

  Overwrites a response header with a given name to a value read from memory.
  
  Note: A host who fails to set the response header will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#set_response_header.name" name="set_response_header.name"></a> `name`: `u32`
- <a href="#set_response_header.name_len" name="set_response_header.name_len"></a> `name-len`: `u32`
- <a href="#set_response_header.value" name="set_response_header.value"></a> `value`: `u32`
- <a href="#set_response_header.value_len" name="set_response_header.value_len"></a> `value-len`: `u32`

----

#### <a href="#send_response" name="send_response"></a> `send-response` 

  sends the HTTP response with a given status code and optional body. This is
  an alternative to dispatching to the `next` handler.
  
  Note: The "Content-Length" header is set to `body-len` when non-zero. If
  you need to set "Content-Length: 0", call `set-response-header` first.
  
  Note: A host who fails to send the response will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#send_response.status_code" name="send_response.status_code"></a> `status-code`: `u32`
- <a href="#send_response.body" name="send_response.body"></a> `body`: `u32`
- <a href="#send_response.body_len" name="send_response.body_len"></a> `body-len`: `u32`

