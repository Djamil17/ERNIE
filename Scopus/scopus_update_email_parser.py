"""
Title: Email Parser-Downloader
Author: Djamil Lakhdar-Hamina
Date: 06/13/2019

The point of this parser is to take an email and scan it for url.
Once the url is found it opens it up and saves it to a specified directory.
This is code for an automated process which will leverage Jenkins to set off a process when
triggered by the reception of an email with a url-link.

Example link:

https://sccontent-scudd-delivery-prod.s3.amazonaws.com/sccontent-scudd-delivery-prod/nete_1557815293641/2019-6-4/nete_1557815293641_2019-6-4_ANI-ITEM-delete.zip?AWSAccessKeyId=AKIA33DQTS4C4RTMKWFE&Expires=1567427254&Signature=Lecw433oI7gWk4jqVwO8B3KsH%2BY%3D


"""
import time
import re
import zipfile
import urllib
import requests
from argparse import ArgumentParser

start_time=time.time()

##Build a function that 1) opens email 2) scans it for urls 3) stores urls and then opens file in them 4) then rename this downloaded file and store in specified directory.

def email_parser():
    """
    Assumptions:

    Given an email, read the email, then scan it for url.
    If url is found, download, rename, and then save to specified directory.

    Arguments: email_message and default directory= /Scopus

    Input: email_message with forwarded emails called pmt_content because that is the property name given by Jenkins when you call as variable to be executed in process
    Output: A group of zip files, renamed, and stored in specified directory called /Scopus

    :return:
    """

    parser = ArgumentParser

    parser.add_argument('-p', '--pmt_content', required=True,
                        help="""email message that will get parsed for url-link and zip-file""")

    parser.add_argument('-d','--data_directory', required=True, help="""specified directory for zip-file""")

    args = parser.parse_args()

    ## Open email, fortunately the parse function will treat attachments, essentially, as part of (an instance) of the MIME or email data-structure.
    ## might have to use email module to get the text part of the email
    ##with open(args.pmt_content, 'r') as email_msg:
    ##   msg = email.parse(email_msg, policy=default)

    ## Scan emails for url and store the url(s) in a list
    print("Scanning email now for url...")
    links= re.findall('https://\S*.3D', args.pmt_content)
    links=links[0:3]
    return links
    links.remove(links[1])
    print("Relevant urls are in the following links:", links )
    for link in links:
    ## Go through list of links, download url
        print("Getting url-requests...")
        req=requests.get(link)
        print("The request went through:", req.ok)
        print("Now saving zip files to specified directory.")
        zip_file=zipfile.ZipFile(BytesIO(req.content))
        zip_file.extractall(args.data_directory)
        print("The zip files should be present in specified directory!")
        #through list of links, come up with name, rename/store in testing_directory
        print("Renaming files...")
        zip_file_name= re.findall('nete.*ANI.*zip', link)
        zip_file.filename = zip_file_name[0].split('/')[2]
        #print("The revelevant zip files (names) are:", zip_file_name)
        print("The zip files should downloaded in the directory with the correct name!")

## Run the function with the relevant input, d is a name of data directory
email_parser(pmt_content, d)
print('The revelevant files are parsed!')
print('Total duration:',time.time()-start_time)
## End of the script
