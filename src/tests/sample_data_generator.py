import json
import os
import random
import uuid
from datetime import datetime, timedelta

import boto3

# This generator writes data to  bronze structure

# Configuration for different modes
DATA_GENERATION_CONFIG = {
    "testing": {
        "target_size_mb": 100,
        "duration_hours": 6,  # 6 hours of data
        "requests_per_minute_peak": 50,  # Reduced for testing
        "description": "Small dataset for testing pipeline",
    },
    "production_simulation": {
        "target_size_mb": 8320,  # 8GB for production
        "duration_hours": 120,  # 3 days of realistic data
        "requests_per_minute_peak": 2000,  # High traffic site to reach 5GB
        "description": "Realistic production-grade dataset",
    },
}

# Default configuration
GENERATION_MODE_1 = "production_simulation"
GENERATION_MODE_2 = "testing"

s3_bucket_name = "assignment5-data-lake"
local_file = "web_logs.json"
region = "us-east-2"
LOG_EVERY = 1000


# Realistic web log generator for medium e-commerce site
def generate_event(event_dt, session_context=None):
    event_ts = event_dt.isoformat()

    # 5% chance of messy/invalid data - to have realistic etl function
    is_messy = random.random() < 0.05

    if is_messy:
        # Invalid data that real systems encounter
        method = random.choice(["GET", "POST", "PUT", "DELETE", "INVALID", "OPTIONS"])
        status = random.choice([200, 404, 500, 503, 999, 0])
        response_time_ms = random.choice([0, -1, 999999])
        bytes_sent = random.choice([0, -1, 999999999])
        client_ip = random.choice(["0.0.0.0", "127.0.0.1", "invalid_ip", None])
        path = random.choice(["/", "//", None, ""])
        user_id = random.choice([None, "", "SYSTEM", "BOT"])
        cache_status = "INVALID"
        cdn_edge = "UNKNOWN"
        db_query_time_ms = -1
    else:
        # Realistic HTTP method distribution
        method = random.choices(
            ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
            weights=[75, 15, 5, 2, 2, 1],
            k=1,
        )[0]

        # Realistic status code distribution for medium e-commerce site
        status = random.choices(
            [200, 304, 404, 301, 302, 500, 503, 403, 401],
            weights=[70, 12, 10, 3, 2, 1.5, 0.8, 0.5, 0.2],
            k=1,
        )[0]

        # Generate realistic paths for e-commerce site
        path = generate_realistic_path()

        # Performance monitoring: Response time based on path type and status
        response_time_ms = generate_realistic_response_time(path, status)

        # Realistic file sizes based on content type
        bytes_sent = generate_realistic_bytes_sent(path, status)

        # Valid public IP addresses
        client_ip = generate_valid_public_ip()

        # User ID: 30% logged in users, 70% anonymous
        user_id = (
            f"user_{random.randint(100000, 999999)}" if random.random() < 0.3 else None
        )

        # Performance monitoring fields
        cache_status = random.choices(
            ["HIT", "MISS", "BYPASS", "EXPIRED"], weights=[60, 25, 10, 5], k=1
        )[0]

        cdn_edge = random.choice(
            [
                "edge-us-east-1",
                "edge-us-west-2",
                "edge-eu-west-1",
                "edge-ap-southeast-1",
                "origin",
            ]
        )

        # Database query time (only for dynamic content)
        if path.startswith(("/api/", "/search", "/cart", "/checkout")):
            db_query_time_ms = int(random.gauss(50, 20))
        else:
            db_query_time_ms = 0

    # Realistic referrer patterns
    referrer = generate_realistic_referrer()

    # Realistic user agents
    user_agent = generate_realistic_user_agent()

    # Session tracking
    session_id = (
        session_context["session_id"]
        if session_context
        else f"sess_{int(event_dt.timestamp())}_{random.randint(1000, 9999)}"
    )

    # Add some padding to increase record size for 5GB target
    log_message = f"Processing {method} request to {path} - status {status} - {response_time_ms}ms response time"
    additional_metadata = {
        "log_level": random.choice(["INFO", "WARN", "ERROR", "DEBUG"]),
        "log_message": log_message,
        "server_name": random.choice(
            ["web-01", "web-02", "web-03", "api-01", "api-02"]
        ),
        "datacenter": random.choice(["us-east-1a", "us-east-1b", "us-west-2a"]),
        "request_headers": json.dumps(
            {
                "Accept": "text/html,application/json",
                "Accept-Encoding": "gzip, deflate",
                "Connection": "keep-alive",
                "Host": "example.com",
            }
        ),
        "response_headers": json.dumps(
            {
                "Content-Type": (
                    "application/json"
                    if path and path.startswith("/api/")
                    else "text/html"
                ),
                "Cache-Control": (
                    "max-age=3600" if cache_status == "HIT" else "no-cache"
                ),
                "Server": "nginx/1.20.1",
            }
        ),
    }

    return {
        "event_id": str(uuid.uuid4()),
        "event_ts": event_ts,
        "session_id": session_id,
        "client_ip": client_ip,
        "method": method,
        "path": path,
        "status": status,
        "bytes_sent": bytes_sent,
        "response_time_ms": response_time_ms,
        "referrer": referrer,
        "user_agent": user_agent,
        "user_id": user_id,
        # Performance monitoring fields for dashboards
        "cache_status": cache_status,
        "cdn_edge": cdn_edge,
        "db_query_time_ms": db_query_time_ms,
        "request_id": f"req_{random.randint(1000000, 9999999)}",
        # INtrodcuing additional fields to increase record size
        **additional_metadata,
    }


def generate_realistic_path():
    # Generates a realistic e-commerce site paths
    path_patterns = {
        "homepage": {"paths": ["/"], "weight": 15},
        "category": {
            "paths": [
                "/category/electronics",
                "/category/books",
                "/category/clothing",
                "/category/home",
                "/category/sports",
            ],
            "weight": 12,
        },
        "product": {
            "paths": [f"/product/{random.randint(10000, 99999)}" for _ in range(50)],
            "weight": 25,
        },
        "search": {
            "paths": [
                "/search?q=laptop",
                "/search?q=phone",
                "/search?q=books",
                "/search?q=clothes",
                "/search",
            ],
            "weight": 8,
        },
        "user_account": {
            "paths": ["/account", "/profile", "/orders", "/wishlist", "/settings"],
            "weight": 6,
        },
        "cart_checkout": {
            "paths": ["/cart", "/checkout", "/payment", "/confirmation"],
            "weight": 4,
        },
        "api_endpoints": {
            "paths": [
                "/api/products",
                "/api/cart",
                "/api/user",
                "/api/search",
                "/api/recommendations",
            ],
            "weight": 8,
        },
        "static_assets": {
            "paths": [
                "/css/main.css",
                "/js/app.js",
                "/js/analytics.js",
                "/images/logo.png",
                "/images/product-thumb.jpg",
            ],
            "weight": 20,
        },
        "admin_cms": {
            "paths": ["/admin", "/admin/products", "/admin/orders", "/cms"],
            "weight": 2,
        },
    }

    # Weighted random selection
    pattern_names = list(path_patterns.keys())
    weights = [path_patterns[name]["weight"] for name in pattern_names]
    selected_pattern = random.choices(pattern_names, weights=weights, k=1)[0]
    selected_path = random.choice(path_patterns[selected_pattern]["paths"])

    # Safety check to ensure we never return None
    if selected_path is None:
        return "/"  # default - if something goes wrong
    return selected_path


def generate_realistic_response_time(path, status):
    base_times = {
        "static": (10, 100),  # CSS, JS, images
        "api": (50, 300),  # API endpoints
        "dynamic": (100, 800),  # Server-rendered pages
        "search": (200, 1200),  # Search queries
        "checkout": (150, 600),  # E-commerce flows
    }

    # Determining content type
    if any(ext in path for ext in [".css", ".js", ".png", ".jpg", ".gif"]):
        content_type = "static"
    elif path.startswith("/api/"):
        content_type = "api"
    elif path in ["/search"] or "search" in path:
        content_type = "search"
    elif path in ["/cart", "/checkout", "/payment"]:
        content_type = "checkout"
    else:
        content_type = "dynamic"

    min_time, max_time = base_times[content_type]

    # Adjusting for status codes
    if status >= 500:  # Server errors take longer
        min_time *= 3
        max_time *= 5
    elif status == 404:  # This is Not found and is usually fast
        max_time = min(max_time, 200)
    elif status == 304:  # Not modified is very fast
        min_time, max_time = 5, 50

    return random.randint(min_time, max_time)


def generate_realistic_bytes_sent(path, status):
    # Generates realistic response sizes
    if status >= 400:  # Error pages are small
        return random.randint(200, 2000)

    # Size based on content type
    if path.endswith((".jpg", ".png", ".gif")):
        return random.randint(5000, 200000)
    elif path.endswith(".js"):
        return random.randint(1000, 100000)
    elif path.endswith(".css"):
        return random.randint(500, 50000)
    elif path.startswith("/api/"):
        return random.randint(100, 10000)
    else:
        return random.randint(2000, 50000)


def generate_valid_public_ip():
    # Using some realistic public IP ranges
    ip_ranges = [
        (8, 8, 8),
        (1, 1, 1),
        (208, 67, 222),
        (74, 125, 224),
        (151, 101, 1),
    ]

    range_prefix = random.choice(ip_ranges)
    return f"{range_prefix[0]}.{range_prefix[1]}.{range_prefix[2]}.{random.randint(1, 254)}"


def generate_realistic_referrer():
    # Generate realistic referrer patterns
    referrers = [
        None,  # Direct traffic
        "-",  # No referrer
        "https://www.google.com/search?q=electronics",
        "https://www.google.com/search?q=laptop",
        "https://www.bing.com/search?q=books",
        "https://duckduckgo.com/",
        "https://facebook.com/",
        "https://twitter.com/",
        "https://reddit.com/r/technology",
        "https://amazon.com/",
        "internal",
    ]

    weights = [25, 5, 15, 10, 8, 3, 8, 5, 3, 3, 15]  # Direct traffic is most common
    return random.choices(referrers, weights=weights, k=1)[0]


def generate_realistic_user_agent():
    user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Googlebot/2.1 (+http://www.google.com/bot.html)",
        "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
    ]

    # Realistic browser distributions
    weights = [35, 20, 15, 12, 8, 7, 2, 1]
    return random.choices(user_agents, weights=weights, k=1)[0]


def generate_realistic_traffic_pattern(config):
    # Generate realistic hourly traffic distribution for medium e-commerce site

    # Realistic 24-hour traffic pattern generation
    hourly_multipliers = [
        0.15,
        0.08,
        0.05,
        0.03,
        0.05,
        0.12,
        0.25,
        0.45,
        0.65,
        0.80,
        0.90,
        0.95,
        1.00,
        0.95,
        0.90,
        0.85,
        0.80,
        0.75,
        0.70,
        0.60,
        0.50,
        0.40,
        0.30,
        0.20,
    ]

    peak_requests_per_minute = config["requests_per_minute_peak"]
    duration_hours = config["duration_hours"]

    events_schedule = []
    current_time = datetime.now() - timedelta(hours=duration_hours)

    for hour in range(duration_hours):
        hour_of_day = (current_time.hour + hour) % 24
        traffic_multiplier = hourly_multipliers[hour_of_day]

        # Adds some randomness
        traffic_multiplier *= random.uniform(0.8, 1.2)

        requests_this_hour = int(peak_requests_per_minute * 60 * traffic_multiplier)

        # Generates timestamps for this hour
        hour_start = current_time + timedelta(hours=hour)
        for _ in range(requests_this_hour):
            random_minute = random.randint(0, 59)
            random_second = random.randint(0, 59)
            event_time = hour_start.replace(
                minute=random_minute, second=random_second, microsecond=0
            )
            events_schedule.append(event_time)

    return sorted(events_schedule)


def write_json(filepath, config_mode="testing"):

    config = DATA_GENERATION_CONFIG[config_mode]
    target_size_bytes = config["target_size_mb"] * 1024 * 1024

    print(f"\n{config['description']}")
    print(f"Target size: {config['target_size_mb']} MB")
    print(f"Duration: {config['duration_hours']} hours")
    print(f"Peak traffic: {config['requests_per_minute_peak']} requests/minute")
    print(f"Generating realistic traffic pattern...")

    # Generates a realistic traffic schedule
    events_schedule = generate_realistic_traffic_pattern(config)

    print(f"Generated {len(events_schedule):,} events based on traffic pattern")
    print(f"Starting data generation to {filepath}...")

    count = 0
    size = 0
    current_session = None
    session_event_count = 0
    max_session_events = random.randint(3, 15)

    with open(filepath, "w", encoding="utf-8") as f:
        for event_dt in events_schedule:
            # Check if we've reached target size
            if size >= target_size_bytes:
                print(f"Reached target size of {target_size_bytes / 1e6:.1f} MB")
                break

            # Session management (like a realistic user sessions)
            if not current_session or session_event_count >= max_session_events:
                current_session = {
                    "session_id": f"sess_{int(event_dt.timestamp())}_{random.randint(1000, 9999)}",
                    "user_type": random.choices(
                        ["anonymous", "logged_in", "bot"], weights=[60, 35, 5], k=1
                    )[0],
                }
                session_event_count = 0
                max_session_events = random.randint(1, 20)  # New session length

            # Generates an event with session context
            record = generate_event(event_dt, current_session)

            # Convert to JSON
            json_str = json.dumps(
                record, separators=(",", ":"), ensure_ascii=False, default=str
            )
            f.write(json_str)
            f.write("\n")

            size += len(json_str.encode("utf-8")) + 1
            count += 1
            session_event_count += 1

            # Progress logging
            if count % LOG_EVERY == 0:
                print(
                    f"  {count:,} records written, {size / 1e6:.2f} MB so far ({size/target_size_bytes*100:.1f}%)"
                )

    actual_size_mb = size / 1e6
    print(f"\n Generation Complete")
    print(f"Records generated: {count:,}")
    print(f"File size: {actual_size_mb:.2f} MB")
    print(f"Average record size: {size/count:.0f} bytes")
    print(f"File written to: {filepath}")

    return filepath


def upload_to_s3(filepath, bucket, key, region):
    try:
        s3_client = boto3.client("s3", region_name=region)

        from datetime import datetime

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        flat_key = f"bronze/logs_{timestamp}.json"

        s3_client.upload_file(filepath, bucket, flat_key)
        print(f"Successfully uploaded to: s3://{bucket}/{flat_key}")
        return True

    except Exception as e:
        print(f"Upload failed: {e}")
        return False


if __name__ == "__main__":
    random.seed(42)

    # Configuration
    print("Realistic Web Log Data Generator")
    print(f"Available modes:")
    for mode, config in DATA_GENERATION_CONFIG.items():
        print(f"  {mode}: {config['description']} ({config['target_size_mb']} MB)")

    print(f"\nCurrent mode: {GENERATION_MODE_1}")
    print("To change mode, modify GENERATION_MODE variable at the top of the file")

    # Creates a timestamped filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    mode_suffix = "test" if GENERATION_MODE_2 == "testing" else "prod"
    local_file_timestamped = f"web_logs_{mode_suffix}_{timestamp}.json"

    # S3 key will be automatically partitioned
    # The key here is just a fallback if partitioning fails
    s3_key_fallback = f"bronze/logs_{mode_suffix}_{timestamp}.json"

    print(f"Output file: {local_file_timestamped}")
    print(f"S3 destination: Will be written to flat bronze structure")
    print(f"Fallback path: s3://{s3_bucket_name}/{s3_key_fallback}")

    try:
        # Generates a realistic JSON data
        json_path = write_json(local_file_timestamped, GENERATION_MODE_1)

        # Upload to S3 (flat structure for real-world scenario)
        print(f"\n S3 Upload ")
        success = upload_to_s3(json_path, s3_bucket_name, s3_key_fallback, region)

        if success:
            print(f"\nSuccess! Data generation and upload completed.")
            print(
                f"Generated realistic {GENERATION_MODE_1} dataset for medium e-commerce site"
            )
            print(
                f"Dataset includes: traffic patterns, performance metrics, user sessions"
            )
            print(f"Data written to bronze for real-world ETL processing")
        else:
            print(f"\nUpload failed. Local file available at: {json_path}")

    except Exception as e:
        print(f"\nError during generation: {str(e)}")
        import traceback

        traceback.print_exc()
