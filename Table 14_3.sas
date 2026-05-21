options nodate nonumber missing=' ' validvarname=upcase formchar="|----|+|---+=|-/\<>*";

/*=============================================================================
  Rule: If a PT occurs in fewer than 3 patients total, group it into "Other".
=============================================================================*/
%let min_count = 5;

proc freq data=work.adae noprint;
    tables AEBODSYS * AEDECOD / out=work.pt_baseline;
run;

data work.pt_mapping;
    set work.pt_baseline;
    length AEDECOD_NEW $50;
    if COUNT < &min_count. then AEDECOD_NEW = 'Other';
    else AEDECOD_NEW = AEDECOD;
    keep AEBODSYS AEDECOD AEDECOD_NEW;
run;

proc sort data=work.adae_all; by AEBODSYS AEDECOD; run;
proc sort data=work.pt_mapping; by AEBODSYS AEDECOD; run;

data work.adae_mapped;
    merge work.adae_all(in=a) work.pt_mapping(in=b);
    by AEBODSYS AEDECOD;
    if a;
    AEDECOD = AEDECOD_NEW; /* Replace rare events with 'Other' */
run;


/*=============================================================================
  PHASE 1: DEDUPLICATION (THE CLINICAL RULE)
=============================================================================*/
proc sort data=work.adae_mapped out=work.soc_unique nodupkey;
    by TRT01PN AEBODSYS USUBJID;
run;

proc sort data=work.adae_mapped out=work.pt_unique nodupkey;
    by TRT01PN AEBODSYS AEDECOD USUBJID;
run;


/*=============================================================================
  PHASE 2: STATISTICAL FREQUENCIES & PERCENTAGES
=============================================================================*/
proc freq data=work.soc_unique noprint;
    tables TRT01PN * AEBODSYS / out=work.soc_counts;
run;

proc freq data=work.pt_unique noprint;
    tables TRT01PN * AEBODSYS * AEDECOD / out=work.pt_counts;
run;

%macro calc_pct(indata=, outdata=);
    data &outdata;
        merge &indata(in=a) work.bign(in=b);
        by TRT01PN;
        if a; 
        length VALUEC $50;
        PCT = (COUNT / BIGN) * 100;
        VALUEC = strip(put(COUNT, 4.)) || " (" || strip(put(PCT, 5.1)) || "%)";
    run;
%mend;

%calc_pct(indata=work.soc_counts, outdata=work.soc_stats);
%calc_pct(indata=work.pt_counts, outdata=work.pt_stats);


/*=============================================================================
  PHASE 3: SORTING ALGORITHM & DUMMY SKELETON
  Rule: SOC Alpha -> PT Descending -> 'Other' ALWAYS forced to the bottom.
=============================================================================*/
data work.pt_totals;
    set work.pt_stats;
    if TRT01PN = 99; 

    if strip(AEDECOD) = 'Other' then SORT_FLAG = 2; 
    else SORT_FLAG = 1;
    
    keep AEBODSYS AEDECOD COUNT SORT_FLAG;
run;

proc sort data=work.pt_totals out=work.dict_pt;
    by AEBODSYS SORT_FLAG descending COUNT AEDECOD;
run;

data work.dict_pt;
    set work.dict_pt;
    by AEBODSYS;
    if first.AEBODSYS then PT_SEQ = 0;
    PT_SEQ + 1;
run;

data work.dummy_soc_pt;
    set work.dict_pt;
    do _i = 1 to _n_trt;
        set work.trt_list point=_i nobs=_n_trt;
        output;
    end;
run;


/*=============================================================================
  PHASE 4: MERGE & ROW TYPE CATEGORIZATION
=============================================================================*/
proc sort data=work.dummy_soc_pt; by TRT01PN AEBODSYS AEDECOD; run;
proc sort data=work.pt_stats; by TRT01PN AEBODSYS AEDECOD; run;

data work.pt_final;
    merge work.dummy_soc_pt(in=a) work.pt_stats(in=b);
    by TRT01PN AEBODSYS AEDECOD;
    if a; 
    if missing(VALUEC) then VALUEC = "0 (0.0%)";
    
    length LABEL $100;
    ROW_TYPE = 2; 
    LABEL = 'A0A0A0'x || strip(AEDECOD); 
    keep TRT01PN AEBODSYS PT_SEQ ROW_TYPE LABEL VALUEC;
run;

data work.soc_final;
    set work.soc_stats;
    length LABEL $100;
    ROW_TYPE = 1;
    PT_SEQ = 0; 
    LABEL = strip(AEBODSYS);
    keep TRT01PN AEBODSYS PT_SEQ ROW_TYPE LABEL VALUEC;
run;

data work.table_14_3_stacked;
    set work.soc_final work.pt_final;
run;


/*=============================================================================
  PHASE 5: TRANSPOSE
=============================================================================*/
proc sort data=work.table_14_3_stacked;
    by AEBODSYS ROW_TYPE PT_SEQ;
run;

proc transpose data=work.table_14_3_stacked out=work.table_14_3_data(drop=_NAME_) prefix=TRT_;
    by AEBODSYS ROW_TYPE PT_SEQ LABEL;
    id TRT01PN;
    var VALUEC;
run;

data work.table_14_3_data;
    set work.table_14_3_data;
    array trt_cols[*] TRT_1 TRT_2 TRT_3 TRT_99;
    do i = 1 to dim(trt_cols);
        if missing(trt_cols[i]) then trt_cols[i] = "0 (0.0%)";
    end;
    drop i;
run;


/*=============================================================================
  PHASE 6: PROC REPORT (SECTIONED & GROUPED VISUALS)
=============================================================================*/
ods pdf file="/home/u64498821/Project_SAS_CDISC/Table_14_3.pdf" style=Journal;

title1 j=c "Table 14.3 Treatment-Emergent Adverse Events by System Organ Class and Preferred Term";
title2 j=c "Safety Population";

proc report data=work.table_14_3_data split='|' nowd headline headskip style(report)={width=100%};
    
    columns AEBODSYS ROW_TYPE PT_SEQ LABEL TRT_1 TRT_2 TRT_3 TRT_99;
    
    define AEBODSYS / order noprint;
    define ROW_TYPE / order noprint;
    define PT_SEQ   / order noprint;
    
    define LABEL / display "System Organ Class /|  Preferred Term" 
                   style(column)={width=40% just=left asis=yes};
                   
    define TRT_1 / display "Placebo|(N=&N_1.)";
    define TRT_2 / display "Low Dose|(N=&N_2.)";
    define TRT_3 / display "High Dose|(N=&N_3.)";
    define TRT_99 / display "Total|(N=&N_99.)";

    compute LABEL;
        if ROW_TYPE = 1 then call define(_col_, "style", "style=[fontweight=bold]");
    endcomp;

    compute after AEBODSYS;
        line ' ';
    endcomp;
run;

title; 
ods pdf close;
