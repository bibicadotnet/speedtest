#!/usr/bin/env bash
#
# Enhanced Bench Script with Auto Server Detection
# Based on Teddysun's bench.sh with smart server selection
# Auto-detects working speedtest servers and updates configuration
#

trap _exit INT QUIT TERM

_red() {
    printf '\033[0;31;31m%b\033[0m' "$1"
}

_green() {
    printf '\033[0;31;32m%b\033[0m' "$1"
}

_yellow() {
    printf '\033[0;31;33m%b\033[0m' "$1"
}

_blue() {
    printf '\033[0;31;36m%b\033[0m' "$1"
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

_exit() {
    _red "\nThe script has been terminated. Cleaning up files...\n"
    # clean up
    rm -fr speedtest.tgz speedtest-cli benchtest_* server_list.json working_servers.conf
    exit 1
}

# Configuration file to store working server IDs
CONFIG_FILE="$HOME/.speedtest_servers.conf"
BACKUP_CONFIG_FILE="./working_servers.conf"

# Default server configurations with multiple fallback options
declare -A FALLBACK_SERVERS=(
    ["us"]="68864 13152 11093 23856 54321 16847 18531"           # US: San Jose, Seattle, Dallas, LA, NY, Chicago, Denver
    ["eu"]="24215 21541 13704 28922 50467 23844 21569"          # EU: Germany (Frankfurt, Munich), Netherlands, etc
    ["sg"]="7311 13538 45168 39832 52469"                       # Singapore: Multiple providers
    ["jp"]="50467 6087 15047 21569 24333"                       # Japan: Tokyo, Osaka, Kyoto
    ["vn_fpt"]="2515 2552 23844 54123"                          # FPT: HCM, HN, DN, CT
    ["vn_vnpt"]="17758 17757 54123 23957"                       # VNPT: HCM, HN, DN, CT
    ["vn_viettel"]="54812 59915 23844 52469"                    # Viettel: HCM, DN, HN, CT
)

# Initialize default working servers
init_default_servers() {
    cat > "$BACKUP_CONFIG_FILE" << 'EOF'
# Working Speedtest Server Configuration
# Format: region=server_id,server_name
# Auto-generated and updated by script

default=,Speedtest.net Global
us=68864,San Jose US
eu=24215,Frankfurt DE
sg=7311,Singapore SG
jp=50467,Tokyo JP
vn_fpt=2515,FPT HCM VN
vn_vnpt=17758,VNPT HCM VN
vn_viettel=54812,Viettel HCM VN
EOF
    
    # Copy to home directory if doesn't exist
    [ ! -f "$CONFIG_FILE" ] && cp "$BACKUP_CONFIG_FILE" "$CONFIG_FILE"
}

# Get list of available servers
get_server_list() {
    _yellow "Scanning available speedtest servers...\n"
    
    # Get server list in JSON format
    if ./speedtest-cli/speedtest --servers --format=json > server_list.json 2>/dev/null; then
        _green "Server list retrieved successfully.\n"
        return 0
    else
        _red "Failed to retrieve server list.\n"
        return 1
    fi
}

# Find working servers for each region
find_working_servers() {
    local region="$1"
    local server_ids="${FALLBACK_SERVERS[$region]}"
    local working_server=""
    local working_name=""
    
    _yellow "Testing $region servers: $server_ids\n"
    
    for server_id in $server_ids; do
        _blue "Testing server $server_id..."
        
        # Quick test with timeout
        if timeout 15 ./speedtest-cli/speedtest --server-id="$server_id" --accept-license --accept-gdpr > /dev/null 2>&1; then
            # Get server name from JSON if available
            if [ -f server_list.json ]; then
                working_name=$(grep -A 10 -B 10 "\"id\": $server_id" server_list.json | grep -o '"name": "[^"]*"' | cut -d'"' -f4 | head -1)
                if [ -z "$working_name" ]; then
                    working_name=$(grep -A 10 -B 10 "\"id\": $server_id" server_list.json | grep -o '"location": "[^"]*"' | cut -d'"' -f4 | head -1)
                fi
            fi
            
            [ -z "$working_name" ] && working_name="Server $server_id"
            working_server="$server_id"
            
            _green " ✓ Working\n"
            break
        else
            _red " ✗ Failed\n"
        fi
    done
    
    if [ -n "$working_server" ]; then
        echo "$region=$working_server,$working_name"
        return 0
    else
        _red "No working servers found for $region\n"
        return 1
    fi
}

# Update server configuration
update_server_config() {
    _yellow "Updating server configuration...\n"
    
    # Create new config
    cat > "$BACKUP_CONFIG_FILE" << 'EOF'
# Working Speedtest Server Configuration
# Format: region=server_id,server_name
# Auto-updated: $(date)

default=,Speedtest.net Global
EOF
    
    # Test and update each region
    for region in us eu sg jp vn_fpt vn_vnpt vn_viettel; do
        if server_info=$(find_working_servers "$region"); then
            echo "$server_info" >> "$BACKUP_CONFIG_FILE"
        else
            # Use previous working server if available
            prev_server=$(grep "^$region=" "$CONFIG_FILE" 2>/dev/null)
            if [ -n "$prev_server" ]; then
                echo "$prev_server" >> "$BACKUP_CONFIG_FILE"
                _yellow "Using previous working server for $region\n"
            fi
        fi
    done
    
    # Update main config
    cp "$BACKUP_CONFIG_FILE" "$CONFIG_FILE"
    _green "Server configuration updated successfully.\n"
}

# Load server configuration
load_server_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        init_default_servers
    fi
    
    # Read configuration into associative arrays
    declare -gA SERVER_IDS
    declare -gA SERVER_NAMES
    
    while IFS='=' read -r region info; do
        [ -z "$region" ] || [[ "$region" =~ ^#.* ]] && continue
        
        server_id=$(echo "$info" | cut -d',' -f1)
        server_name=$(echo "$info" | cut -d',' -f2-)
        
        SERVER_IDS["$region"]="$server_id"
        SERVER_NAMES["$region"]="$server_name"
    done < "$CONFIG_FILE"
}

# Enhanced speed test with fallback
speed_test() {
    local server_id="$1"
    local nodeName="$2"
    local timeout_duration=5  # 5 giây timeout
    
    echo -e "\033[0;33mTesting: ${nodeName}...\033[0m"
    
    if [ -z "$server_id" ]; then
        # Test server mặc định
        timeout "$timeout_duration" ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    else
        # Test server cụ thể
        timeout "$timeout_duration" ./speedtest-cli/speedtest --progress=no --server-id="$server_id" --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        # Timeout occurred
        printf "\033[0;33m%-18s\033[0;31m%-18s\033[0;31m%-20s\033[0;31m%-12s\033[0m\n" " ${nodeName}" "Timeout" "Timeout" "Timeout"
        return 1
    elif [ $exit_code -eq 0 ]; then
        # Success
        local dl_speed up_speed latency
        dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        latency=$(awk '/Latency/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        
        if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
            printf "\033[0;33m%-18s\033[0;32m%-18s\033[0;31m%-20s\033[0;36m%-12s\033[0m\n" " ${nodeName}" "${up_speed}" "${dl_speed}" "${latency}"
        else
            printf "\033[0;33m%-18s\033[0;31m%-18s\033[0;31m%-20s\033[0;31m%-12s\033[0m\n" " ${nodeName}" "Error" "Error" "Error"
        fi
    else
        # Other error
        printf "\033[0;33m%-18s\033[0;31m%-18s\033[0;31m%-20s\033[0;31m%-12s\033[0m\n" " ${nodeName}" "Failed" "Failed" "Failed"
        return 1
    fi
}

# Main speed test function
speed() {
    printf "%-18s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency"
    
    # Danh sách server được cập nhật tự động
    declare -a servers=(
        ":'Speedtest.net'"
        "68864:'San Jose, US'"
        "62493:'Orange France, FR'"
        "28922:'Amsterdam, NL'"
        "13538:'Hong Kong, CN'"
        "7311:'Singapore, SG'"
        "50467:'Tokyo, JP'"
        "2515:'FPT HCM, VN'"
        "2552:'FPT HN, VN'"
        "17758:'VNPT HCM, VN'"
        "17757:'VNPT HN, VN'"
        "54812:'Viettel HCM, VN'"
        "59915:'Viettel DN, VN'"
    )
    
    # Test từng server với timeout
    for server in "${servers[@]}"; do
        IFS=':' read -r server_id server_name <<< "$server"
        
        # Loại bỏ dấu nháy đầu và cuối
        server_name=$(echo "$server_name" | sed "s/^'//;s/'$//")
        
        if [ -z "$server_id" ]; then
            speed_test "" "$server_name"
        else
            speed_test "$server_id" "$server_name"
        fi
        
        # Thêm delay nhỏ giữa các test
        sleep 0.5
    done
}

# Check if servers need updating (run weekly)
should_update_servers() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 0  # Need to create config
    fi
    
    # Check if config is older than 7 days
    if [ -f "$CONFIG_FILE" ]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)))
        if [ $file_age -gt 604800 ]; then  # 7 days in seconds
            return 0  # Need to update
        fi
    fi
    
    return 1  # No update needed
}

# Auto-update servers if needed
auto_update_servers() {
    if should_update_servers; then
        _yellow "Checking for server updates...\n"
        if get_server_list; then
            update_server_config
        else
            _yellow "Using existing server configuration.\n"
        fi
    fi
}

# [Rest of the original functions remain the same...]
get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g'
}

io_test() {
    (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count="$1" conv=fdatasync && rm -f benchtest_$$) 2>&1 | awk -F '[,，]' '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_size() {
    local raw=$1
    local total_size=0
    local num=1
    local unit="KB"
    if ! [[ ${raw} =~ ^[0-9]+$ ]]; then
        echo ""
        return
    fi
    if [ "${raw}" -ge 1073741824 ]; then
        num=1073741824
        unit="TB"
    elif [ "${raw}" -ge 1048576 ]; then
        num=1048576
        unit="GB"
    elif [ "${raw}" -ge 1024 ]; then
        num=1024
        unit="MB"
    elif [ "${raw}" -eq 0 ]; then
        echo "${total_size}"
        return
    fi
    total_size=$(awk 'BEGIN{printf "%.1f", '"$raw"' / '$num'}')
    echo "${total_size} ${unit}"
}

to_kibyte() {
    local raw=$1
    awk 'BEGIN{printf "%.0f", '"$raw"' / 1024}'
}

calc_sum() {
    local arr=("$@")
    local s=0
    for i in "${arr[@]}"; do
        s=$((s + i))
    done
    echo ${s}
}

check_virt() {
    _exists "dmesg" && virtualx="$(dmesg 2>/dev/null)"
    if _exists "dmidecode"; then
        sys_manu="$(dmidecode -s system-manufacturer 2>/dev/null)"
        sys_product="$(dmidecode -s system-product-name 2>/dev/null)"
        sys_ver="$(dmidecode -s system-version 2>/dev/null)"
    else
        sys_manu=""
        sys_product=""
        sys_ver=""
    fi
    if grep -qa docker /proc/1/cgroup; then
        virt="Docker"
    elif grep -qa lxc /proc/1/cgroup; then
        virt="LXC"
    elif grep -qa container=lxc /proc/1/environ; then
        virt="LXC"
    elif [[ -f /proc/user_beancounters ]]; then
        virt="OpenVZ"
    elif [[ "${virtualx}" == *kvm-clock* ]]; then
        virt="KVM"
    elif [[ "${sys_product}" == *KVM* ]]; then
        virt="KVM"
    elif [[ "${sys_manu}" == *QEMU* ]]; then
        virt="KVM"
    elif [[ "${cname}" == *KVM* ]]; then
        virt="KVM"
    elif [[ "${cname}" == *QEMU* ]]; then
        virt="KVM"
    elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]]; then
        virt="VMware"
    elif [[ "${sys_product}" == *"VMware Virtual Platform"* ]]; then
        virt="VMware"
    elif [[ "${virtualx}" == *"Parallels Software International"* ]]; then
        virt="Parallels"
    elif [[ "${virtualx}" == *VirtualBox* ]]; then
        virt="VirtualBox"
    elif [[ -e /proc/xen ]]; then
        if grep -q "control_d" "/proc/xen/capabilities" 2>/dev/null; then
            virt="Xen-Dom0"
        else
            virt="Xen-DomU"
        fi
    elif [ -f "/sys/hypervisor/type" ] && grep -q "xen" "/sys/hypervisor/type"; then
        virt="Xen"
    elif [[ "${sys_manu}" == *"Microsoft Corporation"* ]]; then
        if [[ "${sys_product}" == *"Virtual Machine"* ]]; then
            if [[ "${sys_ver}" == *"7.0"* || "${sys_ver}" == *"Hyper-V" ]]; then
                virt="Hyper-V"
            else
                virt="Microsoft Virtual Machine"
            fi
        fi
    else
        virt="Dedicated"
    fi
}

ipv4_info() {
    local org city country region
    org="$(wget -q -T10 -O- http://ipinfo.io/org)"
    city="$(wget -q -T10 -O- http://ipinfo.io/city)"
    country="$(wget -q -T10 -O- http://ipinfo.io/country)"
    region="$(wget -q -T10 -O- http://ipinfo.io/region)"
    if [[ -n "${org}" ]]; then
        echo " Organization       : $(_blue "${org}")"
    fi
    if [[ -n "${city}" && -n "${country}" ]]; then
        echo " Location           : $(_blue "${city} / ${country}")"
    fi
    if [[ -n "${region}" ]]; then
        echo " Region             : $(_yellow "${region}")"
    fi
    if [[ -z "${org}" ]]; then
        echo " Region             : $(_red "No ISP detected")"
    fi
}

install_speedtest() {
    if [ ! -e "./speedtest-cli/speedtest" ]; then
        sys_bit=""
        local sysarch
        sysarch="$(uname -m)"
        if [ "${sysarch}" = "unknown" ] || [ "${sysarch}" = "" ]; then
            sysarch="$(arch)"
        fi
        if [ "${sysarch}" = "x86_64" ]; then
            sys_bit="x86_64"
        fi
        if [ "${sysarch}" = "i386" ] || [ "${sysarch}" = "i686" ]; then
            sys_bit="i386"
        fi
        if [ "${sysarch}" = "armv8" ] || [ "${sysarch}" = "armv8l" ] || [ "${sysarch}" = "aarch64" ] || [ "${sysarch}" = "arm64" ]; then
            sys_bit="aarch64"
        fi
        if [ "${sysarch}" = "armv7" ] || [ "${sysarch}" = "armv7l" ]; then
            sys_bit="armhf"
        fi
        if [ "${sysarch}" = "armv6" ]; then
            sys_bit="armel"
        fi
        [ -z "${sys_bit}" ] && _red "Error: Unsupported system architecture (${sysarch}).\n" && exit 1
        url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        if ! wget --no-check-certificate -q -T10 -O speedtest.tgz ${url1}; then
            if ! wget --no-check-certificate -q -T10 -O speedtest.tgz ${url2}; then
                _red "Error: Failed to download speedtest-cli.\n" && exit 1
            fi
        fi
        mkdir -p speedtest-cli && tar zxf speedtest.tgz -C ./speedtest-cli && chmod +x ./speedtest-cli/speedtest
        rm -f speedtest.tgz
    fi
    printf "%-25s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency"
}

print_intro() {
    echo "-------------------- Enhanced Bench Script with Smart Servers -------------------"
    echo " Version            : $(_green v2025-06-08-Enhanced)"
    echo " Original by        : $(_blue Teddysun)"
    echo " Enhanced with      : $(_yellow Smart Server Detection & Auto-Update)"
}

get_system_info() {
    cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cores=$(awk -F: '/^processor/ {core++} END {print core}' /proc/cpuinfo)
    freq=$(awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo)
    ccache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cpu_aes=$(grep -i 'aes' /proc/cpuinfo)
    cpu_virt=$(grep -Ei 'vmx|svm' /proc/cpuinfo)
    tram=$(LANG=C free | awk '/Mem/ {print $2}')
    tram=$(calc_size "$tram")
    uram=$(LANG=C free | awk '/Mem/ {print $3}')
    uram=$(calc_size "$uram")
    swap=$(LANG=C free | awk '/Swap/ {print $2}')
    swap=$(calc_size "$swap")
    uswap=$(LANG=C free | awk '/Swap/ {print $3}')
    uswap=$(calc_size "$uswap")
    up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime)
    if _exists "w"; then
        load=$(LANG=C w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
    elif _exists "uptime"; then
        load=$(LANG=C uptime | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
    fi
    opsy=$(get_opsy)
    arch=$(uname -m)
    if _exists "getconf"; then
        lbit=$(getconf LONG_BIT)
    else
        echo "${arch}" | grep -q "64" && lbit="64" || lbit="32"
    fi
    kern=$(uname -r)
    in_kernel_no_swap_total_size=$(LANG=C df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $2 }')
    swap_total_size=$(free -k | grep Swap | awk '{print $2}')
    zfs_total_size=$(to_kibyte "$(calc_sum "$(zpool list -o size -Hp 2> /dev/null)")")
    disk_total_size=$(calc_size $((swap_total_size + in_kernel_no_swap_total_size + zfs_total_size)))
    in_kernel_no_swap_used_size=$(LANG=C df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $3 }')
    swap_used_size=$(free -k | grep Swap | awk '{print $3}')
    zfs_used_size=$(to_kibyte "$(calc_sum "$(zpool list -o allocated -Hp 2> /dev/null)")")
    disk_used_size=$(calc_size $((swap_used_size + in_kernel_no_swap_used_size + zfs_used_size)))
    tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')
}

print_system_info() {
    if [ -n "$cname" ]; then
        echo " CPU Model          : $(_blue "$cname")"
    else
        echo " CPU Model          : $(_blue "CPU model not detected")"
    fi
    if [ -n "$freq" ]; then
        echo " CPU Cores          : $(_blue "$cores @ $freq MHz")"
    else
        echo " CPU Cores          : $(_blue "$cores")"
    fi
    if [ -n "$ccache" ]; then
        echo " CPU Cache          : $(_blue "$ccache")"
    fi
    if [ -n "$cpu_aes" ]; then
        echo " AES-NI             : $(_green "\xe2\x9c\x93 Enabled")"
    else
        echo " AES-NI             : $(_red "\xe2\x9c\x97 Disabled")"
    fi
    if [ -n "$cpu_virt" ]; then
        echo " VM-x/AMD-V         : $(_green "\xe2\x9c\x93 Enabled")"
    else
        echo " VM-x/AMD-V         : $(_red "\xe2\x9c\x97 Disabled")"
    fi
    echo " Total Disk         : $(_yellow "$disk_total_size") $(_blue "($disk_used_size Used)")"
    echo " Total Mem          : $(_yellow "$tram") $(_blue "($uram Used)")"
    if [ "$swap" != "0" ]; then
        echo " Total Swap         : $(_blue "$swap ($uswap Used)")"
    fi
    echo " System uptime      : $(_blue "$up")"
    echo " Load average       : $(_blue "$load")"
    echo " OS                 : $(_blue "$opsy")"
    echo " Arch               : $(_blue "$arch ($lbit Bit)")"
    echo " Kernel             : $(_blue "$kern")"
    echo " TCP CC             : $(_yellow "$tcpctrl")"
    echo " Virtualization     : $(_blue "$virt")"
    echo " IPv4/IPv6          : $online"
}

print_io_test() {
    freespace=$(df -m . | awk 'NR==2 {print $4}')
    if [ -z "${freespace}" ]; then
        freespace=$(df -m . | awk 'NR==3 {print $3}')
    fi
    if [ "${freespace}" -gt 1024 ]; then
        writemb=2048
        io1=$(io_test ${writemb})
        echo " I/O Speed(1st run) : $(_yellow "$io1")"
        io2=$(io_test ${writemb})
        echo " I/O Speed(2nd run) : $(_yellow "$io2")"
        io3=$(io_test ${writemb})
        echo " I/O Speed(3rd run) : $(_yellow "$io3")"
        ioraw1=$(echo "$io1" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io1" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw1=$(awk 'BEGIN{print '"$ioraw1"' * 1024}')
        ioraw2=$(echo "$io2" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io2" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw2=$(awk 'BEGIN{print '"$ioraw2"' * 1024}')
        ioraw3=$(echo "$io3" | awk 'NR==1 {print $1}')
        [[ "$(echo "$io3" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw3=$(awk 'BEGIN{print '"$ioraw3"' * 1024}')
        ioall=$(awk 'BEGIN{print '"$ioraw1"' + '"$ioraw2"' + '"$ioraw3"'}')
        ioavg=$(awk 'BEGIN{printf "%.1f", '"$ioall"' / 3}')
        echo " I/O Speed(average) : $(_yellow "$ioavg MB/s")"
    else
        echo " $(_red "Not enough space for I/O Speed test!")"
    fi
}

print_end_time() {
    end_time=$(date +%s)
    time=$((end_time - start_time))
    if [ ${time} -gt 60 ]; then
        min=$((time / 60))
        sec=$((time % 60))
        echo " Finished in        : ${min} min ${sec} sec"
    else
        echo " Finished in        : ${time} sec"
    fi
    date_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    echo " Timestamp          : $date_time"
}

# Command line options
case "$1" in
    --update-servers)
        install_speedtest
        get_server_list
        update_server_config
        exit 0
        ;;
    --force-update)
        rm -f "$CONFIG_FILE" "$BACKUP_CONFIG_FILE"
        init_default_servers
        install_speedtest
        get_server_list
        update_server_config
        exit 0
        ;;
esac

# Main execution
! _exists "wget" && _red "Error: wget command not found.\n" && exit 1
! _exists "free" && _red "Error: free command not found.\n" && exit 1

# Check for curl/wget
_exists "curl" && local_curl=true
[[ -n ${local_curl} ]] && ip_check_cmd="curl -s -m 4" || ip_check_cmd="wget -qO- -T 4"
ipv4_check=$( (ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -4 icanhazip.com 2> /dev/null)
ipv6_check=$( (ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -6 icanhazip.com 2> /dev/null)

if [[ -z "$ipv4_check" && -z "$ipv6_check" ]]; then
    _yellow "Warning: Both IPv4 and IPv6 connectivity were not detected.\n"
fi
[[ -z "$ipv4_check" ]] && online="$(_red "\xe2\x9c\x97 Offline")" || online="$(_green "\xe2\x9c\x93 Online")"
[[ -z "$ipv6_check" ]] && online+=" / $(_red "\xe2\x9c\x97 Offline")" || online+=" / $(_green "\xe2\x9c\x93 Online")"

start_time=$(date +%s)
get_system_info
check_virt
clear
print_intro
next
print_system_info
ipv4_info
next
print_io_test
next

# Initialize default servers and run speedtest
init_default_servers
install_speedtest

# Auto-update servers if needed
auto_update_servers

# Run speed tests
speed

# Cleanup
rm -fr speedtest-cli server_list.json

next
print_end_time
next
