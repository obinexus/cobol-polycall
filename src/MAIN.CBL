      * CBLPolyCall Main Program v1.1
      * OBINexus Aegis Engineering - PolyCall COBOL Client
      * Technical Lead: Nnamdi Michael Okpala
      *
      * Interactive client over POLYCALL-BRIDGE (src/POLYCALL.CBL).
      * Reads one operation per line from standard input; end of input
      * exits. Non-interactive use: pipe the lines in, e.g.
      *   printf 'VERSION\nCONNECT\nnode-a\n5\n' | target/cblpolycall

       IDENTIFICATION DIVISION.
       PROGRAM-ID. CBLPOLYCALL-MAIN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-OPERATION            PIC X(20).
       01  WS-INPUT-DATA           PIC X(1024).
       01  WS-OUTPUT-DATA          PIC X(1024).
       01  WS-RESULT-CODE          BINARY-LONG VALUE 0.
       01  WS-RESULT-DISPLAY       PIC -(9)9.
       01  WS-CONTINUE-FLAG        PIC X VALUE "Y".
       01  WS-FAILURES             BINARY-LONG VALUE 0.

       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           DISPLAY "CBLPolyCall Client v1.1 - Aegis Engineering"
           DISPLAY "=============================================="

           PERFORM UNTIL WS-CONTINUE-FLAG = "N"
               DISPLAY " "
               DISPLAY "Available Operations:"
               DISPLAY "1. CONNECT          (open a peer node)"
               DISPLAY "2. SEND_MESSAGE     (peer payload)"
               DISPLAY "3. RECEIVE_MESSAGE"
               DISPLAY "4. DISCONNECT"
               DISPLAY "5. EXIT"
               DISPLAY "   VERSION | VALIDATE | CALL"
               DISPLAY " "
               DISPLAY "Enter operation: " WITH NO ADVANCING
      *        a blank line or end of input exits
               MOVE "EXIT" TO WS-OPERATION
               ACCEPT WS-OPERATION
               IF WS-OPERATION = SPACES
                   MOVE "EXIT" TO WS-OPERATION
               END-IF
               MOVE SPACES TO WS-INPUT-DATA

               EVALUATE WS-OPERATION
                   WHEN "1"
                   WHEN "CONNECT"
                       MOVE "CONNECT" TO WS-OPERATION
                       DISPLAY "Enter node id: " WITH NO ADVANCING
                       ACCEPT WS-INPUT-DATA
                       PERFORM CALL-BRIDGE
                   WHEN "2"
                   WHEN "SEND_MESSAGE"
                       MOVE "SEND_MESSAGE" TO WS-OPERATION
                       DISPLAY "Enter peer and message: "
                           WITH NO ADVANCING
                       ACCEPT WS-INPUT-DATA
                       PERFORM CALL-BRIDGE
                   WHEN "3"
                   WHEN "RECEIVE_MESSAGE"
                       MOVE "RECEIVE_MESSAGE" TO WS-OPERATION
                       PERFORM CALL-BRIDGE
                   WHEN "4"
                   WHEN "DISCONNECT"
                       MOVE "DISCONNECT" TO WS-OPERATION
                       PERFORM CALL-BRIDGE
                   WHEN "VERSION"
                       PERFORM CALL-BRIDGE
                   WHEN "VALIDATE"
                       DISPLAY "Enter configuration path: "
                           WITH NO ADVANCING
                       ACCEPT WS-INPUT-DATA
                       PERFORM CALL-BRIDGE
                   WHEN "CALL"
                       DISPLAY "Enter endpoint service operation json: "
                           WITH NO ADVANCING
                       ACCEPT WS-INPUT-DATA
                       PERFORM CALL-BRIDGE
                   WHEN "5"
                   WHEN "EXIT"
                       MOVE "N" TO WS-CONTINUE-FLAG
                   WHEN OTHER
                       DISPLAY "Invalid operation. Please try again."
               END-EVALUATE
           END-PERFORM

           DISPLAY "CBLPolyCall Client terminated."
           IF WS-FAILURES > 0
               MOVE 1 TO RETURN-CODE
           ELSE
               MOVE 0 TO RETURN-CODE
           END-IF
           STOP RUN.

       CALL-BRIDGE.
           CALL "POLYCALL-BRIDGE" USING WS-OPERATION,
                                        WS-INPUT-DATA,
                                        WS-OUTPUT-DATA,
                                        WS-RESULT-CODE
           END-CALL
           IF WS-RESULT-CODE NOT = 0
               ADD 1 TO WS-FAILURES
           END-IF
           MOVE WS-RESULT-CODE TO WS-RESULT-DISPLAY
           DISPLAY "Operation: " FUNCTION TRIM(WS-OPERATION)
           DISPLAY "Result Code: " FUNCTION TRIM(WS-RESULT-DISPLAY)
           DISPLAY "Output: " FUNCTION TRIM(WS-OUTPUT-DATA).
