       >>SOURCE FORMAT IS FREE
*> VERSION-CHECK -- the smallest program that uses cobol-polycall from
*> another project. It checks that the Polycall core it was linked against
*> speaks binding ABI v1, prints the core version through the cobpc_* shim,
*> then asks the same question through the POLYCALL-BRIDGE operation API.
*> Exit status 0 when both work, 1 otherwise.
*>
*> Build it (README: "Use the binding in your own program"), with
*> PC = the installed package directory, e.g. node_modules/cobol-polycall:
*>   cc -c -fPIC $(pkg-config --cflags polycall) "$PC/src/cobpolycall.c" -o cobpolycall.o
*>   cobc -x -fstatic-call -I "$PC/copybooks" -o version-check \
*>        "$PC/examples/VERSION-CHECK.CBL" "$PC/src/POLYCALL.CBL" \
*>        cobpolycall.o $(pkg-config --libs polycall)
IDENTIFICATION DIVISION.
PROGRAM-ID. VERSION-CHECK.

DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "POLYCALL-CONSTANTS.CPY".
COPY "POLYCALL-STRUCTURES.CPY".
01  WS-ABI                      PIC -(9)9.
01  WS-OPERATION                PIC X(20) VALUE "VERSION".
01  WS-INPUT                    PIC X(1024) VALUE SPACES.
01  WS-OUTPUT                   PIC X(1024) VALUE SPACES.
01  WS-RESULT                   BINARY-LONG VALUE 0.

PROCEDURE DIVISION.
MAIN-PARA.
    CALL "cobpc_abi_version" USING PC-ABI PC-STATUS
    MOVE PC-ABI TO WS-ABI
    IF PC-STATUS NOT = PC-OK OR PC-ABI NOT = PC-ABI-VERSION
        DISPLAY "version-check: the loaded core reports binding ABI "
                FUNCTION TRIM(WS-ABI) "; this binding needs ABI 1"
        MOVE 1 TO RETURN-CODE
        STOP RUN
    END-IF

    CALL "cobpc_version" USING PC-VERSION PC-STATUS
    DISPLAY "version-check: libpolycall " FUNCTION TRIM(PC-VERSION)
            ", binding ABI " FUNCTION TRIM(WS-ABI)

    CALL "POLYCALL-BRIDGE" USING WS-OPERATION WS-INPUT WS-OUTPUT WS-RESULT
    IF WS-RESULT = PC-OK
        DISPLAY "version-check: POLYCALL-BRIDGE VERSION -> "
                FUNCTION TRIM(WS-OUTPUT)
        MOVE 0 TO RETURN-CODE
    ELSE
        DISPLAY "version-check: POLYCALL-BRIDGE VERSION failed: "
                FUNCTION TRIM(WS-OUTPUT)
        MOVE 1 TO RETURN-CODE
    END-IF
    STOP RUN.
