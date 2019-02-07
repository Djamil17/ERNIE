from pyspark import Row
from pyspark.sql import SparkSession
from pyspark.sql.functions import rand
from pyspark.sql.functions import monotonically_increasing_id
import time,sys
import argparse
import pandas as pd

warehouse_location = '/user/spark/data'

spark = SparkSession.builder.appName("permute_in_spark") \
                    .config("spark.sql.warehouse.dir", warehouse_location) \
                    .enableHiveSupport() \
                    .getOrCreate()
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)


# Read the input dataset into a variable
input_dataset = spark.sql("SELECT * FROM {}".format(sys.argv[1]))
input_dataset.show()


def obs_frequency_calculations():
    obs_df=input_dataset.select(['source_id','reference_issn'])

    obs_df=obs_df.withColumn('id',monotonically_increasing_id())

    obs_df.createOrReplaceTempView('input_table')

    obs_df=spark.sql("SELECT ref1,ref2,count(*) as obs_frequency from (SELECT a.reference_issn as ref1, b.reference_issn as ref2 FROM input_table a JOIN input_table b \
    ON a.source_id=b.source_id WHERE a.reference_issn = b.reference_issn and a.id!=b.id and a.id < b.id \
    UNION ALL SELECT a.reference_issn, \
    b.reference_issn FROM input_table a JOIN input_table b ON a.source_id=b.source_id WHERE a.reference_issn < b.reference_issn) as temp group by ref1,ref2")

    obs_df=obs_df.withColumnRenamed('ref1','journal_pair_A').withColumnRenamed('ref2','journal_pair_B')

    spark.catalog.dropTempView('input_table')

    return obs_df

'''def shuffle_generator(ref_year_group):
    group = []
    group_size = 0
    for row in ref_year_group:
        group.append(row)
        group_size += 1
    if group_size > 0:  # ready to process
        for i, row in enumerate(group):
            shuffle_index = i + 1 if i < group_size - 1 else 0
            yield Row(source_id=row.source_id,
                      source_year=row.source_year,
                      source_document_id_type=row.source_document_id_type,
                      source_issn=row.source_issn,
                      cited_source_uid=group[shuffle_index].cited_source_uid,
                      reference_year=group[shuffle_index].reference_year,
                      reference_document_id_type=group[shuffle_index].reference_document_id_type,
                      reference_issn=group[shuffle_index].reference_issn))'''

def calculate_journal_pairs_freq(file_name,i):

    # df=spark.read.csv(file_name,inferSchema=True,header=True)

    df=file_name.select(['source_id','reference_issn'])

    # df=df.withColumnRenamed('s_reference_issn','reference_issn')

    df=df.withColumn('id',monotonically_increasing_id())

    df.createOrReplaceTempView('bg_table')

    df=spark.sql("SELECT ref1,ref2,count(*) as bg_freq from (SELECT a.reference_issn as ref1, b.reference_issn as ref2 FROM bg_table a JOIN bg_table b \
    ON a.source_id=b.source_id WHERE a.reference_issn = b.reference_issn and a.id!=b.id and a.id < b.id \
    UNION ALL SELECT a.reference_issn,b.reference_issn \
        FROM bg_table a JOIN bg_table b ON a.source_id=b.source_id WHERE a.reference_issn < b.reference_issn) as temp group by ref1,ref2")

    df=df.withColumnRenamed('ref1','journal_pair_A').withColumnRenamed('ref2','journal_pair_B')

    df.createOrReplaceTempView('bg_table')

    df=spark.sql('SELECT a.*,b.bg_freq from obs_frequency a left join bg_table b on a.journal_pair_A=b.journal_pair_A and a.journal_pair_B=b.journal_pair_B ')

    df=df.withColumnRenamed('bg_freq','bg_'+str(i))

    df.createOrReplaceTempView('obs_frequency')

    if i in [10,100]:
        z_score_calculations(i)

def final_table(iterations):
    # df=spark.read.csv(obs_file_name,header=True,inferSchema=True)

    df=input_dataset.select(['source_id','cited_source_uid','reference_issn'])

    df=df.withColumn('id',monotonically_increasing_id())

    df.createOrReplaceTempView('final_table')

    df=spark.sql("SELECT a.source_id,a.cited_source_uid as wos_id_A,b.cited_source_uid as wos_id_B,a.reference_issn as journal_pair_A,b.reference_issn as journal_pair_B FROM final_table a JOIN \
        final_table b ON a.source_id=b.source_id WHERE a.reference_issn = b.reference_issn and a.id!=b.id and a.id < b.id \
            UNION ALL SELECT a.source_id,a.cited_source_uid,b.cited_source_uid,a.reference_issn,b.reference_issn FROM final_table a JOIN final_table b ON \
                a.source_id=b.source_id WHERE a.reference_issn < b.reference_issn \
                ")

    df.createOrReplaceTempView('final_table')

    df=spark.sql("SELECT a.*,b.obs_frequency,b.z_score,b.count,b.mean from final_table a JOIN z_scores_table b ON a.journal_pair_A=b.journal_pair_A \
        AND a.journal_pair_B=b.journal_pair_B")

    df.repartition(1).write.csv("spark_results_"+str(iterations),header=True,mode='overwrite')
    #duration=time.time()-start_time
    #print(f'Total duration in seconds for {iterations} iterations is {duration}')


def z_score_calculations(iterations):
    #z-score calculations
    # print('printing the spark dataframe')
    # testing=spark.sql("SELECT * from obs_frequency")
    # testing.show(n=5)
    pandas_df=spark.sql("SELECT * from obs_frequency").toPandas()

    #Calculating the mean
    pandas_df['mean']=pandas_df.iloc[:,3:].mean(axis=1)

    #Calculating the standard deviation
    pandas_df['std']=pandas_df.iloc[:,3:iterations+3].std(axis=1)

    #Calculating z_scores
    pandas_df['z_score']=(pandas_df['obs_frequency']-pandas_df['mean'])/pandas_df['std']

    #Calculating the count
    pandas_df['count']=pandas_df.iloc[:,3:iterations+3].apply(lambda x: x.count(),axis=1)

    pandas_df=pandas_df[['journal_pair_A','journal_pair_B','obs_frequency','mean','z_score','count']].dropna()
    # print('printing the pandas dataframe')
    # pandas_df.head(n=10)
    # obs_file['count']=obs_file.iloc[:,2:number].apply(lambda x: x.count(),axis=1)
    # obs_file[['journal_pairs','obs_frequency','mean','z_scores','count']].dropna().to_csv(bg_files+'zscores_file.csv',index=False)
    obs_df=spark.createDataFrame(pandas_df)
    # del(pandas_df)
    obs_df.createOrReplaceTempView('z_scores_table')

    final_table(iterations)

obs_df=obs_frequency_calculations()
obs_df.createOrReplaceTempView('obs_frequency')
calculate_journal_pairs_freq(input_dataset,i)
z_score_calculations(number_of_repetitions)
spark.stop()
