      *> POLYCALL-STRUCTURES -- work fields for the cobpc_* C shim
      *> (src/cobpolycall.h). Text fields have these exact sizes: input
      *> ends at the trailing spaces, output is space padded. Integers are
      *> BINARY-LONG (int32), passed BY REFERENCE. Byte data (payloads,
      *> JSON) is a field of the caller's size plus an explicit length or
      *> capacity. Valid in fixed and free source format.
       01  POLYCALL-API.
           05  PC-STATUS               BINARY-LONG VALUE 0.
           05  PC-HANDLE               BINARY-LONG VALUE 0.
           05  PC-TIMEOUT-MS           BINARY-LONG VALUE 5000.
           05  PC-RUN                  BINARY-LONG VALUE 1.
           05  PC-ABI                  BINARY-LONG VALUE 0.
           05  PC-LEN                  BINARY-LONG VALUE 0.
           05  PC-CAP                  BINARY-LONG VALUE 0.
           05  PC-VERSION              PIC X(64).
           05  PC-STATUS-NAME          PIC X(512).
           05  PC-DETAIL               PIC X(512).
           05  PC-CONFIG-PATH          PIC X(512).
           05  PC-NODE-ID              PIC X(64).
           05  PC-PEER-ID              PIC X(64).
           05  PC-MESSAGE-ID           PIC X(64).
           05  PC-SENDER               PIC X(64).
           05  PC-ENDPOINT             PIC X(128).
           05  PC-BIND-ENDPOINT        PIC X(128).
           05  PC-TARGET               PIC X(128).
           05  PC-AUTH-TOKEN           PIC X(128).
           05  PC-SERVICE              PIC X(64).
           05  PC-OPERATION            PIC X(64).
