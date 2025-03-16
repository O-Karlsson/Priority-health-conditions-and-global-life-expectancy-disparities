global dir "C:\Users\\Karls\\OneDrive\Everything\Work in progress\CIH\deomposition paper\"
global data "C:\Users\\Karls\\OneDrive\Everything\Work in progress\CIH\data\"  
cd "$dir"
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
