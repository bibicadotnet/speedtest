import re
import requests

BENCH_FILE = "bench.sh"
API_URL = "https://www.speedtest.net/api/js/servers"

def fetch_first_id(provider):
    try:
        response = requests.get(API_URL, params={
            "engine": "js",
            "https_functional": "true",
            "limit": 1000,
            "search": provider
        }, timeout=10)
        response.raise_for_status()
        servers = response.json()
        
        if servers and "id" in servers[0]:
            return str(servers[0]["id"])
    except Exception as e:
        print(f"[ERROR] Cannot fetch ID for '{provider}': {e}")
    return None

def update_ids(content):
    # pattern để tìm speed_test 'id' 'provider, CC'
    pattern = r"speed_test\s+'(\d*)'\s+'(.+?),\s*([A-Z]{2})'"

    def replacer(match):
        old_id, provider, country = match.groups()
        provider_clean = provider.strip()

        new_id = fetch_first_id(provider_clean)

        if new_id and new_id != old_id:
            print(f"[Updated] {provider_clean}, {country}: {old_id} → {new_id}")
            return f"speed_test '{new_id}' '{provider}, {country}'"
        else:
            print(f"[No Change] {provider_clean}, {country} (kept {old_id})")
            return match.group(0)

    return re.sub(pattern, replacer, content)

def main():
    try:
        with open(BENCH_FILE, "r", encoding="utf-8") as f:
            content = f.read()

        updated_content = update_ids(content)

        with open(BENCH_FILE, "w", encoding="utf-8") as f:
            f.write(updated_content)

        print("✅ bench.sh updated successfully.")
    except FileNotFoundError:
        print(f"[ERROR] {BENCH_FILE} not found.")
    except Exception as e:
        print(f"[ERROR] {e}")

if __name__ == "__main__":
    main()
