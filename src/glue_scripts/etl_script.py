import sys

import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Initializing the Glue context
args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# job parameters
raw_path = getResolvedOptions(sys.argv, ["raw_path"])["raw_path"]
processed_path = getResolvedOptions(sys.argv, ["processed_path"])["processed_path"]

"""
ETL function with storage optimization
"""


def process_data():
    try:
        # Read data from catalog (handles schema evolution automatically)
        raw_data = glueContext.create_dynamic_frame.from_catalog(
            database="assignment5-data-database",
            table_name="raw",
            transformation_ctx="raw_data",
        )

        # Convert to DataFrame
        df = raw_data.toDF()

        # Print current schema for debugging
        print("Current schema detected:")
        df.printSchema()

        # Defining core  columns
        required_columns = ["event_type", "event_id", "user_id"]

        # Defining optional columns
        optional_columns = ["location", "session_id"]

        # Validate if required columns exist
        missing_required = [col for col in required_columns if col not in df.columns]
        if missing_required:
            raise ValueError(f"Missing required columns: {missing_required}")

        # Add missing optional columns with null values
        for col_name in optional_columns:
            if col_name not in df.columns:
                df = df.withColumn(col_name, lit(None).cast("string"))
                print(f"Added missing column '{col_name}' with null values")

        # Add metadata columns
        df = df.withColumn("processing_timestamp", current_timestamp())
        df = df.withColumn(
            "schema_version", when(col("location").isNotNull(), "v2").otherwise("v1")
        )
        df = df.withColumn("row_id", monotonically_increasing_id())

        # partition columns for time-based partitioning
        df = df.withColumn("year", year(col("processing_timestamp")))
        df = df.withColumn("month", month(col("processing_timestamp")))
        df = df.withColumn("day", dayofmonth(col("processing_timestamp")))

        # Data quality checks
        df = df.withColumn(
            "data_quality_score",
            when(
                col("event_type").isNotNull()
                & col("event_id").isNotNull()
                & col("user_id").isNotNull(),
                100,
            ).otherwise(0),
        )

        # Filtering out invalid records
        valid_df = df.filter(col("data_quality_score") > 0)
        invalid_df = df.filter(col("data_quality_score") == 0)

        # Log data quality metrics
        total_count = df.count()
        valid_count = valid_df.count()
        invalid_count = invalid_df.count()

        print(f"Data Quality Report:")
        print(f"  Total records: {total_count}")
        print(f"  Valid records: {valid_count}")
        print(f"  Invalid records: {invalid_count}")
        print(f"  Quality rate: {(valid_count/total_count)*100:.2f}%")

        # Optimizing DataFrame for Parquet
        partition_count = valid_count // 100000
        optimal_partitions = 1 if partition_count < 1 else partition_count
        print(f"Optimizing to {optimal_partitions} partitions for optimal file sizes")

        # Coalesce to optimal file sizes
        valid_df = valid_df.coalesce(optimal_partitions)

        #  Order by timestamp
        valid_df = valid_df.orderBy("processing_timestamp")

        # Back to DynamicFrame
        processed_data = DynamicFrame.fromDF(valid_df, glueContext, "processed_data")

        # Writing with optimal partitioning and compression
        glueContext.write_dynamic_frame.from_options(
            frame=processed_data,
            connection_type="s3",
            connection_options={
                "path": processed_path,
                "partitionKeys": ["year", "month", "day"],  # YYYY-MM-DD partition
            },
            format="parquet",
            format_options={
                "compression": "snappy",  # Netflix, Airbnb uses this compression method , experimenting
                "writeCompatibility": "BACKWARD",
                "blockSize": 134217728,
                "pageSize": 1048576,
            },
            transformation_ctx="write_processed_data",
        )

        # Writing invalid records to separate location in s3 for investigation
        if invalid_count > 0:
            invalid_data = DynamicFrame.fromDF(invalid_df, glueContext, "invalid_data")
            glueContext.write_dynamic_frame.from_options(
                frame=invalid_data,
                connection_type="s3",
                connection_options={
                    "path": f"{processed_path.replace('/processed/', '/invalid/')}"
                },
                format="json",  # Keeping invalid records in JSON for debugging
                transformation_ctx="write_invalid_data",
            )
            print(f"Written {invalid_count} invalid records to invalid/ folder")

        # Logs for monitoring
        storage_metrics = {
            "total_records_processed": valid_count,
            "invalid_records": invalid_count,
            "quality_rate": (valid_count / total_count) * 100 if total_count > 0 else 0,
            "partitions_created": optimal_partitions,
            "schema_version_detected": valid_df.select("schema_version")
            .distinct()
            .count(),
            "unique_users": valid_df.select("user_id").distinct().count(),
            "compression_format": "snappy",
            "partition_strategy": "year/month/day",
        }

        print(f"Storage Optimization Metrics: {storage_metrics}")
        print(f"Successfully processed {valid_count} records with optimized storage")

    except Exception as e:
        print(f"Error in ETL processing: {str(e)}")
        raise e


# Execute
if __name__ == "__main__":
    process_data()
    job.commit()
