import json
import logging
from datetime import datetime

import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
glue_client = boto3.client("glue")
s3_client = boto3.client("s3")


def lambda_handler(event, context):
    """
    Lambda function to trigger Glue crawler and ETL job
    """
    try:
        logger.info("Lambda function triggered")
        logger.info(f"Event: {json.dumps(event)}")

        # Extract S3 bucket and key from event
        s3_bucket = event["Records"][0]["s3"]["bucket"]["name"]
        s3_key = event["Records"][0]["s3"]["object"]["key"]

        logger.info(f"Processing file: s3://{s3_bucket}/{s3_key}")

        # Trigger Glue crawler
        crawler_name = "assignment5-crawler"
        trigger_glue_crawler(crawler_name)

        # Wait for crawler to complete
        wait_for_crawler_completion(crawler_name)

        # Trigger Glue ETL job
        job_name = "assignment5-etl-job"
        trigger_glue_job(job_name)

        logger.info("Pipeline execution completed successfully")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Pipeline triggered successfully",
                    "s3_bucket": s3_bucket,
                    "s3_key": s3_key,
                    "timestamp": datetime.now().isoformat(),
                }
            ),
        }

    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        raise e


def trigger_glue_crawler(crawler_name):
    """
    Trigger the Glue crawler
    """
    try:
        logger.info(f"Starting Glue crawler: {crawler_name}")

        response = glue_client.start_crawler(Name=crawler_name)

        logger.info(f"Glue crawler started: {crawler_name}")
        return response

    except Exception as e:
        logger.error(f"Error starting Glue crawler: {str(e)}")
        raise e


def wait_for_crawler_completion(crawler_name):
    """
    Wait for crawler to complete
    """
    try:
        logger.info(f"Waiting for crawler completion: {crawler_name}")

        while True:
            response = glue_client.get_crawler(Name=crawler_name)
            state = response["Crawler"]["State"]

            if state == "READY":
                logger.info(f"Crawler {crawler_name} completed successfully")
                break
            elif state == "RUNNING":
                logger.info(f"Crawler {crawler_name} is still running...")
                import time

                time.sleep(30)  # Wait 30 seconds before checking again
            else:
                raise Exception(f"Crawler {crawler_name} failed with state: {state}")

    except Exception as e:
        logger.error(f"Error waiting for crawler completion: {str(e)}")
        raise e


def trigger_glue_job(job_name):
    """
    Trigger the Glue ETL job
    """
    try:
        logger.info(f"Starting Glue ETL job: {job_name}")

        response = glue_client.start_job_run(JobName=job_name)

        logger.info(f"Glue ETL job started: {job_name}")
        return response

    except Exception as e:
        logger.error(f"Error starting Glue ETL job: {str(e)}")
        raise e
