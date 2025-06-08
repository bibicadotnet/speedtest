import re
import requests

BENCH_FILE = "bench.sh"
API_BASE = "https://www.speedtest.net/api/js/servers"
TIMEOUT = 10

def fetch_first_id(provider):
    try:
        resp = requests.get(API_BASE, params={
            "engine": "js",
            "https_functional": "true",
            "limit": "1000",
            "search": provider
        }, timeout=TIMEOUT)
        servers = resp.json()
        if servers:
            return servers[0]["id"]
    except:
        pass
    return None

with open(BENCH_FILE, "r", encoding="utf-8") as f:
    content = f.read()

def replace_ids(text):
    def repl(match):
        old_id, provider, country = match.groups()
        new_id = fetch_first_id(provider)
        if new_id and new_id != old_id:
            print(f"[Update] {provider}, {country}: {old_id} → {new_id}")
            return f"speed_test '{new_id}' '{provider}, {country}'"
        else:
            return match.group(0)

    return re.sub(
        r"speed_test\s+'(\d*)'\s+'([^,]+),\s*([A-Z]{2})'", 
        repl, 
        text
    )

new_content = replace_ids(content)

with open(BENCH_FILE, "w", encoding="utf-8") as f:
    f.write(new_content)

print("bench.sh updated.")
