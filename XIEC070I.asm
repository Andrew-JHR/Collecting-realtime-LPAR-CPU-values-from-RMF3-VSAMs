//ANDREWJA JOB  IBM,SP,CLASS=A,MSGCLASS=X,NOTIFY=ANDREWJ                00010000
//ASM      EXEC PGM=ASMA90,PARM='OBJECT,NODECK,XREF(FULL),RENT,FLAG(NOC-00031000
//             ONT)'                                                    00031000
//SYSLIB   DD   DSN=ANDREWJ.BDF.MACLIB,DISP=SHR                         00032000
//         DD   DSN=SYS1.MACLIB,DISP=SHR                                00033000
//         DD   DSN=SYS1.MODGEN,DISP=SHR                                00034000
//SYSUT1   DD   UNIT=SYSDA,SPACE=(CYL,(10,5)),DSN=&SYSUT1               00035000
//SYSIN    DD   *                                                       00036000
*******************************************************************     00052000
* created to process the console message: IEC070I                       00052000
*                              andrew jan 10/Sep/2016                   00052000
*                                                                       00052000
*  Module name       = XIEC070I                                         00060000
*                                                                       00070000
*  Descrpition       = Communication task user exit to parse            00080000
*                      IEC070I when a RMF III VSAM data set is closed   00090000
*                                                                       00100000
*  Remark   1. The LMD of this program should be AMODE=24/RMODE=24      00100000
*           2. Once this program is updated/compiled/linkedited into    00100000
*              a LMD file that is in LNKLST, an 'F LLA,REFRESH' and     00100000
*              a 'T MPF=00' MVS commands are needed to take effect      00100000
*                                                                       00100000
*  Function          = Automatically starts a post-processing PROC      00110000
*                      to read the RMF III VSAM data set                00111000
*                                                                       00120000
*  Operation         = R1  points to the addr of the CTXT               00130000
*                      R13 points to the addr of the standard save area 00140000
*                      R14 return point                                 00150000
*                      R15 entry  point                                 00160000
*                                                                       00170000
*  Register usage    = R5  - addr of the CTXT                           00180000
*                      R10 - module data register                       00190000
*                      R11 - potential 2nd base                         00191000
*                      R12 - module base register                       00200000
*                      R13 - pointer of a standard save area            00210000
*                      R14 - return point                               00220000
*                      R15 - entry  point                               00230000
*                                                                       00240000
*  CONTROL  BLOCK    = R5  - pointer to the address of the CTXT         00250000
*    name     mapping macro    reason used                  usage       00260000
*   ------    -------------    ---------------------------  -----       00270000
*    CTXT       IEZVX100       WTO USER EXIT PARAMETER LIST  R,W        00280000
*    MGCR       IEZMGCR        SVC 34 PARAMETER LIST         C,D        00290000
*                                                                       00300000
*    KEY = R-READ, W-WRITE, C-CREATE, D-DELETE                          00310000
*                                                                       00320000
*    macros          =  GETMAIN, FREEMAIN, MGCR                         00330000
****************************************************************C160929 00052000
* This module will start a STC named: RMF3CPC                   C160929 00052000
*                              andrew jan 29/Sep/2016           C160929 00052000
****************************************************************C160929 00052000
                                                                        00340000
                                                                        00350000
         PRINT OFF               bypass inline macro expansion          00570000
         LCLA  &REG                                                     00580000
.LOOP    ANOP                    inline macro to generate registers     00581000
R&REG    EQU   &REG              generate the equates                   00582000
&REG     SETA  &REG+1            next                                   00583000
         AIF   (&REG LE 15).LOOP if not yet finished, loop it           00584000
         PRINT ON                trigger printing                       00585000
         PRINT GEN               not allow macro expansion              00586000
                                                                        00587000
SPINPRVT EQU    230                                                     00720000
                                                                        00721000
*   Work area                                                           00721200
DATAAREA DSECT                                                          00721400
         DS    0F                                                       00721500
SAVEAREA DS    18F               standard save area                     00721600
         DS    0F                                                       00721700
MGCR     IEZMGCR DSECT=NO        for issuing MVS command                00721900
         ORG   MGCRTEXT                                                 00722000
             DS  CL9             S RMF3CPC                      C160929 00722100
             DS  CL7             ,NAME='                                00722400
MGCR_SSS     DS  CL19            SLR.RMF.MONIII.DSxx            C160929 00722500
         ORG                                                            00722700
DATALEN  EQU   *-DATAAREA                                               00722800
                                                                        00722900
                                                                        00723000
*   Mapping of the message text                                         00723100
MSGTEXT  DSECT                                                          00723200
MSGID    DS    CL8               console message id                     00723300
MAJOR    DS    CL8               '203-204,'                     C160929 00723400
RMF3ID   DS    CL6               rmfiii                                 00723500
         ORG   MAJOR             redefine for the minor line    C160929 00723600
DSNAME   DS    CL44              dsn                            C160929 00723700
                                                                        00727100
         IEZVX100                DSECT for CTXT                         00727200
                                                                        00727300
XIEC070I CSECT                                                          00727400
*IEC070I AMODE 24                                                       00727500
*IEC070I RMODE 24                                                       00727600
                                                                        00727700
         USING *,R15              setup addressibility                  00727800
         STM   R14,R12,12(R13)    save parent's register                00727900
         B     CMNTTAIL           skip over the remarks                 00728000
*                                                                       00728100
CMNTHEAD EQU   *                                                        00728200
         PRINT GEN                print out remarks                     00728300
         DC    CL8'&SYSDATE'      compiling date                        00728400
         DC    C' '                                                     00728500
         DC    CL5'&SYSTIME'      compiling time                        00728600
         DC    C'ANDREW JAN'      author                                00728700
         CNOP  2,4                ensure half word boundary             00728800
         PRINT NOGEN              disable macro expansion               00728900
CMNTTAIL EQU   *                                                        00729000
                                                                        00730000
         BALR  R12,0              module base                           00790000
         DROP  R15                avoid compiling warning               00791000
         USING *,R12              addressibility                        00800000
                                                                        00801000
         L     R5,0(,R1)          establish addressability              00810000
         USING CTXT,R5            to the CTXT                           00820000
                                                                        00821000
*  Dynamic storage for this module is being obtained below              00840000
*  the 16 MEG line because SVC 34 requires the MGCR parameter           00850000
*  list to be in 24-BIT addressable storage                             00860000
                                                                        00870000
         GETMAIN RU,LV=DATALEN,SP=SPINPRVT,LOC=BELOW   obtain dynamic  X00880000
                                                       storage          00890000
         LR    R10,R1              address return in R1                 00900000
         USING DATAAREA,R10        addressability to dynmaic           X00910000
                                   storage                              00920000
         ST    R13,SAVEAREA+4      set backward ptr                     00930000
         LA    R15,SAVEAREA        get address of out own savearea      00940000
         ST    R15,8(,R13)         save ours to caller's                00950000
         LR    R13,R15             R13 points to our own savearea       00960000
                                                                        00961000
*  Determine which message is to be processed.  IEC070I                 00980000
                                                                        00990000
         L     R2,CTXTTXPJ         text of major                        01000000
         USING CTXTATTR,R2         comm task exit message               01010000
*        LA    R4,CTXTTMSG         text of message (126 bytes)          01020000
*        USING MSGTEXT,R4         addressibility for console messages   01030000
         USING MSGTEXT,CTXTTMSG   addressibility for console messages   01030000
                                                                        01031000
         #SPM PRINT=GEN            generate smp macros                  01040000
                                                                        01050000
                                                                        01060000
         #IF   MSGID,EQ,IEC070I                                         01070000
            #IF   RMF3ID,EQ,RMFGAT                                      01171000
                #IF  CTXTTXPN,EQ,ZERO                           C160929
                     #PERF R14,PROCESS_MAJOR                    C160929 01180000
                #ELSE  ,                                        C160929
                     L     R2,CTXTTXPN        text of minor     C160929 01000000
                     #IF   (TM,CTXTTFB1,CTXTTFMD,ON)            C160929 01020000
                       TM  CTXTTFB1,CTXTTFME  end minor line?   C160929
                       BO  END_PROCESS                          C160929
                       #PERF R14,PROCESS_MINOR                  C160929 01180000
                       #PERF R14,ISSUE_MGCR                     C160929 01190000
END_PROCESS EQU  *                                              C160929 01700000
                     #EIF ,                                     C160929
                #EIF ,                                          C160929
            #EIF                                                        01620000
                                                                        01130000
         #EIF                                                           01630000
                                                                        01640000
FINISH   EQU   *                                                        01700000
         L     R13,4(R13)                                               01710000
         FREEMAIN RU,LV=DATALEN,A=(R10),SP=SPINPRVT free the storage    01720000
         LM    R14,R12,12(R13)        restore caller's register values  01730000
         BR    R14                    go back to caller                 01740000
                                                                        01750000
*  procedure of requesting to read minon                        C160929 01760000
        #SUBR  PROCESS_MAJOR,R14                                C160929 01980000
               OI  CTXTRFB1,CTXTRPML                            C160929
        #ESUB  ,                                                C160929 02020000
                                                                        01900000
*  procedure  -  issue 'S PROC,.... via MGCR                            01910000
        #SUBR  ISSUE_MGCR,R14                                           01980000
                 STC   R1,MGCRLGTH         save length in the MGCRPL    01990000
                 SR    R0,R0                                            02000000
                 MGCR  MGCRPL              issue the command            02010000
        #ESUB                                                           02020000
                                                                        02130000
*  procedure of reading minor lines                             C160929 01760000
        #SUBR  PROCESS_MINOR,R14                                C160929 02050000
                 XC    MGCRPL(MGCRLTH),MGCRPL  clear parm list          02060000
                 LA    R7,MGCRTEXT        locate the start of buffer
                 MVC   0(L'RMF3CPC,R7),RMF3CPC   move skeleton          02070000
                 LA    R7,L'RMF3CPC(,R7)  skip over the skeleton        02070000
                 LA    R1,(MGCRTEXT-MGCRPL)+L'RMF3CPC           C160929 02110000
                 LA    R4,DSNAME      locate the dsn from ctxt  C160929 02070000
                 LA    R3,L'DSNAME    set the maximum size      C160929 02070000
DSNAME_CPY EQU   *                                              C160929 02070200
                 CLI   0(R4),C','          reach end of dsn?    C160929 02070200
                 BE    DSNAME_END          yes, branch          C160929 02070200
                 MVC   0(1,R7),0(R4)       copy this char       C160929 02071000
                 LA    R7,1(,R7)           next byte            C160929 02071000
                 LA    R4,1(,R4)           next byte            C160929 02071000
                 LA    R1,1(,R1)           increase the length  C160929 02110000
                 BCT   R3,DSNAME_CPY       loop till end of dsn C160929 02110000
DSNAME_END EQU   *                                                      02070200
                 MVI   0(R7),C''''         copy the end char            02070200
                 LA    R1,1(,R1)           increase the length          02070200
        #ESUB                                                           02120000
                                                                        02130000
                                                                        02130000
*  constants                                                            02590000
IEC070I  DC    C'IEC070I '                                              02620000
RMFGAT   DC    C'RMFGAT'                                                02620000
ZERO     DC    F'0'                                             C160929 02900000
                                                                        02921000
RMF3CPC  DC    C'S RMF3CPC,NAME='''                             C160929 02950000
                                                                        02960000
                                                                        02970000
         END   XIEC070I                                                 03530000
/*                                                                      03531000
//SYSPRINT DD   SYSOUT=*                                                03532000
//SYSLIN   DD   DUMMY                                                   03532000
