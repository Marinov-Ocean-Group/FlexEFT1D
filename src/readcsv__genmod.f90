        !COMPILER-GENERATED INTERFACE MODULE: Thu Sep 29 14:19:27 2016
        MODULE READCSV__genmod
          INTERFACE 
            SUBROUTINE READCSV(FILENAME,NROW,NCOL,DAT)
              INTEGER(KIND=4), INTENT(IN) :: NCOL
              INTEGER(KIND=4), INTENT(IN) :: NROW
              CHARACTER(LEN=20), INTENT(IN) :: FILENAME
              REAL(KIND=8), INTENT(OUT) :: DAT(NROW,NCOL)
            END SUBROUTINE READCSV
          END INTERFACE 
        END MODULE READCSV__genmod
