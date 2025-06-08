import requests
import xml.etree.ElementTree as ET
import re

BENCH_FILE = "bench.sh"
SERVER_LIST_URL = "https://www.speedtest.net/speedtest-servers-static.php"

def is_host_alive(host):
    try:
        base_host = host.split(":")[0]
        url = f"http://{base_host}/speedtest/upload.php"
        response = requests.head(url, timeout=5)
        return response.status_code < 500
    except:
        return False

def fetch_speedtest_servers():
    print("Fetching server list...")
    response = requests.get(SERVER_LIST_URL)
    response.raise_for_status()
    servers = []
    root = ET.fromstring(response.content)
    for server in root.iter('server'):
        servers.append({
            'id': server.attrib['id'],
            'host': server.attrib['host'],
            'name': server.attrib['name'],
            'country': server.attrib['country'],
            'sponsor': server.attrib['sponsor'],
        })
    return servers

def extract_speed_entries(content):
    return re.findall(r"speed_test\s+'(\d*)'\s+'(.+?)'", content)

def find_server_by_id(servers, id_):
    return next((s for s in servers if s['id'] == id_), None)

def find_replacement(servers, original_location):
    city = original_location.split(',')[0].strip().lower()
    for s in servers:
        if city in s['name'].lower() and is_host_alive(s['host']):
            return s
    return None

def build_speed_block(entries, servers):
    updated_lines = []
    for id_, location in entries:
        if not id_:
            updated_lines.append(f"    speed_test '' '{location}'")
            continue

        server = find_server_by_id(servers, id_)
        if server and is_host_alive(server['host']):
            updated_lines.append(f"    speed_test '{id_}' '{location}'")
        else:
            print(f"ID {id_} ({location}) seems down. Finding replacement...")
            replacement = find_replacement(servers, location)
            if replacement:
                new_loc = f"{replacement['name']}, {replacement['country']}"
                updated_lines.append(f"    speed_test '{replacement['id']}' '{new_loc}'  # replaced")
            else:
                updated_lines.append(f"    # speed_test '{id_}' '{location}'  # no replacement found")
    return "speed() {\n" + "\n".join(updated_lines) + "\n}"

def main():
    with open(BENCH_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    servers = fetch_speedtest_servers()
    entries = extract_speed_entries(content)
    new_speed_func = build_speed_block(entries, servers)

    # Replace old speed() block
    updated_content = re.sub(r"speed\(\) \{.*?\}", new_speed_func, content, flags=re.DOTALL)

    with open(BENCH_FILE, 'w', encoding='utf-8') as f:
        f.write(updated_content)

    print("✅ bench.sh updated successfully.")

if __name__ == "__main__":
    main()
