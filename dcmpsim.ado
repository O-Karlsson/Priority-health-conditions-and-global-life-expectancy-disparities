program define dcmpsim
syntax , dir(string) rounds(integer) child(integer) outputdir(string) type(string)
cd "`dir'"

***********************************************************************************
***********************************************************************************
*** Start by writing out the simulation here
***********************************************************************************
***********************************************************************************

forval ii = 1/`rounds' {

use data, clear

*if "`type'"=="simulation" gen double simdths = exp(rnormal(ln(dths) - (sqrt(ln(1 + (se^2)/(dths^2)))^2)/2 , sqrt(ln(1 + (se^2)/(dths^2))))) // <--  This is where the dths are sampled each time
if "`type'"=="simulation" gen simdthstemp = exp(rnormal(ln(dths), se))

if "`type'"=="central" gen simdthstemp=dths


bys geoid year sex age level2parent (ghecause): gen total = sum(simdthstemp) if level2parent!=.
replace level2parent = ghecause if level2parent==. 

bys geoid year sex age level2parent (ghecause): gen simdths = simdthstemp[1] - total[_N] if _n==1
replace simdths = simdthstemp if simdths == .
replace simdths = 0 if simdths == .

bys geoid year sex age (ghecause): egen x = sum(simdths) if inlist(ghecause,1020,1470) // these are only included in rich countries
bys geoid year sex age (x): replace x = x[1]
bys geoid year sex age (ghecause): replace total= sum(simdths) // needs to add up to total deaths
bys geoid year sex age (ghecause): replace simdths = simdths+((simdths/total[_N])*x)
drop if inlist(ghecause,1020,1470)

drop se dths level2parent  simdthstemp total x
save temp_r`ii'_c`child'_`type' ,replace

***********************************************************************************
*** Aggregating over regions
***********************************************************************************

// quantiles
drop if exQuantile==.
replace geoid = exQuantile
collapse (sum) simdths  ,  by(geoid ghecause sex year age)
save temp2_r`ii'_c`child'_`type',  replace

// global
use temp_r`ii'_c`child'_`type', clear
replace geoid = 1001
collapse (sum) simdths,  by(geoid ghecause sex year age)
append using temp2_r`ii'_c`child'_`type'
save temp2_r`ii'_c`child'_`type' ,replace

// region
use temp_r`ii'_c`child'_`type', clear
replace geoid = regionid
drop if regionid==.
collapse (sum) simdths  ,  by(geoid ghecause sex year age)
append using temp2_r`ii'_c`child'_`type'
append using temp_r`ii'_c`child'_`type'

***********************************************************************************
*** Projecting the cause of death fractions onto the UN mx
***********************************************************************************

bys geoid year sex age (ghecause): gen total= sum(simdths) // needs to add up to total deaths-x
merge m:1 geoid year sex age using UNdata, keep(match) nogen keepusing(mx mxb1 Aw1 Pw1 mxb2 Aw2 Pw2)
bys geoid year sex age (ghecause): gen mxc = mx*simdths/total[_N] // the bys needs to be in the same order as above
drop total

gen mxcb1 = mxc if year == 2019 & geoid==1002
bys ghecause sex age (mxcb1): replace mxcb1 = mxcb1[1]

gen mxcb2 = mxc if year == 2019 & geoid==2001 & sex == 3
bys ghecause age (mxcb2): replace mxcb2 = mxcb2[1]

***********************************************************************************
*** Decomposition (the age weight are made above)
***********************************************************************************

gen A = Aw1*(mxc-mxcb1)/(mx-mxb1)
gen P = Pw1*(mxc-mxcb1)
gen Pd = Pw2*(mxc-mxcb2)

collapse (sum)  A P  Pd , by(geoid year sex ghecause)
save temp_r`ii'_c`child'_`type' , replace

***********************************************************************************
*** Aggregating conditions
***********************************************************************************

// Aggregating GHE causes into the broader CIH causes (ie, the 15 conditions)
/* In many cases the I8 and NCD7 overlap with WHO GHE categories */
replace ghecause = 9972 if inlist(ghecause, 1130,1141)
replace ghecause = 9973 if inlist(ghecause,640,661,662,710,1110,1231,1232)
replace ghecause = 9974 if inlist(ghecause, 620, 680, 753, 1180)
replace ghecause = 9975 if inlist(ghecause, 800,1272)
keep if inrange(ghecause,9970,9979)
collapse (sum) P A Pd , by(geoid sex year ghecause)
append using temp_r`ii'_c`child'_`type' 

// Removing zeros 
/* consider doing this after the aggreagation of conditions below. This can lead
to a bit strange results. OR just skip this. */

// just do this for the aggregate 15 conditions and others
gen tag = inlist(ghecause, 1130,1141) | inlist(ghecause,640,661,662,710,1110,1231,1232) | inlist(ghecause, 620, 680, 753, 1180) | inlist(ghecause, 800,1272)

bys tag geoid sex year (ghecause): gen gap = sum(P) if tag == 0
gen no0 = P if tag == 0
replace no0 = 0 if no0<0 & tag == 0
bys tag geoid sex year (ghecause): gen gap0 = sum(no0)
bys tag geoid sex year (ghecause): gen PNo0 = (no0/gap0[_N])*gap[_N] // the bys order must always be the same
drop gap no0 gap0 tag
save temp_r`ii'_c`child'_`type' , replace

// aggreagating over the broader CIH conditons (I8 NCD7 and Other)
drop if inlist(ghecause, 1130,1141) | inlist(ghecause,640,661,662,710,1110,1231,1232) | inlist(ghecause, 620, 680, 753, 1180) | inlist(ghecause, 800,1272)
merge m:1 ghecause using cause_codes_ghe, keep(master match) nogen keepusing(type)
replace type = 2 if inrange(ghecause,9970,9979)
replace ghecause = 9000+type
collapse (sum) P A PNo0  Pd , by(geoid sex year ghecause)
save temp2_r`ii'_c`child'_`type', replace

// aggregating total (ie, total e0 gap)
collapse (sum) P A PNo0 Pd , by(geoid sex year)
gen ghecause= -1
append using temp_r`ii'_c`child'_`type'
append using temp2_r`ii'_c`child'_`type'




foreach var in P A Pd PNo0 {
replace `var' = round(round(`var'*10000))
}
replace year = year-2000

label drop _all
foreach var of varlist _all {
    label var `var' ""
}
compress
save "`outputdir'\\`type'_`ii'_`child'", replace

erase temp_r`ii'_c`child'_`type'.dta 
erase temp2_r`ii'_c`child'_`type'.dta

}
end	