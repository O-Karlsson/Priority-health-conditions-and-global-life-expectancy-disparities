global dir "C:\Users\\Om\\OneDrive\Everything\Work in progress\CIH\deomposition paper\"
global data "C:\Users\\Om\\OneDrive\Everything\Work in progress\CIH\data\"  
cd "$dir"

***********************************************************************************
***********************************************************************************
*** Picking the causes of deaths to decompose fom the WHO GHE
***********************************************************************************
***********************************************************************************

use if year==2019 & sex==2  & iso3 == "NGA" & inlist(age,0)  using "$data\\GHE2021_update" , clear
keep ghecause causename

gen level = 1 if inlist(ghecause,10,600,1510)

replace level = 2 if inlist(ghecause,20,380,420,490,540,610,790,800,810,820,940,1020,1100,1170,1210,1260,1330,1340,1400,1470,1505,1520,1600)

replace level = 3 if inlist(ghecause,30, 40, 100, 110, 120, 170, 180, 185, 210, 330, 365, 370, 390, 400, 410, 500, 510, 520, 530, 550, 560, 570) | inlist(ghecause,580, 590, 620, 630, 640, 650, 660, 670, 680, 690, 700, 710, 720, 730, 740, 742, 745, 750, 751, 752, 753, 754) | inlist(ghecause,755, 760, 770, 780, 811, 812, 813, 814, 830, 840, 850, 860, 870, 880, 890, 900, 910, 920, 930, 950, 960) | inlist(ghecause, 970, 980, 990, 1000, 1010, 1030, 1040, 1050, 1060, 1070, 1080, 1090, 1110, 1120, 1130, 1140, 1150) | inlist(ghecause, 1160, 1180, 1190, 1200, 1220, 1230, 1240, 1241, 1242, 1244, 1246, 1248, 1250, 1270, 1280, 1290, 1300, 1310, 1320) | inlist(ghecause, 1350, 1360, 1370, 1380, 1390, 1410, 1420, 1430, 1440, 1450, 1460, 1480, 1490, 1500, 1502, 1530) | inlist(ghecause, 1540, 1550, 1560, 1570, 1575, 1580, 1590, 1610, 1620, 1630)
replace level = 4 if level==.
replace level = 0 if ghecause==0

// Picking which causes to decompose (I just set these to level 3 and than keep)
replace level = 3 if ghecause == 1330 
drop if inlist(ghecause,1331,1332,1333,1334,1335,1336,1337,1339) // skin diseases (something missing: they don't add up to the total 1330)

replace level = 3 if inlist(ghecause,420,790,800,1505) // there are nothing below these 
replace level =.  if inlist(ghecause,210,660,1230,1270,1140) // replace these level 3 cause with their level 4 causes below

replace level = 3 if inrange(ghecause,220,320)
replace level = 3 if inrange(ghecause,661,664) // these are not listed in the documentation
replace level = 3 if inrange(ghecause,1231,1234) // these are not listed in the documentation
replace level = 3 if inrange(ghecause,1271,1273) // these are not listed in the documentation
replace level = 3 if inrange(ghecause,1141,1142) // these are not listed in the documentation

replace level = 3 if inlist(ghecause,395,1700)

gen type="NCD" if inlist(ghecause, 1130,1141,1142,640,661, 662, 710, 1110, 1231, 1232, 620, 680, 753, 1180, 800, 1272, 1530, 1610)
replace type = "CCD" if inlist(ghecause,30,100,110,120,220,390,420,500,510,520,530) 
replace type = "All0" if ghecause == 0
replace type = "Other" if type =="" & level==3
keep if level == 3 | level == 0

save cause_codes_ghe, replace

***********************************************************************************
***********************************************************************************
*** Preparing UN life expectancy to project onto
***********************************************************************************
***********************************************************************************
use if ghecause==0  using "$data\\GHE2021_update" , clear
bys iso3 year sex (age): gen  n = age[_n+1]-age
replace n = 16 if n==.
keep iso3 pop n age year sex
save inwho,replace

use if loctype=="Country/Area" & inrange(year, 2000,2021) using  "$data\\wpp_life_table_singleyr" , clear
egen age = cut(x),at(0(5)100)
replace age=1 if inrange(x,1,4)
replace age = 85 if x >=85
table age, content(min x max x)

merge m:1 iso3 sex age year using inwho, nogen keep(match)
replace p = pop/1000/n if p==0
replace p = nD/mx if p == 0
bys iso3  year x (sex): replace p = p[2]/10 if p==0 & sex == 1

merge m:1 iso3 using "$data\\regions", keep(match) nogen
keep  age iso3 sex p ax x year mx len region
save temp, replace

collapse (mean) mx ax (rawsum) p (first) len [pweight=p] , by(region year sex x)
gen iso3 = region
save temp2, replace

collapse (mean) mx ax (rawsum) p (first) len [pweight=p]  , by(year sex x)
gen iso3 = "World"

append using temp
append using temp2


save UNdata, replace

***********************************************************************************
***********************************************************************************
*** Preparing the benchmark (2000, 2010, 2019, NA) mortality rates
***********************************************************************************
***********************************************************************************

use iso3 age year ghecause dths sex if inlist(year,2000,2010,2019) using  "$data\\GHE2021_update", clear
merge m:1 ghecause using  cause_codes_ghe, keep(match) nogen
merge m:1 iso3 using "$data\\regions", keep(match) nogen

save temp, replace

collapse (sum) dths, by(region year sex age ghecause)
rename region iso3
save temp2, replace

collapse (sum) dths , by(year sex age ghecause)
gen iso3 = "World"

append using temp
append using temp2
bys iso3 year sex age (ghecause): gen double dpr = dths/dths[1]
replace dpr=0 if dpr == . 
replace dpr=1 if ghecause==0
bys ghecause iso3 year sex (age): gen  n = age[_n+1]-age

replace n = 16 if n==.
expand n 

bys ghecause iso3 year sex age: gen double x = age+_n-1

merge m:1 iso3 year sex x using UNdata, nogen keep(match)

gen mxb = mx*dpr

keep iso3 year sex x ax mxb p ghecause len

gen double nqx = (len*mxb)/(1+(len-ax)*mxb)
replace nqx = 1 if x==100
gen double lxb = 1 if x==0
bys ghecause iso3 year sex (x): replace lxb = lxb[_n-1]*(1-nqx[_n-1]) if x!=0
gen double ndx = nqx*lxb
gen double nLxb = ((lxb-ndx)*len)+(ndx*ax)
replace nLxb = lxb/mxb if x == 100
bys ghecause  iso3 year sex: egen double Txb = total(nLxb)
bys ghecause  iso3 year sex (x): replace Txb=Txb[_n-1]-nLxb[_n-1] if x!=0
bys ghecause iso3 year sex (x): gen exb = Txb/lxb

keep ghecause  iso3 year sex x mx lxb nLxb Txb exb len
gen id = iso3 + " " + string(year)
save temp, replace
keep if iso3=="North Atlantic" & year == 2019
replace id = "NA"
append using temp 
keep mxb lxb nLxb Txb exb id ghecause x sex 
save bs_ex , replace


***********************************************************************************
***********************************************************************************
***********************************************************************************
***********************************************************************************
clear	
cd "$dir"
sysdir set PERSONAL "$dir\\dos"
clear all

*dcmp, dir($dir) data($data) year(2019) bench(NA)

parallel initialize  26, force
program def myprogram
	local j = 0
	forval i = 2000/2021 {

	if	($pll_instance == `++j') dcmp, dir($dir) data($data) year(`i') bench(NA)
	}
	if	($pll_instance == `++j') dcmp, dir($dir) data($data) year(2021) bench(2019)
	if	($pll_instance == `++j') dcmp, dir($dir) data($data) year(2019) bench(2010)
	if	($pll_instance == `++j') dcmp, dir($dir) data($data) year(2010) bench(2000)
	if	($pll_instance == `++j') dcmp, dir($dir) data($data) year(2019) bench(2000)

end
parallel, nodata processors(8) prog(myprogram): myprogram

cd "$dir"
use estimates_2000_NA , clear
forval i = 2001/2021 {
append using estimates_`i'_NA
}
append using estimates_2021_2019
append using estimates_2019_2010
append using estimates_2010_2000
append using estimates_2019_2000

bys bench iso3 sex year (ghecause): gen exobs =  ex[1]
gen D=ex-exobs
drop if ghecause==0

gen oghecause=ghecause
replace ghecause= 0
gen x = 0
gen id = iso3+" "+bench
replace id = bench if bench=="NA"
merge m:1 id sex x ghecause using bs_ex, keepusing(exb) nogen keep(master match)
replace ghecause = oghecause	
drop x oghecause

gen Dgap=exb-exobs


bys bench iso3 sex year: egen total=total(D)
replace D = D+((D/total)*(Dgap-total)) // it's not ideal since they go in both directions
pwcorr D P C
drop total


foreach var in P C D {
if "`var'"!="D" bys bench iso3 sex year: egen `var'gap=total(`var') // It's a bit different then the actual gap in a few small countries
gen diff`var' = `var'
replace diff`var' = 0 if diff`var'<0
replace diff`var' = . if bench!="NA" | `var'gap<0
bys bench iso3 sex year: egen total=total(diff`var') if diff`var'!=.
replace diff`var'=(diff`var'/total)*`var'gap
drop total
}

merge m:1 ghecause using  cause_codes_ghe, keep(master match) nogen keepusing(causename type)



replace causename="Diarrheal diseases" if causename=="Diarrhoeal diseases"
replace causename="Ischemic heart disease" if causename=="Ischaemic heart disease"
replace causename="Iron-deficiency anemia" if causename=="Iron-deficiency anaemia"
replace causename="Esophagus cancer" if causename=="Oesophagus cancer"
replace causename="Leukemia" if causename=="Leukaemia"
replace causename="Thalassemia" if causename=="Thalassaemias"
replace causename="Other haemoglobinopathies and hemolytic anemia" if causename=="Other haemoglobinopathies and haemolytic anaemias"
replace causename="Other mental and behavioral disorders" if causename=="Other mental and behavioural disorders"
replace causename="Hemorrhagic stroke" if causename=="Haemorrhagic stroke"
replace causename = "Ischemic stroke" if causename == "Ischaemic stroke"


replace causename="Suicide" if causename=="Self-harm"

save temp, replace

collapse (sum) diffP diffC diffD ex P C D (first) Dgap Pgap Cgap exobs exb , by(bench iso3 sex year type)
replace type = "_"+type
gen causename=type
save temp2, replace

collapse (sum) diffP diffC diffD ex P C D (first) Dgap Pgap Cgap exobs exb , by(bench iso3 sex year)
gen type = "_All0"
gen causename=type
gen ghecause=0

append using temp
append using temp2

bys causename: egen ever=max((abs(P)>0.0001 & P<.) | (abs(C)>0.0001 & abs(C)<.))
drop if ever==0
drop ever

replace ghecause = 9997 if type == "_CCD" & ghecause==.
replace ghecause = 9998 if type == "_NCD" & ghecause==.
replace ghecause = 9999 if type == "_Other" & ghecause==.

gen detail = 2
gen ocausename = causename
replace ocausename = "Neonatal conditions" if inlist(ghecause, 500,510,520,530)
replace ocausename = "Atherosclerotic CVDs" if inlist(ghecause, 1130,1141)
replace ocausename = "Infection-related NCDs" if inlist(ghecause,640,661,662,710,1110,1231,1232)
replace ocausename = "Tobacco-related NCDs" if inlist(ghecause, 620, 680, 753, 1180)
replace ocausename = "Diabetes" if inlist(ghecause, 800,1272)
replace detail = 1 if ocausename!=causename
save temp, replace

keep if ocausename!=causename
collapse (sum) diffP diffC diffD ex P C D (first) Dgap Pgap Cgap exobs exb , by(bench iso3 sex year ocausename type)
gen detail=0
rename ocausename causename
append using temp
drop ocausename 


merge m:1 iso3 using "$data\\regions",  keep(match master) nogen
replace region = iso3 if region==""
replace country = region if country ==""
replace country = subinstr(country,"*","",.)
replace country = subinstr(country," and "," & ",.)	

bys bench iso3 sex year detail (causename): replace ghecause = 9970+_n if ghecause==.


compress
save "$dir\\estimates", replace

use "$dir\\estimates" , clear
br iso3 C diff type if strpos(type,"_") & iso3==region & sex == 3


