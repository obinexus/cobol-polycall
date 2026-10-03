       >>SOURCE FORMAT IS FREE
*> Loader check for tests/loader-errors.sh: what a COBOL program sees from
*> the library it was started with. Prints one line per step:
*>
*>   loader-check: abi=<n>
*>   loader-check: check_abi=<status> <message>
*>   loader-check: run_config=<status>
*>   loader-check: call=<status>   (127.0.0.1:1: E_TRANSPORT with the real core)
*>   loader-check: peer_open=<status> <message>
*>
*> check_abi compares cobpc_abi_version with PC-ABI-VERSION, as a COBOL
*> program does; cobpc_run_config, cobpc_call and cobpc_peer_open refuse a
*> library of another ABI themselves. Run from the repository root.
IDENTIFICATION DIVISION.
PROGRAM-ID. LOADER-CHECK.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "POLYCALL-CONSTANTS.CPY".
COPY "POLYCALL-STRUCTURES.CPY".
01  WS-NUM                      PIC -(9)9.
01  WS-ABI                      PIC -(9)9.
01  WS-H                        BINARY-LONG VALUE 0.
01  WS-INPUT                    PIC X(2).
01  WS-INPUT-LEN                BINARY-LONG VALUE 2.
01  WS-OUT                      PIC X(256).
01  WS-OUT-CAP                  BINARY-LONG VALUE 256.
01  WS-OUT-LEN                  BINARY-LONG VALUE 0.

PROCEDURE DIVISION.
MAIN-PARA.
    CALL "cobpc_abi_version" USING PC-ABI PC-STATUS
    MOVE PC-ABI TO WS-ABI
    DISPLAY "loader-check: abi=" FUNCTION TRIM(WS-ABI)
    IF PC-ABI = PC-ABI-VERSION
        DISPLAY "loader-check: check_abi=0 OK"
    ELSE
        MOVE PC-E-UNSUPPORTED TO PC-STATUS
        CALL "cobpc_strerror" USING PC-STATUS PC-STATUS-NAME
        DISPLAY "loader-check: check_abi=-15 " FUNCTION TRIM(PC-STATUS-NAME)
            " (libpolycall reports binding ABI " FUNCTION TRIM(WS-ABI)
            ", cobol-polycall requires ABI 1)"
    END-IF

    MOVE "cobol-polycallrc" TO PC-CONFIG-PATH
    MOVE 1 TO PC-RUN
    CALL "cobpc_run_config" USING PC-CONFIG-PATH PC-RUN PC-STATUS
    MOVE PC-STATUS TO WS-NUM
    DISPLAY "loader-check: run_config=" FUNCTION TRIM(WS-NUM)

    MOVE "127.0.0.1:1" TO PC-TARGET
    MOVE "debug" TO PC-SERVICE
    MOVE "echo" TO PC-OPERATION
    MOVE "{}" TO WS-INPUT
    MOVE 1000 TO PC-TIMEOUT-MS
    CALL "cobpc_call" USING PC-TARGET PC-SERVICE PC-OPERATION WS-INPUT WS-INPUT-LEN
        PC-TIMEOUT-MS WS-OUT WS-OUT-CAP WS-OUT-LEN PC-STATUS
    MOVE PC-STATUS TO WS-NUM
    DISPLAY "loader-check: call=" FUNCTION TRIM(WS-NUM)

    MOVE "loader-check" TO PC-NODE-ID
    MOVE "127.0.0.1:0" TO PC-BIND-ENDPOINT
    MOVE SPACES TO PC-AUTH-TOKEN
    CALL "cobpc_peer_open" USING PC-NODE-ID PC-BIND-ENDPOINT PC-AUTH-TOKEN
        WS-H PC-STATUS
    IF PC-STATUS = PC-OK
        CALL "cobpc_peer_close" USING WS-H PC-STATUS
        DISPLAY "loader-check: peer_open=0 OK"
    ELSE
        MOVE PC-STATUS TO WS-NUM
        CALL "cobpc_strerror" USING PC-STATUS PC-STATUS-NAME
        DISPLAY "loader-check: peer_open=" FUNCTION TRIM(WS-NUM) " "
            FUNCTION TRIM(PC-STATUS-NAME)
    END-IF
    MOVE 0 TO RETURN-CODE
    STOP RUN.
