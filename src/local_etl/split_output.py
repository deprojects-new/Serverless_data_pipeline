import pandas as pd
from pathlib import Path

# Step 1: Read the full Parquet file created in Step 4
df = pd.read_parquet("processed_logs.parquet")

# Step 2: Create output folder (like S3 destination)
output_dir = Path("parquet_output")
output_dir.mkdir(exist_ok=True)

# Step 3: Split into chunks (100,000 rows per file)
chunk_size = 100_000
for i in range(0, len(df), chunk_size):
    chunk = df.iloc[i:i + chunk_size]
    chunk_path = output_dir / f"logs_part_{i // chunk_size}.parquet"
    chunk.to_parquet(chunk_path, engine='pyarrow', compression='snappy')

print("✅ Split into multipart Parquet files in ./parquet_output/")
