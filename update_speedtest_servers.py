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
        
        # Kiểm tra qua cả 2 API endpoint
        url1 = f"https://www.speedtest.net/api/js/servers?engine=js&search={server_id}&limit=1"
        url2 = f"https://www.speedtest.net/speedtest-servers-static.php?ids={server_id}"
        
        # Thử endpoint đầu tiên
        response = requests.get(url1, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data and str(data[0]['id']) == server_id:
                return True
        
        # Thử endpoint thứ 2 nếu endpoint đầu không thành công
        response = requests.get(url2, headers=headers, timeout=10)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'xml')
            if soup.find('server', {'id': server_id}):
                return True
                
        return False
    except Exception as e:
        print(f"Error checking server {server_id}: {str(e)}")
        return False  # Coi như không hoạt động nếu có lỗi

# Hàm tìm server thay thế (phiên bản cải tiến)
def find_replacement_server(server_id, location):
    try:
        search_term = location.split(',')[0].strip()
        country = location.split(',')[-1].strip()
        
        # Thêm header
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://www.speedtest.net/'
        }
        
        # Xử lý đặc biệt cho VN
        vn_providers = {
            'FPT': ['FPT', 'fpt'],
            'VNPT': ['VNPT', 'vnpt'],
            'Viettel': ['Viettel', 'viettel']
        }
        
        if country == 'VN':
            for provider, keywords in vn_providers.items():
                if provider in location:
                    for keyword in keywords:
                        url = f"https://www.speedtest.net/api/js/servers?engine=js&search={keyword}&limit=50"
                        response = requests.get(url, headers=headers, timeout=15)
                        servers = response.json()
                        
                        for server in servers:
                            if (country.lower() in server['country'].lower() and 
                                any(kw.lower() in server['sponsor'].lower() for kw in keywords)):
                                return str(server['id']), f"{server['sponsor']}, {server['country']}"
        
        # Tìm kiếm thông thường cho các quốc gia khác
        url = f"https://www.speedtest.net/api/js/servers?engine=js&search={search_term}&limit=50"
        response = requests.get(url, headers=headers, timeout=15)
        servers = response.json()
        
        # Ưu tiên server cùng thành phố và quốc gia
        for server in servers:
            if (country.lower() in server['country'].lower() and 
                search_term.lower() in server['name'].lower()):
                return str(server['id']), f"{server['name']}, {server['country']}"
        
        # Ưu tiên server cùng quốc gia
        for server in servers:
            if country.lower() in server['country'].lower():
                return str(server['id']), f"{server['name']}, {server['country']}"
        
        # Trả về server có ping tốt nhất nếu không tìm thấy
        if servers:
            servers.sort(key=lambda x: x.get('latency', 999))
            return str(servers[0]['id']), f"{servers[0]['name']}, {servers[0]['country']}"
            
    except Exception as e:
        print(f"Error finding replacement for {location}: {str(e)}")
    
    return None, None

# Kiểm tra và cập nhật từng server
updated = False
for server_id, location in current_servers:
    print(f"\nChecking server {server_id} ({location})...")
    if not server_id:  # Bỏ qua trường hợp empty ID
        continue
        
    active = is_server_active(server_id)
    print(f"Server status: {'Active' if active else 'Inactive'}")
    
    if not active:
        print(f"Finding replacement for {location}...")
        new_id, new_location = find_replacement_server(server_id, location)
        
        if new_id:
            old_str = f"speed_test '{server_id}' '{location}'"
            new_str = f"speed_test '{new_id}' '{new_location}'"
            content = content.replace(old_str, new_str)
            print(f"Replaced: {old_str} => {new_str}")
            updated = True
        else:
            print(f"Warning: No replacement found for {location}")

# Ghi lại file nếu có thay đổi
if updated:
    with open('bench.sh', 'w') as f:
        f.write(content)
    print("\nbench.sh has been updated with new server IDs")
else:
    print("\nAll servers are active, no updates needed")
