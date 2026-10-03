# CBLPolyCall - COBOL binding for Polycall

CBLPolyCall connects GnuCOBOL programs to the
[Polycall](https://github.com/obinexus/polycall) core (**polycall >= 1.1.0**,
binding ABI v1), as part of the OBINexus Aegis Engineering project under the
technical leadership of Nnamdi Michael Okpala.

Everything goes through the core's binding ABI (`<polycall.h>`,
`docs/BINDING_ABI.md` in the core repository). This repository adds no
protocol, parser or network code of its own.

## Layers

| Layer | File | Role |
| --- | --- | --- |
| C shim | `src/cobpolycall.c`, `src/cobpolycall.h` | `cobpc_*` functions with COBOL-friendly signatures over the real ABI |
| Copybooks | `copybooks/POLYCALL-CONSTANTS.CPY`, `copybooks/POLYCALL-STRUCTURES.CPY` | status codes (`PC-OK`, `PC-E-TIMEOUT`, ...) and the shim's work fields |
| Bridge | `src/POLYCALL.CBL` (`POLYCALL-BRIDGE`) | operation-level API used by the client |
| Client | `src/MAIN.CBL` (`CBLPOLYCALL-MAIN`) | interactive / scripted client |

### Shim conventions (`cobpc_*`)

GnuCOBOL passes `BY REFERENCE` arguments as bare pointers, so the shim fixes
the field sizes and adapts COBOL text fields:

- Text fields have the sizes in `POLYCALL-STRUCTURES.CPY`: ids `PIC X(64)`,
  endpoints and tokens `PIC X(128)`, paths `PIC X(512)`. Input ends at the
  trailing spaces; output is space padded. A blank bind endpoint opens a
  send-only node; a blank token means no authentication; a blank message id
  lets the core generate one.
- Byte data (payloads, JSON) is a field of the caller's size plus an explicit
  `BINARY-LONG` length (input) or capacity + returned length (output). It is
  binary-safe (`X"00"` and any other byte), never trimmed or padded.
- Every integer is `BINARY-LONG` passed by reference; a timeout of `-1`
  (`PC-WAIT-FOREVER`) waits indefinitely.
- The last argument of every call receives the core status unchanged
  (`PC-OK` = 0 or a negative `PC-E-*`); it is also the `RETURN-CODE`.
  `cobpc_strerror` and `cobpc_last_error` give the status name and the
  detail of the failing call.

```cobol
       COPY "POLYCALL-CONSTANTS.CPY".
       COPY "POLYCALL-STRUCTURES.CPY".
       ...
           MOVE "cobol-polycallrc" TO PC-CONFIG-PATH
           MOVE 1 TO PC-RUN
           CALL "cobpc_run_config" USING PC-CONFIG-PATH PC-RUN PC-STATUS
           IF PC-STATUS NOT = PC-OK
               CALL "cobpc_strerror" USING PC-STATUS PC-STATUS-NAME
               CALL "cobpc_last_error" USING PC-DETAIL
           END-IF

           MOVE "alpha" TO PC-NODE-ID
           MOVE "127.0.0.1:0" TO PC-BIND-ENDPOINT
           MOVE SPACES TO PC-AUTH-TOKEN
           CALL "cobpc_peer_open" USING PC-NODE-ID PC-BIND-ENDPOINT
                                        PC-AUTH-TOKEN PC-HANDLE PC-STATUS
           CALL "cobpc_peer_send" USING PC-HANDLE PC-TARGET WS-PAYLOAD
                                        WS-PAYLOAD-LEN PC-MESSAGE-ID
                                        PC-TIMEOUT-MS PC-STATUS
```

Functions: `cobpc_abi_version`, `cobpc_version`, `cobpc_strerror`,
`cobpc_last_error`, `cobpc_run_config` (run 1 = strict, 0 = validate),
`cobpc_describe`, `cobpc_call`, `cobpc_peer_open`, `cobpc_peer_close`,
`cobpc_peer_endpoint`, `cobpc_peer_node_id`, `cobpc_peer_register`,
`cobpc_peer_unregister`, `cobpc_peer_list`, `cobpc_peer_ping`,
`cobpc_peer_send`, `cobpc_peer_recv`, `cobpc_peer_cancel`,
`cobpc_peer_health` -- see `src/cobpolycall.h`.

### Bridge operations (`POLYCALL-BRIDGE`)

`CALL "POLYCALL-BRIDGE" USING operation PIC X(20), input PIC X(1024),
output PIC X(1024), result BINARY-LONG`:

| Operation | Input | Output |
| --- | --- | --- |
| `VERSION` | -- | `libpolycall 1.1.0 (binding ABI 1)` |
| `VALIDATE` | config path | `VALID` (`polycall_ffi_run_config(path, 1)`) |
| `CONNECT` | node id | `CONNECTED <node> <host:port>` (token from `POLYCALL_DEV_TOKEN`) |
| `SEND_MESSAGE` | `<peer> <text>` | `MESSAGE_SENT` |
| `RECEIVE_MESSAGE` | -- | `<sender> <message-id> <text>` (waits up to 5 s) |
| `DISCONNECT` | -- | `DISCONNECTED` |
| `CALL` | `<endpoint> <service> <operation> <json>` | result JSON |

`result` is the core status; on failure `output` holds the status name and
the detail.

## Build and test (Linux)

Needs GnuCOBOL >= 3.1 (`cobc`), a C compiler and an installed core found
through pkg-config:

```sh
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig LD_LIBRARY_PATH=/opt/polycall/lib
make              # target/cblpolycall
make test         # tests/test_runner.sh
make test-loader  # missing library / old library / ABI mismatch (Linux)
make memcheck     # the real-core test under valgrind memcheck
printf 'VERSION\nCONNECT\nnode-a\nDISCONNECT\n' | target/cblpolycall
```

`make test` builds `tests/POLYCALL-TEST.CBL` and runs it through
`tests/run-real.sh`, which starts `polycall peer serve` and `polycall start`
so RPC and cross-language interop are exercised against the C CLI; then it
drives the client with a scripted session. A GnuCOBOL program has a single
thread, so cancel / close waking a blocked receive (which needs a second
thread in the same process) and concurrent senders from one COBOL process
are reported as SKIP (not applicable); concurrent senders into a COBOL node
are tested with four `polycall peer send` processes running at once. A
missing `cobc`, polycall CLI or valgrind is reported as SKIP (exit 77), never
as success.

### Loading

The shim is linked into the program and the program against the core
(`-lpolycall`), so the dynamic loader resolves `libpolycall.so.1` when it
starts. A missing library
stops the program with the loader's `libpolycall.so.1: cannot open shared
object file` (exit 127); a 1.0 library without the binding ABI v1 symbols
with `undefined symbol: polycall_...` (exit 127); neither is a crash. A
library that reports another binding ABI is refused: `cobpc_run_config`,
`cobpc_describe`, `cobpc_call` and `cobpc_peer_open` return
`PC-E-UNSUPPORTED` and do nothing; compare `cobpc_abi_version` with
`PC-ABI-VERSION` to report it. `make test-loader` checks all three against
fake libraries.

## Windows

`build.bat` (GnuCOBOL 3.2+, uses `config\default.conf`) links the shim and
the core from `POLYCALL_PREFIX` (an installed Polycall prefix with
`include\polycall`, `lib`, `bin`). It has not been run on Windows by QA (no
GnuCOBOL on the QA host); `config\default.conf` uses GnuCOBOL 3.2
configuration tags that 3.1 rejects.

---

**CBLPolyCall v1.1** - COBOL binding for Polycall
OBINexus Aegis Engineering - Technical Lead: Nnamdi Michael Okpala
