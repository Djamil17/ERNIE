from pyspark import Row
from pyspark.sql import SparkSession
from pyspark.sql.functions import rand
from pyspark.sql.functions import monotonically_increasing_id
import time,sys
import argparse
import pandas as pd
import datetime
import numpy as np
from pyspark.sql.functions import col, udf, lit,struct
import pyspark.sql.types as sql_type
import threading as thr
import psycopg2

# Issue a command to postgres to shuffle the target table
def postgres_shuffle_data(conn,table_name):
    cur = conn.cursor()
    cur.execute("REFRESH MATERIALIZED VIEW {}".format(table_name))
    conn.commit()

# Shuffle dataset in Spark -- must use rand() here instead of random per https://spark.apache.org/docs/2.4.0/api/sql/#rand
# TODO: test/look for differences in random number generation and check if this has any effect on output
def spark_shuffle_data(table_name):
    sql = '''
        WITH cte AS (
          SELECT
            source_id,
            source_year,
            source_document_id_type,
            source_issn,
            coalesce(lead(cited_source_uid, 1) OVER (PARTITION BY reference_year ORDER BY rand()),
                     first_value(cited_source_uid) OVER (PARTITION BY reference_year ORDER BY rand()))
              AS shuffled_cited_source_uid,
            coalesce(lead(reference_year, 1) OVER (PARTITION BY reference_year ORDER BY rand()),
                     first_value(reference_year) OVER (PARTITION BY reference_year ORDER BY rand()))
              AS shuffled_reference_year,
            coalesce(lead(reference_document_id_type, 1) OVER (PARTITION BY reference_year ORDER BY rand()),
                     first_value(reference_document_id_type) OVER (PARTITION BY reference_year ORDER BY rand()))
              AS shuffled_reference_document_id_type,
            coalesce(lead(reference_issn, 1) OVER (PARTITION BY reference_year ORDER BY rand()),
                     first_value(reference_issn) OVER (PARTITION BY reference_year ORDER BY rand()))
              AS shuffled_reference_issn
          FROM {}
        )
        SELECT
          source_id,
          source_year,
          source_document_id_type,
          source_issn,
          shuffled_cited_source_uid,
          shuffled_reference_year,
          shuffled_reference_document_id_type,
          shuffled_reference_issn
        FROM cte
        WHERE source_id NOT IN (
          SELECT source_id
          FROM cte
          GROUP BY source_id, shuffled_cited_source_uid
          HAVING COUNT(1) > 1)'''.format(table_name)
    return spark.sql(sql)

# Functions to handle RW operations to PostgreSQL
def read_postgres_table_into_HDFS(table_name,connection_string,properties):
    spark.read.jdbc(url='jdbc:{}'.format(connection_string), table=table_name, properties=properties).write.mode("overwrite").saveAsTable(table_name)
def read_postgres_table_into_memory(table_name,connection_string,properties):
    spark.read.jdbc(url='jdbc:{}'.format(connection_string), table=table_name, properties=properties).write.mode("overwrite").saveAsTable(table_name)
def write_table_to_postgres(spark_table_name,postgres_table_name,connection_string,properties):
    df=spark.table(spark_table_name)
    df.write.jdbc(url='jdbc:{}'.format(connection_string), table=postgres_table_name, properties=properties, mode="overwrite")

warehouse_location = '/user/spark/data'
spark = SparkSession.builder.appName("shuffle_analysis") \
                    .config("spark.sql.warehouse.dir", warehouse_location) \
                    .enableHiveSupport() \
                    .getOrCreate()
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)


# Collect user input and possibly override defaults based on that input
parser = argparse.ArgumentParser(description='''
 This script interfaces with the PostgreSQL database and then creates summary tables for the Abt project
''', formatter_class=argparse.RawTextHelpFormatter)
parser.add_argument('-tt','--target_table',help='the target table in HDFS to perform an operation on',default='localhost',type=str)
parser.add_argument('-ph','--postgres_host',help='the server hosting the PostgreSQL server',default='localhost',type=str)
parser.add_argument('-pd','--postgres_dbname',help='the database to query in the PostgreSQL server',type=str,required=True)
parser.add_argument('-pp','--postgres_port',help='the port hosting the PostgreSQL service on the server', default='5432',type=int)
parser.add_argument('-U','--postgres_user',help='the PostgreSQL user to log in as',required=True)
parser.add_argument('-W','--postgres_password',help='the password of the PostgreSQL user',required=True)
parser.add_argument('-i','--permutations',help='the number of permutations we wish to execute',type=int)
args = parser.parse_args()
url = 'postgresql://{}:{}/{}'.format(args.postgres_host,args.postgres_port,args.postgres_dbname)
properties = {'user': args.postgres_user, 'password': args.postgres_password}
postgres_conn=psycopg2.connect(dbname=args.postgres_dbname,user=args.postgres_user,password=args.postgres_password, host=args.postgres_host, port=args.postgres_port)

# Issue the specified amount of shuffles in Postgres on the materialized view. Caculate average time and populate into dataframe
print("Shuffling data in PostgreSQL {} times. Collecting performance statistics".format(args.permutations))
postgres_raw_shuffle_times = []
for i in range(0,args.permutations):
    print("On iteration {}/{} for task".format(i+1,args.permutations))
    start = datetime.datetime.now()
    postgres_shuffle_data(postgres_conn,"{}_shuffled".format(args.target_table))
    end = datetime.datetime.now()
    time_taken = end-start
    postgres_raw_shuffle_times += [time_taken.total_seconds()]


# Issue the specified amount of shuffles in Postgres on the materialized view + import into HDFS. Caculate average time and populate into dataframe
print("Uploading raw data from Postgres into HDFS {} times. Collecting performance statistics".format(args.permutations))
postgres_import_times = []
for i in range(0,args.permutations):
    print("On iteration {}/{} for task".format(i+1,args.permutations))
    start = datetime.datetime.now()
    read_postgres_table_into_memory("{}".format(args.target_table),url,properties)
    end = datetime.datetime.now()
    time_taken = end-start
    postgres_import_times += [time_taken.total_seconds()]


# Shuffle and cache table locally in spark. Caculate average time and populate into dataframe
print("Shuffling data locally in PySpark {} times. Collecting performance statistics".format(args.permutations))
spark_shuffle_times = []
for i in range(0,args.permutations):
    print("On iteration {}/{} for task".format(i+1,args.permutations))
    start = datetime.datetime.now()
    spark_shuffle_data("{}".format(args.target_table)).registerTempTable("{}_shuffled".format(args.target_table))
    SQLContext(spark).cacheTable("{}_shuffled".format(args.target_table))
    end = datetime.datetime.now()
    time_taken = end-start
    spark_shuffle_times += [time_taken.total_seconds()]
num_executors = int(sc._conf.get('spark.executor.instances'))
stat_df = pd.DataFrame({'postgres_raw_shuffle':postgres_raw_shuffle_times,
                        'postgres_import':postgres_import_times,
                        'spark_shuffle (Using {} executors)'.format(num_executors):spark_shuffle_times})
print(stat_df)
print("mean run times:")
print(stat_df.mean())
