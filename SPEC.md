# HTTP-WASM ABI specification

> warning: This is unstable for now and can be changed in practice.

## Functions implemented in the Wasm module

### `_start`

- params:
  - none
- returns:
  - none

Start function which is called when the module is loaded and initialized. This can be used by SDKs to setup and/or initialize state, but no proxy_ functions can be used at that point yet.

### `proxy_on_request`

- params:
  - `i32 (uint32_t) context_id`
  - `i32 (size_t) num_headers`
  - `i32 (size_t) body_size`
- returns:
  - `i32 (proxy_action_t) next_action`

Called when HTTP request is received from the client. Headers can be retrieved using `proxy_get_header` and/or `proxy_get_header_value`.Request body can be retrieved using `proxy_get_body`. The return vaule `next_action` currently have one valid value `ActionContinue` means that the host continues the processing.

### `proxy_on_response`

- params:
  - `i32 (uint32_t) context_id`
  - `i32 (size_t) num_headers`
  - `i32 (size_t) body_size`
- returns:
  - `i32 (proxy_action_t) next_action`

Called when HTTP response is received from the upstream. Headers can be retrieved using `proxy_get_header` and/or `proxy_get_header_value`. Response body can be retrieved using `proxy_get_body`.



## Functions implemented in the host environment

All functions implemented in the host environment return `proxy_result_t`, which indicates the status of the call (successful, invalid memory access, etc.), and the return values are written into memory pointers passed in as arguments (indicated by the `return_` prefix in the specification).

## Logging

### `proxy_log`

- params:
  - `i32 (proxy_log_level_t) log_level`
  - `i32 (const char*) message_data`
  - `i32 (size_t) message_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Log message (`message_data`, `message_size`) at the given `log_level`.

## Requests and response

### `proxy_get_body`

- params:
  - `i32 (proxy_buffer_type_t) buffer_type`
  - `i32 (offset_t) offset`
  - `i32 (size_t) max_size`
  - `i32 (const char**) return_buffer_data`
  - `i32 (size_t*) return_buffer_size`
  - `i32 (uint32_t*) return_flags`
- returns:
  - `i32 (proxy_result_t) call_result`

Get up to max_size bytes from the `buffer_type`(enum for request and response), starting from `offset`. Bytes are written into buffer slice (`return_buffer_data`, `return_buffer_size`), and buffer flags are written into `return_flags`.

### `proxy_set_body`

- params:
  - `i32 (proxy_buffer_type_t) buffer_type`
  - `i32 (offset_t) offset`
  - `i32 (size_t) size`
  - `i32 (const char*) buffer_data`
  - `i32 (size_t) buffer_size`
  - `i32 (uint32_t) flags`
- returns:
  - `i32 (proxy_result_t) call_result`

Set content of the buffer `buffer_type` to the bytes (`buffer_data`, `buffer_size`), replacing `size` bytes, starting at `offset` in the existing buffer.

### `proxy_get_header`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char**) return_map_data`
  - `i32 (size_t*) return_map_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Get all key-value pairs from a given map with `map_type`(enum for request and response).

### `proxy_set_header`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char*) map_data`
  - `i32 (size_t) map_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Set all key-value pairs in a given map (`map_type`).

### `proxy_get_header_value`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char*) key_data`
  - `i32 (size_t) key_size`
  - `i32 (const char**) return_value_data`
  - `i32 (size_t*) return_value_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Get content of key (`key_data`, `key_size`) from a given map (`map_type`).

### `proxy_set_header_value`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char*) key_data`
  - `i32 (size_t) key_size`
  - `i32 (const char*) value_data`
  - `i32 (size_t) value_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Set or replace the content of key (`key_data`, `key_size`) to the value (`value_data`, `value_size`) in a given map (`map_type`).

### `proxy_add_header_value`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char*) key_data`
  - `i32 (size_t) key_size`
  - `i32 (const char*) value_data`
  - `i32 (size_t) value_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Add key (`key_data`, `key_size`) with the value (`value_data`, `value_size`) to a given map (`map_type`).

### `proxy_remove_header_value`

- params:
  - `i32 (proxy_map_type_t) map_type`
  - `i32 (const char*) key_data`
  - `i32 (size_t) key_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Remove key (`key_data`, `key_size`) from a given map (`map_type`).

### `proxy_send_http_response`

- params:
  - `i32 (uint32_t) response_code`
  - `i32 (const char*) response_code_details_data`
  - `i32 (size_t) response_code_details_size`
  - `i32 (const char*) response_body_data`
  - `i32 (size_t) response_body_size`
  - `i32 (const char*) additional_headers_map_data`
  - `i32 (size_t) additional_headers_size`
- returns:
  - `i32 (proxy_result_t) call_result`

Sends HTTP response without forwarding request to the upstream.