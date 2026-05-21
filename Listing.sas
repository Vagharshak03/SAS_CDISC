options nodate nonumber missing=' ' validvarname=upcase formchar="|----|+|---+=|-/\<>*";

/*=============================================================================
  PHASE 1: DATA PREPARATION & FILTERING
=============================================================================*/

data work.listing_adae;
    set myproj.myadae;

    where TRTEMFL = 'Y' and SAFFL = 'Y';

    format ASTDT TRTSDT date9.;
    
    AESER = upcase(strip(AESER));
    AESEV = propcase(strip(AESEV));
run;


/*=============================================================================
  PHASE 2: SORTING
  Rule: Sort by Subject ID, then by AE Start Date.
=============================================================================*/

proc sort data=work.listing_adae;
    by USUBJID ASTDT;
run;

/*=============================================================================
  PHASE 3: PROC REPORT (THE LISTING OUTPUT)
=============================================================================*/
ods pdf file="/home/u64498821/Project_SAS_CDISC/Listing 14_1.pdf" style=Journal;
title1 j=c "Listing 14.1 Patient Adverse Event Listing";
title2 j=c "Safety Population";

proc report data=work.listing_adae split='|' nowd headline headskip style(report)={width=100%};
    columns USUBJID TRTA AEDECOD AEBODSYS AESEV AESER ASTDT TRTSDT TRTEMFL;
    define USUBJID / order "Subject ID"; 
    define TRTA    / order "Treatment";                     
    define AEDECOD / display "Preferred Term";   
    define AEBODSYS/ display "System Organ Class";
    define AESEV   / display "Severity";
    define AESER   / display "Serious|(Y/N)";
    define ASTDT   / display "AE Start Date";
    define TRTSDT  / display "Treatment|Start Date";
    define TRTEMFL / display "TEAE|(Y/N)";
run;

title;
ods pdf close;