#!/usr/bin/env bash
#** Usage notes are incorporated into online help (-h). The format mimics a manual page.
if [[ $1 == "-h" ]]; then
  cat <<'HEREDOC'
NAME
  spark_analysis.sh -- import data from PostgreSQL, analyze in PySpark, and export back to PostgreSQL

SYNOPSIS
  spark_analysis.sh
  spark_analysis.sh -h: display this help

DESCRIPTION
  Analysis is performed in the Spark Cluster

NOTE
  Success of this job is dependent upon pre-established Azure privileges and a saved connection via cli

ENVIRONMENT
  Required environment variables:
  * POSTGRES_DATABASE                           the postgres database you wish to connect to
  * POSTGRES_USER                               the postgres user you wish to connect as
  * POSTGRES_PASSWORD                           a PostgreSQL password for the target server
  * POSTGRES_HOSTNAME                           the IP address of the server hosting the data
  * POSTGRES_SCHEMA                             the schema to execute code against
  * TARGET_DATASET                              the target dataset to evaluate
  * NUM_PERMUTATIONS                            num of permutations to run
HEREDOC
  exit 1
fi


# First, clean the HDFS if needed
echo "*** CLEANING HIVE DATA WAREHOUSE : $(date)"
hdfs dfs -rm -r -f /hive/warehouse/*
echo "*** CLEANING ANY MISCELLANEOUS DATA : $(date)"
hdfs dfs -rm -r -f /user/spark/data/*

# Ensure the necessary libraries are installed/updated
wget https://jdbc.postgresql.org/download/postgresql-42.2.6.jar
sudo cp postgresql-42.2.6.jar /usr/hdp/current/sqoop-client/lib/
sudo /opt/anaconda3/bin/conda install -y --debug psycopg2
sudo /opt/anaconda3/bin/conda update -y --debug numpy
sudo /opt/anaconda3/bin/conda update -y --debug pandas
#sudo /usr/bin/anaconda/bin/conda install -y --debug psycopg2
#sudo /usr/bin/anaconda/bin/conda update -y --debug numpy
#sudo /usr/bin/anaconda/bin/conda update -y --debug pandas

# Next run PySpark calculations
$SPARK_HOME/bin/spark-submit --driver-memory 15g --executor-memory 25G --num-executors 8 --executor-cores 4 \
  --driver-class-path $(pwd)/postgresql-42.2.6.jar --jars $(pwd)/postgresql-42.2.6.jar \
  ./uzzi_count_and_analyze.py -tt ${TARGET_DATASET} -ph ${POSTGRES_HOSTNAME} -pd ${POSTGRES_DATABASE} -U ${POSTGRES_USER} -W "${POSTGRES_PASSWORD}" -i ${NUM_PERMUTATIONS}
