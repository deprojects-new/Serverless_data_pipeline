import pandas as pd
import json

# Function to read line-delimited JSON
def read_json_lines(filepath):
    with open(filepath, 'r') as f:
        return [json.loads(line) for line in f]

# Step 1: Read raw logs
records = read_json_lines("sample_logs.json")
df = pd.DataFrame(records)

# Step 2: Flatten 'user' nested fields
df["user_id"] = df["user"].apply(lambda x: x.get("id"))
df["user_ip"] = df["user"].apply(lambda x: x.get("ip"))
df.drop(columns=["user"], inplace=True)

# Step 3: Filter only INFO and ERROR logs
df = df[df["level"].isin(["INFO", "ERROR"])]

# Step 4: Save to Parquet format
df.to_parquet("processed_logs.parquet", engine='pyarrow', compression='snappy')

print("✅ Processed logs saved to processed_logs.parquet")
