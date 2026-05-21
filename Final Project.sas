libname myproj "/home/u64498821/Project_SAS_CDISC";
libname myaexpt xport "/home/u64498821/Project_SAS_CDISC/ae.xpt" access=readonly;
libname mydmxpt xport "/home/u64498821/Project_SAS_CDISC/dm.xpt" access=readonly;
proc copy inlib=mydmxpt outlib=myproj;run;
proc copy inlib=myaexpt outlib=myproj;run;

proc contents data=myproj.dm;run;

proc print data=myproj.dm(obs=10);
var USUBJID ARM AGE SEX;
run;

proc contents data=myproj.ae;run;

proc print data=myproj.ae(obs=10);
var USUBJID AEBODSYS AEDECOD AESEV;
run;

data myproj.dm_validated;
    set myproj.dm;

    length DMVALIDFL CTVALIDFL DATEVALIDFL $1;
    
    if cmiss(of STUDYID, USUBJID, SEX, AGE, ARM) > 0
    then DMVALIDFL='N';
    else DMVALIDFL='Y';


    CTVALIDFL='Y';
    
    if not (SEX in ('M','F','U'))
    then CTVALIDFL='N';

    DATEVALIDFL='Y';

    if missing(RFSTDTC)
    then DATEVALIDFL='N';

    else if prxmatch('/^\d{4}-\d{2}-\d{2}$/', strip(RFSTDTC))=0
    then DATEVALIDFL='N';

run;

proc sort data=myproj.dm_validated out=myproj.dm_final
          nodupkey dupout=myproj.dm_duplicates;
    by USUBJID;
run;


data myproj.ae_validated;
    set myproj.ae;

    length AEVALIDFL CTVALIDFL DATEVALIDFL $1;

    if cmiss(of USUBJID, AETERM, AEDECOD, AESEV, AESER, AESTDTC) > 0
    then AEVALIDFL='N';
    else AEVALIDFL='Y';

    CTVALIDFL='Y';
    if not (AESEV in ('MILD','MODERATE','SEVERE'))
    then CTVALIDFL='N';

    if not (AESER in ('Y','N'))
    then CTVALIDFL='N';

    DATEVALIDFL='Y';

    if missing(AESTDTC)
    then DATEVALIDFL='N';

    else if prxmatch('/^\d{4}-\d{2}-\d{2}$/', strip(AESTDTC))=0
    then DATEVALIDFL='N';

run;

proc sort data=myproj.ae_validated out=myproj.ae_final;
    by USUBJID AETERM AESTDTC;
run;


proc sort data=myproj.dm_final;
    by USUBJID;
run;

proc sort data=myproj.ae_final;
    by USUBJID;
run;