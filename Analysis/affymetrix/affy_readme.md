Date: 11/30/2017
Author: George Chacko

Affymetrix Amplichip CYP is the fourth case study in ERNIE. This is an unusual case study in that involves looking at inventions from two independent manufacturers as well as 
discovery. Thus, our canonical workflow has to be modified as well as the XML spec. A second tweak is greater reliance on WoS data for the backbone. A third tweak is the 
incorporation of all available data rather than using a cutoff date as in the case of pinnacle-event case studies like FDA approved drugs.

a) FDA: List relevant 510ks. List Amplichip 510ks for CYP2D6 and 2C19. There are no embedded references in these documents. We are using Jan 31 2005 as the date of approval
for both the 2D6 and 2C19 Amplichip CYP450 reagents.
 
b) Patents: Find relevant patents. 
A cluster of 13 patents from 1989 with Pirrung and Fodor as inventor was used as the core patent set. Non-patent citations for each of them were copied from Google patents
into individual files. The files were concatenated into a single file, sorted, and passed through uniq. A second manual step was used to remove duplicates and Solr 
was used to search for relevant WoSIDs. The results were manually curated again and then de-duplicated using sort and uniq and stored in the affymetrix_npl_wosid file.
c) Pubs:
   i) PubMed and WoS searches using Amplichip CYP450 as keyword, e.g. " python mass_solr_search.py -c wos_pub_core -qf citation -q "Amplichip CYP450"  -ip 10.0.0.5:8983 -n 100" 
   ii) Cited references from Pirrung's review, Lenoir's review,  Garfield's Microarray historiography were mined.
d) Clinical Trials: Not clear that any are relevant
e) Create two files. affymetrix_wosid and affymetrix_pmid. Interconvert and deduplicate to a single wosid list with corresponding pmids where available. 


