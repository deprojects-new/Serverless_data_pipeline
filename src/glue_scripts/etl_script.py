import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Initializing
args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Get job parameters
raw_bucket = getResolvedOptions(sys.argv, ["raw_bucket"])["raw_bucket"]
processed_bucket = getResolvedOptions(sys.argv, ["processed_bucket"])[
    "processed_bucket"
]


def process_data():
    """
    Main ETL processing function
    """
    try:
        # Read data from raw bucket
        raw_data = glueContext.create_dynamic_frame.from_options(
            connection_type="s3",
            connection_options={"paths": [f"s3://{raw_bucket}/"], "recurse": True},
            format="csv",
            format_options={"withHeader": True, "separator": ","},
        )

        # Converting to Spark DataFrame
        df = raw_data.toDF()

        # Add processing timestamp
        df = df.withColumn("processing_timestamp", current_timestamp())

        # Add row number for tracking
        df = df.withColumn("row_id", monotonically_increasing_id())

        # Sample transformations - just to check

        df = df.na.drop()

        # Added quality checks
        df = df.withColumn(
            "data_quality_score", when(col("row_id").isNotNull(), 100).otherwise(0)
        )

        # Convert back to DynamicFrame
        processed_data = DynamicFrame.fromDF(df, glueContext, "processed_data")

        # Writing to processed bucket
        glueContext.write_dynamic_frame.from_options(
            frame=processed_data,
            connection_type="s3",
            connection_options={
                "path": f"s3://{processed_bucket}/processed/",
                "partitionKeys": ["processing_timestamp"],
            },
            format="parquet",
        )

        print(
            f"Successfully processed data from {raw_bucket} " f"to {processed_bucket}"
        )

    except Exception as e:
        print(f"Error in ETL processing: {str(e)}")
        raise e


# Execute
if __name__ == "__main__":
    process_data()
    job.commit()
