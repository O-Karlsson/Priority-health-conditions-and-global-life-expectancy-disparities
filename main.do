global dir "C:\Users\\Karls\\OneDrive\Everything\Work in progress\CIH\deomposition paper\"
global data "C:\Users\\Karls\\OneDrive\Everything\Work in progress\CIH\data\"  
cd "$dir"

// Documentation on the GHE data
*http://cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/ghe2021_cod_methods.pdf?sfvrsn=dca346b7_1

// The WHO GHE data is available on request from @WHO (variable names may differ): The file used here is GHE2021_CoD.dta
// at the bottom of this page are excel sheets: https://www.who.int/data/gho/data/themes/mortality-and-global-health-estimates/ghe-leading-causes-of-death

***********************************************************************************
***********************************************************************************
*** Picking the causes of deaths to decompose fom the WHO GHE and making key
***********************************************************************************
***********************************************************************************
	
use if year==2019 & sex==2  & iso3 == "NGA" & inlist(age,0)  using "$data\GHE2021_CoD" , clear // just need a single observation for each cause

keep ghecause causename

// The GHE are divided into 4 levels (see documentations at top)
gen level = 1 if inlist(ghecause,10,600,1510,1700)
replace level = 2 if inlist(ghecause,20,380,420,490,540,610,790,800,810,820,940,1020,1100,1170,1210,1260,1330,1340,1400,1470,1505,1520,1600)
replace level = 3 if inlist(ghecause,30, 40, 100, 110, 120, 170, 180, 185, 210, 330, 365, 370, 390, 395, 400, 410, 500, 510, 520, 530, 550, 560, 570) | inlist(ghecause,580, 590, 620, 630, 640, 650, 660, 670, 680, 690, 700, 710, 720, 730, 740, 742, 745, 750, 751, 752, 753, 754) | inlist(ghecause,755, 760, 770, 780, 811, 812, 813, 814, 830, 840, 850, 860, 870, 880, 890, 900, 910, 920, 930, 950, 960) | inlist(ghecause, 970, 980, 990, 1000, 1010, 1030, 1040, 1050, 1060, 1070, 1080, 1090, 1110, 1120, 1130, 1140, 1150) | inlist(ghecause, 1160, 1180, 1190, 1200, 1220, 1230, 1240, 1241, 1242, 1244, 1246, 1248, 1250, 1270, 1280, 1290, 1300, 1310, 1320) | inlist(ghecause, 1350, 1360, 1370, 1380, 1390, 1410, 1420, 1430, 1440, 1450, 1460, 1480, 1490, 1500, 1502, 1530) | inlist(ghecause, 1540, 1550, 1560, 1570, 1575, 1580, 1590, 1610, 1620, 1630)
replace level = 4 if level==.
replace level = 0 if ghecause==0 // All deaths

// The types are the priority conditions: 1=I-8; 2=NCD-7; 3= All other
gen type = 1 if inlist(ghecause,30,100,110,120,220,390,420,490) // level 3: 390 120 110 100 30 ...  level 4: 220 
replace type = 2 if inlist(ghecause, 620,640,661,662,680,710,753,800,1110,1130,1141,1142,1180,1231,1232,1272,1530,1610) // level 3: 620 640 680 710 753 1110 1130 1180 1530 1610 .. levlel 4: 661 662 1141 1142 1231 1232 1272
replace type = 3 if inlist(ghecause, 395, 1700) // COVID

keep if level==2 | type!=.  // only keep priority conditions: otherwise only keep level 2 causes (+COVID)

replace type = 3 if type == . // then all causes that are not priority conditions are "other"

// Figure out the level 2 parent code number for level 3 and 4 priority conditions (+COVID) so these can be substracted in order to construct "other causes" (below)
sort ghecause
gen level2parent = ghecause[_n-1] if level>level[_n-1] & level[_n-1]==2
replace level2parent = level2parent[_n-1] if level2parent == . & level>2

compress
save cause_codes_ghe , replace /* This files is used as a key of causes of death */			



***********************************************************************************
***********************************************************************************
*** Generating a geographic key
***********************************************************************************
***********************************************************************************

// During estimation the files will only include a geoid to save memory. This file is a key

// A file which has the CIH regions and country name of each iso3
use region if region!="" using "$data\\regions", clear
replace region = "World" if strpos(region,"*")
duplicates drop region, force

// The e0 quantiles will be added for countries below
set obs `=_N+10'
gen exQuantile = 2001+_N-_n if region=="" // add 2000 so it's clear it's a decile and doens't overlap with any country or region ID. Also reverse: the top decile (1001) is used as a benchmark so keep track of it
save temp, replace

// Make sure to only include countries available in the GHE
use if year==2019 & sex==3 & ghecause==0 & inlist(age,0) & length(iso3)==3  using "$data\GHE2021_CoD" , clear
keep iso3
merge 1:1 iso3 using "$data\\regions", keepusing(region country) keep(master match) nogen
append using temp

encode iso3, gen(geoid)
label define regionid 1 "World" 2 "North Atlantic"  , replace // the North Atlantic (1002) if ususally the benchmark so need to keep track if its  geoid
encode region if !strpos(region,"*") , gen(regionid) // the * is used for the three big countries, China, United States, India
replace regionid = regionid+1000 // add 1000 so it's clear it's a region and doens't overlap with any country ID

 // 'country' will mean location more generally (or decile)
replace country = region if country == ""
replace country = "Quantile " + string(exQuantile-2000)  if country == ""

 // iso3 is unique string identifier, which also includes regions and quantiles (and iso3 in case of countries)
replace iso3 = "region::"+region if iso3=="" & region!=""
replace iso3 = "quantile::"+string(exQuantile-2000) if iso3==""

 // all location and deciles have a specific ID
replace geoid= regionid if geoid==.
replace geoid= exQuantile if geoid==.

label drop _all
foreach var of varlist _all {
    label var `var' ""
}

compress
save geoids, replace


***********************************************************************************
***********************************************************************************
*** Preparing the UN data (only need mx)
***********************************************************************************
***********************************************************************************
// data from https://population.un.org/wpp/downloads?folder=Standard%20Projections&group=CSV%20format

*https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES/WPP2024_PopulationBySingleAgeSex_Medium_1950-2023.csv.gz
// population numbers are just used for weighting the aggregate life tables
import delimited using "$data\\WPP 2024\\WPP2024_PopulationBySingleAgeSex_Medium_1950-2023.csv", clear encoding("utf-8")  case(preserve)
rename  (Time ISO3_code PopMale PopFemale PopTotal)(year iso3 unpop1 unpop2 unpop3)
keep if inlist(year, 2000,2010,2019,2021)  & iso3!=""
egen age = cut(AgeGrpStart), at(0,1,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100,101)
keep year iso3 un* age AgeGrpStart
reshape long unpop , i(iso3 year AgeGrpStart) j(sex) 
bys iso3 year sex: egen tpop=total(unpop) // for weighting the deciles below
bys iso3 year sex age (AgeGrpStart): keep if _n==1

drop AgeGrpStart
save temp, replace

*https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES/WPP2024_Life_Table_Abridged_Medium_1950-2023.csv.gz
// Death fractions from WHO GHE are multiplied by the UN mortality rates so the life expectancy estimates will match the UN
import delimited using "$data\\WPP 2024\\WPP2024_Life_Table_Abridged_Medium_1950-2023.csv" , clear encoding("utf-8")  case(preserve)
rename  (Time AgeGrpStart AgeGrpSpan ISO3_code SexID)(year age n iso3 sex)
keep if inlist(year , 2000,2010,2019,2021) & iso3!="" 
keep year age n iso3 sex mx qx px lx dx Lx Sx Tx ex ax
merge 1:1 iso3 year age sex using temp, nogen
merge m:1 iso3 using geoids , nogen keep(match) keepusing(geoid regionid) // only include countries that are also in the WHO GHE
gen D=unpop*qx // deaths (D) and unpop are used for weighting the aggregates (need to do this before cutting the table at 85+)
drop qx px lx Sx Tx

// cut the life table at 85+ instead of 100+ to match the UN GHE
preserve
drop if age<85
bys geoid sex year (age): replace ax = ex[1]
collapse (sum) Lx dx D (first) ax age regionid, by(geoid sex year) // no tpop or unpop for 85+
gen mx = dx/Lx
save temp, replace
restore
drop if age >=85
append using temp

gen double Lxp = ((unpop-D)*n)+(D*ax)
replace Lxp = D*ax if age==85
save temp, replace

***********************************************************************************
*** aggregate UN data across regions
***********************************************************************************

replace geoid = regionid
drop if regionid==.
collapse (rawsum) D Lxp  (first) n (mean) ax [aweight=D],  by(geoid sex year age)
gen mx = D/Lxp
append using temp
save temp2, replace

***********************************************************************************
*** create quantiles of e0 and aggregate 
***********************************************************************************

use temp, clear
gen exrank = ex if sex == 3 & year == 2019 & age == 0 & !inlist(iso3,"CHN","USA","IND")
xtile exQuantile = exrank [aweight=tpop] ,  nquantiles(10)
bys geoid (exQuantile): replace exQuantile = exQuantile[1]
replace exQuantile = (-exQuantile+11)+2000 // to match the geoid key
table exQuantile if year == 2019 & age == 0 & sex ==3, content(sum tpop)

preserve
keep geoid exQuantile
duplicates drop geoid, force
merge 1:1 geoid using geoids, nogen
label drop _all
foreach var of varlist _all {
    label var `var' ""
}
compress
save geoids, replace
restore

replace geoid = exQuantile
drop if exQuantile==.
collapse (rawsum) D Lxp  (first) n (mean) ax [aweight=D],  by(geoid sex year age)
gen mx = D/Lxp
append using temp2
save temp2, replace

***********************************************************************************
*** aggregate global
***********************************************************************************

use temp, clear
replace geoid = 1001
collapse (rawsum) D Lxp  (first) n geoid (mean) ax [aweight=D],  by(sex year age)
gen mx = D/Lxp
append using temp2


keep age n mx ax geoid sex year

gen double nqx = (n*mx)/(1+(n-ax)*mx)
replace nqx = 1 if age==85
gen double lx = 1 if age==0
bys geoid year sex (age): replace lx = lx[_n-1]*(1-nqx[_n-1]) if age!=0
gen double ndx = nqx*lx
gen double nLx = ((lx-ndx)*n)+(ndx*ax)
replace nLx = lx/m if age==85
bys geoid sex year: egen double Tx = total(nLx)
bys geoid year sex (age): replace Tx=Tx[_n-1]-nLx[_n-1] if age!=0
gen double ex = Tx/lx
*br if sex == 1 & iso3=="world::World" // Compare to UN lift tables (especially the aggregates)



foreach var in nLx lx ex Tx mx {
// The North Atlantic 2019 benchmark
gen `var'b1 = `var' if year == 2019 & geoid==1002
bys sex age (`var'b1): replace `var'b = `var'b1[1]

// The top decile benchmark
gen `var'b2 = `var' if year == 2019 & geoid==2001 & sex == 3
bys age (`var'b2): replace `var'b2 = `var'b2[1]

}

// The age components (weights)
forval i = 1/2 {
// Arriaga weights
gen Aw`i' = (lx)*((nLxb`i'/lxb`i')-(nLx/lx))
bys geoid year sex (age): replace Aw`i'= Aw`i'+(lx*(lxb`i'[_n+1]/lxb`i')-lx[_n+1])*exb`i'[_n+1] if age!=85

// Pollard age weights 
gen Pw`i' =((lx*exb`i')+(lxb`i'*ex))/2
bys geoid year sex (age): replace Pw`i'=n/2*(Pw`i'+Pw`i'[_n+1])
replace Pw`i'=((Txb`i'/mx)+(Tx/mxb`i'))/2 if age == 85
}

keep geoid year sex age ex mx Aw1 Pw1 mxb1 exb1 Aw2 Pw2 mxb2 exb2
save UNdata , replace

***********************************************************************************
***********************************************************************************
*** Peparing ghe WHO GHE
***********************************************************************************
***********************************************************************************

use ghecause iso3 year sex dths dths_up age if inlist(year,2000,2010,2019,2021) & !inrange(age, 0.01 , 0.9) & length(iso3)==3 & ghecause!=0 using "$data\GHE2021_CoD", clear
merge m:1 ghecause using cause_codes_ghe, keep(match) nogen keepusing(ghecause level2parent) // the cause key from above
merge m:1 iso3 using geoids , nogen keep(match) keepusing(geoid) // the geoids from above (not sure why this is being added here: maybe there are some countries in the WHO that are not in the UN)
drop iso3

fillin geoid sex year age ghecause // only maternal deaths no need to adjust level2parent

replace dths=0 if dths<0 | dths==. // ???
replace dths_up=0 if dths_up<0 | dths_up==.

// calculating the standard errors (may want to update this to a diffrent distubution)
gen se = (ln(dths_up)-ln(dths))/1.96 if dths!=0 // upper bound is sometimes non zero while the lower one is
replace se = 0 if dths== 0

merge m:1 geoid using geoids, nogen keep(match) keepusing(geoid exQuantile regionid)

keep age sex year dths se ghecause geoid exQuantile regionid level2parent

label drop _all
foreach var of varlist _all {
    label var `var' ""
}
compress
save data , replace


***********************************************************************************
***********************************************************************************
*** Running the decomposition
***********************************************************************************
***********************************************************************************

clear	
cd "$dir"
sysdir set PERSONAL "$dir\\dos" // this folder should have the dcmpsim.ado stored
clear all
capture mkdir simfiles // There are a 1001 aux files: store them here

parallel initialize  26, force
program def myprogram
	local j = 0
	forval i = 1/25 {
	if	($pll_instance == `i') dcmpsim, dir("$dir") rounds(40) child(`i') outputdir("$dir\\simfiles") type(simulation) // this simulates deaths
	}
	if	($pll_instance == 26) dcmpsim, dir("$dir") rounds(1) child(26) outputdir("$dir\\simfiles") type(central) // this just use the central estimated deaths
end
parallel, nodata processors(1) prog(myprogram): myprogram

// Combining all the simulations
clear
local files : dir "$dir\\simfiles\\"  files "simulation_*.dta"
dis `"`files'"'
gen year=.
foreach file of local files {
append using "$dir\\simfiles\\`file'"
}

// get the 2.5 and 97.5 percentile (as well as the median)
foreach var in P A Pd PNo0  {
bys geoid sex year ghecause (`var'): gen `var'_lo = `var'[25]
bys geoid sex year ghecause (`var'): gen `var'_up = `var'[975]
bys geoid sex year ghecause (`var'): gen `var'_me = (`var'[500]+`var'[501])/2
drop `var'
}

bys geoid sex year ghecause: keep if _n==1 // faster than duplicates drop


merge 1:1 geoid sex year ghecause using "$dir\\simfiles\\central_1_26" , nogen keep(master match) // add the results that used the central estimate for deaths
merge m:1 geoid using geoids , nogen keep(master match) // add the geoid keys from above
merge m:1 ghecause using cause_codes_ghe, nogen keep(master match) // add the causeid key from above 
save simdata, replace

***********************************************************************************
***********************************************************************************
*** cleaning the estimates file
***********************************************************************************
***********************************************************************************

use simdata, clear

// create causenames for the priority conditions (that were not made up of single GHE causes)
replace causename = "Atherosclerotic CVDs" if ghecause==9972
replace causename = "Infection-related NCDs" if ghecause==9973
replace causename = "Tobacco-related NCDs" if ghecause==9974
replace causename = "Diabetes" if ghecause==9975

// create causenames for the 'Totals'
replace causename = "Total impact of I-8" if ghecause == 9001
replace causename = "Total impact of NCD-7" if ghecause == 9002
replace causename = "Total impact of other causes" if ghecause == 9003
replace causename = "Total life expectancy gap" if ghecause == -1

// American spelling for cause names
replace causename="Diarrheal diseases" if causename=="Diarrhoeal diseases"
replace causename="Ischemic heart disease" if causename=="Ischaemic heart disease"
replace causename="Hemorrhagic stroke" if causename=="Haemorrhagic stroke"
replace causename = "Ischemic stroke" if causename == "Ischaemic stroke"

// Cleaner or more transparent causenames names
replace causename = "COVID-19 pandemic-related" if causename=="Other COVID-19 pandemic-related outcomes"
replace causename = "Suicide" if causename=="Self-harm"

// renaming causenames that had priority conditions substracted from them. I list the condition if it's short, other wise just ex. NCD-7
replace causename = "Cardiovascular diseases ex. NCD-7" if causename=="Cardiovascular diseases"
replace causename = "Digestive diseases ex. NCD-7" if causename=="Digestive diseases"
replace causename = "Genitourinary diseases ex. NCD-7" if causename=="Genitourinary diseases"
replace causename = "Inf. and parasitic d. ex. I-8 & NCD-7" if causename=="Infectious and parasitic diseases"
replace causename = "Violence" if causename=="Intentional injuries" // suicide was removed since it was a prioirty conditions. What is left is just violence
replace causename = "Cancers ex. NCD-7" if causename=="Malignant neoplasms"
replace causename = "Respiratory diseases ex. NCD-7" if causename=="Respiratory diseases"
replace causename = "Respiratory infections ex. I-8" if causename=="Respiratory infections "
replace causename = "Unintentional injuries ex. NCD-7" if causename=="Unintentional injuries"

replace causename = subinstr(causename, " and ", " & ",.)

// unround the numbers (it was multiplied by 10000 and rounded to save space in the .ado file)
foreach var in P_lo P_up P_me A_lo A_up A_me Pd_lo Pd_up Pd_me PNo0_lo PNo0_up PNo0_me P A Pd PNo0 {
replace `var' = `var'/10000
}
replace year = 2000+year // 2000 was subtracted from year to save space in the .ado file

// add the e0 and benchmark e0s (ie, North Atlantic and top decile)
gen age = 0
merge m:1 geoid year sex age using UNdata, keep(master match) nogen keepusing(ex exb1 exb2)
drop age

// a string ID for the groups of causes
gen group = "_CCD" if type == 1 | ghecause == 9001
replace group = "_NCD" if type == 2 | ghecause == 9002 | inrange(ghecause,9972,9975)
replace group = "_Other" if type == 3 | ghecause == 9003
replace group = "_All" if  ghecause == -1

label define groupnr  1 "_All" 2 "_NCD" 3 "_CCD" 4 "_Other" , replace
encode group, gen(groupnr) // A numberical ID for the groups of causes (used for sorting)

// the extent of detail of the causes (used for selection or sorting)
gen detail = 0 if ghecause == -1 // All causes (total gap)
replace detail = 1 if inrange(ghecause,9001,9003) // three broad causes: NCD-7, I-8, and Other
replace detail = 2 if inrange(ghecause,9971,9975) // Priority conditions that were NOT the same as GHE causes: after aggregating
replace detail = 4 if inlist(ghecause, 1130,1141) | inlist(ghecause,640,661,662,710,1110,1231,1232) | inlist(ghecause, 620, 680, 753, 1180) | inlist(ghecause, 800,1272) // Priority conditions that were NOT the same as GHE causes before aggregating
replace detail = 3 if detail==. // Other causes and priority conditions that were the same as GHE causes (ie, not aggregated)

foreach var in  P A Pd PNo0 {
replace `var'_lo=. if `var'_up==`var'_lo
replace `var'_up=. if `var'_lo==.
}

replace country = subinstr(country, " and ", " & ",.)

compress 
save estimates, replace


***********************************************************************************
***********************************************************************************
*** Create table with all estimates
***********************************************************************************
***********************************************************************************

use estimates , clear

bys iso3 year sex (ghecause): gen Ppct = P/P[1]*100

gen e = string(P, "%9.2f")
bys iso3 year sex (ghecause): replace e = e + "(" + string(P/P[1]*100, "%9.0f")  + ")" if _n != 1

replace e = subinstr(e, "(-0)","(0)",.)
replace e = subinstr(e, "-0.00","0.00",.)
replace e= subinstr(e, "0.00","0",.)

keep country year iso3 sex  groupnr detail e causename

reshape wide e , i(iso3 year causename) j(sex)
rename e* =_
reshape wide e* , i(iso3 causename) j(year)

gen nr = .
local i = 1
foreach c in `"Total life expectancy gap"' `"Total impact of NCD-7"' `"Atherosclerotic CVDs"' `"Ischemic heart disease"' `"Ischemic stroke"' `"Diabetes"' `"Diabetes mellitus"' `"Chronic kidney disease due to diabetes"' ///
`"Tobacco-related NCDs"' `"Chronic obstructive pulmonary disease"' `"Larynx cancer"' `"Mouth & oropharynx cancers"' `"Stomach cancer"'  `"Trachea, bronchus, lung cancers"'  `"Hemorrhagic stroke"'  `"Road injury"' `"Suicide"'  ///
`"Infection-related NCDs"' `"Cervix uteri cancer"' `"Cirrhosis due to hepatitis B"' `"Cirrhosis due to hepatitis C"' `"Liver cancer secondary to hepatitis B"' `"Liver cancer secondary to hepatitis C"' `"Rheumatic heart disease"' ///
`"Total impact of I-8"' `"Childhood-cluster diseases"' `"Diarrheal diseases"' `"HIV/AIDS"' `"Lower respiratory infections"' `"Malaria"' `"Maternal conditions"' `"Neonatal conditions"'  `"Tuberculosis"' ///
`"Total impact of other causes"' `"Cardiovascular diseases ex. NCD-7"' `"Congenital anomalies"' `"COVID-19"' `"COVID-19 pandemic-related"' `"Digestive diseases ex. NCD-7"' ///
`"Endocrine, blood, immune disorders"' `"Genitourinary diseases ex. NCD-7"' `"Inf. & parasitic d. ex. I-8 & NCD-7"' `"Violence"' ///
`"Cancers ex. NCD-7"' `"Mental & substance use disorders"' `"Musculoskeletal diseases"' `"Neurological conditions"' `"Nutritional deficiencies"' `"Other neoplasms"' ///
 `"Respiratory diseases ex. NCD-7"' `"Respiratory infections ex. I-8"' `"Skin diseases"' `"Sudden infant death syndrome"'  `"Unintentional injuries"'  {
 replace nr = `i++' if causename=="`c'"
 }
levelsof causename if nr == .

replace causename = "	" + causename if detail==2 |  detail==3
replace causename = "		-" + causename if detail==4

gen last = strpos(iso3,"::")
sort last iso3 nr
replace nr = _n 
sort nr

set obs `=_N+4'
replace nr = 0 if _n==_N
replace nr = -1 if _n==_N-1
replace nr = -2 if _n==_N-2
replace nr = -3 if _n==_N-3


foreach var of varlist e* {
if substr("`var'",1,2)=="e1" replace `var' = "Males" if nr == -1
if substr("`var'",1,2)=="e2" replace `var' = "Females" if nr == -1
if substr("`var'",1,2)=="e3" replace `var' = "Both" if nr == -1

replace `var' = substr("`var'",-4,4) if nr == -2
replace `var' = "Years (%)" if nr == -3

order `var'
}
replace causename = "Cause of death" if nr == -1 
replace country = "Location" if nr == -1
replace country = subinstr(country, "region::", "",.) 
replace country =subinstr(country, "quantile::", "Decile ",.) 

order iso3 country causename
sort nr
keep country causename e*
export delimited using "JAMA OPEN Revision\\Supplement_2" ,replace
