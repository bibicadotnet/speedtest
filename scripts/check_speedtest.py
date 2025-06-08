import re
import requests

BENCH_FILE = "bench.sh"
API_URL = "https://www.speedtest.net/api/js/servers"

# Danh sách các sponsor uy tín theo từng quốc gia
BIG_SPONSORS_BY_COUNTRY = {
    "US": {
        "Comcast", "AT&T", "Verizon", "Frontier", "Spectrum"
    },
    "FR": {
        "ORANGE FRANCE", "Scaleway", "Sewan"
    },
    "DE": {
        "Deutsche Telekom", "Vodafone", "1&1", "Internetnord GmbH", "DNS:NET Internet Service GmbH", "Cronon GmbH"
    },
    "HK": {
        "HKBN", "PCCW", "CMI", "Hong Kong Broadband Network", "Netvigator"
    },
    "SG": {
        "Singtel", "StarHub", "M1", "MyRepublic", "ViewQwest"
    },
    "JP": {
        "Verizon", "Contabo", "SoftBank", "Rakuten", "IPA CyberLab 400G", "So-net"
    },
    "VN": {
        "FPT Telecom", "VNPT-NET", "Viettel Network"
    }
}

def fetch_first_id(provider, country_code):
    try:
        response = requests.get(API_URL, params={
            "engine": "js",
            "https_functional": "true",
            "limit": 1000,
            "search": provider
        }, timeout=10)
        response.raise_for_status()
        servers = response.json()

        if not servers:
            return None

        sponsors_to_check = BIG_SPONSORS_BY_COUNTRY.get(country_code, set())

        # Ưu tiên tìm server có sponsor uy tín
        for server in servers:
            sponsor = server.get("sponsor", "").strip()
            if sponsor in sponsors_to_check:
                print(f"  → Found sponsor '{sponsor}' in BIG_SPONSORS, using ID {server.get('id')}")
                return str(server.get("id"))

        # Nếu không tìm thấy, trả về ID server đầu tiên
        print(f"  → No BIG_SPONSORS found, using first server ID {servers[0].get('id')}")
        return str(servers[0].get("id"))
    except Exception as e:
        print(f"[ERROR] Cannot fetch ID for '{provider}': {e}")
    return None

def update_ids(content):
    pattern = r"speed_test\s+'(\d*)'\s+'(.+?),\s*([A-Z]{2})'"

    def replacer(match):
        old_id, provider, country = match.groups()
        provider_clean = provider.strip()

        print(f"Fetching ID for {provider_clean}, {country}...")
        new_id = fetch_first_id(provider_clean, country)

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
