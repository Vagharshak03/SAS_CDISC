options nodate nonumber missing=' ' validvarname=upcase;

/*=============================================================================
  PHASE 1: DATA PREPARATION FOR VISUALIZATION
=============================================================================*/

data work.fig_adae;
    set myproj.myadae;
    where TRTEMFL = 'Y' and SAFFL = 'Y';
    
    AESEV = propcase(strip(AESEV)); 
    
    if missing(AESEV) then AESEV = 'Unknown';
run;

proc sort data=work.fig_adae;
    by TRTA AESEV;
run;


/*=============================================================================
  PHASE 2: PROC SGPLOT (THE VISUALIZATION)
=============================================================================*/
ods pdf file='/home/u64498821/Project_SAS_CDISC/Figure14_1.pdf' notoc dpi=300 style=journal;

title1 j=c "Figure 14.1 Treatment-Emergent Adverse Events by Severity and Treatment Arm";
title2 j=c "Safety Population";

ods graphics on / width=6.5in height=4.5in imagefmt=png;

proc sgplot data=work.fig_adae;
    
    styleattrs datacolors=(LightGreen Gold Tomato Gray);
    
    vbar TRTA / group=AESEV 
                groupdisplay=stack 
                stat=freq 
                datalabel 
                datalabelattrs=(weight=bold size=9)
                outline;
                
    xaxis label="Treatment Group" 
          labelattrs=(weight=bold size=11) 
          valueattrs=(size=10);
          
    yaxis label="Total Number of TEAEs" 
          labelattrs=(weight=bold size=11) 
          valueattrs=(size=10) 
          grid;
          

    keylegend / title="AE Severity:" 
                titleattrs=(weight=bold) 
                position=bottom 
                noborder;
run;

title;
ods pdf close;