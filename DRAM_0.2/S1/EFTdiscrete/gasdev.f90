module gasdevf90
  implicit none

contains
  real(8) function gasdev() result(gval)
    use mtmod
    implicit none
    real(8) :: FAC, R, V1, V2, X
    real(8), save :: GSET
    integer, save :: ISET = 0

    IF (ISET.EQ.0) THEN
       R = 99 
       do while( R .ge. 1.0d0 )
          V1= 2.0d0*grnd() - 1.0d0
          V2= 2.0d0*grnd() - 1.0d0
          R = V1**2 + V2**2
       end do
       FAC = SQRT( -2.0d0*LOG(R)/R )
       GSET   = V1*FAC
       gval = V2*FAC
       ISET=1
    ELSE
       gval=GSET
       ISET=0
    ENDIF

    RETURN
  END function gasdev

end module gasdevf90
