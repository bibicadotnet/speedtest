#!/bin/bash
#
# Script: Auto Update Speedtest Server IDs
# Author: GitHub Action
# Description: Automatically check and update speedtest server IDs in bench.sh
set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timeout cho mỗi test (giây)
TIMEOUT=5

# File script cần cập nhật
SCRIPT_FILE="paste.txt"
BACKUP_FILE="paste.txt.backup"

# Tạo backup
cp "$SCRIPT_FILE" "$BACKUP_FILE"

echo -e "${BLUE}🔍 Bắt đầu kiểm tra speedtest server IDs...${NC}"

# Danh sách server cần kiểm tra (ID, Location, Search Keywords)
declare -A SERVERS=(
    ["68864"]="San Jose, US|san jose|california|us"
    ["62493"]="Orange France, FR|orange|france|fr"
    ["28922"]="Amsterdam, NL|amsterdam|netherlands|nl"
    ["13538"]="Hong Kong, CN|hong kong|hk"
    ["7311"]="Singapore, SG|singapore|sg"
    ["50467"]="Tokyo, JP|tokyo|japan|jp"
    ["2515"]="FPT HCM, VN|ho chi minh|fpt|vietnam|vn"
    ["2552"]="FPT HN, VN|hanoi|fpt|vietnam|vn"
    ["17758"]="VNPT HCM, VN|ho chi minh|vnpt|vietnam|vn"
    ["17757"]="VNPT HN, VN|hanoi|vnpt|vietnam|vn"
    ["54812"]="Viettel HCM, VN|ho chi minh|viettel|vietnam|vn"
    ["59915"]="Viettel DN, VN|da nang|viettel|vietnam|vn"
)

# Hàm test server với timeout
test_server() {
    local server_id=$1
    local timeout_duration=$2
    
    echo -e "${YELLOW}Testing server ID: $server_id${NC}"
    
    # Sử dụng timeout command để giới hạn thời gian
    if timeout "$timeout_duration" speedtest -s "$server_id" --progress=no --accept-license --accept-gdpr > /dev/null 2>&1; then
        return 0  # Thành công
    else
        return 1  # Thất bại hoặc timeout
    fi
}

# Hàm tìm server thay thế
find_replacement_server() {
    local location_name=$1
    local search_keywords=$2
    
    echo -e "${YELLOW}🔍 Tìm kiếm server thay thế cho: $location_name${NC}"
    
    # Lấy danh sách server gần nhất
    local server_list
    server_list=$(timeout 10 speedtest -L 2>/dev/null | grep -i "$location_name" | head -10)
    
    if [ -z "$server_list" ]; then
        # Nếu không tìm thấy theo tên location, thử với keywords
        IFS='|' read -ra KEYWORDS <<< "$search_keywords"
        for keyword in "${KEYWORDS[@]}"; do
            server_list=$(timeout 10 speedtest -L 2>/dev/null | grep -i "$keyword" | head -5)
            [ -n "$server_list" ] && break
        done
    fi
    
    if [ -n "$server_list" ]; then
        # Lấy các server ID từ danh sách
        local candidate_ids
        candidate_ids=$(echo "$server_list" | grep -oE '[0-9]+\)' | sed 's/).*//' | head -5)
        
        # Test từng server candidate
        for candidate_id in $candidate_ids; do
            echo -e "${BLUE}Testing candidate: $candidate_id${NC}"
            if test_server "$candidate_id" 3; then
                echo -e "${GREEN}✅ Found working replacement: $candidate_id${NC}"
                echo "$candidate_id"
                return 0
            fi
        done
    fi
    
    echo -e "${RED}❌ No working replacement found for $location_name${NC}"
    return 1
}

# Hàm cập nhật server ID trong file
update_server_id() {
    local old_id=$1
    local new_id=$2
    local location=$3
    
    echo -e "${GREEN}🔄 Updating server ID: $old_id → $new_id for $location${NC}"
    
    # Sử dụng sed để thay thế ID trong file
    sed -i "s/speed_test '$old_id'/speed_test '$new_id'/g" "$SCRIPT_FILE"
    
    # Ghi log thay đổi
    echo "$(date): Updated server $location: $old_id → $new_id" >> speedtest_updates.log
}

# Main logic
failed_servers=()
updated_servers=()

echo -e "${BLUE}📊 Kiểm tra tất cả ${#SERVERS[@]} servers...${NC}"

for server_id in "${!SERVERS[@]}"; do
    server_info="${SERVERS[$server_id]}"
    IFS='|' read -r location search_keywords <<< "$server_info"
    
    echo -e "\n${BLUE}🔍 Checking: $location (ID: $server_id)${NC}"
    
    if test_server "$server_id" "$TIMEOUT"; then
        echo -e "${GREEN}✅ Server $server_id ($location) is working${NC}"
    else
        echo -e "${RED}❌ Server $server_id ($location) failed or timed out${NC}"
        failed_servers+=("$server_id:$location:$search_keywords")
        
        # Tìm server thay thế
        if replacement_id=$(find_replacement_server "$location" "$search_keywords"); then
            update_server_id "$server_id" "$replacement_id" "$location"
            updated_servers+=("$location: $server_id → $replacement_id")
        else
            echo -e "${RED}⚠️  Could not find replacement for $location${NC}"
        fi
    fi
done

# Tóm tắt kết quả
echo -e "\n${BLUE}📋 SUMMARY REPORT${NC}"
echo -e "${BLUE}==================${NC}"

if [ ${#failed_servers[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All servers are working properly!${NC}"
else
    echo -e "${YELLOW}⚠️  Failed servers: ${#failed_servers[@]}${NC}"
    for failed in "${failed_servers[@]}"; do
        IFS=':' read -r id location _ <<< "$failed"
        echo -e "   - $location (ID: $id)"
    done
fi

if [ ${#updated_servers[@]} -gt 0 ]; then
    echo -e "\n${GREEN}🔄 Updated servers: ${#updated_servers[@]}${NC}"
    for update in "${updated_servers[@]}"; do
        echo -e "   - $update"
    done
    
    # Validate updated script
    echo -e "\n${BLUE}🔍 Validating updated script...${NC}"
    if bash -n "$SCRIPT_FILE"; then
        echo -e "${GREEN}✅ Script syntax is valid${NC}"
    else
        echo -e "${RED}❌ Script syntax error! Restoring backup...${NC}"
        cp "$BACKUP_FILE" "$SCRIPT_FILE"
        exit 1
    fi
else
    echo -e "${GREEN}✨ No updates needed${NC}"
fi

# Cleanup
rm -f "$BACKUP_FILE"

echo -e "\n${GREEN}✅ Script execution completed!${NC}"
