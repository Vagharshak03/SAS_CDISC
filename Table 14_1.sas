options nodate nonumber missing=' ' validvarname=upcase formchar="|----|+|---+=|-/\<>*";
/*=============================================================================
  PHASE 1: ADSL CREATION & TOTAL COLUMN REPLICATION
=============================================================================*/

data myproj.adsl;
    set myproj.dm_final;
    TRTA = ARM;
    if ARM not in ('Screen Failure', 'Not Assigned') then SAFFL = 'Y';
    else SAFFL = 'N';

    if SAFFL = 'Y';
run;

data work.adsl;
    set myproj.dm_final;
    length TRT01P $20 AGEGR1 $10 SAFFL $1;
   
    if index(upcase(ARM), 'PLACEBO') > 0 then TRT01PN = 1;
    else if index(upcase(ARM), 'LOW') > 0 then TRT01PN = 2;
    else if index(upcase(ARM), 'HIGH') > 0 then TRT01PN = 3;
    else TRT01PN = 98;

if not missing(AGE) then do;
    if AGE < 65 then AGEGR1 = '<65';
    else AGEGR1 = '>=65';
end;
    SEX = upcase(SEX);
    SAFFL = 'Y';
    
    keep USUBJID TRT01PN AGE AGEGR1 SEX SAFFL;
run;

data work.adsl_all;
    set work.adsl;
    output;
    TRT01PN = 99;   
    output;
run;


/*=============================================================================
  PHASE 2: BIG "N" MACRO VARIABLES & DUMMY SKELETON
=============================================================================*/
proc freq data=work.adsl_all noprint;
    tables TRT01PN / out=work.bign(rename=(count=BIGN));
run;

data _null_;
    set work.bign;
    call symputx(cats('N_', TRT01PN), BIGN);
run;

data work.shell;
    length LABEL $50;
    ORD=1; LABEL="Age (years)"; output;
    ORD=2; LABEL="  n"; output;
    ORD=3; LABEL="  Mean (SD)"; output;
    ORD=4; LABEL="  Median"; output;
    ORD=5; LABEL="  Min, Max"; output;
    ORD=6; LABEL="Age Group, n (%)"; output;
    ORD=7; LABEL="  < 65 years"; output;
    ORD=8; LABEL="  >= 65 years"; output;
    ORD=9; LABEL="Sex, n (%)"; output;
    ORD=10; LABEL="  Male"; output;
    ORD=11; LABEL="  Female"; output;
run;

proc sort data=work.bign out=work.trt_list(keep=TRT01PN); 
    by TRT01PN; 
run;

data work.dummy_full;
    set work.shell;
    do _i = 1 to _n_trt;
        set work.trt_list point=_i nobs=_n_trt;
        output;
    end;
run;


/*=============================================================================
  PHASE 3: STATISTICAL CALCULATIONS
=============================================================================*/

proc summary data=work.adsl_all nway;
    class TRT01PN;
    var AGE;
    output out=work.age_sum(drop=_type_ _freq_)
           n=n mean=mean std=std median=median min=min max=max;
run;

data work.stat_age;
    set work.age_sum;
    length LABEL $50 VALUEC $50;
    
    ORD=2; LABEL="  n"; VALUEC = put(n, 4.); output;
    
    ORD=3; LABEL="  Mean (SD)"; 
    VALUEC = strip(put(mean, 8.1)) || " (" || strip(put(std, 8.2)) || ")"; output;
    
    ORD=4; LABEL="  Median"; VALUEC = put(median, 8.1); output;
    
    ORD=5; LABEL="  Min, Max"; 
    VALUEC = strip(put(min, 8.)) || ", " || strip(put(max, 8.)); output;
    
    keep TRT01PN ORD LABEL VALUEC;
run;

%macro cat_stat(var=, val=, ord=, lbl=);
    proc freq data=work.adsl_all noprint;
        tables TRT01PN * &var / out=work.frq_&var._&ord;
    run;
    
    data work.stat_&var._&ord;
        merge work.frq_&var._&ord (in=a) work.bign (in=b);
        by TRT01PN;
        if a;
        
        length LABEL $50 VALUEC $50;
        if &var = "&val" then do;
            ORD = &ord;
            LABEL = "&lbl";
            pct = (count / BIGN) * 100;
            VALUEC = strip(put(count, 4.)) || " (" || strip(put(pct, 5.1)) || "%)";
            output;
        end;
        keep TRT01PN ORD LABEL VALUEC;
    run;
%mend;

%cat_stat(var=AGEGR1, val=<65, ord=7,  lbl=  < 65 years);
%cat_stat(var=AGEGR1, val=>=65, ord=8, lbl=  >= 65 years);
%cat_stat(var=SEX,    val=M,   ord=10, lbl=  Male);
%cat_stat(var=SEX,    val=F,   ord=11, lbl=  Female);


/*=============================================================================
  PHASE 4: CONSOLIDATION, DUMMY MERGE & TRANSPOSE
=============================================================================*/
data work.stats_all;
    set work.stat_age
        work.stat_AGEGR1_7
        work.stat_AGEGR1_8
        work.stat_SEX_10
        work.stat_SEX_11;
run;

proc sort data=work.stats_all; by TRT01PN ORD; run;
proc sort data=work.dummy_full; by TRT01PN ORD; run;

data work.final_blocks;
    merge work.dummy_full(in=a) work.stats_all(in=b);
    by TRT01PN ORD;
    if a;
    
    if missing(VALUEC) then do;
        if ORD > 5 then VALUEC = "0 (0.0%)"; /* Categorical */
        else VALUEC = "0";                   /* Continuous */
    end;
    
    if ORD in (1, 6, 9) then VALUEC = "";
run;

proc sort data=work.final_blocks;
    by ORD LABEL;
run;

proc transpose data=work.final_blocks out=work.table_data(drop=_NAME_) prefix=TRT_;
    by ORD LABEL;
    id TRT01PN;
    var VALUEC;
run;


/*=============================================================================
  PHASE 5: REPORTING (THE OUTPUT)
=============================================================================*/
ods pdf file="/home/u64498821/Project_SAS_CDISC/Table_14_1.pdf" style=Journal;
title1 j=c "Table 14.1 Demographic and Baseline Characteristics";
title2 j=c "Safety Population";

proc report data=work.table_data split='|' nowd headline headskip style(report)={width=100%};
    
    columns ORD LABEL TRT_1 TRT_2 TRT_3 TRT_99;
    define ORD / order noprint;
    define LABEL / display "Parameter / Category";
    define TRT_1 / display "Placebo|(N=&N_1.)";
    define TRT_2 / display "Low Dose|(N=&N_2.)";
    define TRT_3 / display "High Dose|(N=&N_3.)" ;
    define TRT_99 / display "Total|(N=&N_99.)";
run;

title;
ods pdf close;