      * CBLPolyCall FFI Bridge v1.1
      * OBINexus Aegis Engineering - COBOL to Polycall Interface
      * Technical Lead: Nnamdi Michael Okpala
      *
      * POLYCALL-BRIDGE maps the client operations onto the Polycall
      * binding ABI v1 (polycall >= 1.1.0) through the cobpc_* C shim
      * (src/cobpolycall.c). It keeps one peer node open between calls.
      *
      *   VERSION          -> "libpolycall <v> (binding ABI <n>)"
      *   VALIDATE path    -> polycall_ffi_run_config(path, 1)
      *   CONNECT node-id  -> open a peer node on 127.0.0.1:<ephemeral>
      *                       (token: POLYCALL_DEV_TOKEN when set)
      *   SEND_MESSAGE peer payload
      *                    -> one acknowledged delivery to peer (host:port
      *                       or registered id); payload = rest of line
      *   RECEIVE_MESSAGE  -> "<sender> <message-id> <payload>" (5 s)
      *   DISCONNECT       -> close the node
      *   CALL endpoint service operation json
      *                    -> polycall_call; output = result JSON
      *
      * LNK-RESULT-CODE receives the core status (0 or POLYCALL_E_*);
      * on failure LNK-OUTPUT holds the status name and detail.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. POLYCALL-BRIDGE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "POLYCALL-CONSTANTS.CPY".
       COPY "POLYCALL-STRUCTURES.CPY".
       01  WS-NODE-HANDLE          BINARY-LONG VALUE 0.
       01  WS-PTR                  BINARY-LONG VALUE 1.
       01  WS-PAYLOAD              PIC X(1024).
       01  WS-PAYLOAD-LEN          BINARY-LONG VALUE 0.
       01  WS-PAYLOAD-CAP          BINARY-LONG VALUE 1024.
       01  WS-JSON                 PIC X(1024).
       01  WS-JSON-LEN             BINARY-LONG VALUE 0.
       01  WS-JSON-CAP             BINARY-LONG VALUE 1024.
       01  WS-ABI-DISPLAY          PIC -(9)9.

       LINKAGE SECTION.
       01  LNK-OPERATION           PIC X(20).
       01  LNK-INPUT-DATA          PIC X(1024).
       01  LNK-OUTPUT-DATA         PIC X(1024).
       01  LNK-RESULT-CODE         BINARY-LONG.

       PROCEDURE DIVISION USING LNK-OPERATION,
                                LNK-INPUT-DATA,
                                LNK-OUTPUT-DATA,
                                LNK-RESULT-CODE.

       MAIN-LOGIC.
           MOVE SPACES TO LNK-OUTPUT-DATA
           MOVE PC-OK TO PC-STATUS
           EVALUATE LNK-OPERATION
               WHEN "VERSION"
                   PERFORM POLYCALL-VERSION
               WHEN "VALIDATE"
                   PERFORM POLYCALL-VALIDATE
               WHEN "CONNECT"
                   PERFORM POLYCALL-CONNECT
               WHEN "SEND_MESSAGE"
                   PERFORM POLYCALL-SEND
               WHEN "RECEIVE_MESSAGE"
                   PERFORM POLYCALL-RECEIVE
               WHEN "DISCONNECT"
                   PERFORM POLYCALL-DISCONNECT
               WHEN "CALL"
                   PERFORM POLYCALL-RPC
               WHEN OTHER
                   MOVE PC-E-INVALID-ARGUMENT TO PC-STATUS
                   MOVE "UNKNOWN_OPERATION" TO LNK-OUTPUT-DATA
           END-EVALUATE
           MOVE PC-STATUS TO LNK-RESULT-CODE
           IF PC-STATUS NOT = PC-OK
              AND LNK-OUTPUT-DATA = SPACES
               PERFORM DESCRIBE-FAILURE
           END-IF
           GOBACK.

       DESCRIBE-FAILURE.
           CALL "cobpc_last_error" USING PC-DETAIL
           CALL "cobpc_strerror" USING PC-STATUS PC-STATUS-NAME
           STRING FUNCTION TRIM(PC-STATUS-NAME) DELIMITED BY SIZE
                  " (" DELIMITED BY SIZE
                  FUNCTION TRIM(PC-DETAIL) DELIMITED BY SIZE
                  ")" DELIMITED BY SIZE
             INTO LNK-OUTPUT-DATA
           END-STRING.

       POLYCALL-VERSION.
           CALL "cobpc_abi_version" USING PC-ABI PC-STATUS
           CALL "cobpc_version" USING PC-VERSION PC-STATUS
           IF PC-STATUS = PC-OK
               MOVE PC-ABI TO WS-ABI-DISPLAY
               STRING "libpolycall " DELIMITED BY SIZE
                      FUNCTION TRIM(PC-VERSION) DELIMITED BY SIZE
                      " (binding ABI " DELIMITED BY SIZE
                      FUNCTION TRIM(WS-ABI-DISPLAY) DELIMITED BY SIZE
                      ")" DELIMITED BY SIZE
                 INTO LNK-OUTPUT-DATA
               END-STRING
           END-IF.

       POLYCALL-VALIDATE.
           MOVE LNK-INPUT-DATA TO PC-CONFIG-PATH
           MOVE 1 TO PC-RUN
           CALL "cobpc_run_config" USING PC-CONFIG-PATH PC-RUN
                                         PC-STATUS
           IF PC-STATUS = PC-OK
               MOVE "VALID" TO LNK-OUTPUT-DATA
           END-IF.

       POLYCALL-CONNECT.
           IF WS-NODE-HANDLE NOT = 0
               CALL "cobpc_peer_close" USING WS-NODE-HANDLE PC-STATUS
               MOVE 0 TO WS-NODE-HANDLE
           END-IF
           MOVE LNK-INPUT-DATA TO PC-NODE-ID
           IF PC-NODE-ID = SPACES
               MOVE "cobol-node" TO PC-NODE-ID
           END-IF
           MOVE "127.0.0.1:0" TO PC-BIND-ENDPOINT
           MOVE SPACES TO PC-AUTH-TOKEN
           ACCEPT PC-AUTH-TOKEN FROM ENVIRONMENT "POLYCALL_DEV_TOKEN"
           CALL "cobpc_peer_open" USING PC-NODE-ID PC-BIND-ENDPOINT
                                        PC-AUTH-TOKEN WS-NODE-HANDLE
                                        PC-STATUS
           IF PC-STATUS = PC-OK
               CALL "cobpc_peer_endpoint" USING WS-NODE-HANDLE
                                                PC-ENDPOINT PC-STATUS
               STRING "CONNECTED " DELIMITED BY SIZE
                      FUNCTION TRIM(PC-NODE-ID) DELIMITED BY SIZE
                      " " DELIMITED BY SIZE
                      FUNCTION TRIM(PC-ENDPOINT) DELIMITED BY SIZE
                 INTO LNK-OUTPUT-DATA
               END-STRING
           END-IF.

       POLYCALL-SEND.
           MOVE SPACES TO PC-TARGET WS-PAYLOAD PC-MESSAGE-ID
           MOVE 1 TO WS-PTR
           UNSTRING LNK-INPUT-DATA DELIMITED BY ALL SPACE
               INTO PC-TARGET
               WITH POINTER WS-PTR
           END-UNSTRING
           MOVE 0 TO WS-PAYLOAD-LEN
           IF WS-PTR <= 1024
               MOVE LNK-INPUT-DATA(WS-PTR:) TO WS-PAYLOAD
               MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-PAYLOAD TRAILING))
                 TO WS-PAYLOAD-LEN
               IF WS-PAYLOAD = SPACES
                   MOVE 0 TO WS-PAYLOAD-LEN
               END-IF
           END-IF
           MOVE 5000 TO PC-TIMEOUT-MS
           CALL "cobpc_peer_send" USING WS-NODE-HANDLE PC-TARGET
                                        WS-PAYLOAD WS-PAYLOAD-LEN
                                        PC-MESSAGE-ID PC-TIMEOUT-MS
                                        PC-STATUS
           IF PC-STATUS = PC-OK
               MOVE "MESSAGE_SENT" TO LNK-OUTPUT-DATA
           END-IF.

       POLYCALL-RECEIVE.
           MOVE 5000 TO PC-TIMEOUT-MS
           MOVE SPACES TO WS-PAYLOAD
           CALL "cobpc_peer_recv" USING WS-NODE-HANDLE PC-TIMEOUT-MS
                                        PC-SENDER PC-MESSAGE-ID
                                        WS-PAYLOAD WS-PAYLOAD-CAP
                                        WS-PAYLOAD-LEN PC-STATUS
           IF PC-STATUS = PC-OK
               STRING FUNCTION TRIM(PC-SENDER) DELIMITED BY SIZE
                      " " DELIMITED BY SIZE
                      FUNCTION TRIM(PC-MESSAGE-ID) DELIMITED BY SIZE
                      " " DELIMITED BY SIZE
                 INTO LNK-OUTPUT-DATA
               END-STRING
               IF WS-PAYLOAD-LEN > 0
                   STRING FUNCTION TRIM(LNK-OUTPUT-DATA)
                            DELIMITED BY SIZE
                          " " DELIMITED BY SIZE
                          WS-PAYLOAD(1:WS-PAYLOAD-LEN)
                            DELIMITED BY SIZE
                     INTO LNK-OUTPUT-DATA
                   END-STRING
               END-IF
           END-IF.

       POLYCALL-DISCONNECT.
           CALL "cobpc_peer_close" USING WS-NODE-HANDLE PC-STATUS
           MOVE 0 TO WS-NODE-HANDLE
           IF PC-STATUS = PC-OK
               MOVE "DISCONNECTED" TO LNK-OUTPUT-DATA
           END-IF.

       POLYCALL-RPC.
           MOVE SPACES TO PC-TARGET PC-SERVICE PC-OPERATION WS-PAYLOAD
           MOVE 1 TO WS-PTR
           UNSTRING LNK-INPUT-DATA DELIMITED BY ALL SPACE
               INTO PC-TARGET PC-SERVICE PC-OPERATION
               WITH POINTER WS-PTR
           END-UNSTRING
           MOVE 0 TO WS-PAYLOAD-LEN
           IF WS-PTR <= 1024
               MOVE LNK-INPUT-DATA(WS-PTR:) TO WS-PAYLOAD
               IF WS-PAYLOAD NOT = SPACES
                   MOVE FUNCTION LENGTH(
                          FUNCTION TRIM(WS-PAYLOAD TRAILING))
                     TO WS-PAYLOAD-LEN
               END-IF
           END-IF
           MOVE 5000 TO PC-TIMEOUT-MS
           CALL "cobpc_call" USING PC-TARGET PC-SERVICE PC-OPERATION
                                   WS-PAYLOAD WS-PAYLOAD-LEN
                                   PC-TIMEOUT-MS WS-JSON WS-JSON-CAP
                                   WS-JSON-LEN PC-STATUS
           IF WS-JSON-LEN > 0
               MOVE WS-JSON(1:WS-JSON-LEN) TO LNK-OUTPUT-DATA
           END-IF.
