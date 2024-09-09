global dir "C:\Users\\Om\\OneDrive\Everything\Work in progress\CIH\deomposition paper\"
global data "C:\Users\\Om\\OneDrive\Everything\Work in progress\CIH\data\"  
cd "$dir"
use estimates , clear
br
keep if bench=="NA"
gen ocausename = "Neonatal conditions" if inlist(ghecause, 500,510,520,530)
replace ocausename = "Atherosclerotic CVDs" if inlist(ghecause, 1130,1141)
replace ocausename = "Infection-related NCDs" if inlist(ghecause,640,661,662,710,1110,1231,1232)
replace ocausename = "Tobacco-related NCDs" if inlist(ghecause, 620, 680, 753, 1180)
replace ocausename = "Diabetes" if inlist(ghecause, 800,1272)
replace ocausename=causename if ocausename==""
gen diffpct = diffP/Pgap*100
gen Ppct = P/Pgap*100

keep sex year iso3 region country P diffP causename type detail ocausename diffpct Ppct ghecause
gen iscc=iso3!=region
gen istype=!strpos(type,"_")
replace type = subinstr(type,"_","",.)
bys ocausename (ghecause): gen crank = ghecause[1]
sort sex year region iscc country iso3  type istype crank ocausename detail causename  

replace causename = "Total " + ocausename if detail == 0  
order sex year region country  type  ocausename causename 
gen nr = _n
replace country = "Aggregate" if iso3==region
replace type = "I-8" if type=="CCD"
replace type = "NCD-7" if type=="NCD"
replace type = "All other" if type == "_other"
replace diffP=0 if diffP==.
replace ocausename = "" if ocausename=="_All0"
replace causename = "" if causename=="_All0"
replace causename = "" if causename==ocausename
replace type = "Total gap" if type=="All0"

replace ocausename = "Total I-8" if ocausename=="_CCD"
replace ocausename = "Total NCD-7" if ocausename=="_NCD"
replace ocausename = "Total other" if ocausename=="_Other"
replace causename ="" if strpos(causename,"_") 
label define sex 1 "Male" 2 "Female" 3 "Both_sexes" , replace
label val sex sex
decode sex, gen(Sex)
order Sex

bys Sex (nr): replace nr = _n

rename (year region country  type ocausename causename diffP P)(Year Region Country  Set Cause Sub_cause _years _years_incl_neg)
keep Sex Year Region Country Set Cause Sub_cause iso3 _years _years_incl_neg nr diffpct Ppct
reshape wide _years _years_incl_neg diffpct Ppct , i(iso3 Country Region Year Set Cause Sub_cause) j(Sex) string
replace iso3 = "" if iso3==Region
order iso3 , last
sort nr
drop nr
compress
rename (_yearsBoth_sexes _years_incl_negBoth_sexes _yearsFemale _years_incl_negFemale _yearsMale _years_incl_negMale)(Both_sexes_years Both_sexes_years_incl_neg Female_years Female_years_incl_neg Male_years Male_years_incl_neg)
rename (diffpctBoth_sexes PpctBoth_sexes diffpctFemale PpctFemale diffpctMale PpctMale)(Both_sexes_pct Both_sexes_pct_incl_neg Female_pct Female_pct_incl_neg Male_pct Male_pct_incl_neg)
order Year Region Country Set Cause Sub_cause Both_sexes_years Both_sexes_pct Female_years Female_pct  Male_years Male_pct Both_sexes_years_incl_neg  Both_sexes_pct_incl_neg Female_years_incl_neg Female_pct_incl_neg Male_years_incl_neg  Male_pct_incl_neg iso3



export delimited using dataset ,replace
