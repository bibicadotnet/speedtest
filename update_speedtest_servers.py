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
            timeout=120
        )
        
        # Kiểm tra output có phải JSON hợp lệ
        try:
            data = json.loads(result.stdout)
            return 'ping' in data and isinstance(data['ping']['latency'], (int, float))
        except json.JSONDecodeError:
            print(f"Invalid JSON response for server {server_id}")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"Timeout checking server {server_id}")
        return False
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
            timeout=120
        )
        
        # Xử lý kết quả tìm kiếm
        try:
            servers = json.loads(result.stdout)['servers']
            
            # Tìm server phù hợp nhất
            for server in servers:
                server_country = server['location']['country'].lower()
                server_name = server['location']['name'].lower()
                
                if (country.lower() in server_country and 
                    search_term.lower() in server_name):
                    return server['id'], f"{server['location']['name']}, {server['location']['country']}"
            
            # Fallback: Tìm server cùng quốc gia
            for server in servers:
                if country.lower() in server['location']['country'].lower():
                    return server['id'], f"{server['location']['name']}, {server['location']['country']}"
                    
        except (json.JSONDecodeError, KeyError):
            print("Failed to parse server list")
            return None, None
            
    except subprocess.TimeoutExpired:
        print("Timeout searching for servers")
    except Exception as e:
        print(f"Error finding replacement: {str(e)}")
    
    return None, None

def update_bench_file(updates):
    with open('bench.sh', 'r') as f:
        content = f.read()
    
    for old, new in updates.items():
        content = content.replace(old, new)
    
    with open('bench.sh', 'w') as f:
        f.write(content)

def main():
    print(f"\n{'='*50}")
    print(f"Starting server check at {datetime.now().isoformat()}")
    print(f"{'='*50}\n")
    
    current_servers = get_current_servers()
    updates = {}
    
    for server_id, location in current_servers:
        print(f"\n[Checking] Server {server_id} ({location})")
        
        if not server_id:  # Skip empty ID
            print("Skipping empty server ID")
            continue
            
        if is_server_active(server_id):
            print("✓ Server is active")
            continue
            
        print("✗ Server inactive. Finding replacement...")
        new_id, new_location = find_replacement_server(location)
        
        if new_id:
            old_str = f"speed_test '{server_id}' '{location}'"
            new_str = f"speed_test '{new_id}' '{new_location}'"
            updates[old_str] = new_str
            print(f"✓ Replacement found: {new_str}")
        else:
            print("⚠ No suitable replacement found")
    
    if updates:
        update_bench_file(updates)
        print("\n" + "="*50)
        print(f"Successfully updated {len(updates)} server IDs")
        print("="*50)
    else:
        print("\n" + "="*50)
        print("All servers are active - no updates needed")
        print("="*50)

if __name__ == "__main__":
    main()
