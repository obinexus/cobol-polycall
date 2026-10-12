# CBLPolyCall - COBOL binding for Polycall

CBLPolyCall connects GnuCOBOL programs to the
[Polycall](https://github.com/obinexus/polycall) core (**polycall >= 1.1.0**,
binding ABI v1), as part of the OBINexus Aegis Engineering project under the
technical leadership of Nnamdi Michael Okpala.

Everything goes through the core's binding ABI (`<polycall.h>`,
`docs/BINDING_ABI.md` in the core repository). This repository adds no
protocol, parser or network code of its own.

## Install from npm

```
npm install cobol-polycall
```

npm is only the delivery channel: it copies the **source** of the binding
into `node_modules/cobol-polycall`. Nothing is compiled during
installation, there is no JavaScript API, and npm does **not** install
GnuCOBOL, a C compiler or the Polycall core -- you install those yourself
(below) and build the binding with them.

What the package contains:

| Path | Contents |
| --- | --- |
| `src/POLYCALL.CBL`, `src/MAIN.CBL` | `POLYCALL-BRIDGE` (operation API) and the `CBLPOLYCALL-MAIN` client |
| `src/cobpolycall.c`, `src/cobpolycall.h` | the `cobpc_*` C shim over the Polycall binding ABI v1 |
| `copybooks/*.CPY` | status codes and work fields to `COPY` into your programs |
| `examples/VERSION-CHECK.CBL` | the smallest program using the binding (see below) |
| `Makefile`, `build.bat`, `config/default.conf` | Linux/macOS build and the Windows build |
| `tests/` | the real-core test suite run by `npm test` |
| `cobol-polycallrc`, `polycall-binding.json` | runtime overrides and the binding manifest |
| `LICENSE.md` | OBINexus NT Open Access License |

### Requirements

| Needed for | Requirement | Debian / Ubuntu |
| --- | --- | --- |
| building | GnuCOBOL >= 3.1 (`cobc`) | `sudo apt install gnucobol` |
| building | a C compiler, GNU make, pkg-config | `sudo apt install build-essential pkg-config` |
| building and running | **Polycall core >= 1.1.0** (binding ABI v1): `libpolycall.so.1`, headers and `polycall.pc` | build from source, below |
| `npm test` | the `polycall` CLI from the same core, on `PATH` | installed with the core |
| `npm run test:memcheck` | valgrind (optional) | `sudo apt install valgrind` |

The binding needs the binding ABI v1 that core **1.1.0** added. A 1.0 core
(including the 1.0.0 Debian/Ubuntu packages of `polycall`) does not have
it: programs then stop at start-up with `undefined symbol: polycall_...`.
Build the core from its repository's `main` branch (the repository's
default branch is still the 1.0 line):

```sh
git clone --branch main https://github.com/obinexus/polycall
cmake -S polycall -B polycall/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/polycall
cmake --build polycall/build --parallel
sudo cmake --install polycall/build
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig
export LD_LIBRARY_PATH=/opt/polycall/lib
export PATH=/opt/polycall/bin:$PATH
pkg-config --modversion polycall   # must print 1.1.0 or later
```

### Build and test the installed package

With the environment above:

```sh
cd node_modules/cobol-polycall
npm run build              # make: target/cblpolycall
npm test                   # make test: real-core tests + scripted client run
npm run test:loader        # make test-loader: missing / old / wrong-ABI library (Linux)
npm run test:memcheck      # make memcheck: the real-core test under valgrind
printf 'VERSION\nCONNECT\nnode-a\nDISCONNECT\n' | target/cblpolycall
```

Without the core, `npm run build` stops with `pkg-config cannot find
polycall (>= 1.1.0)`; without GnuCOBOL, or (for `npm test`) without the
`polycall` CLI, the scripts print `SKIP: ...` and exit non-zero -- a
missing prerequisite is never reported as a pass.

### Use the binding in your own program

`COPY` the copybooks, compile the shim once, and link your program with the
bridge, the shim and the core. From the project that ran
`npm install cobol-polycall` (`examples/VERSION-CHECK.CBL` is a complete
program):

```sh
PC=node_modules/cobol-polycall
cc -c -fPIC $(pkg-config --cflags polycall) "$PC/src/cobpolycall.c" -o cobpolycall.o
cobc -x -fstatic-call -I "$PC/copybooks" -o version-check \
     "$PC/examples/VERSION-CHECK.CBL" "$PC/src/POLYCALL.CBL" \
     cobpolycall.o $(pkg-config --libs polycall)
./version-check
# version-check: libpolycall 1.1.0, binding ABI 1
# version-check: POLYCALL-BRIDGE VERSION -> libpolycall 1.1.0 (binding ABI 1)
```

Replace `VERSION-CHECK.CBL` with your own source. `-fstatic-call` resolves
`CALL "cobpc_..."` and `CALL "POLYCALL-BRIDGE"` at link time. The program
needs `libpolycall.so.1` at run time: keep `LD_LIBRARY_PATH` set, or
install the core under a prefix the dynamic loader already searches (for
example `/usr/local` followed by `sudo ldconfig`). Leave `POLYCALL.CBL` out
if you call the `cobpc_*` functions directly.

On Windows, `build.bat` builds the same pieces from `POLYCALL_PREFIX` (see
[Windows](#windows)); it has not yet been run end to end.

### Publishing (maintainers)

Releases are published by `.github/workflows/npm-publish.yml` when a
`vX.Y.Z` tag matching `package.json` is pushed: it builds Polycall core
1.1.0, packs the package, installs the tarball into a clean project, runs
`npm run build`, `npm test`, `npm run test:loader` and
`npm run test:memcheck` there, builds `examples/VERSION-CHECK.CBL` with the
commands above, and publishes that exact tarball with npm trusted
publishing (OIDC, no stored token). The same checks run on every pull
request.

A manual publication, from a clean checkout of the release commit after
`npm login`:

```
npm pack --dry-run
npm publish --access public
```

See [Publishing setup](#publishing-setup) for the one-time npm
configuration.

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

## Publishing setup

One-time configuration by an owner of the `cobol-polycall` npm package. No
npm token is stored in this repository or in GitHub secrets.

1. npm sets up trusted publishers in a package's settings, so the first
   version is published by hand: `npm login` (with two-factor
   authentication), then, from a clean checkout of the release tag,
   `npm pack --dry-run` and `npm publish --access public`.
2. On npmjs.com, package `cobol-polycall` -> Settings -> Trusted
   publishing -> GitHub Actions: organization/user `obinexus`, repository
   `cobol-polycall`, workflow filename `npm-publish.yml`, environment `npm`.
3. Settings -> Publishing access -> "Require two-factor authentication and
   disallow tokens".

Every later release: set the same version in `package.json`, `Makefile`
(`VERSION`), `polycall-binding.json` and `build.bat` (`CBL_VERSION`), then
push a `vX.Y.Z` tag. The workflow refuses a tag whose version does not
match all four.

## License

OBINexus NT Open Access License: the MIT grant plus the "Use It, Respect
It" additional terms -- not plain MIT. See [LICENSE.md](LICENSE.md);
`package.json` declares it as `SEE LICENSE IN LICENSE.md`.

---

**CBLPolyCall v1.1** - COBOL binding for Polycall
OBINexus Aegis Engineering - Technical Lead: Nnamdi Michael Okpala
