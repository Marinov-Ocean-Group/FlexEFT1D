PROGRAM AMAssim
USE sub_mod
implicit none
real(4)            :: start,finish,t2,t1,AMaccR,DRaccR
real, parameter    :: OtherIGf  = 1d0 ! factor multiplying IG value for 
logical, parameter :: BURNIN_YES   = .TRUE.
logical, parameter :: BURNIN_NO    = .FALSE.
! All parameters varied in an Identical Twin Test assimilation.
integer :: i,k,row,col
integer :: RunITT = No

real    :: dum  ! Log-likelihood with the mean value of parameters
integer :: Readfile   = NO  ! Read parameter set from "out/Best.out", and start from Subpcurr
!    To run a simulation using best-fit parameters from a given Assimilation,
!    save the file "out/status" from that assimilation as "out/Best.out",
!    then, run this program with nruns = 1, and Readfile = 1, (after compiling)

namelist /MCMCrun/    nruns, BurnInt,EnsLen, NDays, Readfile
character(128)     :: inbuf
character(15)      :: dumchar
      
call cpu_time(start) 
!  open the namelist file and read station name.
open(namlst,file='Station.nml',status='old',action='read')
read(namlst,nml=MCMCrun)
close(namlst)

!Initialize the Arrays of model parameters with the biological model chosen
call SetUpArrays

allocate(subpguess(Np2Vary))
allocate(  subppro(Np2Vary))
allocate( subppro2(Np2Vary))
allocate( subpbest(Np2Vary))  
allocate( subpcurr(Np2Vary))  
allocate( subpmean(Np2Vary))  
allocate(   cffpar(Np2Vary))  
allocate( Apvguess(Np2Vary))  
allocate(  Apvbest(Np2Vary))  
allocate(  Apvcurr(Np2Vary))  
allocate(  Apvmean(Np2Vary))  
allocate(subpcurrmean(Np2Vary))  
allocate(sdev(Np2Vary*(Np2Vary+1)/2)) 

! Initialize the 1D model:
 call Model_setup

! Sigma and SSqE vectors:
allocate(sigmabest(NDTYPE))   
allocate(sigmamean(NDTYPE))   
allocate( BestSSqE(NDTYPE))    
allocate(   TwtSSE(NDTYPE))   
allocate(     dumE(NDTYPE))

!$ initialize the random number generator with a seed
call sgrnd(17001)

! (Integer values: 1 = Yes, 0 = No)
! for ITT, start with Subpbest !
RunITT = No
  
! An initial guess that is some factor times the inital parameter estimates 
do i = 1, Np2Vary
   subpguess(i) = OtherIGf*Npv(i)
enddo
!  Set current to guess
subpcurr    = subpguess
subppro     = subpguess
subppro2    = subpguess

sigmabest   = sigma

! A very large, negative number for very low probability
BestLogLike = -1d12  
startrun    = 0
      
!$  Estimate the priors based on initial parameter values
call EstimatePriors(PriorCvm, InvPriorCvm, error)

! Set the labels for the standard deviations for each type of observation 
call SetSigmaLabels
      
!!$ Take the intial Covariance matrix to be the Prior Covariance Matrix
!!$ (these are in compacted form)
! The factor of 0.1 is just a guess to tune the initial proposal function for this particular example
! PriorCvm is the prior covariance matrix generated by the subroutine EstimatePriors 
! Cvm is the Covariance Matrix for parameters
Cvm = PriorCvm

write(6, *) 'Initial Covariance matrix = '
do row = 1, Np2Vary
   write(6,3000) (Cvm(row*(row-1)/2+col), col = 1, row )
end do

Rwtold = 1d0  ! Set the initial weight equal to One
      
!!$ The Proposal Covariance Matrix
!!$ Set the Proposal covariance matrix, by scaling the Parameter Covariance matrix

Pcvm = Cvm*Spcvm/Np2Vary  ! Np2Vary = d in p. 11 of Laine 2008

!!$ Add a small term to the diagonal entries, so that the matrix will not be singular. 
do k = 1, Np2Vary
   Pcvm(k*(k+1)/2) = Pcvm(k*(k+1)/2) + CvEpsilon*Spcvm/Np2Vary
enddo

!!$ Calculate the Cholesky factor for Pcvm, which is called Rchol here. 
!  The Pcvm and Rchol will not vary until the burn-in finishes.
call cholesky(Pcvm,Np2Vary,Np2Vary*(Np2Vary+1)/2,Rchol,nullty,error)
   
write(6, *) 'Initial Proposal Covariance matrix = '

DO row = 1, Np2Vary
   write(6,3000) (Pcvm(row*(row-1)/2+col), col = 1, row )
End do

write(6, *) 'Cholesky factor for Proposal Covariance matrix = '

DO row = 1, Np2Vary
   write(6,3000) ( Rchol(row*(row-1)/2+col), col = 1, row )
Enddo

!------
if(Readfile .eq. Yes) then
   
   write(6, *) ' Reading Parameters from file Best_par'
   Open(bpfint, file = bpfn, status='old',iostat=err,action='read')
   
   IF (err /= 0) THEN
      write(6,*) 'open ', TRIM(bpfn),' fails'
      stop
      close(bpfint)
   ELSE
      inbuf(1:1) = '*'  ! comment flag 
      do while( inbuf(1:1) .eq. '*' )
         read(bpfint,'(a128)') inbuf
      end do
      write(6,'(a128)') inbuf
      read(inbuf,1200) dumchar, startrun
      write( 6, 1200) dumchar, startrun
      read(bpfint,'(a128)') inbuf
      do while( inbuf(1:1) .eq. '*' )
         read(bpfint,'(a128)') inbuf
      end do
      write(6,'(a128)') inbuf

      read(inbuf,1220) dumchar, BestLogLike
      write( 6,  1220) dumchar, BestLogLike

   
         do i = 1, Np2Vary
           read(bpfint,'(a128)') inbuf

           do while( inbuf(1:1) .eq. '*' )
              read(bpfint,'(a128)') inbuf
           end do

          
          write( 6, 1010    ) i
          write( 6, '(a128)') inbuf
!!!!  This Reading Section needs Fixing !!
!!!    Now that the parameters can be different for each incubation, we have to read them
!!!    from a separate file for each incubation.
! Or just read from one file   "out/Best.out", above
! And use those values for ALL incubations

       read(inbuf, 1320) dumchar,        &                     
        Apvcurr(i),Apvguess(i),Apvbest(i),Apvmean(i)

       write(   6, 1320) dumchar,        &                
        Apvcurr(i),Apvguess(i),Apvbest(i),Apvmean(i)
         
      enddo ! loop over parameters

    close(bpfint)
    subpcurr = Npv_(Apvcurr)
    subpguess= Npv_(Apvguess)
    subpbest = Npv_(Apvbest)
    subpmean = Npv_(Apvmean)
    subppro  = subpcurr  ! This way, if subpcurr was read from file, start with those values
    do i = 1, Np2Vary
       write(6,101) ParamLabel(i), subppro(i), Apvcurr(i)
    enddo

   ENDIF 
endif
! But, if I want to start a new Assim'n from the Best position from a previous one
! xpro = subpbest ! Start with the Best !
! for ITT, start with Subpbest !
! for all parameters that are NOT varied
       
  If( (RunITT .Eq. Yes) .And. (Readfile .Eq. Yes) ) Then
        
!!$   Set all parameters to their Best values from the file           
!!$  EXCEPT those to be varied
   subpcurr = subpguess
   subpguess= subpbest
   subppro  = OtherIGf * subpbest
   
   BestLogLike = -1d12  !A large, negative number for very low probability
      
  elseif( RunITT .Eq. Yes .And. Readfile .Eq. No ) Then
          
    subpbest = subpguess
    ! except for parameters that are varied in the assimilation
    subpcurr = subpguess
    subppro  = OtherIGf * subpguess
          
  else if( Readfile .eq. No ) then

     ! If NOT reading parameters from files, set subpbest = xpro
     subpbest = subppro 

  Endif                ! end of if to read parameter values from best position
      

!  First, one simulation, to initialize all routines
!  This avoids the problem that
!  Parameter Values will be read from the data file on the initial run;
! if they are different than the values in this program for Assimilated Params,
! this could return a much different cost. 
! If the cost with the Values in the Parm file is much lower,
! the assimilation may almost never accept any new parameter sets)

!!$  Reset subpmean to Zero for the new run
   subpmean     = 0d0
   subpcurrmean = 0d0
   sigmamean    = 0d0

   if(nruns .gt. 1) then

!!$ Parameter Ensemble file (only one file needed)
     open(epfint,file=epfn,status='replace',action='write')

     write(epfint,1800) (ParamLabel(i), i = 1, Np2Vary)

!!$ Sigma (standard error) Ensemble file (One file needed)
     open(esfint,file=esfn,status='replace',action='write')
     write(esfint,1900) (SigmaLabel(i), i = 1,NDTYPE), &
                        (SSqELabel(i),  i = 1,NDTYPE)

!!$ Output Ensemble files to store the ensemble of simulated values
!   Be consistent with subroutine modelensout

     open(eofint, file=eofn,status='replace',action='write')
     write(eofint,'(5(A8))')  'RunNo   ',   &
                              'DOY     ',   &
                              'Depth   ',   &
                              'Name    ',   &
                              'Value   '
   endif


   AMacc       = 0
   DRacc       = 0
   MeanLogLike = 0d0
   write(6, *) ' Testing whether cost remains',     &
               ' the same on subsequent calls '
   ! Write output 
   DO i = 1, 1
      ! run with the Best Parameters, writing to the best output file
      call cpu_time(t1)
      open(bofint, file=bofn,action='write',status='replace')

      savefile = .FALSE.
      call model(bofint, subppro, SSqE )
      CurrLogLike = CalcLogLike(SSqE,sigma,subppro)
      write(6, 1001) i,  CurrLogLike

      close(bofint)
      call cpu_time(t2)
      print '("One model run takes ",f8.3," seconds.")', t2-t1 
   ENDDO
   CurrSSqE = SSqE
      
!Start "Burn-in", i.e., spin-up the MC before starting to adapt the proposal function
 jrun  = startrun + 1
 call MCMC_adapt(BURNIN_YES)
 AMaccR = real(AMacc)/real(jrun-startrun)
 DRaccR = real(DRacc)/real(jrun-startrun)

 write(6,*) 'During Burn-in, acceptance rate of the first  move: ', AMaccR
 write(6,*) 'During Burn-in, acceptance rate of the second move: ', DRaccR

!------------------------------------------------------------------------
! End of burn-in...' 
!------------------------------------------------------------------------
 write(6, *) ' After Burn-in, Proposal Covariance matrix = '
 DO row = 1, Np2Vary
    write(6,3000) (Pcvm( row*(row-1)/2 + col ), col = 1, row )
 end do
 write(6, *) '  '

 write(6, 1050)
!
!------------------------------------------
!	HERE STARTS THE MAIN LOOP
!------------------------------------------
     ! The counter for the jth run
     jrun        = startrun + 1

     ! Total number of runs
     nruns       = nruns + startrun
     AMacc       = 0
     DRacc       = 0
     BestLogLike = -1d12  ! A very large, negative number for very low probability
     sdev(:)     = 0 !Variance of parameters
     sdwt        = 1 !Weight of SD
 
 call MCMC_adapt(BURNIN_NO)
 write(6, *) ' Finished the main loop for assimilation! '
 write(6, *)

    write(6, *) ' Proposal Covariance matrix = '
    DO row = 1, Np2Vary
       write(6,3000) ( Pcvm( row*(row-1)/2 + col ), col = 1, row )
    end do

    write(6, *) ' Writing the last entry in',          &
                ' the ensembles of simulated values.'
!!$ write output ot Ensemble file for simulated values

    call modelensout(eofint, jrun, subpcurr, dumE)
    close(eofint)

!	end of main loop...now we are basically finished and
!	just produce a few summary statistics
    if( nruns .gt. 1 ) then
       ! Write the Ensemble of Parameters for each Incubation simulated.
       ! Write Ensemble file(s) (Run #, Cost and Parameters)

      cffpar= Apv_(subpcurr)
      write(epfint,1850) jrun, CurrLogLike, (cffpar(i), i = 1, Np2Vary)
      write(esfint,1850) jrun, CurrLogLike,  (sigma(i), i = 1, NDTYPE), &
                         (CurrSSqE(i),i= 1, NDTYPE)
    endif

    call write_bestpar
    call write_bestsigma  

    !	now re-run model with  Mean parameters and calculate the Cost
    !
    if( nruns - startrun .gt. 1000 ) then
       write(6,*) '                              '
       write(6,*) ' Running with the Mean parameter set ... '
       write(6,*) '                              '
       write(6,*) ' calculated Mean of LogL ', MeanLogLike

       call modelnooutput(subpmean, SSqE)
       dum=CalcLogLike(SSqE,sigmamean,subpmean)
       write( 6,*) 'LogL with subpmean is', dum
    endif

    write(6, 4010)
    write(6, 4020)
    write(6, 4030)
    do k = 1, Np2Vary  ! diagonal elements of the Covariance matrix are the variances
       write(6, 4000) k, ParamLabel(k),         &
           Cvm(k*(k+1)/2)**0.5, sdev(k*(k+1)/2)**0.5
    enddo

4010    format(25x)
4020    format(' ----------------------------------------------------')
4030    format('Standard Deviations (normalized) of the',              &
               'Parameters varied ',/,2x,4x,1x,'   Parameter   ',1x,   &
               ' whole ensemble',2x,' after burn in')
4000    format(2x,i4,1x,a15,1x,100(1pe12.3,2x) )
        write(6, 4020) 
        write(6, 4010) 

!
!now re-run model with Best parameters, calculate Cost and produce output
!
     
    IF( NRUNS + READFILE .GT. 0 ) THEN

        write( 6, *) ' Running with the Best parameter set ',   &
              'and writing output...'
        write( 6, *) ' (using the standard routine (output)     '
        write( 6, *) '                              '

        open(bofint, file=bofn, action='write',status='replace')
        savefile = .FALSE.
        call model(bofint, subpbest, SSqE)
        close(bofint)

        dum = CalcLogLike(SSqE, sigmabest, subpbest)
        write( 6,*) 'LogL with Subpbest is', dum

        write(6, *) ' Running with the Best parameter set',   &
                    ' and writing output...'
        write(6, *) ' (using the nooutput routine      '
        write(6, *) '                              '
       
        savefile = .TRUE.

        call modelnooutput(subpbest, SSqE)

        dum = CalcLogLike(SSqE, sigmabest, subpbest)
        write( 6, *) 'LogL with Subpbest is', dum
        write( 6, *) '                              '

    ENDIF
      
101  format(A8, 2(1x, 1pe12.2))
1001 format(/,'  Call # ',i4,', LogL = ',1pe13.3,/)
1010 format(5x,' i = ',i4,', read the following line:')
1050 format(/,'Starting the main loop to Assimilate ',/) 
1200 format(a15,1x,i16)
1210 format('** % 1st Accept. = ',1x,1f8.2,                         &
            '     ** % 2nd Accept. = ',1f8.2)
1220 format(a25,1x,1pe11.3)
1300 format('*** LogL:    New ',1pe11.3,'     Curr ',1pe11.3,  &
           '     Best ',1pe11.3)
1310 format('*** LogL:    New ',1pe11.3,'     Curr ',1pe11.3,  &
           '     Best ',1pe11.3,'     Mean ',1pe11.3)

1320 format(    a15,1x,1pe20.13,4(1x,1pe20.3), /) 

1350 format('LogL:    New ',f10.1,'   Curr ',f10.1,'   Best ',f10.1, &
           '   acceptance = ',f10.2,' %',/,                          &
           ' with Subpcurr  = ',100(f11.5,/,70x) )
1800 format('Run        LogL     ', 100(a15) )
1850 format(i9,1x,100(1pe12.3,2x))
1900 format('Run        LogL     ', 100(a12,2x) )
3000 format(5x,20(1pe8.1,1x))
!  call End_model
  call cpu_time(finish)
  print '("Time = ",f8.3," hours.")', (finish-start)/3600.0 

END PROGRAM AMAssim
