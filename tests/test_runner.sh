#!/usr/bin/env sh
# cobol-polycall test runner: builds the client and the COBOL test program
# against the installed Polycall core, runs the checklist test with live C-CLI
# counterparts (tests/run-real.sh) and drives the interactive client with a
# scripted session. Exit 77 = SKIP (toolchain or polycall CLI missing),
# never reported as success.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

if ! command -v "${COBC:-cobc}" >/dev/null 2>&1; then
    echo "SKIP: GnuCOBOL (cobc) not found"
    exit 77
fi

make test-build

status=0
sh tests/run-real.sh build/polycall-test . || status=$?
if [ "$status" -eq 77 ]; then
    echo "SKIP: COBOL real-core test needs the polycall CLI"
    exit 77
fi
if [ "$status" -ne 0 ]; then
    echo "FAIL: COBOL real-core test exited $status"
    exit "$status"
fi

# Scripted client session; a blank line / end of input must end the loop.
out=$(printf 'VERSION\nVALIDATE\ncobol-polycallrc\nCONNECT\ncbl-main\nDISCONNECT\n' |
      timeout 30 ./target/cblpolycall) || {
    echo "FAIL: client session exited $?"
    printf '%s\n' "$out"
    exit 1
}
for want in "Output: libpolycall 1." "Output: VALID" "Output: CONNECTED cbl-main 127.0.0.1:" \
            "Output: DISCONNECTED" "CBLPolyCall Client terminated."; do
    case "$out" in
        *"$want"*) echo "PASS client: $want" ;;
        *) echo "FAIL client: missing '$want'"; printf '%s\n' "$out"; exit 1 ;;
    esac
done
echo "cobol-polycall tests: PASS"
