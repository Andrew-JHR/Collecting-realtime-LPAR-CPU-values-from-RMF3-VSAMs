//ANDREWJC JOB  IBM,SP,CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP1    EXEC ASMACLG,REGION=0M
//SYSIN    DD   *
         PRINT NOGEN
*-------------------------------------------------------------------*
* This program is used to extract RMFIII data from the RMFIII VSAM
* data sets
* The VSAM is fixed RRDS with a record length as 32752. However, data
* saved in the VSAM is compressed by RMFIII using its own algorithm
* -- except for the Data Set Header and Index (DSIG3) and the Set of
* Samples Header (SSHG3)
* So to extract data, we should first decompress the MINTIME of sample
* sets (across more than just one record) by dynamically linking to
* the RMFIII provided module: ERB3RDEC to a piece of consecutive
* storage, one MINTIME at a time.
* The input to invoking ERB3RDEC is the starting address of ech SSHG3,
* whereas the output is the expanded, decompressed real SSHG3, which
* can then be interpreted using the table formated described in
* RMF Programmer's Guide.
* Special attention should be paid to the VSAM record structure that
* one complete MINTIME set of samples -- in compressed form --
* may cross record boundaries like the following
* | dsig3 | mintime 1   | mintime 2   | mintime 3  | mintime 4 ...
* |*******|*************|*************|************|**********
* | rec 1 | rec 2 | rec 3 | rec 4 | rec5 | rec 6 | rec 7 | .......
* |       | sshg3 |       |       |      |       |       |
*
* Developer     : Andrew Jan
* Completed Date: Aug 15, 2013
* ------------------------------------------------------------------*
* Updated : Aug 30, 2013 by Andrew Jan                          C130830
* There are probably gaps between each SSHG3                    C130830
* ------------------------------------------------------------------*
* Updated : Sep 05, 2013 by Andrew Jan                          C130905
* Increase the getmain size from 20 * 32752 to 30 * 32752       C130905
* Some SSHG3 may be as large as more than 20 records            C130905
*-------------------------------------------------------------------*
* Updated : Sep 09, 2013 by Andrew Jan                          C130909
* Fixing the bug when the entire SSHG3 size is exact a multiple C130909
* of 32752 -- no more bytes left in a record for the next SSHG3 C130909
*-------------------------------------------------------------------*
* Updated : Dec 27, 2013 by Andrew Jan                          C131227
* Solving a 0C4 problem caused by no enough space               C131227
*-------------------------------------------------------------------*
* Updated : Dec 31, 2013 by Andrew Jan                          C131231
* expand further the storage and allocate it above 16M line     C131231
*-------------------------------------------------------------------*
* Updated : Sep 22, 2016 by Andrew Jan                          C160922
* Add extra macro CPCDB                                         C160922
* Add extra fields to CPUG3                                     C160922
* Collect CPC figures                                           C160922
*-------------------------------------------------------------------*
* Updated : Sep 27, 2016 by Andrew Jan                          C160927
* get the defined weight                                        C160927
*-------------------------------------------------------------------*
* Updated : Nov 21, 2016 by Andrew Jan                          C161121
* prevent division errors                                       C161121
*-------------------------------------------------------------------*
*-------------------------------------------------------------------*
* Updated : Apr 02, 2018 by Andrew Jan                          C180402
* increase the record length                                    C180402
*-------------------------------------------------------------------*
         PRINT OFF
         LCLA  &REG
.LOOP    ANOP                              GENERATE REGS.
R&REG    EQU   &REG
&REG     SETA  &REG+1
         AIF   (&REG LE 15).LOOP
         PRINT ON
*
*------------------------------------------------*
*
VSRECLEN EQU   32752        vsam record length
*
********************** (erbdsig3 mapping macro) ********************
DSIG3    DSECT
DSIDSIG3 DC    CL5'DSIG3'   acronym 'DSIG3'
DSIGRMFV DC    X'02'        control block version x'02'
DSIGID   DS    CL4          system id
         DS    CL2          reserved
DSIGTODC DS    CL8          time data set was created
DSIGTODF DS    CL8          time stamp for first set of samples
DSIGTODL DS    CL8          time stamp for last set of samples
DSIGFSPT DS    CL4          offset of 1st set of samples from ERBDSIG3
DSIGLSPT DS    CL4          offset of last set of smples from ERBDSIG3
DSIGNEPT DS    CL4          offset of next set of smples to be written
DSIGFIPT DS    CL4          offset of 1st index entry from ERBDSIG3
DSIGLIPT DS    CL4          offset of last index entry from ERBDSIG3
DSIGNIPT DS    CL4          offset of next index entry from ERBDSIG3
DSIGILEN DS    CL4          length of an index entry
DSIGINUS DS    CL4          signd, # of current index to set of samples
DSIGTDSF DS    CL8          time stamp of first policy
DSIGTDSL DS    CL8          time stamp of last  policy
DSIGFPPT DS    CL4          offset to start of first policy
DSIGLPPT DS    CL4          offset to start of last  policy
DSIGFPIP DS    CL4          offset to first policy index
DSIGLPIP DS    CL4          offset to last  policy index
DSIGNPIP DS    CL4          offset to next  policy index
DSIGCIPN DS    CL4          current index number to policy
DSIGFIPN DS    CL4          first index number to policy
DSIGSPLX DS    CL8          sysplex id of this system
DSIGSPXD DS    CL32         reserved for sysplex
         DS    CL104        reserved
DSIGTOD1 DS    CL8          time stamp for start of samples or policy
DSIGTOD2 DS    CL8          time stamp for end   of samples or policy
DSIGSBEG DS    CL4          offset fm start of dataset to start of samp
DSIGSLEN DS    CL4          physical (compressed) length
DSIGFLG  DS    CL1          bit0 service policy index
         DS    CL3          reserved
*
********************** (erbsshg3 mapping macro) ********************
SSHG3    DSECT ,            sample header
         DS    0D           align on dword boundary
SSHSSHG3 DS    XL5          acronym sshg3
SSHRMFV  DS    XL1          sshg3 control block version x'0c'
SSHLEN   DS    H            length of sshg3
SSHRMFVN DS    XL3          rmf version number
SSHFLAG1 DS    XL1          flag byte
SSHGCOMP EQU   X'80'        on = data are compressed
SSHPREVP DS    A            pointer to previous ssh
SSHNEXTP DS    A            pointer to next ssh
         DS    4F           reserved
SSHSHDFO DS    A            pointer first sample header
SSHSHDLO DS    A            pointer to last sample
SSHTOTLE DS    A            total length for this set of samples
         DS    CL8          reserved
SSHSMPNR DS    A            number of valid samples
SSHTIBEG DS    CL8          begin time for this set of samples
SSHTIEND DS    CL8          end time for this set of samples
         DS    CL16         reserved
SSHASIO  DS    A            offset of the asid table from erbsshg3
         DS    CL12         reserved
SSHDVTO  DS    A            offset of the dvt table from erbsshg3
         DS    CL8          reserved
SSHENTO  DS    A            offset of the end table from erbsshg3
         DS    CL12         reserved
SSHPMTO  DS    A            offset to PTMG3
         DS    CL8          reserved
SSHGEIO  DS    CL4          offset of the general information table
SSHIOML  DS    CL1          processor type on which data was created
SSHIOMLZ EQU   X'03'        9672, zSeries 900
SSHEFLAG DS    CL1          extended storage bit0 ES installed
SSHPRFGS DS    CL2          0 ES/conn chnl enabled, 1 ES/conn director
SSHGOCYC DS    A            gatherer cycle option
SSHGOSTP DS    A            gatherer stop  option
SSHGOSYN DS    A            gatherer sync  option
SSHGOMNT DS    A            gatherer mintime option
         DS    CL3          reserved
SSHGOCLA DS    CL1          gatherer sysout  option
         DS    CL4          reserved
SSHJESN  DS    CL4          name of jes subsystem
SSHGOWHL DS    A            gathered dataset whold suboption
SSHGOWST DS    A            gathered wstor  option
         DS    CL40         reserved
SSHSTDIF DS    CL8          difference between local time & GMT
SSHHSMJN DS    CL8          jobname of hsm subsystem
SSHHSMAS DS    CL2          ASID number of hsm subsystem
SSHJESJN DS    CL8          jobname of jes subsystem
SSHJESAS DS    CL2          ASID number of jes subsystem
SSHPGPO  DS    A            offset to PGPER cntrol block - wrap bfr
         DS    CL4          reserved
SSHCSRO  DS    A            offset to CSR table when data in wrap bfr
SSHJLCYC DS    A            time-offset when last cycle gathered
         DS    CL4          reserved
SSHRCDO  DS    A            offset to RCDG3
SSHCPUO  DS    A            offset to CPUG3
SSHIPLTI DS    CL8          ipl time in tod
SSHWLMTK DS    CL8          WLM token
SSHENCO  DS    A            offset to ENCG3
SSHSM2O  DS    A            offset to SM2G3
SSHDDNO  DS    A            offset to DDNG3
SSHCFIO  DS    A            offset to CFIG3
SSHCATO  DS    A            offset to CATG3
SSHVRIO  DS    A            offset to VRIG3
SSHOPDO  DS    A            offset to OPDG3
         DS    A            reserved
*-------------------------------------------------------------  C160922
*New Macro CPCDB                                                C160922
********************** (erbcpcdb mapping macro) ****************C160922
CPCDB    DSECT ,            CPC data control block              C160922
              DS   0D       align on dword boundary             C160922
CPC_EyeCt     DS   XL5      eye cather: CPCDB                   C160922
CPC_VerNum    DS   XL1      control block version x'05'         C160922
              DS   XL2      reserved                            C160922
CPC_HdrLen    DS   CL4      length of CPCDB header              C160922
CPC_TotLen    DS   CL4      total length of CPCDB               C160922
CPC_Flags     DS   CL2      status flags                        C160922
CPC_MaxLpars  DS   CL2      Maximum # of LPARs                  C160922
CPC_MaxProcs  DS   CL2      Maximum # of processors             C160922
CPC_PhysProcs DS   CL2      # of physical processors            C160922
CPC_Homeo     DS   CL4      offset to home LPAR section         C160922
CPC_Homel     DS   CL2      length of home LPAR section         C160922
CPC_LparMainL DS   CL2      length of CPC LPAR section          C160922
CPC_LparO     DS   CL4      offset to CPC LPAR section          C160922
CPC_LparL     DS   CL2      length of CPC LPAR section with CPC C160922*
                            logical Processor section(s)        C160922
CPC_LparN     DS   CL2      # of CPC LPAR section               C160922
CPC_DTime     DS   CL8      Time delta between two DIAG calls   C160922
*                                                               C160922
********************** Home LPAR Section        **************  C160922
CPCHOME       DSECT ,       CPC home section               C160922
CPC_HomeFlags DS   CL2      status flags                        C160922
              DS   CL2      reserved                            C160922
CPC_CecMSU    DS   CL4      effective processor capacity available6to22*
                            the CPC                             C160922
CPC_LparMSU   DS   CL4      see LPDatImgCapacity of IRALPDAT    C160922
              DS   CL4      reserved                            C160922
CPC_HomeLPName DS  CL8      name of the home partition          C160922
CPC_PhyAdj     DS  CL4      see LPDatPhyCpuAdjFactor of IRALPDATC160922
CPC_WeightCumD DS  CL4      see LPDatCumWeight of IRALPDAT. ThisCis0922*
                            the delta between begin and end of MINTIME2
CPC_WeightNumD DS  CL4      see LPDatWeightAccumCounter of IRALPDAT.922*
                            this is the delta between begin and end0of2*
                            MINTIME                             C160922
              DS   CL2      reserved                            C160922
CPC_CapAdj    DS   CL1      Capacity adjustment indication      C160922
CPC_CapRsn    DS   CL1      Capacity change reason              C160922
CPC_ImgMsuLimit DS   CL4    Image capacity MSU limit            C160922
CPC_4hAverage   DS   CL4    see LPDatAvgImgService of IRALPDAT  C160922
CPC_UncappedTimeD DS  CL8   uncapped time delta. See            C160922*
                            LPDatCumUncappedElapsedTime of IRALPDAT.922*
                            this is the delta between begin and end0of2*
                            MINTIME                             C160922
CPC_CappedTimeD DS  CL8     capped time delta. See              C160922*
                            LPDatCumUncappedElapsedTime of IRALPDAT.922*
                            this is the delta between begin and end0of2*
                            MINTIME                             C160922
CPC_MsuInterval DS  CL4     Approximate time interval (in seconds)6for2*
                            each entry in the MSU table. see    C160922*
                            LPDatServiceTableEntryInterval of IRALPDAT2
CPC_MsuDataEntries DS CL4   # of WLM intervals within the last 4Chours2
                DS   CL384    reserved                          C160922
CPC_GrpCapName  DS   CL8    name of the capacity group to which the0922*
                            partition belongs                   C160922
CPC_GrpCapLimit DS   CL4    MSU limit for the capacity grp to which0922*
                            the partition belongs               C160922
                DS   CL4    reserved                            C160922
CPC_GrpJoinedTOD DS   CL8   time when the LPAR has joined the group0922
                DS   CL192    reserved                          C160922
CPC_Prod_AAP    DS   CL4    multithreading core productivity numerator2*
                            for AAP                             C160922
CPC_Prod_IIP    DS   CL4    multithreading core productivity numerator2*
                            for IIP                             C160922
CPC_Prod_CP     DS   CL4    multithreading core productivity numerator2*
                            for CP                              C160922
CPC_MaxCapF_AAP DS   CL4    multithreading maximum capacity Factor60922*
                            numerator for AAP                   C160922
CPC_MaxCapF_IIP DS   CL4    multithreading maximum capacity Factor60922*
                            numerator for IIP                   C160922
CPC_MaxCapF_CP  DS   CL4    multithreading maximum capacity Factor60922*
                            numerator for CP                    C160922
CPC_CapF_AAP    DS   CL4    multithreading Capacity Factor      C160922*
                            numerator for AAP                   C160922
CPC_CapF_IIP    DS   CL4    multithreading Capacity Factor      C160922*
                            numerator for IIP                   C160922
CPC_CapF_CP     DS   CL4    multithreading Capacity Factor      C160922*
                            numerator for CP                    C160922
CPC_ATD_AAP     DS   CL4    Average Thread Density for AAP      C160922
CPC_ATD_IIP     DS   CL4    Average Thread Density for IIP      C160922
CPC_ATD_CP      DS   CL4    Average Thread Density for CP       C160922
CPC_MODE_AAP    DS   CL2    MT mode AAP                         C160922
CPC_MODE_IIP    DS   CL2    MT mode IIP                         C160922
CPC_MODE_CP     DS   CL2    MT mode CP                          C160922
                DS   CL14   Reserved                            C160922
*                                                               C160922
********************** CPC  LPAR Section        *************   C160922
CPCLPAR         DSECT ,     CPC lpar section                    C160922
CPC_LparName    DS   CL8    Lpar name                           C160922
CPC_LparId      DS   CL2    Lpar #                              C160922
CPC_LparFlags   DS   CL1    Lpar status flags                   C160922
CPC_UPID        DS   CL1    user partition ID                   C160922
CPC_LparDefMSU  DS   CL4    defined MSU limit                   C160922
CPC_OSname      DS   CL8    OS instance name                    C160922
CPC_ProcO       DS   CL4    offset to logical Processor Section C160922
CPC_ProcL       DS   CL2    length of logical Processor Section C160922
CPC_ProcN       DS   CL2    # of logical Processor Section      C160922
CPC_LPCname     DS   CL8    Lpar cluster name                   C160922
CPC_GroupName   DS   CL8    name of the capacity group to which the0922*
                            partition belongs                   C160922
CPC_GroupMLU    DS   CL4    Group maximum license units         C160922
CPC_OnlineCS    DS   CL4    central storage (in MB) currently online9to*
                            this partition                      C160922
*                                                               C160922
********************** CPC Logical Processor Section *********  C160922
CPCPROC         DSECT ,     CPC logical processor section       C160922
CPC_ProcId      DS   CL2    Logical CPU address                 C160922
CPC_ProcTyp     DS   CL1    Processor type 1:cp ,2:icf, 3:AAP, 4:IFL922*
                            5:ICF, 6:IIP                        C160922
                DS   CL1    reserved                            C160922
CPC_ProcState   DS   CL2    Processor status indicators bit 0:cpu1N/A22*
                            1:online, 2:dedicated, 3:Wait completion=Y2*
                            4: Wait Completion=N, 5:init cap=ON C160922*
                            6: Polarization flag: vertically polarized2*
                               HiperDispatch mode is active.    C160922*
                               CPC_ProcPolarWgt is valid        C160922*
                            7-8: 00: Horizontally polarized     C160922*
                                 01: Vertical Polarized w/ low entitlem*
                                 10: Vertical Polarized w/ medium1entit*
                                 11: Vertical Polarized w/ high entitle
*                           9-15: reserved                      C160922
CPC_ProcChgInd  DS   CL2    Processor status change ind Bit     C160922*
                            0: change from online to offline vice-versa*
                            1: change from shared to dedicated vice-ver*
                            2: 'initial capping' status changed C160922*
                            3: wait completion changed          C160922*
                            4: maximum wait changed             C160922*
                            5: absolute limit on partition usageCchngd2*
                            6-15 reserved                       C160922
CPC_ProcDispTimeD DS CL8    dispatch time between begin & end ofC160922*
                            MINTIME in microseconds             C160922
CPC_ProcEffDispTimeD DS CL8 Eff dispatch time between begin & end1of922*
                            MINTIME in microseconds             C160922
CPC_ProcOnlineTimeD DS CL8  online time between begin & end of  C160922*
                            MINTIME in microseconds             C160922
CPC_ProcMaxWeight DS CL2    maximum LPAR share                  C160922
CPC_ProcCurWeight DS CL2    current LPAR share                  C160922
CPC_ProcMinWeight DS CL2    minimum LPAR share                  C160922
CPC_ProcIniWeight DS CL2    defined LPAR weight                 C160922
CPC_ProcPolarWeight DS CL4  weight for the logical CPU when Hiper-60922*
                            dispatch mode is active. See bit 6 of160922*
                            CPC_ProcState.multiplied by a factorCof0922*
                            4096 for more granularity           C160922
CPC_HWCapLimit      DS CL4  if not zero, absolute limit on partition922*
                            usage of all CPUs of the type indicated0in2*
                            CPC_ProcTyp in terms of # of hundredth6of22*
                            CPU                                 C160922
*                                                               C160922
*                                                               C160922
*
********************** (erbcpug3 mapping macro) ********************
CPUG3    DSECT ,            sample header
         DS    0F           align on word boundary
CPUG3_AC DS    CL5          acronym cpug3
CPUG3_VE DS    XL1          cpug3 control block version x'04'
         DS    CL2          reserved
CPUG3_HDRL   DS  A          header length
CPUG3_TOTL   DS  A          total length this area
CPUG3_NUMPRC DS  D          # of processors online during total mintimex
                            multiplied by mintime (in microseconds)
CPUG3_LOGITI DS  D          logic cpu time in microseconds. sum of MVS x
                            NON_WAIT time of all online logic cpu
CPUG3_PHYSTI DS  D          physical cpu time in ms. Sum of all cpu    x
                            times used by all logic cpu. for non PR/SM x
                            this time is equal to the logical cpu time
CPUG3_STATUS DS  F          status information, bits 1:LPAR, 7:no MSU
CPUG3_PRCON  DS  F          # of online cpus at end of mintime
CPUG3_NUMPRCOL   DS  F      accumulated # of online cpus, avg. #  divide
                            by # of samples
CPUG3_NUMVECOL   DS  F      accumulated # of online vector cpus.  divide
                            by # of samples to get average #
*C160922     DS  CL72       reserved
*-------------------------------------------------------------  C160922
*New fields found from z/OS 2.2                                 C160922
CPUG3_CPCOFF     DS  F      offset to CPCDB
CPUG3_IFCON      DS  F      # of zAAPs online at end of range
CPUG3_NUMIFCOL   DS  F      accumulated # of zAAP online. divide       *
                            by # of samples to get average #
CPUG3_NUMPRIFA   DS  D      accumulated online time of zAAPs in        *
                            microseconds
CPUG3_LOGITIFA   DS  D      logical CPU time: sum of MVS NON_WAIT      *
                            time of all online logical zAAPs in the    *
                            time range (in microseconds)
CPUG3_PHYSTIFA   DS  D      physical CPU time: sum of all CPU times    *
                            used by all online logical zAAPs in the    *
                            time range (in microseconds)
CPUG3_SUCON      DS  F      # of zIIPs online at end of range
CPUG3_NUMSUCOL   DS  F      accumulated # of zIIP online. divide       *
                            by # of samples to get average #
CPUG3_NUMPRSUP   DS  D      accumulated online time of zIIPs in        *
                            microseconds
CPUG3_LOGITSUP   DS  D      logical CPU time: sum of MVS NON_WAIT      *
                            time of all online logical zIIPs in the    *
                            time range (in microseconds)
CPUG3_PHYSTSUP   DS  D      physical CPU time: sum of all CPU times    *
                            used by all online logical zIIPs in the    *
                            time range (in microseconds)
CPUG3_PARK_CP    DS  D      accumulated parked time on CPs in          *
                            microseconds
CPUG3_PARK_IFA   DS  D      accumulated parked time on zAAPs in        *
                            microseconds
CPUG3_PARK_SUP   DS  D      accumulated parked time on zIIPs in        *
                            microseconds
CPUG3_CPUOFF     DS  F      offset to CPUDB
CPUG3_CPOnlCore# DS  F      accumulated # of online CP cores. To get   *
                            average # divide by # of samples
CPUG3_IFAOnlCore# DS  F     accumulated # of online zAAP cores. To     *
                            get average # divide by # of samples
CPUG3_SUPOnlCore# DS  F     accumulated # of online zIIP cores. To     *
                            get average # divide by # of samples
                  DS  F     reseved
*
********************** (erbshdg3 mapping macro) ************
SHDG3    DSECT ,            sample header
         DS    0F           align on word boundary
SHDSHDG3 DS    CL5          acronym    shdg3
SHDRMFV  DS    XL1          shdg3 control block version number x'02'
SHDLEN   DS    XL1          length of shdg3
SHDFLAG1 DS    XL1          sample flag 1
SHDINVAL EQU   X'80'        sample is invalid
SHDPREVP DS    A            pointer to previous sample
SHDNEXTP DS    A            pointer to next sample
SHDREDOF DS    A            offset to first red record
********************** (erbredg3 mapping macro) ********************
REDG3    DSECT              resource record
         DS    0F           align on word boundary
REDREDID DS    XL1          red id
REDUSRCB EQU   X'3F'        red id for user exit
REDFLAG1 DS    XL1          red flag1
REDINVAL EQU   X'80'        user exit data are invalid for this sample
REDRETRY DS    H            nr of retries of the user exit routine
REDFUWDO DS    F            offset to first user exit record
REDUSERL DS    H            length of user exit record
REDUSERN DS    H            number of user exit records
*
********************** (erbasig3 mapping macro) ********************
ASIG3    DSECT              address space record
         DS    0F           align on word boundary
ASIASIG3 DS    CL5          ASIG3
ASIVERG3 DS    CL1          control block version x'0E'
ASIHDRLE DS    CL1          length of ASIG3 header
         DS    CL1          reserved
ASIENTMX DS    A            number of table entries
ASIENTNR DS    A            index of one entry
ASIENTLN DS    A            length of one entry
ASISSTVO DS    A            offset to service class served table
         DS    CL8          reserved
ASIENTRY DS    CL328        array of all asid table entries
****     entry section
ASIG3E   DSECT              address space record entry
ASIENIDX DS    CL2          index of this table entry
ASIPREVI DS    CL2          index of previous entry for same ASID
ASIJOBNA DS    CL8          jobname for this ASID
ASINPG   DS    CL2          control performance group
         DS    CL1          reserved
ASIDMNN  DS    CL1          domain
ASIASINR DS    CL2          ASID number
ASIFLAG1 DS    CL2          job flag 0:STC,1:BTCH,2:TSO,3:ASCH,4:OMVS
ASICPUTA DS    A            total tcb+srb time (in milliseconds)
ASIDCTIA DS    A            total channel connect (in 128 microsecs)
ASIFIXA_VE DS  A            floating pnt # of central fixed frames
ASITRCA  DS    A            total # of transactions
ASIFMCT_VE DS  A            floating pnt # of frames 4 swapped-in users
ASIFMCTI_VE DS A            floating pnt # of frames 4 idle users
ASIESF_VE DS   A            fp # of expanded frames 4 swapped-in users
ASIESFI_VE DS  A            fp # of expanded frames 4 idle users
ASISMPCT DS    CL2          # of valid samples
ASISWAP  DS    CL2          # of samples when job was swapped-out
ASIIDLE  DS    CL2          # of samples when job was idle
ASISWAR  DS    CL2          # of samples when job was swapped-out ready
ASIACT   DS    CL2          active using or delayed count
ASIUKN   DS    CL2          # of samples when job status was unknown
ASISUSEN DS    CL2          # of single state using samples
ASISUCPR DS    CL2          # of single state samples using PROC
ASISUCDV DS    CL2          # of single state samples using DEV
ASISWAIN DS    CL2          # of sss delayed any resource
ASISDCPR DS    CL2          # of sss delayed by the processor PROC
ASISDCDV DS    CL2          # of sss delayed by device DEV
ASISDCST DS    CL2          # of sss delayed by paging or swapping STOR
ASISDCJE DS    CL2          # of sss delayed by JES
ASISDCHS DS    CL2          # of sss delayed by HSM
ASISDCEN DS    CL2          # of sss delayed by ENQ
ASIVECTA DS    A            total accumulated vector processor time
ASISDCSU DS    CL2          # of sss delayed by SUBS
ASISDCOP DS    CL2          # of sss delayed by OPER
ASISDCMS DS    CL2          # of sss delayed by OPER MESSAGE
ASISDCMT DS    CL2          # of sss delayed by OPER MOUNT
ASIPAGES DS    CL2          page delay
ASISWAPS DS    CL2          swap delay
ASIDIV_VE DS   A            fp # of DIV frames
ASIAUXSC_VE DS A            fp # of auxiliary slots
ASIPINA  DS    A            page-in counts
ASIDIVCT DS    CL2          # of DIV invocations
ASIACTHF DS    CL2          # of adr spc active & hold storage counter
ASISWAPI DS    CL2          # of adr spc swapped (not logi/phy swapped)
ASISDCXC DS    CL2          # of sss delayed by XCF - part of subs
ASIJCLAS DS    CL8          job class, source:OUCBCLS
ASIPINES DS    A            expanded storage page-in count
ASIFLAG2 DS    A            com stor 0:CSA,1:SQA,2:APPC,3:BCH
ASICSASC DS    A            CSA sample count
ASISQASC DS    A            SQA sample count
ASICSAA  DS    A            fp CSA allocation
ASISQAA  DS    A            fp SQA allocation
ASIECSAA DS    A            fp ECSA allocation
ASIESQAA DS    A            fp ESQA allocation
ASIJLCYC DS    A            time-offset when job last found CYCLE time
ASIJOBST DS    CL8          job selection time in GMT
ASIJESID DS    CL8          JES ID
ASITET   DS    A            transaction elapsed time, in 1024 microsec
ASISRBTA DS    A            total accumulated SRB time
ASIIOCNT DS    A            IO count
ASILSCT  DS    CL2          count of long logical swaps
ASIESCT  DS    CL2          count of long swaps to expanded storage
ASIPSCT  DS    CL2          count of long physical swaps
ASILSCF  DS    CL4          fp sum of all central frames for logi swap
ASILSEF  DS    CL4          fp sum of all expanded frames for logi swap
ASILSSA  DS    CL2          total logically swapped samples
ASIPSEF  DS    CL4          fp sum of all expanded frames for phy swap
ASIPSSA  DS    CL2          total swapped samples (except logical)
ASIORTI  DS    CL2          stor/outr delay smps 4 swap rsn 1:terminal *
                            input wait
ASIORTO  DS    CL2          stor/outr delay smps 4 swap rsn 2:terminal *
                            output wait
ASIORLW  DS    CL2          stor/outr delay smps 4 swap rsn 3:long wait
ASIORXS  DS    CL2          stor/outr delay smps 4 swap reason 4:Aux.  *
                            storage shortage
ASIORRS  DS    CL2          stor/outr delay smps 4 swap reason 5:Real  *
                            storage shortage
ASIORDW  DS    CL2          stor/outr delay smps 4 swap reason 6:De-   *
                            tected long wait
ASIORRQ  DS    CL2          stor/outr delay smps 4 swap reason 7:Re-   *
                            quested swap
ASIORNQ  DS    CL2          stor/outr delay smps 4 swap reason 8:En-   *
                            queue exchange swap
ASIOREX  DS    CL2          stor/outr delay smps 4 swap reason 9:Ex-   *
                            change swap
ASIORUS  DS    CL2          stor/outr delay smps 4 swap reason 10:Uni- *
                            literal swap
ASIORTS  DS    CL2          stor/outr delay smps 4 swap reason 11:     *
                            transition swap
ASIORIC  DS    CL2          stor/outr delay smps 4 swap reason 12:     *
                            improve central storage usage
ASIORIP  DS    CL2          stor/outr delay smps 4 swap reason 13:     *
                            improve system paging rate
ASIORMR  DS    CL2          stor/outr delay smps 4 swap reason 14:     *
                            make room for an out too long user
ASIORAW  DS    CL2          stor/outr delay smps 4 swap reason 15:     *
                            APPC wait
ASIORIW  DS    CL2          stor/outr delay smps 4 swap reason 16:     *
                            OMVS input
ASIOROW  DS    CL2          stor/outr delay smps 4 swap reason 17:     *
                            OMVS output
ASIRCLX  DS    CL2          report-class-list index
ASIORSR  DS    CL2          stor/outr delay smps 4 swap reason 18:     *
                            In-real swap
ASICPUC  DS    CL2          cpu capping delay
ASIACOM  DS    CL2          common paging
ASIAPRV  DS    CL2          private paging
ASIAVIO  DS    CL2          vio     paging
ASIASWA  DS    CL2          swapping
ASIUNKN  DS    CL2          unknown # 4 calculating execution velocity
ASICCAP  DS    CL2          resource capping delay
ASICQUI  DS    CL2          quiesce delay
ASIAXM   DS    CL2          cross memory delay
ASIAHSP  DS    CL2          hiperspace   delay
ASICUSE  DS    A            cpu using
ASITOTD  DS    A            total delays 4 calculating exec. velocity
ASISRVO  DS    A            offset from service-class-served table     *
                            header to corresponding row
ASITOTSV DS    A            fp, total # of shared page views in this   *
                            address space
ASISVINR DS    A            fp, total # of shared pages in central     *
                            storage that are valid 4 this addr. sp.
ASISPVLC DS    A            fp, total # of shared page validation in   *
                            this address space
ASIGSPPI DS    A            fp, total # of shared page-ins from aux.   *
                            storage for this address space
ASIGASPD DS    CL2          # of single state samples delays for       *
                            shared storage paging
         DS    CL2          reserved
ASIOREPL DS    A            # of outstanding replies
ASITOTU  DS    A            # of multi-state using samples
ASIIOU   DS    A            # of multi-state I/O using samples
ASIASSTA DS    A            aditional srb time
ASIPHTMA DS    A            preemptable-class srb time
ASIMSTS  DS    A            miscellaneous states
*                           0:OMVS related,1:AS matched a classifica-
*                           tion rule in the active policy which pre-
*                           vents managing the region based on the re-
*                           sponse goals of its served transaction
*                           2:CPU protection was assigned either to
*                           the address space or to transaction service
*                           classes being served by the space,and SRM
*                           is honoring the protection, 3:Storage pro-
*                           tection was assigned either to the AS or to
*                           transaction service classes being served by
*                           the space and SRM is honoring the protect-
*                           ion,4:this AS provides service to transact-
*                           ions classified to a different class than
*                           the AS itself, 5:WLM is managing the AS to
*                           meet the goals of work in other service
*                           classes
ASISUCIF DS    CL2          # of single state samples using IFA proc.
ASISUCIC DS    CL2          # of single state samples using IFA on CP
ASISDCIC DS    CL2          # of single state samples delayed by IFA
         DS    CL2          reserved
ASICPTA  DS    A            accumulated CPU time
ASIIFATA DS    A            accumulated IFA time
ASIIFCTA DS    A            accumulated IFA on CP time
*
********************** (erbasig3 mapping macro) ********************
DVTG3    DSECT              device table
         DS    0F           align on word boundary
DVTDVTG3 DS    CL5          DVTG3
DVTVERG3 DS    CL1          control block version x'08'
DVTHDRLE DS    CL1          length of the device table (DVTG3) header
DVTENTLE DS    CL1          length of each table entry
DVTENTMX DS    A            # of table entries
DVTENTNR DS    A            index of last entry
DVTENTRY DS    CL104        entry in the device table
****     entry section
DVTG3E   DSECT              device table entry
DVTVOLI  DS    CL6          volser
DVTENIDX DS    CL2          index of this table entry
DVTDEVNR DS    CL2          device # in hexdecimal format
DVTPREVI DS    CL2          index of the previous tab entry 4 sam dev.
DVTSMPCT DS    A            # of valid samples
DVTSMPNR DS    A            sample sequence number
DVTFLAG1 DS    CL1          1:DASD,2:tape,3:#ofalias for pav changed   *
                            4:virtual DASD,6:LCU is valid,7:PAV
DVTFLAG2 DS    CL1          if valid the following field               *
                            0:CONN/DISC/PEND at begin time available
*                           1:CONN/DISC/PEND at end   time available
*                           2:DEV BUSY DELAY/CUB DELAY/DPB DELAY time
*                             values at begin time available
*                           3:DEV BUSY DELAY/CUB DELAY/DPB DELAY time
*                             values at end   time available
*                           4:device has plpa page data sets
*                           5:device has common page data sets
*                           6:device has local  page data sets
DVTMEXNR DS    CL2          # of base and alias volumes
DVTDISIF DS    A            native dev DISC time (begin) in 2048ms
DVTPETIF DS    A            native dev PEND time (begin) in 2048ms
DVTCOTIF DS    A            native dev CONN time (begin) in 2048ms
DVTDVBIF DS    A            dev busy delay  time (begin) in 2048ms
DVTCUBIF DS    A            no longer used
DVTDISIL DS    A            native dev DISC time ( end ) in 2048ms
DVTPETIL DS    A            native dev PEND time ( end ) in 2048ms
DVTCOTIL DS    A            native dev CONN time ( end ) in 2048ms
DVTDVBIL DS    A            dev busy delay  time ( end ) in 2048ms
DVTCUBIL DS    A            no longer used
DVTTYP   DS    CL4          device type mapped by UCBTYP macro
DVTIDEN  DS    CL8          device identification (model)
DVTCUID  DS    CL8          control unit model
DVTSPBIF DS    CL4          no longer used
DVTSPBIL DS    CL4          no longer used
DVTIOQLC DS    CL4          I/O queue length count
DVTSAMPA DS    A            accumulated I/O instruction count
         DS    CL2          reserved
DVTLCUNR DS    CL2          LCU number
DVTSAMPP DS    A            I/O instruction count (previous value)
DVTCMRIF DS    A            initial command response time first
DVTCMRIL DS    A            initial command response time last
DVTCUQTP DS    A            control unit queuing time previous sample
DVTCUQTN DS    A            accumulated CU queuing time not conn.FICON
DVTCUQTF DS    A            accumulated CU queuing time conn.FICON chl
********************** csect ***************************************
RMF3CPC  CSECT
RMF3CPC  AMODE 31
         USING *,R15
         STM   R14,R12,12(R13)      USE R13 AS BASE AS WELL AS
         LR    R2,R13               REG-SAVE AREA
         B     CMNTTAIL             REG-SAVE AREA
*
CMNTHEAD EQU   *
         PRINT GEN
         DC    CL8'&SYSDATE'
         DC    C' '
         DC    CL5'&SYSTIME'
         DC    C'ANDREW JAN'
         CNOP  2,4
         PRINT NOGEN
CMNTTAIL EQU   *
*
         BALR  R12,0
         BAL   R13,76(R12)
SAVREG   DS    18F
         DROP  R15
         USING SAVREG,R13
         ST    R2,4(R13)
         ST    R13,8(R2)
*
*---MAINSTREAM BELOW-----------------------------------------------*
*
        BAL    R6,GETMAIN        get storage
*
        BAL    R6,OPEN_FILES     open files
*
        B      PROCESS           go to main body
*
FINISH  EQU    *
        BAL    R6,CLOSE_FILES    close files
        B      RETURN            return to system
*
*---MAINSTREAM ABOVE-----------------------------------------------*
*
PROCESS  EQU    *
         USING  DSIG3,R2         addressibility
         L      R2,BLKADR        the start of our buffer
         LR     R10,R2           copy the address
         GET    RPL=MASRPL       get dsig3 - header & index
         L      R4,RECADR        save the read-in bfr addr
         L      R5,=A(VSRECLEN)  length
         LR     R11,R5           copy the length
         MVCL   R10,R4           copy data
*
         L      R3,DSIGFSPT      load the 1st SSHG3 offset
         A      R3,BLKADR        the actual address when executing
         ST     R3,SSHADR        save it as fixed for all sshg3
         MVC    DSIGLEN,DSIGILEN save the index entry size 4 later use
*
         L      R3,DSIGINUS      loop thru all samples in this file
         L      R9,DSIGSBEG      load the 1st SSHG3 offset
         A      R9,DSIGSLEN      add the total length
         S      R9,=A(VSRECLEN)  deduct the bytes of 1st line
         XR     R12,R12          gap is 0 btwn 1st & 2nd sshg3s C130830
         B      INDEX_LOOP_1ST   branch
*
INDEX_LOOP EQU   *               2nd, 3rd,... will enter here
         L      R12,DSIGLEN      length to next sshg3           C130830
         L      R12,DSIGSBEG(R12)  begin of next sshg3          C130830
         LTR    R12,R12          does it go beyond the last ?   C130830
         BZ     INDEX_LOOP_SKIP  yes,branch                     C130830
         S      R12,DSIGSBEG     deduct begin of the sshg3      C130830
         S      R12,DSIGSLEN     deduct length of the sshg3     C130830
INDEX_LOOP_SKIP EQU *                                           C130830
         L      R9,DSIGSLEN      add the total length
         AR     R9,R12           possible non-consecutive blck  C130830
         S      R9,REMAIND       deduct those already read & moved
INDEX_LOOP_1ST EQU   *           count how many recs to read in
         XR     R8,R8            clear for division
         D      R8,=A(VSRECLEN)  quotient in r9, remainder in r8
         LTR    R8,R8            any remainder?
         BZ     READ_LOOP        no branch
         LA     R9,1(,R9)        add one more time
READ_LOOP EQU   *                read all sample sets for this sshg3
         GET    RPL=MASRPL       get a record
         L      R4,RECADR        locate the record
         L      R5,=A(VSRECLEN)  length
         LR     R11,R5           copy the length
         MVCL   R10,R4           copy data
         BCT    R9,READ_LOOP     loop the # in r9
*--------------------------------------------------------*
*
         BAL    R6,ERB3RDEC      go decompress
*
*--------------------------------------------------------*
*-move the remaining bytes (if any) to start of 1st SSHG3*
*--------------------------------------------------------*
         L      R10,SSHADR       locate addr of 1st SSHG3
         LTR    R8,R8            any remainder?
*C130909 BZ     LOOP_NEXT        no, branch
         BZ     RESET_REMAIN     set the remainder as 0         C130909
         LR     R4,R10           copy the address
         A      R4,DSIGSLEN      the start of left bytes 4 next sshg3
         AR     R4,R12           gap of non-consecutive bytes   C130830
         L      R5,=A(VSRECLEN)  load rec length
         SR     R5,R8            remainders - next SSHG3
         ST     R5,REMAIND       save it for later use
         LR     R11,R5           copy the length
         MVCL   R10,R4           move to the addr of 1st SSHG3
         B      LOOP_NEXT        branch to process next sshg3   C130909
RESET_REMAIN EQU  *              no next sshg3 data in this rec C130909
         MVC    REMAIND,=F'0'    set the remaider as 0          C130909
LOOP_NEXT EQU  *
         A      R2,DSIGLEN       shift the base for next index entry
         BCT    R3,INDEX_LOOP    loop thru all SSHG3 indexes
         B      FINISH           finished, go back
*
*
*--------------------------------------------------------*
ERB3RDEC  EQU   *
          STM   R14,R12,REGSAV   save regs avoid possilbe conflicts
          MVC   INRECA,SSHADR    pointer to input record
          LA    R1,OUTAREA       addr of uncompressed record
          ST    R1,OUTRECA       store addr in parmlist
          MVC   OUTRECL,INITLNG  length of uncompressed record
          LA    R1,PARMADDR      parameter to r1
          LINK  EP=ERB3RDEC      invokes decompress routine
          ST    R15,RETCODE      save return code
          CLC   R15,=F'4'        check return code
          BNE   PROCESS_MORE     output area not too small
          L     R3,OUTRECL       required output length
          SR    R4,R4            subpool 0
          GETMAIN RU,LV=(3),SP=(4),BNDRY=DBLWD get a storage
          ST    R1,OUTRECA       address of uncompressed record
          LA    R1,PARMADDR      parameter to r1
          LINK  EP=ERB3RDEC      invokes decompress routine
          ST    R15,RETCODE      save return code
          LTR   R15,R15          test return code
          BZ    PROCESS_MORE     decompress successful
          PUT   WARN,=CL80'Invalid SSHG3 format found!'
** following marked lines are for tests if needed               C130830
**        L     R2,OUTRECA       area address                   C130830
**        L     R3,OUTRECL       area length                    C130830
**        SR    R4,R4            subpool 0                      C130830
**        FREEMAIN RU,LV=(3),A=(2),,SP=(4)                      C130830
**        LM    R14,R12,REGSAV   save the registers             C130830
**        BR    R6               go back                        C130830
          B     FINISH
PROCESS_MORE EQU *
*--------------------------------------------------------*
          L     R4,OUTRECA       start of the set of samples
          USING SSHG3,R4         addressibility
          STCKCONV STCKVAL=SSHTIBEG,CONVVAL=WORK16,DATETYPE=YYYYMMDD
          UNPK  C_Y4MMDD(9),W_Y4MMDD(5) unpack the value
          UNPK  C_HHMMSS(7),W_HHMMSS(4) unpack the value
          MVC   BEGYYYY,C_Y4MMDD begin year
          MVC   BEGMM,C_Y4MMDD+4 begin month
          MVC   BEGDD,C_Y4MMDD+6 begin day
          MVC   BEGH,C_HHMMSS    begin hour
          MVC   BEGM,C_HHMMSS+2  begin minute
          MVC   BEGS,C_HHMMSS+4  begin second
          STCKCONV STCKVAL=SSHTIEND,CONVVAL=WORK16,DATETYPE=YYYYMMDD
          UNPK  C_HHMMSS(7),W_HHMMSS(4) unpack the value
          MVC   ENDH,C_HHMMSS    begin hour
          MVC   ENDM,C_HHMMSS+2  begin minute
          MVC   ENDS,C_HHMMSS+4  begin second
*
          A     R4,SSHCPUO        locate the cpug3 area
          USING CPUG3,R4          addressibility
*                                                               C160922
          A     R4,CPUG3_CPCOFF  locate the cpcdb area          C160922
          USING CPCDB,R4         addressibility                 C160922
          LR    R7,R4            set a base for cpc home        C160922
          A     R7,CPC_Homeo     locate the cpc home area       C160922
          USING CPCHOME,R7       addressibility                 C160922
          L     R2,CPC_CecMSU    total MSU                      C160922
          CVD   R2,WORKD         convert to packed decimal      C160922
          UNPK  CECMSU,WORKD+5(3)  zone decimal                 C160922
          OI    CECMSU+3,X'F0'   make it readable               C160922
*                                                               C160922
          LA    R10,CECMSU+L'CECMSU+1  next available byte      C160922
          LR    R7,R4            set a base for cpc lpar        C160922
          LH    R3,CPC_LparN     how many lpars                 C160922
          A     R7,CPC_Lparo     locate the cpc lpar area       C160922
          USING CPCLPAR,R7       addressibility                 C160922
*                                                               C160922
LOOP_LPAR EQU   *                loop thru all lpars            C160922
          TM    CPC_LparFlags,X'10'  cpc upid is valid          C160922
          BZ    LOOP_LPAR_1      branch for invalid one         C160922
* skip no msu defined                                           C160922
          CLC   CPC_LparName(4),=C'LP08'                        C180402
          BE    LOOP_LPAR_00                                    C180402
          L     R2,CPC_LparDefMSU defined MSU                   C160922
          LTR   R2,R2            test if zero                   C160922
          BZ    LOOP_LPAR_1      branch for invalid one         C160922
* lpar name                                                     C160922
LOOP_LPAR_00    EQU *                                           C180402
          MVC   0(L'CPC_LparName,R10),CPC_LparName prt lpar nameC160922
LOOP_LPAR_01    EQU *                                           C160922
          LA    R10,1(,R10)      check the name to end at x'40' C160922
          CLI   0(R10),X'40'     is it space?                   C160922
          BE    LOOP_LPAR_02     yes, branch                    C160922
          B     LOOP_LPAR_01     loop thru all bytes of the nameC160922
LOOP_LPAR_02    EQU *                                           C160922
          MVI   0(R10),C','      delimiter                      C160922
          LA    R10,1(,R10)      next available addr to print   C160922
* os name                                                       C160922
          MVC   0(L'CPC_OSname,R10),CPC_OSname prt OS name      C160922
          LA    R11,L'CPC_OSname  max len of the name (8)       C160922
LOOP_LPAR_03    EQU *                                           C160922
          LA    R10,1(,R10)      check the name to end at x'40' C160922
          CLI   0(R10),X'40'     is it space?                   C160922
          BE    LOOP_LPAR_04     yes, branch                    C160922
          BCT   R11,LOOP_LPAR_03 loop thru all letters          C160922
LOOP_LPAR_04    EQU *                                           C160922
          MVI   0(R10),C','      delimiter                      C160922
          LA    R10,1(,R10)      next available addr to print   C160922
* defined msu                                                   C160922
          CVD   R2,WORKD         convert to packed decimal      C160922
          UNPK  0(3,R10),WORKD+6(2)  zone decimal               C160922
          OI    2(R10),X'F0'     make it readable               C160922
          MVI   3(R10),C','      delimiter                      C160922
          LA    R10,4(,R10)      next availabe addr.            C160922
*                                                               C160922
          CLI   CPC_GroupName,X'00' no group                    C160922
          BE    LOOP_LPAR_06     branch                         C160922
          MVC   0(L'CPC_GroupName,R10),CPC_GroupName group name C160922
          LA    R11,L'CPC_GroupName                             C160922
LOOP_LPAR_05    EQU *                                           C160922
          LA    R10,1(,R10)      check the name to end at x'40' C160922
          CLI   0(R10),X'40'     is it space?                   C160922
          BE    LOOP_LPAR_06     yes, branch                    C160922
          BCT   R11,LOOP_LPAR_05 loop thru all letters          C160922
LOOP_LPAR_06    EQU *                                           C160922
          MVI   0(R10),C','      delimiter                      C160922
          LA    R10,1(,R10)      next available addr to print   C160922
* group msu                                                     C160922
          L     R2,CPC_GroupMLU  defined group msu              C160922
          CVD   R2,WORKD         convert to packed decimal      C160922
          UNPK  0(3,R10),WORKD+6(2)  zone decimal               C160922
          OI    2(R10),X'F0'     make it readable               C160922
          MVI   3(R10),C','      delimiter                      C160922
          LA    R10,4(,R10)      next availabe addr.            C160922
* central storage size                                          C160922
          L     R2,CPC_OnlineCS  defined memory size in MB      C160922
          CVD   R2,WORKD         convert to packed decimal      C160922
          UNPK  0(5,R10),WORKD+5(3)  zone decimal               C160922
          OI    4(R10),X'F0'     make it readable               C160922
          MVI   5(R10),C','      delimiter                      C160922
          LA    R10,6(,R10)      next availabe addr.            C160922
*                                                               C160922
* get to the processor section                                  C160922
          LR    R9,R7            base for processor section     C160922
          LH    R11,CPC_ProcN    how many processors used?      C160922
          A     R9,CPC_ProcO     locate the processor area      C160922
          USING CPCPROC,R9       addressibility                 C160922
*                                                               C160922
          SGR   R2,R2            clean up                       C160922
          STH   R2,ACU_CP        set as zero                    C160922
          STG   R2,ACU_ProcDispTimeD    reset                   C160922
          STG   R2,ACU_ProcEffDispTimeD reset                   C160922
          STG   R2,ACU_ProcOnlineTimeD  reset                   C160922
LOOP_LPAR_P01   EQU *            loop thru all processors       C160922
          CLI   CPC_ProcTyp,X'01' is it a cp ?                  C160922
          BNE   LOOP_LPAR_P02    no, branch                     C160922
          LH    R2,ACU_CP        current cp count kept          C160922
          LA    R2,1(,R2)        current cp count kept          C160922
          STH   R2,ACU_CP        increae cp count               C160922
          LG    R2,ACU_ProcDispTimeD    load accumulated value  C160922
          AG    R2,CPC_ProcDispTimeD    add value of this cp    C160922
          STG   R2,ACU_ProcDispTimeD    save back               C160922
          LG    R2,ACU_ProcEffDispTimeD load accumulated value  C160922
          AG    R2,CPC_ProcEffDispTimeD add value of this cp    C160922
          STG   R2,ACU_ProcEffDispTimeD save back               C160922
          LG    R2,ACU_ProcOnlineTimeD  load accumulated value  C160922
          AG    R2,CPC_ProcOnlineTimeD  add value of this cp    C160922
          STG   R2,ACU_ProcOnlineTimeD  save back               C160922
          MVC   ACU_ProcIniWeight,CPC_ProcIniWeight  weight     C160927
LOOP_LPAR_P02   EQU *            loop thru all processors       C160922
          AH    R9,CPC_ProcL     next processor addr.           C160922
          BCT   R11,LOOP_LPAR_P01 loop thru all processors      C160922
*                                                               C160922
          LH    R2,ACU_CP          cp #                         C160922
          CVD   R2,WORKD          convert to packed decimal     C160922
          UNPK  0(2,R10),WORKD+7(1)  zone decimal               C160922
          OI    1(R10),X'F0'     make it readable               C160922
          MVI   2(R10),C','      delimiter                      C160922
          LA    R10,3(,R10)      next availabe addr.            C160922
*                                                               C160922
          LM    R14,R15,ACU_ProcEffDispTimeD load cp time       C160922
          M     R14,=F'10000'      multiply 100 for percentage  C160922
          LTR   R15,R15            zero ?                       C161121
          BZ    AVOID_DIVIDE_ERROR_01                           C161121
          DL    R14,ACU_ProcOnlineTimeD+4 total mintime         C160922
AVOID_DIVIDE_ERROR_01  EQU *                                    C161121
          CVD   R15,WORKD          convert to packed decimal    C160922
          MVC   0(7,R10),ED_MASK   dispatched cp %              C160922
          ED    0(7,R10),WORKD+5   dispatched cp %              C160922
          MVC   7(2,R10),=C'%,'    dilimiter                    C160922
          LA    R10,9(,R10)      next available addr.           C160922
*                                                               C160922
          LM    R14,R15,ACU_ProcDispTimeD load cp time          C160922
          M     R14,=F'10000'      multiply 100 for percentage  C160922
          LTR   R15,R15            zero ?                       C161121
          BZ    AVOID_DIVIDE_ERROR_02                           C161121
          DL    R14,ACU_ProcOnlineTimeD+4 total mintime         C160922
AVOID_DIVIDE_ERROR_02  EQU *                                    C161121
          CVD   R15,WORKD          convert to packed decimal    C160922
          MVC   0(7,R10),ED_MASK   dispatched cp %              C160922
          ED    0(7,R10),WORKD+5   dispatched cp %              C160922
          MVC   7(2,R10),=C'%,'    dilimiter                    C160922
          LA    R10,9(,R10)      next available addr.           C160922
*                                                               C160922
          LH    R2,ACU_ProcIniWeight  weight defined            C160927
          CVD   R2,WORKD          convert to packed decimal     C160927
          UNPK  0(4,R10),WORKD+5(3)  zone decimal               C160927
          OI    3(R10),X'F0'     make it readable               C160927
          MVI   4(R10),C','      delimiter                      C160927
          LA    R10,5(,R10)      next availabe addr.            C160927
*                                                               C160927
LOOP_LPAR_1 EQU   *                loop thru all lpars          C160922
          AH    R7,CPC_LparL     next lpar addr.                C160922
          BCT   R3,LOOP_LPAR     loop thru all lpars            C160922
*                                                               C160922
          PUT   PRINT,OUTBUFF     print this data
*--------------------------------------------------------*
          L     R2,OUTRECA       area address
          L     R3,OUTRECL       area length
          SR    R4,R4            subpool 0
          FREEMAIN RU,LV=(3),A=(2),,SP=(4)
          LM    R14,R12,REGSAV   save the registers
          BR    R6               go back
*
*--------------------------------------------------------*
*
GETMAIN  EQU  *
*C131227 GETMAIN EC,LV=VSRECLEN*30,BNDRY=PAGE,A=BLKADR          C130905
*C131231 GETMAIN RU,LV=VSRECLEN*100,BNDRY=PAGE                  C131227
         GETMAIN RU,LV=VSRECLEN*200,BNDRY=PAGE,LOC=31           C131231
         ST    R1,BLKADR                                        C131227
         BR    R6                go back
*
*--------------------------------------------------------*
OPEN_FILES EQU  *
         OPEN  (PRINT,OUTPUT,WARN,OUTPUT)   open files
         OPEN  MASACB                       open the rmf vsam
         LTR   R15,R15                      test for good
         BZR   R6                           yes, go on
*                                           error handling
         MVC   WK_WARN(10),=CL10'OPEN ERROR' error msg
         PUT   WARN,WK_WARN                  print it
         B     FINISH                        stop
*
*--------------------------------------------------------*
CLOSE_FILES EQU  *
         CLOSE (MASACB,,PRINT,,WARN)   close files
         BR    R6                      go back
*--------------------------------------------------------*
*
RETURN   EQU   *
         L     R15,RETCODE                show the return code
         L     R13,4(R13)                 restore caller's saved regs
         RETURN (14,12),RC=(15)           back to caller
*--------------------------------------------------------*
*
RTN_LER  EQU   *
         MVC   WK_WARN(L'LOG_ERR),LOG_ERR logical errors
         PUT   WARN,WK_WARN               print warning msg
         B     FINISH                     back to caller
*--------------------------------------------------------*
RTN_SYN  EQU   *
         MVC   WK_WARN(L'PHY_ERR),PHY_ERR physical errors
         PUT   WARN,WK_WARN               print warning msg
         B     FINISH                     back to caller
*--------------------------------------------------------*
RTN_EOD  EQU   *                          end of file encountered
         B     FINISH                     back to caller
*--------------------------------------------------------*
*
*--------------------------------------------------------*
*
         LTORG ,                  here comes the literal table
*
*--------------------------------------------------------*
MASACB   ACB   DDNAME=RMFVSAM,AM=VSAM,                                 X
               MACRF=(SEQ,IN),        sequential input processing      X
               EXLST=EXITS            exit list
*
MASRPL   RPL   ACB=MASACB,AM=VSAM,                                     X
               OPTCD=(SEQ,LOC),       sequential, read to io  buffer   X
               AREA=RECADR,           address for the io  buffer       X
               AREALEN=4,             io buffer address is only 4B longX
               ARG=RCDNO              rrds must have this field
*
EXITS    EXLST LERAD=RTN_LER,     routine for logical errors           X
               SYNAD=RTN_SYN,     routine for physical errors          X
               EODAD=RTN_EOD      routine for end of file
*
*------------------------------------------------------------------*
PRINT  DCB DSORG=PS,DDNAME=PRINT,MACRF=PM
WARN   DCB DSORG=PS,DDNAME=WARN,MACRF=PM,LRECL=80
*------------------------------------------------------------------*
*
ACU_ProcDispTimeD     DS    D     accumuated dispatch time      C160922
ACU_ProcEffDispTimeD  DS    D     accumuated effective disp. timC160922
ACU_ProcOnlineTimeD   DS    D     mintime online time           C160922
RECADR   DS    A                  vsam record address
RCDNO    DS    A                  vsam rrds rrn
REGSAV   DS    15F                register save area
BLKADR   DS    A                  pointer to the storage
SSHADR   DS    A                  pointer to the 1st sshg3
DSIGLEN  DS    F                  length of an index entry
REMAIND  DC    F'0'               left bytes of a rec read
ACU_CP                DC    H'0'  total cp #                    C160922
ACU_ProcIniWeight     DS    H     defined weight                C160922
*
*
INITLNG  DC   F'100'             initial length
OUTAREA  DS   CL100              initial output area
PARMADDR DC   A(PARMLIST)        address of parameter list
RETCODE  DS   F                  return code
         CNOP 2,4                alignment
PARMLIST DC   H'12'              length of parm area
INRECA   DS   F                  addr of compressed set-of-samples
OUTRECA  DS   F                  addr of uncompressed set-of-samples
OUTRECL  DS   F                  size of the output area
*
WORKD     DS   D                 work
*
WORK16    DS   0F                work to convert time format
W_HHMMSS  DS    CL3              HHMMSS
          DS    XL5              THMIJU0000
W_Y4MMDD  DS   0CL4              4-byte yyyymmdd after stckconv
W_CENTURY DS    CL1              x'01' means 20xx
W_JULIAN  DS    CL3              packed yyddd
          DS    F                reserved
C_Y4MMDD  DS    CL8
          DS    CL1
C_HHMMSS  DS    CL6
          DS    CL1
ED_MASK   DC    X'402020214B2020'
*
WK_WARN  DS    0CL80               work area for warning
         DC    80C' '              initiated as blanks
*
LOG_ERR  DC    C'Some Logical Errors Happened !'
PHY_ERR  DC    C'Some Physical Errors Happened !'
*
BLANKS   DS    0CL256             blanks                        C160922
         DC    256C' '                                          C160922
*
OUTBUFF  DS   0CL600                                            C180402
         DC   600C' '                                           C180402
         ORG  OUTBUFF
BEGYYYY  DS   CL4
         DC   C'/'
BEGMM    DS   CL2
         DC   C'/'
BEGDD    DS   CL2
         DC   C','
BEGH     DS   CL2
         DC   C'.'
BEGM     DS   CL2
         DC   C'.'
BEGS     DS   CL2
         DC   C'-'
ENDH     DS   CL2
         DC   C'.'
ENDM     DS   CL2
         DC   C'.'
ENDS     DS   CL2
         DC   C','
CECMSU   DS   CL4                                               C160922
         DC   C','                                              C160922
         ORG
         END
/*
//*.SYSLMOD DD DISP=SHR,DSN=ANDREWJ.SOURCE.LMD(RMF3CPC)
//G.RMFVSAM DD DISP=SHR,DSN=SLR.RMF.MONIII.DS2
//G.PRINT  DD  SYSOUT=*,LRECL=600
//G.WARN   DD  SYSOUT=*
//
