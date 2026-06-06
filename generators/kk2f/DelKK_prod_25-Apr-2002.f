      PROGRAM DelKK
*****************************************************************************
*****************************************************************************
*
* Main program for production of MC events fro Delphi with KK2f
*
*****************************************************************************
*****************************************************************************
      IMPLICIT NONE

*
      INTEGER            ninp, nout
      COMMON /c_MainPro/ ninp, nout

* Length of xpar
      INTEGER          imax
      PARAMETER        (imax = 10000)
      DOUBLE PRECISION xpar(imax)

      INTEGER          igroup, ngroup, nevt, loop, iev
      DOUBLE PRECISION xSecPb, xErrPb

      INTEGER          ijklin, ntotin, ntot2n


      REAL ECMS

* PJH/US 25-apr-2002 add some DelKK flags as common blocks
      INTEGER IFRM,KINT,KQSR,KHAD,KBCF,KDCY,KWSB
      COMMON/DELKKF/IFRM,KINT,KQSR,KHAD,KBCF,KDCY,KWSB

      REAL*4 XHAD
      COMMON/DELKKH/XHAD

      REAL*4 GETHAD
      EXTERNAL GETHAD

      DOUBLE PRECISION VMAX

* Initialise FFREAD
      INTEGER NFFSPC
      REAL SPACE
      PARAMETER (NFFSPC=500)
      COMMON/CFREAD/SPACE(NFFSPC)
      INTEGER LFFIN

* Lab number stuff
      INTEGER LTEMP
      INTEGER LABID(46)
      INTEGER LABNUM,LABPOS
      INTEGER IHTP,KHTP,JHTP
      CHARACTER*4 LABO
      CHARACTER*184 LABN

      INTEGER NRUN

* Output from KK2f
      INCLUDE '../KK2f/KK2f.h'
      DOUBLE PRECISION WtMain,WtCrud

      DOUBLE PRECISION WTSUMALL,WTMOD
      SAVE WTSUMALL

      INTEGER IEVTOP
      INTEGER IOUT,LOUT

* PJH 10-Dec-2001
* Tau Polarization
* TPOL1 = polarisation of tau+
* TPOL2 = polarisation of tau-
      REAL*4 TPOL1,TPOL2
      COMMON /TLPOL/ TPOL1,TPOL2


* PJH 14-Feb-2002
* Protection against unhadronized events
      INCLUDE 'DelKK_Flags.h'
      INTEGER n_HadErr
*

*
*     PYTHIA Bose Einstein correlation treatment
*
      INTEGER MSTJ51,MSTJ52,MSTJ53,MSTJ54,TUNE
      REAL PRJ92, PRJ93, PRJ94
      COMMON / PYBE / MSTJ51,MSTJ52,MSTJ53,MSTJ54,TUNE,PRJ92, PRJ93,
     &  PRJ94

*----------------------------------------------------------------------------
      DATA IOUT /6/
      DATA LABN(1:36) /'WIENBELGNBI HELSCDF LAL LPNHSACLSTRA'/
      DATA LABN(37:72) /'KARLWUPPLIVEOXFORAL ATHEANTUDEMOBOLO'/
      DATA LABN(73:108) /'GENOMILAPADUROMATRIETORINIKHBERGOSLO'/
      DATA LABN(109:144) /'CRACWARSSANTVALELUNDSTOCUPPSAMESSERP'/
      DATA LABN(145:164) /'DUBNLISBCERNFARMSNAK'/
      DATA LABN(165:184) /        'LYONGRENMARSCCPNBAST'/
      DATA LABID /110,200,310,410,510,520,530,540,550,610,
     *            620,710,720,730,810,820,830,910,920,930,
     *            940,950,960,970,1010,1110,1120,1210,1220,
     *            1310,1320,1410,1420,1430,1510,1610,1620,
     *            1710,2000,1990,1980,560,570,580,500,590/

*----------------------------------------------------------------------------

      SAVE

*----------------------------------------------------------------------------

** --------------------------------------------------------------------------
** -- Initialisation --------------------------------------------------------
** --------------------------------------------------------------------------
      ninp =5   ! standard input
      nout =16  ! general output for everybody including glibk
      OPEN(nout,FILE='./DelKK_tmp.out',STATUS='UNKNOWN')
      REWIND(nout)
      CALL GLK_SetNout(nout)

* Initialise FFREAD
      CALL FFINIT(NFFSPC)
      LFFIN=19
      CALL FFSET('LINP',LFFIN)
      CALL FFSET('SIZE',6)

* Set FFREAD flags
* Laboratory Identifier
      CALL FFKEY('LABO',  LTEMP,  4,'MIXED')
* Run Number
      CALL FFKEY('NRUN',  NRUN,   1,'INTEGER')
* Number of events to produce
      CALL FFKEY('NEVT',  NEVT,   1,'INTEGER')
* Centre of mass Energy
      CALL FFKEY('ECMS',  ECMS,   1,'REAL')

* Fermion flavour
*  1 = down
*  2 = up
*  3 = strange
*  4 = charm
*  5 = Beauty
* 10 = Inclusive hadrons
* 13 = muons
* 15 = taus
      CALL FFKEY('IFRM',  IFRM,   1,'INTEGER')

* ISR-FSR Interference
*  0 = Interference Off
*  2 = Interference On
      CALL FFKEY('KINT',  KINT,   1,'INTEGER')

* Radiation from Quarks
* -1 = in PYTHIA but with correction to total cross-section
*  0 = in Pythia
*  1 = in KK
      CALL FFKEY('KQSR',  KQSR,   1,'INTEGER')

* Hadronization
*  0 = off
*  1 = on
      CALL FFKEY('KHAD',  KHAD,   1,'INTEGER')

* B/C fragmentation
*  0    = no update b/c fragmentation parametrs
*  NNNN = use update to b/c frag. version NNNN [0402]
      KBCF = 0
      CALL FFKEY('KBCF',  KBCF,   1,'INTEGER')

* Decay tables
*  0    = no update to decay tables
*  NNNN = use update to decay tables version NNNN [0402]
      KDCY = 0
      CALL FFKEY('KDCY',  KDCY,   1,'INTEGER')

* BSW matrix elements for semileptonic b and c decays
* 0     = do not use it
* 1     = use it
      KWSB = 0
      CALL FFKEY('KWSB',  KWSB,   1,'INTEGER')
*
* PYTHIA Bose Einstein correlation treatment
*
* Bose Einstein correlations controlled as in PYTHIA
*  0 = Do nothing
*  1 = exponential parameterization
*  2 = gaussian parameterization
      MSTJ51 = 0
      CALL FFKEY('MSTJ51',MSTJ51,1,'INTEGER')

* Number of mesons participating in BE
      MSTJ52 = 0
      CALL FFKEY('MSTJ52',MSTJ52,1,'INTEGER')

* Bose Einstein correlation applied tomeason from:
*  0 for BE applied on mesons from the whole event
*  1 BE applied on mesons within a W only
      MSTJ53 = 0
      CALL FFKEY('MSTJ53',MSTJ53,1,'INTEGER')

* Bose Einstein model 
*   0 = BE0
*   1 = BE3
*   2 = BE32
      MSTJ54 = 0
      CALL FFKEY('MSTJ54',MSTJ54,1,'INTEGER')

* PRJ92 is input to PYTHIA/JETSET PARJ(92) for:
*  'lambda' parameter suggested   1.1 for BE0,
*                                 2.0 for BE3,
*                                1.35 for BE32
*                                1.11 for BE32 gauss+alternative tuning
*                                1.735 for BE32 exp.param.+alternative tuning
      PRJ92 = 0.
      CALL FFKEY('PRJ92', PRJ92, 1,'REAL')

* PRJ93 is input to PYTHIA/JETSET PARJ(93) for:
*  hbar/r(fm) parameter suggested 0.3 for BE0,
*                                 0.3 for BE3,
*                                0.34 for BE32
*                                0.37 for BE32 gauss+alternative tuning
*                                0.261 for BE32 exp.param.=alternative tuning
      PRJ93 = 0.
      CALL FFKEY('PRJ93', PRJ93, 1,'REAL')

* PRJ94 is additional parameter handling 'distance' between strings
      PRJ94 = 0.
      CALL FFKEY('PRJ94', PRJ94, 1,'REAL')

* Alternative Bose_Einstein tuning (J.d'Hondt)
*  0 = standard DELPHI setup
*  1 = to be used with exponential parameterization of BE
*  2 = to be used with gaussian parameterization of BE
      TUNE = 0
      CALL FFKEY('TUNE', TUNE, 1,'INTEGER')

* Read FFREAD flags
      CALL FFGO

* Decode lab ID
      CALL UHTOC(LTEMP,4,LABO,4)
      LABNUM = 1
      LABPOS = 1
      DO 110 IHTP=1,181,4
       KHTP=IHTP+3
       JHTP=KHTP/4
        IF(LABN(IHTP:KHTP) .EQ. LABO) THEN
         LABNUM=LABID(JHTP)
         LABPOS=JHTP
         WRITE(*,*) 'Laboratory ',LABO,' recognized'
         WRITE(*,*) 'Lab number set to ',LABNUM
        ENDIF
 110  CONTINUE
      IF(LABNUM.EQ.1) THEN
        WRITE (*,1000) LABO
        STOP
      ENDIF
 1000 FORMAT(' Laboratory ',A4,' not recognized - abort')

* Initialise Random Number for KK
c-pjh      ijklin = 54217137
      ijklin=nrun+10000*labnum
      ntotin=0
      ntot2n=0
      WRITE(*,*) 'Random number seed set to ',ijklin
      CALL PseuMar_Initialize(ijklin,ntotin,ntot2n)

* Initialise Random Number Generator used by Tauola
c-pjh 7-may-2003 
c- Tauloa uses RANMAR for random number generation it is not 
c- Initialised by KK.
      CALL RMarIn(ijklin,ntotin,ntot2n)

* Initialise Lund Output
      LOUT = 21
      OPEN(LOUT,FILE='./lund.output',FORM='UNFORMATTED',status='UNKNOWN')

* Initialise counters
      WTSUMALL = 0.0D0
      IEVTOP = 0

* PJH 14-Feb-2002
* Protection against unhadronized events
      n_HadErr = 0

* Write out number of events requested
      WRITE(   6,*)   nevt,' requested events '
      WRITE(nout,*)   nevt,' requested events '

* Read data for main program
* Read general defaults
      CALL KK2f_ReaDataX(    './.KK2f_defaults', 1,imax,xpar)
* Read user input
      CALL KK2f_ReaDataX(         './DelKK.inp', 0,imax,xpar)

* Overwrite futher input here
* Center-of-mass Energy
      XPAR(1)=DBLE(ECMS)
* cut at 2 GeV for generation of ffbar pair ! vmax=1.-s'/s
* PJH 20-May-2001 - set vmax cut to 2 GeV to remove low mass region.
      IF(IFRM.LE.10)THEN	
         XPAR(17)=DBLE(1.-(2.0/ECMS)**2)
      ENDIF	

* ISR-FSR interference
      XPAR(27)=DBLE(KINT)

* PJH 26-Mar-2001 - to handle KQSR = -1
* Treatment of FSR for quarks 
* FSR for quarks inside KK      
*  Computation done using CEEX for v < vmax_GPS else EEX
      IF(KQSR.EQ.1)THEN
       IF(IFRM.LE.10)THEN
        XPAR(29)=DBLE(KQSR)
       ENDIF
      ENDIF
* FSR off in KK (no FSR correction to cross-section)
*  Computation is done using EEX (no ISR*FSR)
      IF(KQSR.EQ.0)THEN
       IF(IFRM.LE.10)THEN
        XPAR(29)=DBLE(KQSR)
        XPAR(518)=0.00D0 ! vmax_GPS for d quarks
        XPAR(528)=0.00D0 !              u
        XPAR(538)=0.00D0 !              s
        XPAR(548)=0.00D0 !              c
        XPAR(558)=0.00D0 !              b
       ENDIF
      ENDIF   
* FSR off in KK (with FSR correction to cross-section)
* Computation is done using CEEX for v < vmax_GPS else EEX
* PJH 6-apr-2001 - vmax cut minimum now corresponds to 20 GeV
      IF(KQSR.EQ.-1)THEN
       IF(IFRM.LE.10)THEN
        XPAR(29)=0.0D0   ! KeyQSR=0
        XPAR(21)=0.0D0   ! KeyFSR=0
        XPAR(53)=2.0D0   ! KeyQCD=2
        VMAX=DBLE(MIN(0.99,(1.0-((20.0/ECMS)**2))))
        XPAR(518)=VMAX   ! vmax_GPS for d quarks
        XPAR(528)=VMAX   !              u
        XPAR(538)=VMAX   !              s
        XPAR(548)=VMAX   !              c
        XPAR(558)=VMAX   !              b
       ENDIF
      ENDIF

* Hadronization
      XPAR(50)=DBLE(KHAD)

* Cut above which hadronization occurs
* PJH 20-May-2001 - set to 2.0 GeV (same as VMAX) 
* hadmin, 0.2 (def of KK) 
* Value set by hand here overrides other inputs
      XPAR(51)=2.0d0

* Fermion Flavour
      XPAR(401)=0.0D0
      XPAR(402)=0.0D0
      XPAR(403)=0.0D0
      XPAR(404)=0.0D0
      XPAR(405)=0.0D0
      XPAR(413)=0.0D0
      XPAR(415)=0.0D0
      IF (IFRM.EQ.1) THEN
       XPAR(401)=1.0D0
      ELSE IF (IFRM.EQ.2) THEN
       XPAR(402)=1.0D0
      ELSE IF (IFRM.EQ.3) THEN
       XPAR(403)=1.0D0
      ELSE IF (IFRM.EQ.4) THEN
       XPAR(404)=1.0D0
      ELSE IF (IFRM.EQ.5) THEN
       XPAR(405)=1.0D0
      ELSE IF (IFRM.EQ.10) THEN
       XPAR(401)=1.0D0
       XPAR(402)=1.0D0
       XPAR(403)=1.0D0
       XPAR(404)=1.0D0
       XPAR(405)=1.0D0
      ELSE IF (IFRM.EQ.13) THEN
       XPAR(413)=1.0D0
      ELSE IF (IFRM.EQ.15) THEN
       XPAR(415)=1.0D0
      ENDIF

* Initialize KK generator
      CALL KK2f_Initialize(xpar)

* PJH/US 25-apr-2002
* Findout what version of the hadronization I am using
      XHAD=GETHAD()

*Initialize Delphi tunning of Pyhtia 
      IF(IFRM.LE.10)THEN
         CALL TUNPY(KQSR,KBCF,KDCY,ijklin)
      ENDIF	

* Initialise quark masses in pythia
      CALL DELKK_SET_PYMASSES(xpar)

* Dump KK tunings
      CALL DELKK_KKFLAGS_DUMP(ijklin,51,61,XPAR)

* Dump pyhtia tunings
      IF(IFRM.LE.10)THEN
         CALL DELKK_PYFLAGS_DUMP(52,62)
      ENDIF	

* PJH 10-Dec-2001
* Initialise helicty version of tauola 
      IF (IFRM.EQ.15) THEN
       CALL DELKKTAUOLA(-1,1)
      ENDIF

* PJH 10-Dec-2001
* Initialise polarisation variables in TPOL
      TPOL1=0.0
      TPOL2=0.0

** -----------------------------------------------------------------------
** -- Main MC loop -------------------------------------------------------
** -----------------------------------------------------------------------
      ngroup = 5000
      iev=0
      DO loop=1,10000000
        DO igroup =1,ngroup
          iev=iev+1
          IF(MOD(iev, ngroup) .EQ. 1) WRITE( 6,*)  'iev= ',iev

* PJH 14-Feb-2002
* Protection against unhadronized events
	  m_DelKK_HadErr = 0


* make single event
          CALL KK2f_Make

* PJH 10-Dec-2001
* call helicty version of tauola for event
          IF (IFRM.EQ.15) THEN
           CALL DELKKTAUOLA(0,1)
          ENDIF

*   Control printouts
*          CALL momprt(' YFSPRO ', 6,iev,1,10,pf1,pf2,qf1,qf2,nphot,sphot,KFfin)
*          CALL dumpri('*momini*', 6,iev,1,10,xf1,xf2,nphox,xphot)
          IF(iev .LE. 10) THEN
             CALL PYgive('MSTU(11)=16')
             CALL PYlist(1)
             CALL PYgive('MSTU(11)=6')
             CALL PYlist(1)
          ENDIF

          CALL KK2f_GetWt(WTMOD,WtCrud)
          WTSUMALL = WTSUMALL + WTMOD
          IEVTOP = IEVTOP + 1

* PJH 10-DEC-2001
*  Add call to DELKKTAUPOL to store info on tau helicity in DELSIM output
          IF (IFRM.EQ.15) THEN
           CALL DELKKTAUPOL
          ENDIF

* Write Printout in DELSIM format
* PJH 14-Feb-2002
* Protection against unhadronized events
	  IF (m_DelKK_HadErr.eq.0) THEN
           CALL DELKKWRITE(LOUT)
          ENDIF
	  IF (m_DelKK_HadErr.eq.1) THEN
           n_HadErr = n_HadErr +1
          ENDIF

          IF (IEV.LE.10) THEN
           CALL PYlist(2)
          ENDIF

          IF (MOD(IEV,100000) .EQ. 0) THEN
            WRITE(IOUT,1002) IEV
            WRITE(IOUT,1005) IEVTOP
            WRITE(IOUT,1007) WTSUMALL
            WRITE(nOUT,1002) IEV
            WRITE(nOUT,1005) IEVTOP
            WRITE(nOUT,1007) WTSUMALL
          ENDIF

          IF(iev  .EQ.  nevt)     GOTO 300
        ENDDO
      ENDDO
 300  CONTINUE


** -----------------------------------------------------------------------
** -- Completion ---------------------------------------------------------
** -----------------------------------------------------------------------
      WRITE(6,*) 'Generation finished '
      WRITE(nOUT,*) 'Generation finished '

      IF(IFRM.LE.10)THEN	
* Check use of Delphi tunning for Jetset/Pythia hadronization
        CALL TUNPY_CONFIRM
      ENDIF
* Final bookkeping, printouts etc.
      CALL KK2f_Finalize 

* PJH 10-Dec-2001
* finalise helicty version of tauola for event
      IF (IFRM.EQ.15) THEN
       CALL DELKKTAUOLA(1,1)
      ENDIF

* Get MC x-section
      CALL KK2f_GetXsecMC(xSecPb, xErrPb)

* Write Ouput
      WRITE(IOUT,1003)
      WRITE(IOUT,1002) IEV
      WRITE(IOUT,1005) IEVTOP
      WRITE(IOUT,1007) WTSUMALL
      WRITE(IOUT,1008) xSecPb,xErrPb
* PJH 14-Feb-2002
* Protection against unhadronized events
      WRITE(IOUT,1009) n_HadErr

      WRITE(nOUT,1003)
      WRITE(nOUT,1002) IEV
      WRITE(nOUT,1005) IEVTOP
      WRITE(nOUT,1007) WTSUMALL
      WRITE(nOUT,1008) xSecPb,xErrPb
* PJH 14-Feb-2002
* Protection against unhadronized events
      WRITE(nOUT,1009) n_HadErr


 1002 FORMAT(1X,I8,' events generated')
 1003 FORMAT(/,' ******************* End of run ********************',/)
 1005 FORMAT(1X,I8,' events written to lund record output file')
 1006 FORMAT(1X,F12.4,' Seconds of CPU time elapsed')
 1007 FORMAT(1X,'Summed weights all events:         ',F20.8)
 1008 FORMAT(1X,'Cross-section: ',F15.5,' +/- ',F15.5,' [pb]')
 1009 FORMAT(1X,'Unhadronized events skipped ',I10)
*

      END


      SUBROUTINE DELKKTAUPOL
*****************************************************************************
*****************************************************************************
*
*     SUBROUTINE DELKKTAUPOL(LUN)
*
*     Purpose: store helicity info of taus by changing
*              helicity -1 tau into a chi which will be handled by DELSIM
*
*     Input: none
*
*     Output:  None
*
*     Called:  Per event
*
* PJH 10-DEC-2001: Routine added to DelKK.f 
*                  Copy of procedure in KOHELT of KORALZ
*
*
*****************************************************************************
*****************************************************************************
      IMPLICIT NONE

      INTEGER N,K,npad
      double precision    P,V      
      COMMON/PYJETS/N,NPAD,K(4000,5),P(4000,5),V(4000,5) 

      INTEGER I
      INTEGER NPART

* PJH 10-Dec-2001
* Tau Polarization
* TPOL1 = polarisation of tau+
* TPOL2 = polarisation of tau-
      REAL*4 TPOL1,TPOL2
      COMMON /TLPOL/ TPOL1,TPOL2

      INTEGER INIT
      DATA INIT/0/
      SAVE INIT
*----------------------------------------------------------------------------

      IF ( INIT.EQ.0 ) THEN
        WRITE(6,1000)
        INIT = 1
      ENDIF

 1000 FORMAT(
     &  /' DELKKTAUPOL: A trick to save tau helicity information'
     &  /' DELKKTAUPOL: Taus with LH helicity flagged as chis')

CC 7-Jan-2002 PJH and IB
CC Code should give us 
CC  (tau+,chi-) for (RH tau+ , LH tau-)
CC or
CC  (chi+,tau-) for (LH tau+ , RH tau-)
CC
CC In KORALZ events were flagged with helicities either 
CC  (+1,-1)     for (RH tau+ , LH tau-)
CC or 
CC  (-1,+1)     for (LH tua+ , RH tau-)
CC
CC In KK we have either 
CC  (-1,-1)     for (LH tau+ , RH tau-)
CC or 
CC  (+1,+1)     for (RH tau+ , LH tau-)
CC
      DO 10 I=1,N
        IF ( K(I,1).EQ.11 ) THEN
          IF ( K(I,2).EQ.-15 .AND. TPOL1.LT.0. ) K(I,2) = -17
          IF ( K(I,2).EQ. 15 .AND. TPOL2.GT.0. ) K(I,2) =  17
c          IF ( K(I,2).EQ. 15 .AND. TPOL2.LT.0. ) K(I,2) =  17
        ENDIF
  10  CONTINUE


      RETURN
      END


      SUBROUTINE DELKKWRITE(LUN)
*****************************************************************************
*****************************************************************************
*
*     SUBROUTINE DELKKWRITE(LUN)
*
*     Purpose: Write LUJETS common to output file
*              on unit LUN in format for DELSIM
*
*     Input:   LUN - output file INTEGER
*
*     Output:  None
*
*     Called:  Per event
*HTP: modified 25/06/96 to write out a final comment line of the form
*HTP: K(1) = 21     LUND code for comment
*HTP: K(2) = 0      Special word containing generator info
*HTP: K(3) = 101    PYTHIA generator ID
*HTP: P(1) = 5.722  PYTHIA version number
*HTP added these entries, 25/2/98
*HTP: P(2) = 7.409  DELPHI-tuned JETSET version number
*HTP: P(3) = 1.12    DELPYT (delphi calling code) version number
*
*
*****************************************************************************
*****************************************************************************
*.----------------------------------------------------------------------
*.
*.
*.  formats: (non-portable!!!)
*.        event records, in the following
*.        format (one record per event):
*.
*.    word 0 : n                    (i)
*.         1 : k(1,1)               (i) \
*.         2 : k(1,2)               (i)  \
*.         3 : k(1,3)               (i)   \
*.         4 : k(1,4)               (i)    \
*.         5 : k(1,5)               (i)     \
*.         6 : p(1,1)               (f)      \
*.         7 : p(1,2)               (f)       \
*.         8 : p(1,3)               (f)        >  repeated n times
*.         9 : p(1,4)               (f)       /
*.        10 : p(1,5)               (f)      /
*.        11 : v(1,1)               (f)     /
*.        12 : v(1,2)               (f)    /
*.        13 : v(1,3)               (f)   /
*.        14 : v(1,4)               (f)  /
*.        15 : v(1,5)               (f) /
*.        16 : k(2,1)
*.       ...
*.     n*7-1 : p(n,4)
*.       n*7 : p(n,5)
*
*.
*.----------------------------------------------------------------------
      IMPLICIT NONE

      INTEGER N,K,npad
      double precision    P,V      
      COMMON/PYJETS/N,NPAD,K(4000,5),P(4000,5),V(4000,5) 

      INTEGER LUN

      INTEGER I,J
      INTEGER NPART,IP,II,IPKF

      REAL*4 PP(4000,5),VV(4000,5)


      DOUBLE PRECISION WtMain
      DOUBLE PRECISION WtList(1000)
      DOUBLE PRECISION WtCEEX2,WtCEEX1,WtCEEX0
      DOUBLE PRECISION WtCEEX2NoIntf,WtCEEX1NoIntf,WtCEEX0NoIntf
      DOUBLE PRECISION WtEEX3,WtEEX2,WtEEX1,WtEEX0


* Pythia Parameters
      INTEGER MSTU,MSTJ,KCHG,MDCY,MDME,KFDP,MSEL,MSELPD,MSUB,KFIN,
     &     MSTP,MSTI
      DOUBLE PRECISION PARU,PARJ,PMAS,PARF,VCKM,BRAT,CKIN,PARI,
     &     PARP

      COMMON /PYDAT1/ MSTU(200),PARU(200),MSTJ(200),PARJ(200)           
      SAVE /PYDAT1/
      COMMON /PYDAT2/ KCHG(500,4),PMAS(500,4),PARF(2000),VCKM(4,4)         
      SAVE /PYDAT2/
      COMMON/PYDAT3/MDCY(500,3),MDME(4000,2),BRAT(4000),KFDP(4000,5)
      SAVE /PYDAT3/
      COMMON/PYSUBS/MSEL,MSELPD,MSUB(500),KFIN(2,-40:40),CKIN(200)
      SAVE /PYSUBS/
      COMMON/PYPARS/MSTP(200),PARP(200),MSTI(200),PARI(200)
      SAVE /PYPARS/

* PJH/US 25-apr-2002 add some DelKK flags as common blocks
      INTEGER IFRM,KINT,KQSR,KHAD,KBCF,KDCY,KWSB
      COMMON/DELKKF/IFRM,KINT,KQSR,KHAD,KBCF,KDCY,KWSB

      REAL*4 XHAD
      COMMON/DELKKH/XHAD

*----------------------------------------------------------------------------

*
*
*   write event data
*
c
C delsim needs    k(Z0 H0 W H+,1)=21
c
        npart=n
        DO 111 ip=1,npart
          ipkf=iabs(k(ip,2))
          IF(ipkf.eq.23 .or. ipkf.eq.24 .or. ipkf.eq.25 .or
     1      .ipkf.eq.37 .or.
     2      (k(ip,1).eq.14 .and. (ipkf.eq.11 .or.  ipkf.eq.13))) then
            k(ip,1)=21
          ENDIF
  111   CONTINUE

*HTP add comment line for generator info
* PJH - 28-Jun-2001: change generator flag for KK to 103
* PJH - 28-Jun-2001: DelKK version 4.14/3.00
* PJH - 10-Dec-2001: new DelKK version 4.14/4.00
* PJH - 04-Feb-2002: new DelKK version 4.14/5.00
* PJH - 25-Apr-2002: new DelKK version 4.14/6.00
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=103
* Set KK version Number
      P(n,1)=4.14
* Set DelKK version number
      P(n,2)=4.14
      P(n,3)=6.00
* PJH - 28-Jun-2001: add PYHTIA version number
      P(n,4)=6.156

* PJH - 1-Jun-2001: Weights
      CALL KK2f_GetWtList(WtMain,WtList)
      WtCEEX2=WtList(203)
      WtCEEX1=WtList(202)
      WtCEEX0=WtList(201)
      WtCEEX2NoIntf=WtList(253)
      WtCEEX1NoIntf=WtList(252)
      WtCEEX0NoIntf=WtList(251)
      WtEEX3=WtList(74)
      WtEEX2=WtList(73)
      WtEEX1=WtList(72)
      WtEEX0=WtList(71)
c PJH - 1-Jun-2001: add weights in common lines
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=0
      P(n,1)=WtMain
      P(n,2)=WtCEEX2
      P(n,3)=WtCEEX1
      P(n,4)=WtCEEX0
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=0
      P(n,1)=WtMain
      P(n,2)=WtCEEX2NoIntf
      P(n,3)=WtCEEX1NoIntf
      P(n,4)=WtCEEX0NoIntf
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=0
      P(n,1)=WtMain
      P(n,2)=WtEEX3
      P(n,3)=WtEEX2
      P(n,4)=WtEEX1
      P(n,5)=WtEEX0
* PJH/US - 25-Apr-2002
* add hadronisation, b/c frag and decay table identifiers
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=0
      P(n,1)= DBLE(XHAD)
      P(n,2)= DBLE(KBCF)
      P(n,3)= DBLE(KDCY)
      P(n,4)= DBLE(KWSB)
* PJH/US 25-apr-2002
* Add the following comment line to store PYTHIA info for 
* lep1 b physics
      n=n+1
      DO ip=1,5
        K(n,ip)=0
        P(n,ip)=0
        V(n,ip)=0
      ENDDO
      K(n,1)=21
      K(n,2)=0
      K(n,3)=0
      P(n,1)=DBLE(MSTU(90))
      P(n,2)=DBLE(MSTU(91))
      P(n,3)=DBLE(MSTU(92))
      P(n,4)=PARU(91)
      P(n,5)=PARU(92)
* PJH/US 25-apr-2002

* Make DELSIM input REAL*4
      DO j  = 1, 5
       DO ii = 1, n
        PP(II,J) = P(II,J)
        VV(II,J) = V(II,J)
       ENDDO
      ENDDO

      write (LUN)
     +     n,((k(i,j),j=1,5),(pp(i,j),j=1,5),(vv(i,j),j=1,5),i=1,n)

* Debug - write formatted lund output 
c      WRITE(LUN,11111) N
c      DO I=1,N
c       WRITE(LUN,11112)(K(I,J),J=1,5),(PP(I,J),J=1,5),(VV(I,J),J=1,5)
c      ENDDO
c11111 FORMAT(I8)
c11112 FORMAT(5I8,5F10.5,5F10.5)

      RETURN
      END


      SUBROUTINE LRKKWRIT(LUNIT)
*****************************************************************************
*****************************************************************************
* Write out event in format for lund_read program - including weights
*
*     Input:   LUN - output file INTEGER
*
*     Output:  None
*
*     Called:  Per event
*
*****************************************************************************
*****************************************************************************
      IMPLICIT NONE
      DOUBLE PRECISION WTMOD,WtCrud
      DOUBLE PRECISION WtMain,WtSet(1000)
      DOUBLE PRECISION WtIntf,WtNoIntf
*

      COMMON/PYJETS/N,NPAD,K(4000,5),P(4000,5),V(4000,5)
      INTEGER LUNIT,I,J,N,K,NPAD
      double precision P,V

*----------------------------------------------------------------------------

      SAVE

*----------------------------------------------------------------------------
*
      CALL KK2f_GetWt(WTMOD,WtCrud)
*

* format for lund_read program - including weights
      CALL KK2f_GetWtAll(WtMain,WtCrud,WtSet)
      WtIntf=WtSet(203)
      WtNoIntf=WtSet(253)
      WRITE(LUNIT,11111) N
      WRITE(LUNIT,11113) SNGL(WtMain),SNGL(WtCrud),
     +                   SNGL(WtIntf),SNGL(WtNoIntf)
      DO I=1,N
       WRITE(LUNIT,11112) FLOAT(K(I,2)),(sngl(P(I,J)),J=1,5)
      ENDDO
11111 FORMAT(I8)
11113 FORMAT(4F10.5)
11112 FORMAT(6F10.5)


      RETURN
      END












