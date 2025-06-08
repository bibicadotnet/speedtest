import re
import json
import subprocess
from datetime import datetime

def get_current_servers():
    with open('bench.sh', 'r') as f:
        content = f.read()
    
    pattern = r"speed_test\s+'(\d*)'\s+'([^']*)'"
    return re.findall(pattern, content)

def is_server_active(server_id):
    if not server_id or not server_id.isdigit():
        return False
        
    try:
        result = subprocess.run(
            ['speedtest', '--server-id=' + server_id, '--accept-license', '--accept-gdpr', '--format=json'],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        data = json.loads(result.stdout)
        return 'ping' in data and data['ping']['latency'] > 0
        
    except Exception as e:
        print(f"Error checking server {server_id}: {str(e)}")
        return False

def find_replacement_server(location):
    try:
        search_term = location.split(',')[0].strip()
        country = location.split(',')[-1].strip()
        
        result = subprocess.run(
            ['speedtest', '--list', '--format=json'],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        servers = json.loads(result.stdout)['servers']
        
        # Tìm server phù hợp nhất
        for server in servers:
            server_country = server['location']['country'].lower()
            server_name = server['location']['name'].lower()
            
            if (country.lower() in server_country and 
                search_term.lower() in server_name):
                return server['id'], f"{server['location']['name']}, {server['location']['country']}"
        
        # Nếu không tìm thấy chính xác, tìm server cùng quốc gia
        for server in servers:
            if country.lower() in server['location']['country'].lower():
                return server['id'], f"{server['location']['name']}, {server['location']['country']}"
                
    except Exception as e:
        print(f"Error finding replacement: {str(e)}")
    
    return None, None

def update_bench_file(updated_servers):
    with open('bench.sh', 'r') as f:
        content = f.read()
    
    for old, new in updated_servers.items():
        content = content.replace(old, new)
    
    with open('bench.sh', 'w') as f:
        f.write(content)

def main():
    print(f"Running server check at {datetime.now().isoformat()}")
    current_servers = get_current_servers()
    updated_servers = {}
    
    for server_id, location in current_servers:
        print(f"\nChecking server {server_id} ({location})...")
        
        if not is_server_active(server_id):
            print("Server inactive. Finding replacement...")
            new_id, new_location = find_replacement_server(location)
            
            if new_id:
                old_str = f"speed_test '{server_id}' '{location}'"
                new_str = f"speed_test '{new_id}' '{new_location}'"
                updated_servers[old_str] = new_str
                print(f"Will replace: {old_str} => {new_str}")
            else:
                print("No suitable replacement found")
        else:
            print("Server active - no change needed")
    
    if updated_servers:
        update_bench_file(updated_servers)
        print("\nSuccessfully updated server IDs")
    else:
        print("\nNo server updates needed")

if __name__ == "__main__":
    main()
