"""
Title: Scopus_Update Delete Function Tester
Author: Djamil Lakhdar-Hamina
Date: 06/27/2019


The point of this delete function is scan a directory. It scans the date when the file was uploaded and whether it was processed.
If the file satisfies both conditions then it is deleted.


"""

import time
import os
#from argparse import ArgumentParser

current_time=time.time()

def delete_function(data_directory):

    """
    Assumptions:

    Given a directory, scan the files in directory. If it is processed and more than 5 weeks old then delete.

    Arguments: directory= /Scopus_update

    Input: directory
    Output: remove file(s)

    """

    # parser = ArgumentParser
    #
    # parser.add_argument('-d','--data_directory', required=True, help="""specified directory for zip-file""")
    #
    # args = parser.parse_args()

    present_time = time.time()
    print("Scanning directory...")
    for file in os.listdir(directory):
        if os.path.isfile(file) == True:
            file_mtimeresult = os.stat(os.path.join(directory, file))
            file_mtimeresult = [file, (present_time - file_mtimeresult.st_mtime)]
            if file_mtimeresult[1] > (840 * 3600):
                print("File" " " + str(file_mtimeresult[0]) + " "  "is removed!")

    #print("File(s) is/(are) removed!")

## Run the function with relevant input
test= "/erniedev_data2/Scopus_updates"
delete_function(test)
print('The relevant files are removed!')
## End of script
