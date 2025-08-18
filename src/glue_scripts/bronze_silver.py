import logging
import sys

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
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

# Set default values
bucket = "assignment5-data-lake"

logger.info("Reading from S3 bronze folder, writing to S3 silver folder")

# Define S3 paths
bronze_path = f"s3://{bucket}/bronze/"
silver_path = f"s3://{bucket}/silver/"

logger.info(f"Reading from bronze structure: {bronze_path}")
logger.info(f"Writing to silver layer: {silver_path}")

"""
ETL function
"""


def handle_schema_validation(df):  # To validate schema
    expected_fields = [
        "event_id",
        "event_ts",
        "session_id",
        "method",
        "path",
        "status",
        "bytes_sent",
        "response_time_ms",
        "referrer",
        "user_agent",
        "user_id",
        "cache_status",
        "cdn_edge",
        "db_query_time_ms",
        "request_id",
    ]

    existing_fields = df.columns
    missing_fields = [
        field for field in expected_fields if field not in existing_fields
    ]

    if missing_fields:
        logger.warning(f"Missing fields: {missing_fields}")
        for field in missing_fields:
            df = df.withColumn(field, lit(None))

    return df


def cast_data_types(df):
    df = df.withColumn("status", col("status").cast("int"))
    df = df.withColumn("bytes_sent", col("bytes_sent").cast("long"))
    df = df.withColumn("response_time_ms", col("response_time_ms").cast("int"))
    df = df.withColumn("db_query_time_ms", col("db_query_time_ms").cast("int"))

    # Handle optional fields
    df = df.withColumn(
        "user_id", when(col("user_id").isNull(), lit(None)).otherwise(col("user_id"))
    )
    df = df.withColumn(
        "referrer",
        when(col("referrer").isNull(), lit("direct")).otherwise(col("referrer")),
    )

    return df


def apply_data_validations(df):
    initial_count = df.count()

    # HTTP validations
    df = df.filter((col("status").isNotNull()) & (col("status").between(100, 599)))
    df = df.filter(
        col("method").isin(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
    )

    # Performance validations
    df = df.filter(
        (col("response_time_ms").isNotNull())
        & (col("response_time_ms") > 0)
        & (col("response_time_ms") <= 30000)
    )
    df = df.filter(
        (col("bytes_sent").isNotNull())
        & (col("bytes_sent") >= 0)
        & (col("bytes_sent") <= 10000000)
    )

    # Data integrity validations
    df = df.filter(col("event_ts").isNotNull())
    df = df.filter(
        (col("path").isNotNull()) & (col("path") != "") & (col("path") != "//")
    )
    df = df.filter((col("client_ip").isNotNull()) & (col("client_ip") != ""))

    # Deduplication
    df = df.dropDuplicates(["event_id"])

    # PII removal
    df = df.drop("client_ip")

    final_count = df.count()
    logger.info(
        f"Validation: {initial_count:,} → {final_count:,} ({initial_count-final_count:,} rejected)"
    )

    return df


def add_enrichment_fields(df):
    # Status indicators
    df = df.withColumn(
        "is_client_error", when(col("status").between(400, 499), 1).otherwise(0)
    )
    df = df.withColumn(
        "is_server_error", when(col("status").between(500, 599), 1).otherwise(0)
    )
    df = df.withColumn(
        "is_success", when(col("status").between(200, 299), 1).otherwise(0)
    )
    df = df.withColumn(
        "is_redirect", when(col("status").between(300, 399), 1).otherwise(0)
    )

    # Performance indicators
    df = df.withColumn("is_slow", when(col("response_time_ms") > 1000, 1).otherwise(0))
    df = df.withColumn("is_fast", when(col("response_time_ms") < 100, 1).otherwise(0))

    # Size indicators
    df = df.withColumn(
        "is_large_response", when(col("bytes_sent") > 100000, 1).otherwise(0)
    )
    df = df.withColumn(
        "is_small_response", when(col("bytes_sent") < 1000, 1).otherwise(0)
    )

    # Date partitions
    df = df.withColumn("event_date", to_date(col("event_ts")))
    df = df.withColumn("year", year(col("event_date")))
    df = df.withColumn("month", month(col("event_date")))
    df = df.withColumn("day", dayofmonth(col("event_date")))

    # Session tracking
    df = df.withColumn(
        "user_session",
        concat(
            coalesce(col("user_id"), lit("anonymous")),
            lit("_"),
            date_format(col("event_ts"), "yyyy-MM-dd-HH"),
        ),
    )
    df = df.withColumn("session_date", to_date(col("event_ts")))
    df = df.withColumn("session_hour", hour(col("event_ts")))

    return df


def process_data():
    try:
        logger.info("Starting ETL processing")
        logger.info("Reading from flat bronze layer")
        logger.info(f"Bronze path: {bronze_path}")
        logger.info(f"Bucket: {bucket}")

        # Validate S3 path before reading
        import boto3

        s3_client = boto3.client("s3")
        try:
            # Check if bronze folder exists and has objects
            response = s3_client.list_objects_v2(
                Bucket=bucket, Prefix="bronze/", MaxKeys=1
            )
            if "Contents" not in response:
                logger.error("No objects found in bronze folder")
                logger.error(
                    "This suggests no data has been uploaded to the bronze layer"
                )
                return False
            else:
                logger.info(
                    f"Bronze folder validation: Found {response.get('KeyCount', 0)} objects"
                )
        except Exception as s3_error:
            logger.error(f"Cannot access S3 bucket '{bucket}': {s3_error}")
            return False

        raw_data = glueContext.create_dynamic_frame.from_options(
            connection_type="s3",
            connection_options={"paths": [bronze_path], "recurse": True},
            format="json",
            transformation_ctx="bronze_data_",
        )

        df = raw_data.toDF()
        initial_count = df.count()
        logger.info(f"Bronze data count (total): {initial_count:,}")

        if initial_count == 0:
            logger.info("No data in bronze layer")
            return True

        logger.info("Finding the most recent file by timestamp")

        import re
        from datetime import datetime

        import boto3

        s3_client = boto3.client("s3")

        try:
            # List all bronze files
            response = s3_client.list_objects_v2(Bucket=bucket, Prefix="bronze/")

            if "Contents" not in response:
                logger.warning("No files found in bronze folder")
                return True

            # files matching the pattern logs_YYYYMMDD_HHMMSS.json
            log_files = []
            pattern = r"bronze/logs_(\d{8})_(\d{6})\.json$"

            for obj in response["Contents"]:
                key = obj["Key"]
                match = re.match(pattern, key)
                if match:
                    date_str = match.group(1)
                    time_str = match.group(2)

                    # Parse timestamp from filename
                    timestamp_str = f"{date_str}_{time_str}"
                    timestamp = datetime.strptime(timestamp_str, "%Y%m%d_%H%M%S")

                    log_files.append(
                        {
                            "key": key,
                            "timestamp": timestamp,
                            "timestamp_str": timestamp_str,
                        }
                    )
                    logger.debug(f"Found log file: {key} (timestamp: {timestamp})")

            if not log_files:
                logger.warning(
                    "No log files matching pattern logs_YYYYMMDD_HHMMSS.json found"
                )
                return True

            # Sort by timestamp and get the latest file
            log_files.sort(key=lambda x: x["timestamp"], reverse=True)
            latest_file = log_files[0]

            logger.info(f"LATEST FILE SELECTED: {latest_file['key']}")
            logger.info(f"Timestamp: {latest_file['timestamp']}")
            logger.info(f"Total log files found: {len(log_files)}")

            # Process only the latest file
            latest_path = f"s3://{bucket}/{latest_file['key']}"
            logger.info(f"Reading latest file: {latest_path}")

            latest_file_frame = glueContext.create_dynamic_frame.from_options(
                connection_type="s3",
                connection_options={"paths": [latest_path], "recurse": False},
                format="json",
                transformation_ctx="latest_file_data_",
            )
            df = latest_file_frame.toDF()

            latest_count = df.count()
            logger.info(f"Latest file data count: {latest_count:,} records")

            if latest_count == 0:
                logger.warning("No data in the latest file")
                return True

        except Exception as e:
            logger.error(f"Latest file processing failed: {e}")
            logger.warning("Fallback: Processing all bronze data")

            # Use the original df from the initial read

        logger.info(f"Ready for processing: {df.count():,} records")

        # Schema and type handling
        df.printSchema()
        df = handle_schema_validation(df)
        df = cast_data_types(df)

        # Data quality validations
        df = apply_data_validations(df)

        # Add enrichment fields and processing metadata
        df = df.withColumn("processing_timestamp", current_timestamp())
        df = add_enrichment_fields(df)
        df = df.cache()

        final_count = df.count()
        logger.info(f"Final silver layer record count: {final_count:,}")

        # Writing to silver layer with proper append mode using Spark DataFrame
        logger.info("Writing to silver layer with APPEND mode using Spark DataFrame")

        #  Spark DataFrame  for  append mode
        df.write.mode("append").partitionBy("year", "month", "day").format(
            "parquet"
        ).option("compression", "snappy").save(silver_path)

        # Get total count in silver bucket after writing
        try:
            silver_total_frame = glueContext.create_dynamic_frame.from_options(
                connection_type="s3",
                connection_options={"paths": [silver_path], "recurse": True},
                format="parquet",
            )
            silver_total_df = silver_total_frame.toDF()
            silver_total_count = silver_total_df.count()
            logger.info(f"JOB COMPLETED: Wrote {final_count:,} new records to silver")
            logger.info(f"SILVER LAYER TOTAL: {silver_total_count:,} records")
        except Exception as count_error:
            logger.warning(f"Could not get silver layer total count: {count_error}")

        logger.info("ETL processing completed successfully!")
        logger.info(f"Silver transformation complete: {final_count:,} records")

        return True

    except Exception as e:
        logger.error(f"Error in ETL processing: {e}")
        raise e


if __name__ == "__main__":
    job.init(args["JOB_NAME"], args)
    process_data()
    job.commit()
