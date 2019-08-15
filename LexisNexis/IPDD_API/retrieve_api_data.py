from zeep import Client
import zipfile
import argparse
from time import sleep
from datetime import datetime, timedelta

# IPDD returns security token and expiration info
def log_on(ipdd_service_reference,username,password):
    client = Client(ipdd_service_reference)
    result = client.service.LogOn(username,password)
    expiration = result['Expiration']
    security_token = result['SecurityToken']
    return expiration,security_token

# Close IPDD session
def log_off(ipdd_service_reference,security_token):
    client = Client(ipdd_service_reference)
    return client.service.LogOff(security_token)

# per page 96 of TRG, DataSet is the Authority code or custom type used to identify the dataset (e.g. US or EP)
# Per page 96 of TRG, DataType can be one of ('Xml','Pdf','Clip','Images')
# Per page 96 of TRG, KindGroup can be one of ('All','Application','Grant','Other')
def create_update_request(ipdd_service_reference,security_token,dataset,datatype='Xml',list_format=None,kind_group=None):
    client = Client(ipdd_service_reference)
    request_factory = client.type_factory('ns1')
    return request_factory.UpdateRequest(SecurityToken=security_token,DataSet=dataset,DataType=datatype,
                                          ListFormat=list_format,KindGroup=kind_group)

# This function is used to request a history list in XML format of all the previously requested batches
def create_history_request(ipdd_service_reference,security_token,dataset,datatype='Xml',list_format=None,kind_group=None,
                            request_date_from=(datetime.today() - timedelta(days=7)).strftime("%Y-%m-%d"), request_date_to=(datetime.today()).strftime("%Y-%m-%d"),
                            status='All'):
    client = Client(ipdd_service_reference)
    request_factory = client.type_factory('ns1')
    return request_factory.HistoryRequest(SecurityToken=security_token,DataSet=dataset,DataType=datatype,
                                          ListFormat=list_format,KindGroup=kind_group,
                                          RequestDateFrom=request_date_from,RequestDateTo=request_date_to,
                                          Status=status)

# Request past history
def request_history(ipdd_service_reference,history_request_variable):
    client = Client(ipdd_service_reference)
    return client.service.RequestHistory(history_request_variable)

# IPDD returns the number of documents in a batch based on entitlement (or access denied)
def retrieve_batch_info(ipdd_service_reference,request_variable):
    client = Client(ipdd_service_reference)
    return client.service.RetrieveBatchInfo(request_variable)

# IPDD returns a batchList
# batch_size must be between 20K and 50K
def request_batch_sized(ipdd_service_reference,request_variable,batch_size=20000):
    client = Client(ipdd_service_reference)
    return client.service.RequestBatchSized(request_variable,batch_size)

# IPDD returns information on batch including Queued, Running, Finished, Failed, Retrieved
def retrieve_batch_status(ipdd_service_reference,security_token,batch_id):
    client = Client(ipdd_service_reference)
    return client.service.RetrieveBatchStatus(security_token,batch_id)

# IPDD returns stream containing the data in a single Zip file
def retrieve_batch(ipdd_service_reference,security_token,batch_id,position):
    client = Client(ipdd_service_reference)
    return client.service.RetrieveBatch(security_token,batch_id,position)

if __name__ == "__main__" :
    # Read in available arguments
    parser = argparse.ArgumentParser(description='''
     This script interfaces with the IPDD API, collects data and passes it to the XMLTABLE parser.
    ''', formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-U','--ipdd_username',help='IPDD API username',type=str,required=True)
    parser.add_argument('-W','--ipdd_password',help='IPDD API password',type=str,required=True)
    parser.add_argument('-R','--ipdd_service_reference',help='IPDD service reference address',type=str,required=True)
    parser.add_argument('-b','--batch_size',help='Desired batch size on API retrievals',type=int,default=20000)
    parser.add_argument('-s','--sleep_time',help='Amount of ms to sleep in between batch info calls',type=int,default=300000)
    parser.add_argument('-D','--datasets', type=str, nargs='+',help='Space delimited list of target datasets to collect patent data for')
    parser.add_argument('-d','--download_dir',help='Target directory to download zip data into',type=str,default='API_downloads')
    print('Reading arguments')
    args = parser.parse_args()
    print('Finished reading arguments')
    datatype='Xml'
    # Log on
    print("Logging on...")
    expiration,security_token = log_on(args.ipdd_service_reference,args.ipdd_username,args.ipdd_password)
    # For each type of dataset we are interested in...
    for dataset in args.datasets:
        # Check if new/updated publications are available. If so:
        print ("Collecting data for {} patents with datatype format {}".format(dataset,datatype))
        # Create updateRequestVariable
        updateRequestVariable = create_update_request(args.ipdd_service_reference,security_token,dataset)

        if retrieve_batch_info(args.ipdd_service_reference,updateRequestVariable)['Count'] > 0:
            print("Update data available for download...")
            # Request the publications
            batch_list = request_batch_sized(args.ipdd_service_reference,updateRequestVariable,batch_size=args.batch_size)
            # While loop on batch list
            while len(batch_list.Batch) > 0:
                # Wait for batch to complete
                cur_batch_id = batch_list.Batch.pop(0)['BatchId']
                print("Monitoring batch {}".format(cur_batch_id))
                cur_batch_status = retrieve_batch_status(args.ipdd_service_reference,security_token,cur_batch_id)['Status']
                while cur_batch_status != "Finished":
                    if cur_batch_status == "Failed":
                        print("Batch {} has failed during creation".format(cur_batch_id))
                        break
                    print("Batch {} is still generating...".format(cur_batch_id))
                    sleep(args.sleep_time)
                    cur_batch_status = retrieve_batch_status(args.ipdd_service_reference,security_token,cur_batch_id)['Status']

                # Notify batch completion
                print("Batch {} has completed and is available at the FTP location".format(cur_batch_id))
                '''# Download the data in a try catch block inside of a while loop and write the stream to a zip file
                retry=True;retry_count=0;position=0
                while retry_count < 1000 and retry:
                    cur_position=0
                    try:
                        # Retrieve the batch and write to file - NOTE: edit to do this in a while loop with a buffer
                        data_stream = retrieve_batch(ipdd_service_reference,security_token,cur_batch_id,position)
                        with open('{}/{}.zip'.format(args.download_dir,cur_batch_id)) as tmp_zip:
                            tmp_zip.write(data_stream)
                        data_stream.close()
                        retry=False
                    except:
                        position+=cur_position
                        print("IOError while downloading {}. Will retry at position {}".format(cur_batch_id,position))
                        retry_count+=1'''
    # Logoff
    print("Logging off...")
    log_off(args.ipdd_service_reference,security_token)
