import json
import boto3
import os
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
glue_client = boto3.client('glue')

def lambda_handler(event, context):
    """
    Lambda function to process data from S3 and trigger Glue ETL job
    """
    try:
        logger.info(f"Event received: {json.dumps(event)}")
        
        # Get environment variables
        raw_bucket = os.environ['RAW_BUCKET']
        processed_bucket = os.environ['PROCESSED_BUCKET']
        environment = os.environ['ENVIRONMENT']
        
        # Process S3 event
        for record in event.get('Records', []):
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            logger.info(f"Processing file: s3://{bucket_name}/{object_key}")
            
            # Validate that the file is in the raw bucket
            if bucket_name != raw_bucket:
                logger.warning(f"File not in expected bucket. Expected: {raw_bucket}, Got: {bucket_name}")
                continue
            
            # Process the file
            process_file(bucket_name, object_key, processed_bucket)
            
            # Trigger Glue ETL job
            trigger_glue_job()
            
        return {
            'statusCode': 200,
            'body': json.dumps('Data processing completed successfully')
        }
        
    except Exception as e:
        logger.error(f"Error processing data: {str(e)}")
        raise e

def process_file(source_bucket, object_key, target_bucket):
    """
    Process the uploaded file and move it to processed bucket
    """
    try:
        # Generate processed file name
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        processed_key = f"processed/{timestamp}_{object_key.split('/')[-1]}"
        
        # Copy file to processed bucket
        copy_source = {'Bucket': source_bucket, 'Key': object_key}
        s3_client.copy_object(
            CopySource=copy_source,
            Bucket=target_bucket,
            Key=processed_key
        )
        
        logger.info(f"File processed and copied to: s3://{target_bucket}/{processed_key}")
        
        # Add metadata to processed file
        s3_client.put_object_tagging(
            Bucket=target_bucket,
            Key=processed_key,
            Tagging={
                'TagSet': [
                    {'Key': 'processed_date', 'Value': timestamp},
                    {'Key': 'source_file', 'Value': object_key},
                    {'Key': 'environment', 'Value': os.environ['ENVIRONMENT']}
                ]
            }
        )
        
    except Exception as e:
        logger.error(f"Error processing file {object_key}: {str(e)}")
        raise e

def trigger_glue_job():
    """
    Trigger the Glue ETL job
    """
    try:
        job_name = f"assignment5-etl-job-{os.environ['ENVIRONMENT']}"
        
        # Start the Glue job
        response = glue_client.start_job_run(
            JobName=job_name
        )
        
        logger.info(f"Glue job triggered: {response['JobRunId']}")
        
    except Exception as e:
        logger.error(f"Error triggering Glue job: {str(e)}")
        # Don't raise here as this is not critical for the main processing 