#!/usr/bin/env python3


import os
import sys
import time
from datetime import datetime, timedelta

import boto3


class PipelineMonitor:
    def __init__(self):
        """Initialize AWS clients and configuration"""
        self.lambda_client = boto3.client("lambda")
        self.glue_client = boto3.client("glue")
        self.logs_client = boto3.client("logs")
        self.s3_client = boto3.client("s3")

        # Configuration
        self.lambda_function_name = "assignment5-data-pipeline-lambda"
        self.crawler_name = "assignment5-crawler"
        self.etl_job_name = "assignment5-etl-job"
        self.database_name = "assignment5-data-database"
        self.bucket_name = "assignment5-data-lake"

        print("Starting Serverless Data Pipeline Monitor")

    def clear_screen(self):
        """Clear the terminal screen"""
        os.system("cls" if os.name == "nt" else "clear")

    def get_lambda_status(self):
        """Get Lambda function status and recent invocations"""
        try:
            # Get function info
            function_info = self.lambda_client.get_function(
                FunctionName=self.lambda_function_name
            )

            # Get recent logs to detect invocations
            log_group = f"/aws/lambda/{self.lambda_function_name}"

            try:
                # Get recent log events (last 5 minutes)
                end_time = int(time.time() * 1000)
                start_time = end_time - (5 * 60 * 1000)  # 5 minutes ago

                response = self.logs_client.filter_log_events(
                    logGroupName=log_group,
                    startTime=start_time,
                    endTime=end_time,
                    filterPattern="Lambda function triggered",
                )

                recent_invocations = len(response.get("events", []))
                last_invocation = None

                if response.get("events"):
                    last_event = response["events"][-1]
                    last_invocation = datetime.fromtimestamp(
                        last_event["timestamp"] / 1000
                    )

                return {
                    "status": "ACTIVE",
                    "last_modified": function_info["Configuration"]["LastModified"],
                    "recent_invocations": recent_invocations,
                    "last_invocation": last_invocation,
                    "memory_size": function_info["Configuration"]["MemorySize"],
                    "timeout": function_info["Configuration"]["Timeout"],
                }

            except self.logs_client.exceptions.ResourceNotFoundException:
                return {
                    "status": "NO_LOGS",
                    "last_modified": function_info["Configuration"]["LastModified"],
                    "recent_invocations": 0,
                    "last_invocation": None,
                }

        except Exception as e:
            return {"status": "ERROR", "error": str(e)}

    def get_crawler_status(self):
        """Get Glue Crawler status"""
        try:
            response = self.glue_client.get_crawler(Name=self.crawler_name)
            crawler = response["Crawler"]

            return {
                "status": crawler["State"],
                "last_crawl": crawler.get("LastCrawl", {}),
                "creation_time": crawler.get("CreationTime"),
                "targets": len(crawler.get("Targets", {}).get("S3Targets", [])),
            }

        except Exception as e:
            return {"status": "ERROR", "error": str(e)}

    def get_etl_job_status(self):
        """Get Glue ETL Job status"""
        try:
            # Get recent job runs
            response = self.glue_client.get_job_runs(
                JobName=self.etl_job_name, MaxResults=5
            )

            job_runs = response.get("JobRuns", [])

            if not job_runs:
                return {"status": "NO_RUNS"}

            latest_run = job_runs[0]

            return {
                "status": latest_run["JobRunState"],
                "job_run_id": latest_run["Id"],
                "started_on": latest_run.get("StartedOn"),
                "completed_on": latest_run.get("CompletedOn"),
                "execution_time": latest_run.get("ExecutionTime"),
                "error_message": latest_run.get("ErrorMessage"),
                "total_runs": len(job_runs),
            }

        except Exception as e:
            return {"status": "ERROR", "error": str(e)}

    def get_s3_recent_uploads(self):
        """Get recent S3 uploads to raw folder"""
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix="raw/", MaxKeys=10
            )

            objects = response.get("Contents", [])
            # Filter out the folder marker and sort by last modified
            files = [obj for obj in objects if not obj["Key"].endswith("/")]
            files.sort(key=lambda x: x["LastModified"], reverse=True)

            return files[:5]  # Return last 5 files

        except Exception as e:
            return []

    def get_processed_data_status(self):
        """Check processed data folder"""
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name, Prefix="processed/", MaxKeys=10
            )

            objects = response.get("Contents", [])
            files = [obj for obj in objects if not obj["Key"].endswith("/")]
            files.sort(key=lambda x: x["LastModified"], reverse=True)

            total_size = sum(obj["Size"] for obj in files)

            return {
                "file_count": len(files),
                "total_size": total_size,
                "latest_file": files[0] if files else None,
            }

        except Exception as e:
            return {"file_count": 0, "total_size": 0, "latest_file": None}

    def format_timestamp(self, timestamp):
        """Format timestamp for display"""
        if timestamp is None:
            return "Never"

        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            except:
                return timestamp

        if isinstance(timestamp, datetime):
            now = datetime.now(timestamp.tzinfo) if timestamp.tzinfo else datetime.now()
            diff = now - timestamp

            if diff.total_seconds() < 60:
                return "Just now"
            elif diff.total_seconds() < 3600:
                minutes = int(diff.total_seconds() / 60)
                return f"{minutes}m ago"
            else:
                return timestamp.strftime("%H:%M:%S")

        return str(timestamp)

    def format_size(self, size_bytes):
        """Format file size for display"""
        if size_bytes == 0:
            return "0 B"

        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"

    def display_status(self):
        """Display real-time status dashboard"""
        # Get all status information
        lambda_status = self.get_lambda_status()
        crawler_status = self.get_crawler_status()
        etl_status = self.get_etl_job_status()
        s3_uploads = self.get_s3_recent_uploads()
        processed_status = self.get_processed_data_status()

        # Clear screen and display header
        self.clear_screen()
        print("SERVERLESS DATA PIPELINE MONITOR")
        print("=" * 60)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()

        # Lambda Function Status
        print("LAMBDA FUNCTION STATUS")
        print("-" * 30)

        if lambda_status["status"] == "ERROR":
            print(f"Status: ERROR - {lambda_status['error']}")
        else:
            print(f"Status: {lambda_status['status']}")
            print(f"Recent Invocations (5m): {lambda_status['recent_invocations']}")
            print(
                f"Last Invocation: {self.format_timestamp(lambda_status['last_invocation'])}"
            )
            print(
                f"Memory/Timeout: {lambda_status.get('memory_size', 'N/A')}MB / {lambda_status.get('timeout', 'N/A')}s"
            )
        print()

        # Crawler Status
        print("GLUE CRAWLER STATUS")

        if crawler_status["status"] == "ERROR":
            print(f"Status: ERROR - {crawler_status['error']}")
        else:
            print(f"Status: {crawler_status['status']}")

            last_crawl = crawler_status.get("last_crawl", {})
            if last_crawl:
                crawl_status = last_crawl.get("Status", "Unknown")
                crawl_time = last_crawl.get("StartTime")
                print(
                    f"Last Crawl: {crawl_status} at {self.format_timestamp(crawl_time)}"
                )
            else:
                print("Last Crawl: Never")
        print()

        # ETL Job Status
        print("GLUE ETL JOB STATUS")

        if etl_status["status"] == "ERROR":
            print(f"Status: ERROR - {etl_status['error']}")
        elif etl_status["status"] == "NO_RUNS":
            print("Status: No job runs found")
        else:
            print(f"Status: {etl_status['status']}")
            print(f"Started: {self.format_timestamp(etl_status.get('started_on'))}")

            if etl_status.get("completed_on"):
                print(f"Completed: {self.format_timestamp(etl_status['completed_on'])}")

            if etl_status.get("execution_time"):
                print(f"Duration: {etl_status['execution_time']}s")

            if etl_status.get("error_message"):
                print(f"Error: {etl_status['error_message'][:50]}...")
        print()

        # S3 Data Status
        print("S3 DATA STATUS")

        print("Recent Uploads to raw/:")
        if s3_uploads:
            for i, obj in enumerate(s3_uploads[:3]):
                filename = obj["Key"].split("/")[-1]
                size = self.format_size(obj["Size"])
                timestamp = self.format_timestamp(obj["LastModified"])
                print(f"  {i+1}. {filename} ({size}) - {timestamp}")
        else:
            print("  No recent uploads")

        print(f"\nProcessed Data:")
        print(f"  Files: {processed_status['file_count']}")
        print(f"  Total Size: {self.format_size(processed_status['total_size'])}")

        if processed_status["latest_file"]:
            latest = processed_status["latest_file"]
            filename = (
                latest["Key"].split("/")[-1][:30] + "..."
                if len(latest["Key"].split("/")[-1]) > 30
                else latest["Key"].split("/")[-1]
            )
            print(
                f"  Latest: {filename} - {self.format_timestamp(latest['LastModified'])}"
            )

        print()

        # Footer
        print("Press Ctrl+C to exit | Refreshing every 10 seconds")

    def run_monitor(self, refresh_interval=10):
        """Run the monitoring loop"""
        try:
            while True:
                self.display_status()
                time.sleep(refresh_interval)

        except KeyboardInterrupt:
            print("\nMonitor stopped by user")
            print("Thanks for using Pipeline Monitor!")
        except Exception as e:
            print(f"\nError: {str(e)}")


def main():
    """Main function"""
    monitor = PipelineMonitor()

    # Parse command line arguments
    refresh_interval = 10
    if len(sys.argv) > 1:
        try:
            refresh_interval = int(sys.argv[1])
        except ValueError:
            print("Invalid refresh interval. Using default 10 seconds.")

    print(f"Starting monitor with {refresh_interval}s refresh interval...")
    time.sleep(2)

    monitor.run_monitor(refresh_interval)


if __name__ == "__main__":
    main()
