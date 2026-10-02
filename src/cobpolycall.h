#ifndef COBPOLYCALL_H
#define COBPOLYCALL_H

/*
 * cobpolycall -- COBOL-friendly C shim over the Polycall binding ABI v1
 * (<polycall.h>, polycall >= 1.1.0).
 *
 * GnuCOBOL passes BY REFERENCE arguments as bare pointers, without lengths,
 * and COBOL text fields are fixed-length and space-padded. This shim adapts
 * exactly that and nothing else:
 *
 *   - Short text fields have the fixed sizes below (copybooks/POLYCALL-API.CPY
 *     declares them). Input text ends at the first trailing space or
 *     LOW-VALUE; output text is copied and padded with spaces.
 *   - Byte data (payloads, JSON) travels as field + explicit BINARY-LONG
 *     length (input) or capacity + returned length (output); binary-safe,
 *     never padded or trimmed.
 *   - Integers (status, handle, timeout, run flag, lengths) are BINARY-LONG
 *     BY REFERENCE (int32). A timeout of -1 means "wait forever".
 *   - Every function stores the core's status in its last argument and also
 *     returns it (RETURN-CODE). Status values are the core's POLYCALL_OK /
 *     POLYCALL_E_* codes, unchanged.
 */

#include <stdint.h>

#define COBPC_ID_LEN       64   /* PIC X(64): node, peer and message ids  */
#define COBPC_ENDPOINT_LEN 128  /* PIC X(128): host:port                  */
#define COBPC_TOKEN_LEN    128  /* PIC X(128): shared auth token          */
#define COBPC_NAME_LEN     64   /* PIC X(64): service, operation, version */
#define COBPC_PATH_LEN     512  /* PIC X(512): configuration file path    */
#define COBPC_TEXT_LEN     512  /* PIC X(512): status name / detail       */

#ifdef __cplusplus
extern "C" {
#endif

int cobpc_abi_version(int32_t *abi, int32_t *status);
int cobpc_version(char version[COBPC_NAME_LEN], int32_t *status);
int cobpc_strerror(const int32_t *code, char name[COBPC_TEXT_LEN]);
int cobpc_last_error(char detail[COBPC_TEXT_LEN]);

int cobpc_run_config(const char path[COBPC_PATH_LEN], const int32_t *run,
                     int32_t *status);
int cobpc_describe(const char path[COBPC_PATH_LEN], char *json, const int32_t *cap,
                   int32_t *len, int32_t *status);

int cobpc_call(const char endpoint[COBPC_ENDPOINT_LEN], const char service[COBPC_NAME_LEN],
               const char operation[COBPC_NAME_LEN], const char *input,
               const int32_t *input_len, const int32_t *timeout_ms, char *output,
               const int32_t *output_cap, int32_t *output_len, int32_t *status);

int cobpc_peer_open(const char node_id[COBPC_ID_LEN], const char bind[COBPC_ENDPOINT_LEN],
                    const char token[COBPC_TOKEN_LEN], int32_t *handle, int32_t *status);
int cobpc_peer_close(const int32_t *handle, int32_t *status);
int cobpc_peer_endpoint(const int32_t *handle, char endpoint[COBPC_ENDPOINT_LEN],
                        int32_t *status);
int cobpc_peer_node_id(const int32_t *handle, char node_id[COBPC_ID_LEN], int32_t *status);
int cobpc_peer_register(const int32_t *handle, const char peer_id[COBPC_ID_LEN],
                        const char endpoint[COBPC_ENDPOINT_LEN], int32_t *status);
int cobpc_peer_unregister(const int32_t *handle, const char peer_id[COBPC_ID_LEN],
                          int32_t *status);
int cobpc_peer_list(const int32_t *handle, char *json, const int32_t *cap, int32_t *len,
                    int32_t *status);
int cobpc_peer_ping(const int32_t *handle, const char peer[COBPC_ENDPOINT_LEN],
                    const int32_t *timeout_ms, int32_t *status);
int cobpc_peer_send(const int32_t *handle, const char peer[COBPC_ENDPOINT_LEN],
                    const char *payload, const int32_t *len,
                    const char message_id[COBPC_ID_LEN], const int32_t *timeout_ms,
                    int32_t *status);
int cobpc_peer_recv(const int32_t *handle, const int32_t *timeout_ms,
                    char sender[COBPC_ID_LEN], char message_id[COBPC_ID_LEN], char *payload,
                    const int32_t *cap, int32_t *len, int32_t *status);
int cobpc_peer_cancel(const int32_t *handle, int32_t *status);
int cobpc_peer_health(const int32_t *handle, char *json, const int32_t *cap, int32_t *len,
                      int32_t *status);

#ifdef __cplusplus
}
#endif

#endif /* COBPOLYCALL_H */
