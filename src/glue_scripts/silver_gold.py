import sys
import boto3
import json
import logging

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "bucket",
    "database"
])

# Set default values
bucket = args.get("bucket", "assignment5-data-lake")
database = args.get("database", "serverless-data-pipeline-assignment5_data_database")


# Processing metadata
execution_id = "unknown"
pipeline_run = "unknown"

# Define S3 paths
gold_path = f"s3://{bucket}/gold/"
silver_path = f"s3://{bucket}/silver/"

logger.info(f"Silver to Gold ETL Configuration")
logger.info(f"Bucket: {bucket}")
logger.info(f"Database: {database}")
logger.info(f"Gold path: {gold_path}")
logger.info(f"Silver path: {silver_path}")

def partition_columns(df):
    df = df.withColumn("year", year(col("event_date")))
    df = df.withColumn("month", month(col("event_date")))
    df = df.withColumn("day", dayofmonth(col("event_date")))
    return df

def validate_data(df):
    #Validating data
    logger.info("Data Validation")
    
    # Checking for null values 
    null_counts = df.select([
        count(when(col(c).isNull(), c)).alias(c) 
        for c in df.columns
    ]).collect()[0]
    
    logger.info("Null value counts:")
    for field in df.schema.fields:
        field_name = field.name
        null_count = null_counts[field_name]
        if null_count > 0:
            logger.info(f"  {field_name}: {null_count} nulls")
    
    # Checking data types
    logger.info("Data types:")
    for field in df.schema.fields:
        logger.info(f"  {field.name}: {field.dataType}")
    
    # Checking row count
    total_rows = df.count()
    logger.info(f"Total rows: {total_rows:,}")
    
    if total_rows == 0:
        logger.warning("No data to process!")
        return False
    
    return True

def business_kpis(df):
    
    return df.withColumn(
        "error_rate",
        round((col("client_error_count") + col("server_error_count")) * 100.0 / col("total_requests"), 2)
    ).withColumn(
        "success_rate", 
        round(col("success_count") * 100.0 / col("total_requests"), 2)
    ).withColumn(
        "avg_response_time_seconds",
        round(col("avg_response_time") / 1000.0, 3)
    ).withColumn(
        "performance_grade",
        when(col("avg_response_time") < 200, "Excellent")
        .when(col("avg_response_time") < 500, "Good")
        .when(col("avg_response_time") < 1000, "Fair")
        .otherwise("Poor")
    ).withColumn(
        "availability_score",
        round((col("success_count") * 100.0 / col("total_requests")), 2)
    )

def get_latest_processed_timestamp(bucket):

    #Get the latest processing_timestamp from the gold layer.
    
    try:
        # Try to read existing daily_metrics to get the latest processed timestamp
        gold_path = f"s3://{bucket}/gold/daily_metrics/"
        
        logger.info(f"Checking for existing gold data at: {gold_path}")
        
        from pyspark.sql.functions import max as spark_max
        
        try:
            existing_gold = spark.read.parquet(gold_path)
            latest_timestamp_row = existing_gold.select(spark_max("processing_timestamp")).collect()
            
            if latest_timestamp_row and latest_timestamp_row[0][0]:
                latest_timestamp = latest_timestamp_row[0][0]
                logger.info(f"Found latest processed timestamp in gold layer: {latest_timestamp}")
                return latest_timestamp
            else:
                logger.info("No existing processing_timestamp found in gold layer")
                return None
                
        except Exception as read_error:
            logger.info(f"Could not read existing gold data: {read_error}")
            return None
            
    except Exception as e:
        logger.error(f"Error getting latest processed timestamp: {e}")
        return None

def check_s3_path_exists(bucket, prefix):
    
    #This can be used for validation before processing.
    
    try:
        s3_client = boto3.client('s3')
        response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix, MaxKeys=1)
        return 'Contents' in response and len(response['Contents']) > 0
    except Exception as e:
        logger.error(f"Error checking S3 path {prefix}: {e}")
        return False

def process_data():
    try:
        logger.info("Starting Silver -> Gold ETL processing")

        # PRIMARY APPROACH: Direct S3 reading with timestamp-based incremental processing
        logger.info("Reading silver data directly from S3")
        silver_path = f"s3://{bucket}/silver/"
        logger.info(f"Reading from S3 path: {silver_path}")
        
        # Validate S3 path exists
        if not check_s3_path_exists(bucket, "silver/"):
            logger.error("Silver path does not exist or is empty")
            return False
        
        # Read Silver data directly from S3 (no crawler dependency)
        silver_data = glueContext.create_dynamic_frame.from_options(
            connection_type="s3",
            connection_options={
                "paths": [silver_path],
                "recurse": True,
                "useS3ListImplementation": True
            },
            format="parquet",
            transformation_ctx="silver_to_gold_bookmark"  
        )
        
        df = silver_data.toDF()
        total_count = df.count()
        logger.info(f"Total Silver data found in S3: {total_count:,}")
        
        if total_count == 0:
            logger.info("No Silver data to process")
            return True
        
        # Get last processed timestamp from Gold layer to determine what's new
        latest_processed_timestamp = get_latest_processed_timestamp(bucket)
        logger.info(f"Last processed timestamp from Gold layer: {latest_processed_timestamp}")
        
        if latest_processed_timestamp:
            # Filter to only process newer data (incremental processing)
            df = df.filter(col("processing_timestamp") > latest_processed_timestamp)
            new_count = df.count()
            logger.info(f"New data to process (after {latest_processed_timestamp}): {new_count:,}")
            
            if new_count == 0:
                logger.info("No new data to process - all data already processed")
                return True
                
            logger.info(f"Processing {new_count:,} new records with incremental logic")
        else:
            logger.info("No previous timestamp found - processing all data (first run)")
            logger.info(f"Processing {total_count:,} total records")
        
        # Debug: Show schema and sample data
        logger.debug("Data schema:")
        df.printSchema()

        if df.count() == 0:
            logger.info("No new silver data to process")
            return True

        # Validate data quality
        if not validate_data(df):
            logger.error("Data validation failed. Stopping processing.")
            return False

        # Curated metrics

        # Daily aggregations 
        curated_metrics = df.groupBy("event_date").agg(
            count("*").alias("total_requests"),
            countDistinct("user_id").alias("unique_users"),
            avg("response_time_ms").alias("avg_response_time"),
            sum("bytes_sent").alias("total_bytes_sent"),

            # Error counts
            sum("is_client_error").alias("client_error_count"),
            sum("is_server_error").alias("server_error_count"),
            sum("is_success").alias("success_count"),
            sum("is_redirect").alias("redirect_count"),
            
            # Performance indicators
            sum("is_slow").alias("slow_requests"),
            sum("is_fast").alias("fast_requests"),
            sum("is_large_response").alias("large_responses"),
            sum("is_small_response").alias("small_responses"),
            
            # CRITICAL: Include max processing_timestamp for next incremental run
            max("processing_timestamp").alias("processing_timestamp")
        )

        # Session aggregations
        session_metrics = df.groupBy("user_session").agg(
            count("*").alias("page_views"),
            min("event_ts").alias("session_start"),
            max("event_ts").alias("session_end"),
            countDistinct("path").alias("unique_pages"),
            sum("response_time_ms").alias("total_response_time")
        )

        # Always use APPEND mode - safer approach
        logger.info("Writing daily metrics to Gold layer with APPEND mode")
        logger.info("This ensures we never lose existing data")
        write_mode = "append"
        
        # Add business KPIs and partitions for dashboard-ready data
        curated_metrics = business_kpis(curated_metrics)
        curated_metrics = partition_columns(curated_metrics)
        
        # Write using Spark DataFrame with appropriate mode
        curated_metrics.write.mode(write_mode) \
            .partitionBy("year", "month", "day") \
            .format("parquet") \
            .option("compression", "snappy") \
            .save(f"{gold_path}/daily_metrics/")

        # Writing session metrics to Gold layer with APPEND mode
        logger.info("Writing session metrics to Gold layer with APPEND mode")
        
        # Add session date for partitioning
        session_metrics = session_metrics.withColumn(
            "session_date", 
            to_date(col("session_start"))
        )
        session_metrics = session_metrics.withColumn("year", year(col("session_date")))
        session_metrics = session_metrics.withColumn("month", month(col("session_date")))
        session_metrics = session_metrics.withColumn("day", dayofmonth(col("session_date")))
        
        # Write using Spark DataFrame
        session_metrics.write.mode(write_mode) \
            .partitionBy("year", "month", "day") \
            .format("parquet") \
            .option("compression", "snappy") \
            .save(f"{gold_path}/session_metrics/")

        logger.info("Silver -> Gold ETL processing completed successfully!")
        
        # Final processing summary
        daily_count = curated_metrics.count()
        session_count = session_metrics.count()

        logger.info(f"Processing Summary:")
        logger.info(f"   Records processed: {df.count():,}")
        logger.info(f"   Daily metrics created: {daily_count:,}")
        logger.info(f"   Session metrics created: {session_count:,}")
        
        # Get total counts in gold bucket after writing
        try:
            # Get total daily metrics count
            daily_metrics_total_frame = glueContext.create_dynamic_frame.from_options(
                connection_type="s3",
                connection_options={"paths": [f"{gold_path}/daily_metrics/"], "recurse": True},
                format="parquet"
            )
            daily_metrics_total_df = daily_metrics_total_frame.toDF()
            daily_metrics_total_count = daily_metrics_total_df.count()
            
            # Get total session metrics count
            session_metrics_total_frame = glueContext.create_dynamic_frame.from_options(
                connection_type="s3",
                connection_options={"paths": [f"{gold_path}/session_metrics/"], "recurse": True},
                format="parquet"
            )
            session_metrics_total_df = session_metrics_total_frame.toDF()
            session_metrics_total_count = session_metrics_total_df.count()
            
            logger.info(f"JOB  COMPLETED: Wrote {daily_count:,} daily metrics and {session_count:,} session metrics to gold")
            logger.info(f"GOLD LAYER TOTALS:")
            logger.info(f"   Daily metrics: {daily_metrics_total_count:,} records ")
            logger.info(f"   Session metrics: {session_metrics_total_count:,} records")
            
        except Exception as count_error:
            logger.warning(f"Could not get gold bucket total counts: {count_error}")
        
        return True

    except Exception as e:
        logger.error(f"Error in ETL processing: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return False


if __name__ == "__main__":
    job.init(args['JOB_NAME'], args)
    process_data()
    job.commit()
