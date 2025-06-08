import re
import requests

BENCH_FILE = "bench.sh"
API_URL = "https://www.speedtest.net/api/js/servers"

def fetch_first_id(provider):
    try:
        r = requests.get(API_URL, params={
            "engine": "js",
            "https_functional": "true",
            "limit": 1000,
            "search": provider
        }, timeout=10)
        servers = r.json()
        if servers and 'id' in servers[0]:
            return servers[0]['id']
    except Exception as e:
        print(f"Error fetching for {provider}: {e}")
    return None

with open(BENCH_FILE, "r", encoding="utf-8") as f:
    content = f.read()

def update_ids(text):
    def replacer(match):
        old_id, provider, country = match.groups()
        search_name = provider.strip()
        new_id = fetch_first_id(search_name)
        if new_id and new_id != old_id:
            print(f"[Updated] {search_name}, {country}: {old_id} → {new_id}")
            return f"speed_test '{new_id}' '{provider}, {country}'"
        else:
            print(f"[No Change] {search_name}, {country} (kept {old_id})")
            return match.group(0)
    return re.sub(
        r"speed_test\s+'(\d*)'\s+'([^,]+),\s*([A-Z]{2})'",
        replacer,
        text
    )

new_content = update_ids(content)

with open(BENCH_FILE, "w", encoding="utf-8") as f:
    f.write(new_content)

print("bench.sh updated successfully.")
