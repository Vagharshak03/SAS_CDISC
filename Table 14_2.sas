/*=============================================================================
  PHASE 1: EVENT-LEVEL ADAE CREATION
=============================================================================*/
proc sort data=work.adsl out=work.adsl_srt; by USUBJID; run;
proc sort data=myproj.ae_final out=work.ae_srt; by USUBJID; run;

data work.adae;
    merge work.adsl_srt(in=a) work.ae_srt(in=b);
    by USUBJID;
    
    if a and b; 

    AESER = upcase(strip(AESER));
    AESEV = upcase(strip(AESEV));
    TRTEMFL = 'Y';
    
TRTEMFL = 'N';
if not missing(ASTDT) and not missing(TRTSDT) then do;
	if ASTDT >= TRTSDT then TRTEMFL = 'Y';
end;
else if missing(ASTDT) then TRTEMFL = 'Y'; /* Conservative Clinical Rule */
    S
    if TRTEMFL = 'Y';
run;

data work.adae_all;
    set work.adae;
    output;         
    TRT01PN = 99;   
    output;         
run;


/*=============================================================================
  PHASE 2: PATIENT-LEVEL DEDUPLICATION (The Clinical Rule)
=============================================================================*/
proc sort data=work.adae_all out=work.teae_any nodupkey;
    by TRT01PN USUBJID;
run;
data work.teae_any; set work.teae_any; FLAG_TYPE = 1; run;

data work.ae_ser; set work.adae_all; if AESER = 'Y'; run;
proc sort data=work.ae_ser out=work.teae_ser nodupkey;
    by TRT01PN USUBJID;
run;
data work.teae_ser; set work.teae_ser; FLAG_TYPE = 2; run;

data work.ae_sev; set work.adae_all; if AESEV = 'SEVERE'; run;
proc sort data=work.ae_sev out=work.teae_sev nodupkey;
    by TRT01PN USUBJID;
run;
data work.teae_sev; set work.teae_sev; FLAG_TYPE = 3; run;

data work.teae_flags;
    set work.teae_any work.teae_ser work.teae_sev;
run;


/*=============================================================================
  PHASE 3: STATISTICAL CALCULATION & DUMMY SKELETON
=============================================================================*/

/* 1. Calculate the 'little n' (Count of patients with the flag) */
proc freq data=work.teae_flags noprint;
    tables TRT01PN * FLAG_TYPE / out=work.teae_counts;
run;

/* 2. Merge with Big N (calculated in Table 14.1) and format n (%) */
data work.teae_stats;
    merge work.teae_counts(in=a) work.bign(in=b);
    by TRT01PN;
    if a; /* Keep only if count exists */
    
    length VALUEC $50;
    PCT = (COUNT / BIGN) * 100;
    VALUEC = strip(put(COUNT, 4.)) || " (" || strip(put(PCT, 5.1)) || "%)";
    
    keep TRT01PN FLAG_TYPE VALUEC;
run;

data work.shell_ae;
    length LABEL $70;
    FLAG_TYPE=1; LABEL="Subjects with at least one TEAE"; output;
    FLAG_TYPE=2; LABEL="Subjects with at least one Serious TEAE"; output;
    FLAG_TYPE=3; LABEL="Subjects with at least one Severe TEAE"; output;
run;

data work.dummy_ae_full;
    set work.shell_ae;
    do _i = 1 to _n_trt;
        set work.trt_list point=_i nobs=_n_trt;
        output;
    end;
run;


/*=============================================================================
  PHASE 4: CONSOLIDATION & TRANSPOSE
=============================================================================*/
proc sort data=work.dummy_ae_full; by TRT01PN FLAG_TYPE; run;
proc sort data=work.teae_stats; by TRT01PN FLAG_TYPE; run;

data work.final_ae_blocks;
    merge work.dummy_ae_full(in=a) work.teae_stats(in=b);
    by TRT01PN FLAG_TYPE;
    if a; 
    if missing(VALUEC) then VALUEC = "0 (0.0%)"; 
run;


proc sort data=work.final_ae_blocks;
    by FLAG_TYPE LABEL;
run;

proc transpose data=work.final_ae_blocks out=work.table_ae_data(drop=_NAME_) prefix=TRT_;
    by FLAG_TYPE LABEL;
    id TRT01PN;
    var VALUEC;
run;


/*=============================================================================
  PHASE 5: REPORTING (THE OUTPUT)
=============================================================================*/
ods pdf file="/home/u64498821/Project_SAS_CDISC/Table_14_2.pdf" style=Journal;

title1 j=c "Table 14.2 Overall Summary of Treatment-Emergent Adverse Events";
title2 j=c "Safety Population";

proc report data=work.table_ae_data split='|' nowd headline headskip style(report)={width=100%};
    columns FLAG_TYPE LABEL TRT_1 TRT_2 TRT_3 TRT_99;
    define FLAG_TYPE / order noprint;
    define LABEL / display "Category" ;   
    define TRT_1 / display "Placebo|(N=&N_1.)";           
    define TRT_2 / display "Low Dose|(N=&N_2.)" ;
    define TRT_3 / display "High Dose|(N=&N_3.)" ;
    define TRT_99 / display "Total|(N=&N_99.)" ;
run;

title;
ods pdf close;