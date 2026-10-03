/*
 * cobpolycall -- COBOL-friendly C shim over the Polycall binding ABI v1.
 * See cobpolycall.h for the field conventions. The shim only converts
 * between fixed-length space-padded COBOL fields and C strings; every
 * operation is exactly one call into libpolycall and its status is passed
 * back unchanged.
 */
#include "cobpolycall.h"

#include <polycall.h>

#include <stdlib.h>
#include <string.h>

/* fixed COBOL field -> NUL-terminated C string (trailing spaces and
 * LOW-VALUEs removed); dst must hold n + 1 bytes */
static const char *field_in(const char *src, size_t n, char *dst)
{
    size_t len = 0;
    if (!src) {
        dst[0] = '\0';
        return dst;
    }
    while (len < n && src[len] != '\0') {
        ++len;
    }
    while (len > 0 && src[len - 1] == ' ') {
        --len;
    }
    memcpy(dst, src, len);
    dst[len] = '\0';
    return dst;
}

/* C string -> fixed COBOL field, space padded (truncated if longer) */
static void field_out(char *dst, size_t n, const char *src)
{
    size_t len = src ? strlen(src) : 0;
    if (!dst) {
        return;
    }
    if (len > n) {
        len = n;
    }
    memcpy(dst, src, len);
    memset(dst + len, ' ', n - len);
}

static int finish(int st, int32_t *status)
{
    if (status) {
        *status = (int32_t)st;
    }
    return st;
}

static int32_t value_or(const int32_t *p, int32_t fallback)
{
    return p ? *p : fallback;
}

/* BINARY-LONG timeout -> uint32_t (-1 = UINT32_MAX = wait forever) */
static uint32_t timeout_of(const int32_t *p, int32_t fallback)
{
    return (uint32_t)value_or(p, fallback);
}

/* JSON/text result into a COBOL field of `cap` bytes, space padded */
typedef int (*json_fn)(polycall_peer_t, char *, size_t, size_t *);

static int json_out(json_fn fn, const int32_t *handle, char *json, const int32_t *cap,
                    int32_t *len, int32_t *status)
{
    int32_t c = value_or(cap, 0);
    size_t needed = 0;
    char *tmp;
    int st;
    if (!json || c < 0) {
        return finish(POLYCALL_E_INVALID_ARGUMENT, status);
    }
    tmp = malloc((size_t)c + 1);
    if (!tmp) {
        return finish(POLYCALL_E_NO_MEMORY, status);
    }
    st = fn(value_or(handle, 0), tmp, (size_t)c + 1, &needed);
    if (len) {
        *len = (int32_t)needed;
    }
    if (st == POLYCALL_OK) {
        memcpy(json, tmp, needed);
        memset(json + needed, ' ', (size_t)c - needed);
    }
    free(tmp);
    return finish(st, status);
}

/* ---- library ------------------------------------------------------------ */

int cobpc_abi_version(int32_t *abi, int32_t *status)
{
    if (abi) {
        *abi = polycall_ffi_abi_version();
    }
    return finish(POLYCALL_OK, status);
}

int cobpc_version(char version[COBPC_NAME_LEN], int32_t *status)
{
    char buf[COBPC_NAME_LEN + 1];
    int n = polycall_ffi_version(buf, (int)sizeof buf);
    if (n < 0) {
        return finish(n, status);
    }
    field_out(version, COBPC_NAME_LEN, buf);
    return finish(POLYCALL_OK, status);
}

int cobpc_strerror(const int32_t *code, char name[COBPC_TEXT_LEN])
{
    field_out(name, COBPC_TEXT_LEN, polycall_strerror(value_or(code, 0)));
    return POLYCALL_OK;
}

int cobpc_last_error(char detail[COBPC_TEXT_LEN])
{
    char buf[COBPC_TEXT_LEN + 1];
    buf[0] = '\0';
    polycall_last_error(buf, sizeof buf);
    field_out(detail, COBPC_TEXT_LEN, buf);
    return POLYCALL_OK;
}

/* ---- configuration ---------------------------------------------------- */

int cobpc_run_config(const char path[COBPC_PATH_LEN], const int32_t *run, int32_t *status)
{
    char p[COBPC_PATH_LEN + 1];
    if (polycall_ffi_abi_version() != POLYCALL_FFI_ABI_VERSION) {
        return finish(POLYCALL_E_UNSUPPORTED, status);
    }
    return finish(polycall_ffi_run_config(field_in(path, COBPC_PATH_LEN, p),
                                          value_or(run, 1) ? 1 : 0),
                  status);
}

int cobpc_describe(const char path[COBPC_PATH_LEN], char *json, const int32_t *cap,
                   int32_t *len, int32_t *status)
{
    char p[COBPC_PATH_LEN + 1];
    int32_t c = value_or(cap, 0);
    char *tmp;
    int n;
    if (polycall_ffi_abi_version() != POLYCALL_FFI_ABI_VERSION) {
        return finish(POLYCALL_E_UNSUPPORTED, status);
    }
    if (!json || c < 0 || c == INT32_MAX) { /* c + 1 must fit the int length */
        return finish(POLYCALL_E_INVALID_ARGUMENT, status);
    }
    tmp = malloc((size_t)c + 1);
    if (!tmp) {
        return finish(POLYCALL_E_NO_MEMORY, status);
    }
    n = polycall_ffi_describe(field_in(path, COBPC_PATH_LEN, p), tmp, (int)c + 1);
    if (n < 0) {
        free(tmp);
        return finish(n, status);
    }
    if (len) {
        *len = n;
    }
    if (n > c) {
        free(tmp);
        return finish(POLYCALL_E_TOO_LARGE, status);
    }
    memcpy(json, tmp, (size_t)n);
    memset(json + n, ' ', (size_t)(c - n));
    free(tmp);
    return finish(POLYCALL_OK, status);
}

/* ---- RPC ------------------------------------------------------------------ */

int cobpc_call(const char endpoint[COBPC_ENDPOINT_LEN], const char service[COBPC_NAME_LEN],
               const char operation[COBPC_NAME_LEN], const char *input,
               const int32_t *input_len, const int32_t *timeout_ms, char *output,
               const int32_t *output_cap, int32_t *output_len, int32_t *status)
{
    char ep[COBPC_ENDPOINT_LEN + 1], sv[COBPC_NAME_LEN + 1], op[COBPC_NAME_LEN + 1];
    int32_t in_len = value_or(input_len, 0), cap = value_or(output_cap, 0);
    char *in = NULL, *out;
    size_t got = 0;
    int st;

    if (output_len) {
        *output_len = 0;
    }
    if (polycall_ffi_abi_version() != POLYCALL_FFI_ABI_VERSION) {
        return finish(POLYCALL_E_UNSUPPORTED, status);
    }
    if (!output || cap < 0 || in_len < 0 || (in_len > 0 && !input)) {
        return finish(POLYCALL_E_INVALID_ARGUMENT, status);
    }
    if (in_len > 0) {
        in = malloc((size_t)in_len + 1);
        if (!in) {
            return finish(POLYCALL_E_NO_MEMORY, status);
        }
        memcpy(in, input, (size_t)in_len);
        in[in_len] = '\0';
    }
    out = malloc((size_t)cap + 1);
    if (!out) {
        free(in);
        return finish(POLYCALL_E_NO_MEMORY, status);
    }
    out[0] = '\0';
    st = polycall_call(field_in(endpoint, COBPC_ENDPOINT_LEN, ep),
                       field_in(service, COBPC_NAME_LEN, sv),
                       field_in(operation, COBPC_NAME_LEN, op), in,
                       timeout_of(timeout_ms, 5000), out, (size_t)cap + 1, &got);
    if (st == POLYCALL_OK || st == POLYCALL_E_REMOTE || st == POLYCALL_E_NOT_FOUND ||
        st == POLYCALL_E_TIMEOUT || st == POLYCALL_E_BUSY) {
        /* output JSON, or the remote error object */
        size_t n = st == POLYCALL_OK ? got : strlen(out);
        if (n > (size_t)cap) {
            n = (size_t)cap;
        }
        memcpy(output, out, n);
        memset(output + n, ' ', (size_t)cap - n);
        if (output_len) {
            *output_len = (int32_t)n;
        }
    } else if (output_len) {
        *output_len = (int32_t)got; /* E_TOO_LARGE: size needed */
    }
    free(out);
    free(in);
    return finish(st, status);
}

/* ---- peer nodes ------------------------------------------------------------ */

int cobpc_peer_open(const char node_id[COBPC_ID_LEN], const char bind[COBPC_ENDPOINT_LEN],
                    const char token[COBPC_TOKEN_LEN], int32_t *handle, int32_t *status)
{
    char id[COBPC_ID_LEN + 1], ep[COBPC_ENDPOINT_LEN + 1], tok[COBPC_TOKEN_LEN + 1];
    polycall_peer_t h = 0;
    int st;
    if (polycall_ffi_abi_version() != POLYCALL_FFI_ABI_VERSION) {
        return finish(POLYCALL_E_UNSUPPORTED, status);
    }
    field_in(bind, COBPC_ENDPOINT_LEN, ep);
    field_in(token, COBPC_TOKEN_LEN, tok);
    /* SPACES bind = send-only node; SPACES token = no authentication */
    st = polycall_peer_open(field_in(node_id, COBPC_ID_LEN, id), ep[0] ? ep : NULL,
                            tok[0] ? tok : NULL, &h);
    if (handle) {
        *handle = st == POLYCALL_OK ? h : 0;
    }
    return finish(st, status);
}

int cobpc_peer_close(const int32_t *handle, int32_t *status)
{
    return finish(polycall_peer_close(value_or(handle, 0)), status);
}

int cobpc_peer_endpoint(const int32_t *handle, char endpoint[COBPC_ENDPOINT_LEN],
                        int32_t *status)
{
    char buf[COBPC_ENDPOINT_LEN + 1];
    int st;
    buf[0] = '\0';
    st = polycall_peer_endpoint(value_or(handle, 0), buf, sizeof buf);
    field_out(endpoint, COBPC_ENDPOINT_LEN, st == POLYCALL_OK ? buf : "");
    return finish(st, status);
}

int cobpc_peer_node_id(const int32_t *handle, char node_id[COBPC_ID_LEN], int32_t *status)
{
    char buf[COBPC_ID_LEN + 1];
    int st;
    buf[0] = '\0';
    st = polycall_peer_node_id(value_or(handle, 0), buf, sizeof buf);
    field_out(node_id, COBPC_ID_LEN, st == POLYCALL_OK ? buf : "");
    return finish(st, status);
}

int cobpc_peer_register(const int32_t *handle, const char peer_id[COBPC_ID_LEN],
                        const char endpoint[COBPC_ENDPOINT_LEN], int32_t *status)
{
    char id[COBPC_ID_LEN + 1], ep[COBPC_ENDPOINT_LEN + 1];
    return finish(polycall_peer_register(value_or(handle, 0), field_in(peer_id, COBPC_ID_LEN, id),
                                         field_in(endpoint, COBPC_ENDPOINT_LEN, ep)),
                  status);
}

int cobpc_peer_unregister(const int32_t *handle, const char peer_id[COBPC_ID_LEN],
                          int32_t *status)
{
    char id[COBPC_ID_LEN + 1];
    return finish(polycall_peer_unregister(value_or(handle, 0), field_in(peer_id, COBPC_ID_LEN, id)),
                  status);
}

int cobpc_peer_list(const int32_t *handle, char *json, const int32_t *cap, int32_t *len,
                    int32_t *status)
{
    return json_out(polycall_peer_list, handle, json, cap, len, status);
}

int cobpc_peer_ping(const int32_t *handle, const char peer[COBPC_ENDPOINT_LEN],
                    const int32_t *timeout_ms, int32_t *status)
{
    char p[COBPC_ENDPOINT_LEN + 1];
    return finish(polycall_peer_ping(value_or(handle, 0), field_in(peer, COBPC_ENDPOINT_LEN, p),
                                     timeout_of(timeout_ms, 3000)),
                  status);
}

int cobpc_peer_send(const int32_t *handle, const char peer[COBPC_ENDPOINT_LEN],
                    const char *payload, const int32_t *len,
                    const char message_id[COBPC_ID_LEN], const int32_t *timeout_ms,
                    int32_t *status)
{
    char p[COBPC_ENDPOINT_LEN + 1], mid[COBPC_ID_LEN + 1];
    static const char empty = 0;
    int32_t n = value_or(len, 0);
    if (n < 0) {
        return finish(POLYCALL_E_INVALID_ARGUMENT, status);
    }
    field_in(message_id, COBPC_ID_LEN, mid);
    /* SPACES message id = generated by the core */
    return finish(polycall_peer_send(value_or(handle, 0), field_in(peer, COBPC_ENDPOINT_LEN, p),
                                     payload ? payload : &empty, (size_t)n,
                                     mid[0] ? mid : NULL, timeout_of(timeout_ms, 5000)),
                  status);
}

int cobpc_peer_recv(const int32_t *handle, const int32_t *timeout_ms,
                    char sender[COBPC_ID_LEN], char message_id[COBPC_ID_LEN], char *payload,
                    const int32_t *cap, int32_t *len, int32_t *status)
{
    char s[COBPC_ID_LEN + 1], mid[COBPC_ID_LEN + 1];
    int32_t c = value_or(cap, 0);
    size_t got = 0;
    char one;
    int st;
    if (c < 0 || (c > 0 && !payload)) {
        return finish(POLYCALL_E_INVALID_ARGUMENT, status);
    }
    s[0] = mid[0] = '\0';
    st = polycall_peer_recv(value_or(handle, 0), timeout_of(timeout_ms, 0), s, sizeof s, mid,
                            sizeof mid, c > 0 ? (void *)payload : (void *)&one, (size_t)c, &got);
    if (len) {
        *len = (int32_t)got; /* bytes received, or needed on E_TOO_LARGE */
    }
    field_out(sender, COBPC_ID_LEN, st == POLYCALL_OK ? s : "");
    field_out(message_id, COBPC_ID_LEN, st == POLYCALL_OK ? mid : "");
    return finish(st, status);
}

int cobpc_peer_cancel(const int32_t *handle, int32_t *status)
{
    return finish(polycall_peer_cancel(value_or(handle, 0)), status);
}

int cobpc_peer_health(const int32_t *handle, char *json, const int32_t *cap, int32_t *len,
                      int32_t *status)
{
    return json_out(polycall_peer_health, handle, json, cap, len, status);
}
