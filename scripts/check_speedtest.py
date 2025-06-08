import requests
import xml.etree.ElementTree as ET
import re
import os
import socket

BENCH_FILE = "bench.sh"
SERVER_LIST_URL = "https://www.speedtest.net/speedtest-servers-static.php"

def is_host_alive(host):
    try:
        socket.gethostbyname(host)
        return True
    except:
        return False

def fetch_speedtest_servers():
    response = requests.get(SERVER_LIST_URL)
    response.raise_for_status()
    servers = []
    root = ET.fromstring(response.text)
    for server in root.iter('server'):
        servers.append({
            'id': server.attrib['id'],
            'host': server.attrib['host'],
            'name': server.attrib['name'],
            'country': server.attrib['country'],
            'sponsor': server.attrib['sponsor'],
        })
    return servers

def extract_speed_entries(text):
    return re.findall(r"speed_test\s+'(\d*)'\s+'(.+?)'", text)

def find_replacement(servers, location_name):
    city = location_name.split(',')[0].strip()
    for server in servers:
        full_location = f"{server['name']}, {server['country']}"
        if city.lower() in server['name'].lower() and is_host_alive(server['host']):
            return server['id'], full_location
    return None, None

def main():
    with open(BENCH_FILE, 'r') as f:
        bench_content = f.read()

    servers = fetch_speedtest_servers()
    entries = extract_speed_entries(bench_content)

    updated_lines = []
    for old_id, location in entries:
        if not old_id:  # Skip default entry
            updated_lines.append(f"    speed_test '' '{location}'")
            continue
        matched = next((s for s in servers if s['id'] == old_id), None)
        if matched and is_host_alive(matched['host']):
            updated_lines.append(f"    speed_test '{old_id}' '{location}'")
        else:
            print(f"ID {old_id} ({location}) seems down. Finding replacement...")
            new_id, new_loc = find_replacement(servers, location)
            if new_id:
                updated_lines.append(f"    speed_test '{new_id}' '{new_loc}'  # replaced")
            else:
                updated_lines.append(f"    # speed_test '{old_id}' '{location}'  # no replacement found")

    # Replace speed() function in bench.sh
    new_speed_block = "speed() {\n" + "\n".join(updated_lines) + "\n}"
    new_content = re.sub(r"speed\(\) \{.*?\}", new_speed_block, bench_content, flags=re.DOTALL)

    with open(BENCH_FILE, 'w') as f:
        f.write(new_content)

if __name__ == "__main__":
    main()
