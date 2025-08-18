import json
import logging
import os
from datetime import date, datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def _json_safe(obj):
    # convert datetime/date to ISO-8601]
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type not serializable: {type(obj).__name__}")


def lambda_handler(event, context):
    try:
        logger.info("DATA PIPELINE TRIGGER STARTED")
        logger.info("Event: %s", json.dumps(event))

        # apt Validation
        if not event or "Records" not in event:
            logger.error("Invalid event structure: missing Records")
            return {"statusCode": 400, "body": "Invalid event structure"}

        # Extract S3
        s3_record = event["Records"][0]
        s3_bucket = s3_record["s3"]["bucket"]["name"]
        s3_key = s3_record["s3"]["object"]["key"]
        s3_size = s3_record["s3"]["object"].get("size", 0)

        # Data layer
        if s3_key.startswith("bronze/"):
            data_layer = "bronze"
        elif s3_key.startswith("silver/"):
            data_layer = "silver"
        elif s3_key.startswith("gold/"):
            data_layer = "gold"
        else:
            data_layer = "unknown"

        logger.info(
            "S3 Event: bucket=%s, key=%s, size=%s, layer=%s",
            s3_bucket,
            s3_key,
            s3_size,
            data_layer,
        )

        # State machine ARN
        state_machine_arn = os.environ.get("STATE_MACHINE_ARN")
        if not state_machine_arn:
            logger.error("STATE_MACHINE_ARN environment variable not set")
            return {"statusCode": 500, "body": "Missing environment variable"}

        logger.info("Step Functions ARN: %s", state_machine_arn)

        # Prepare execution input
        execution_input = {
            "bucket": s3_bucket,
            "key": s3_key,
            "size": int(s3_size),
            "data_layer": data_layer,
            "trigger_time": datetime.utcnow().isoformat(),
            "environment": os.environ.get("ENVIRONMENT", "unknown"),
        }
        logger.info("Execution input: %s", json.dumps(execution_input))

        # Start execution
        sfn = boto3.client("stepfunctions")
        response = sfn.start_execution(
            stateMachineArn=state_machine_arn,
            name=f"pipeline-{int(datetime.utcnow().timestamp())}",
            input=json.dumps(execution_input),
        )

        # Log response safely
        logger.info(
            "Step Functions execution started: %s",
            json.dumps(response, default=_json_safe),
        )

        exec_arn = response.get("executionArn")
        start_dt = response.get("startDate")  # this is a datetime
        logger.info("DATA PIPELINE TRIGGER COMPLETED SUCCESSFULLY")

        return {
            "statusCode": 200,
            "body": "Data pipeline execution started successfully",
            "execution_arn": exec_arn,
            "start_date": (
                start_dt.isoformat() if isinstance(start_dt, datetime) else None
            ),
        }

    except Exception as e:
        logger.error("ERROR: %s", str(e))
        import traceback

        logger.error("Traceback: %s", traceback.format_exc())
        return {"statusCode": 500, "body": f"Error: {str(e)}"}
