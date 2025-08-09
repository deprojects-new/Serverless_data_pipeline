import json
import random
import uuid
from datetime import datetime

import boto3

# s3 bucket config

s3_bucket_name = "assignment5-data-lake"
s3_key = "raw/logs.json"
local_file = "large_logs.json"
region = "us-east-2"
target_size_bytes = 5 * 1024 * 1024
LOG_EVERY = 1000

# event generator


def generate_event():
    return {
        "event_id": str(uuid.uuid4()),
        "timestamp": datetime.now().isoformat(),
        "event_type": random.choice(
            ["user_login", "user_logout", "page_view", "purchase"]
        ),
        "user_id": f"U{random.randint(10000, 99999)}",
        "app_version": f"{random.randint(1, 3)}.{random.randint(0, 9)}.{random.randint(0, 9)}",
        "location": random.choice(
            ["Seattle, WA", "New York, NY", "Los Angeles, CA", "Chicago, IL"]
        ),
        "device": random.choice(["iPhone 14", "Samsung Galaxy", "iPad", "Android"]),
        "session_id": f"S{random.randint(100000, 999999)}",
        "ip_address": f"{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}",
    }


# json streams


def generate_json_file(filepath, target_size_bytes):
    print(f"Generating JSON file to reach ~{target_size_bytes / 1e9:.1f} GB")
    count = 0
    size = 0

    with open(filepath, "w") as f:
        f.write("[\n")
        while size < target_size_bytes:
            event = generate_event()
            json_str = json.dumps(event)
            if count > 0:
                f.write(",\n")
                size += 2  # for comma and newline
            f.write(json_str)
            size += len(json_str.encode("utf-8"))
            count += 1

            if count % LOG_EVERY == 0:
                print(f" {count:,} records written, {size / 1e6:.2f} B so far.")

        f.write("\n]")

    print(f"Completed. {count:,} records, {size / 1e9:.2f} B written to: {filepath}")
    return filepath


# upload to s3


def upload_to_s3(file_path, bucket, key, region):
    print(f" Uploading to s3://{bucket}/{key} ...")
    s3 = boto3.client("s3", region_name=region)
    s3.upload_file(file_path, bucket, key)
    print(f" Upload complete ")


if __name__ == "__main__":
    json_path = generate_json_file(local_file, target_size_bytes)
    upload_to_s3(json_path, s3_bucket_name, s3_key, region)
