import re
import requests
from bs4 import BeautifulSoup
import json
import os

# Đọc file bench.sh
with open('bench.sh', 'r') as f:
    content = f.read()

# Tìm và trích xuất các server hiện tại
pattern = r"speed_test\s+'(\d*)'\s+'([^']*)'"
current_servers = re.findall(pattern, content)

# Hàm kiểm tra server có hoạt động không
def is_server_active(server_id):
    try:
        url = f"https://www.speedtest.net/api/js/servers?engine=js&search={server_id}&limit=1"
        response = requests.get(url, timeout=10)
        data = response.json()
        return len(data) > 0 and str(data[0]['id']) == server_id
    except:
        return False

# Hàm tìm server thay thế cùng location
def find_replacement_server(location):
    try:
        # Lấy danh sách server từ speedtest.net
        search_term = location.split(',')[0].strip()
        url = f"https://www.speedtest.net/api/js/servers?engine=js&search={search_term}&limit=10"
        response = requests.get(url, timeout=10)
        servers = response.json()
        
        # Ưu tiên server cùng country
        country = location.split(',')[-1].strip()
        for server in servers:
            if country.lower() in server['country'].lower():
                return str(server['id']), f"{server['name']}, {server['country']}"
        
        # Nếu không có thì lấy server đầu tiên
        if servers:
            return str(servers[0]['id']), f"{servers[0]['name']}, {servers[0]['country']}"
    except:
        pass
    
    return None, None

# Kiểm tra và cập nhật từng server
updated = False
for server_id, location in current_servers:
    if server_id and not is_server_active(server_id):
        print(f"Server {server_id} ({location}) is inactive. Finding replacement...")
        new_id, new_location = find_replacement_server(location)
        
        if new_id:
            # Cập nhật content
            old_str = f"speed_test '{server_id}' '{location}'"
            new_str = f"speed_test '{new_id}' '{new_location}'"
            content = content.replace(old_str, new_str)
            print(f"Replaced {server_id} ({location}) with {new_id} ({new_location})")
            updated = True
        else:
            print(f"Could not find replacement for {location}")

# Ghi lại file nếu có thay đổi
if updated:
    with open('bench.sh', 'w') as f:
        f.write(content)
    print("bench.sh has been updated with new server IDs")
else:
    print("No server updates needed")
