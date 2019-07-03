"""
Title: Email Parser-Downloader
Author: Djamil Lakhdar-Hamina
Date: 06/13/2019

The point of this parser is to take an email and scan it for url.
Once the url is found it opens it up and saves it to a specified directory.

This is part of the code for an automated process which will leverage Jenkins to set off a process when
triggered by the reception of an email with a url-link.
"""

import time
import re
import requests
import urllib
import zipfile
import shutil
from io import BytesIO, StringIO
from sys import argv

start_time=time.time()

pmt_content=argv[1]

##Build a function that 1) opens email 2) scans it for urls 3) stores urls and then opens file in them 4) then rename this downloaded file and store in specified directory.

def email_parser(pmt_content, data_directory="/erniedev_data2/Scopus_updates"):
    """
    Assumptions:

    Given an email, read the email, then scan it for url.
    If url is found, download, rename, and then save to specified directory.

    Input: email_message and default value for directory= /erniedev_data2/Scopus_updates
    Output: A group of zip files, renamed, and stored in specified directory called /erniedev_data2/Scopus_updates

    :return:
    """

    ## Scan emails for url and store the url(s) in a list
    links= re.findall('https://\S*./.zip', pmt_content)
    links=links[0:3]
    links.remove(links[1])
    ## Go through list of links, request https, download url with zip
    for link in links:
        req=requests.get(link)
        scopus_zip_file=zipfile.ZipFile(BytesIO(req.content))
        scopus_zip_file.extractall(data_directory)
        #through list of links, come up with name, rename/store in testing_directory
        zip_file_name= re.findall('nete.*ANI.*zip', link)
        scopus_zip_file.filename = zip_file_name[0].split('/')[2]
        return print ("The relevant files are:", scopus_zip_file)

## Run the function with the relevant input, which is already default argument for email_parser
print("Scanning email now for url...")
testing_directory="/erniedev_data2/testing"
result=email_parser(pmt_content, testing_directory)
print('The revelevant files are parsed!', result )
print('Total duration:',time.time()-start_time)
## End of the script
