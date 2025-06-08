import re
import requests
from bs4 import BeautifulSoup
import json
import os
import time

# Đọc file bench.sh
with open('bench.sh', 'r') as f:
    content = f.read()

# Tìm và trích xuất các server hiện tại
pattern = r"speed_test\s+'(\d*)'\s+'([^']*)'"
current_servers = re.findall(pattern, content)

# Hàm kiểm tra server có hoạt động không (phiên bản cải tiến)
def is_server_active(server_id):
    if not server_id:  # Bỏ qua trường hợp empty ID
        return True
        
    try:
        # Thêm header để tránh bị chặn
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.speedtest.net/'
        }
        
        # Kiểm tra qua API endpoint chính
        url = f"https://www.speedtest.net/api/js/servers?engine=js&ids={server_id}"
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                return True
        
        # Kiểm tra thêm qua API ping
        ping_url = f"https://www.speedtest.net/api/js/ping?serverId={server_id}"
        ping_response = requests.get(ping_url, headers=headers, timeout=10)
        
        if ping_response.status_code == 200:
            ping_data = ping_response.json()
            if ping_data.get('ping') is not None:
                return True
                
        return False
        
    except Exception as e:
        print(f"Error checking server {server_id}: {str(e)}")
        return False  # Coi như không hoạt động nếu có lỗi

# Hàm tìm server thay thế (phiên bản cải tiến)
def find_replacement_server(location):
    try:
        search_term = location.split(',')[0].strip()
        country = location.split(',')[-1].strip()
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.speedtest.net/'
        }
        
        # Tìm kiếm server
        url = f"https://www.speedtest.net/api/js/servers?engine=js&search={search_term}&limit=50"
        response = requests.get(url, headers=headers, timeout=15)
        
        if response.status_code != 200:
            return None, None
            
        servers = response.json()
        if not servers:
            return None, None
        
        # Ưu tiên server cùng thành phố và quốc gia
        best_match = None
        partial_match = None
        
        for server in servers:
            server_country = server.get('country', '').strip()
            server_name = server.get('name', '').strip()
            
            if country.lower() == server_country.lower():
                if search_term.lower() in server_name.lower():
                    best_match = server
                    break
                elif not partial_match:
                    partial_match = server
        
        selected = best_match or partial_match or servers[0]
        return str(selected['id']), f"{selected['name']}, {selected['country']}"
            
    except Exception as e:
        print(f"Error finding replacement for {location}: {str(e)}")
        return None, None

# Kiểm tra và cập nhật từng server
updated = False
for server_id, location in current_servers:
    print(f"\nChecking server {server_id} ({location})...")
    
    if not server_id:  # Bỏ qua trường hợp empty ID
        print("Skipping empty server ID")
        continue
        
    active = is_server_active(server_id)
    print(f"Server status: {'Active' if active else 'Inactive'}")
    
    if not active:
        print(f"Finding replacement for {location}...")
        new_id, new_location = find_replacement_server(location)
        
        if new_id and new_location:
            old_str = f"speed_test '{server_id}' '{location}'"
            new_str = f"speed_test '{new_id}' '{new_location}'"
            
            if old_str in content:
                content = content.replace(old_str, new_str)
                print(f"Replaced: {old_str} => {new_str}")
                updated = True
            else:
                print("Original string not found in content")
        else:
            print("No suitable replacement found")

# Ghi lại file nếu có thay đổi
if updated:
    with open('bench.sh', 'w') as f:
        f.write(content)
    print("\nbench.sh has been updated with new server IDs")
else:
    print("\nAll servers are active, no updates needed")
