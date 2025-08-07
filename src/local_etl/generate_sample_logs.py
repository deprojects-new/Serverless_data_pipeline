import json
import random
from datetime import datetime, timedelta

levels = ['INFO', 'ERROR', 'DEBUG']
messages = ['User login', 'Page visit', 'File uploaded', 'Timeout occurred']
users = ['u123', 'u456', 'u789']

data = []
for i in range(500_000):  # ~50MB depending on size
    entry = {
        "timestamp": (datetime.utcnow() - timedelta(seconds=random.randint(0, 100000))).isoformat() + "Z",
        "level": random.choice(levels),
        "message": random.choice(messages),
        "user": {
            "id": random.choice(users),
            "ip": f"192.168.{random.randint(0,255)}.{random.randint(0,255)}"
        }
    }
    data.append(entry)

# Write line-delimited JSON
with open("sample_logs.json", "w") as f:
    for record in data:
        f.write(json.dumps(record) + "\n")

print("✅ Sample log data generated: sample_logs.json")
