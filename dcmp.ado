program define dcmp
syntax , dir(string) data(string) year(integer) bench(string)
cd "`dir'"

capture erase temp2`year'`bench'.dta  
capture erase temp`year'`bench'.dta 
capture erase estimates_`year'_`bench'.dta

//file to collect results
clear
gen del =.
save estimates_`year'_`bench' , replace

***********************************************************************************
*** Preparing the GHE data
***********************************************************************************
use dths sex iso3 age year ghecause if year==`year'  using "`data'\\GHE2021_update.dta" , clear
merge m:1 ghecause using  cause_codes_ghe, keep(match) nogen keepusing(type)
save temp`year'`bench' , replace

*****************************************************************************
*** aggregating deaths and population from the GHE data into CIH regions and global
*****************************************************************************

merge m:1 iso3 using "$data\\regions", keep(match) nogen
collapse (sum) dths, by(region year sex age ghecause)
rename region iso3
save temp2`year'`bench', replace

collapse (sum) dths , by(year sex age ghecause)
gen iso3 = "World"

append using temp`year'`bench'
erase temp`year'`bench'.dta 
append using temp2`year'`bench'
erase temp2`year'`bench'.dta 

*****************************************************************************
*** Projecting to UN mx
*****************************************************************************

bys iso3 year sex age (ghecause): gen double dpr = dths/dths[1] 
replace dpr=0 if dpr == . 
replace dpr=1 if ghecause==0

bys ghecause iso3 year sex (age): gen double n = age[_n+1]-age
replace n = 16 if n==.
expand n 
bys ghecause iso3 year sex age: gen x = age+_n-1
merge m:1 iso3 year sex x using UNdata, nogen keep(match)
replace mx = mx*dpr
keep iso3 year sex x ax mx p ghecause len

*****************************************************************************
*** Starting decomposition
*****************************************************************************

if "`bench'"=="NA" gen id = "`bench'"
if "`bench'"!="NA" gen id = iso3+" `bench'"

merge m:1 id ghecause sex x using bs_ex, keep(match) nogen

bys iso3 year sex x (ghecause): gen nmx0 = mx[1]
gen double m =nmx0+(mxb-mx)*[1-((nmx0-mx)/2)] if ghecause!=0
replace m =nmx0 if ghecause==0
gen double nqx = (len*m)/(1+(len-ax)*m)
replace nqx = 1 if x==100
gen double lx = 1 if x==0
bys ghecause iso3 year sex (x): replace lx = lx[_n-1]*(1-nqx[_n-1]) if x!=0
gen double ndx = nqx*lx
gen double nLx = ((lx-ndx)*len)+(ndx*ax)
replace nLx = lx/m if x == 100
bys ghecause  iso3 year sex: egen double Tx = total(nLx)
bys ghecause  iso3 year sex (x): replace Tx=Tx[_n-1]-nLx[_n-1] if x!=0
gen double ex = Tx/lx
save temp`year'`bench' , replace

keep if inlist(x,0,70)
bys ghecause iso3 year sex (x): gen ppd = 1-lx[_N]
keep if x == 0
keep iso3 year sex ghecause ex ppd
save estimates_`year'_`bench' , replace

// Arriaga weights

use temp`year'`bench' , clear
keep if ghecause==0
gen nCx = (lx)*((nLxb/lxb)-(nLx/lx))
bys ghecause iso3 year sex (x): replace nCx= nCx+(lx*(lxb[_n+1]/lxb)-lx[_n+1])*exb[_n+1] if x!=100

// Pollard age weights 
gen w =((lx*exb)+(lxb*ex))/2
bys ghecause iso3 year sex (x): replace w=len/2*(w+w[_n+1])
replace w=((Txb/mx)+(Tx/mxb))/2 if x == 100
rename mxb nmxb0
keep iso3 year sex x nCx w nmx0 nmxb0

merge 1:m iso3 year sex x using temp`year'`bench' , nogen keepusing(mx mxb ghecause)
erase temp`year'`bench'.dta 

gen C = nCx*(mx-mxb)/(nmx0-nmxb0)
gen P = w*(mx-mxb)

collapse (sum) C P, by(ghecause iso3 year sex)

merge 1:1 iso3 year sex ghecause using estimates_`year'_`bench' , nogen

gen bench="`bench'"

save estimates_`year'_`bench' , replace
end	