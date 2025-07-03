#!/usr/bin/env bash
# Optimized Bench Script by Teddysun
# Copyright (C) 2015 - 2025 Teddysun <i@teddysun.com>

clear
rm -rf speedtest.tgz speedtest-cli benchtest_* ./*.log ./speedtest.log /tmp/benchmark_* /tmp/speedtest* /tmp/iperf* 2>/dev/null
trap '_red "Script terminated. Cleaning up..."; rm -rf speedtest.tgz speedtest-cli benchtest_* ./*.log ./speedtest.log /tmp/benchmark_* /tmp/speedtest* /tmp/iperf*; exit 1' INT QUIT TERM

# Color functions
_red() { printf '\033[0;31;31m%b\033[0m' "$1"; }
_green() { printf '\033[0;31;32m%b\033[0m' "$1"; }
_yellow() { printf '\033[0;31;33m%b\033[0m' "$1"; }
_blue() { printf '\033[0;31;36m%b\033[0m' "$1"; }

# Check command existence
_exists() { command -v "$1" >/dev/null 2>&1; }

# Get OS info
get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() { printf "%-70s\n" "-" | sed 's/\s/-/g'; }

# Speed test function
speed_test() {
    local nodeName="$2"
    if [ -z "$1" ]; then
        ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    else
        ./speedtest-cli/speedtest --progress=no --server-id="$1" --accept-license --accept-gdpr >./speedtest-cli/speedtest.log 2>&1
    fi
    if [ $? -eq 0 ]; then
        local dl_speed up_speed latency
        dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        latency=$(awk '/Latency/{print $3" "$4}' ./speedtest-cli/speedtest.log)
        if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
            # For screen display with colors
            printf "\033[0;33m%-18s\033[0;32m%-18s\033[0;31m%-20s\033[0;36m%-12s\033[0m\n" " ${nodeName}" "${up_speed}" "${dl_speed}" "${latency}"
            # Store clean version for upload (append to temp file)
            printf "%-18s%-18s%-20s%-12s\n" " ${nodeName}" "${up_speed}" "${dl_speed}" "${latency}" >> /tmp/speedtest_clean_$$
        fi
    fi
}

# Run all speed tests
speed() {
    speed_test '' 'Speedtest.net'
    speed_test '14236' 'Los Angeles, US'; speed_test '61933' 'Paris, FR'; speed_test '49516' 'Berlin, DE'
    speed_test '63143' 'Hong Kong, HK'; speed_test '13623' 'Singapore, SG'; speed_test '48463' 'Tokyo, JP'
    speed_test '2552' 'FPT Telecom, VN'; speed_test '45493' 'VNPT-NET, VN'; speed_test '9903' 'Viettel, VN'
}

# I/O test
io_test() { (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count="$1" conv=fdatasync && rm -f benchtest_$$) 2>&1 | awk -F '[,，]' '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'; }

# Size calculation
calc_size() {
    local raw=$1 total_size=0 num=1 unit="KB"
    [[ ! ${raw} =~ ^[0-9]+$ ]] && echo "" && return
    if [ "${raw}" -ge 1073741824 ]; then num=1073741824; unit="TB"
    elif [ "${raw}" -ge 1048576 ]; then num=1048576; unit="GB"
    elif [ "${raw}" -ge 1024 ]; then num=1024; unit="MB"
    elif [ "${raw}" -eq 0 ]; then echo "${total_size}"; return; fi
    total_size=$(awk 'BEGIN{printf "%.1f", '"$raw"' / '$num'}')
    echo "${total_size} ${unit}"
}

to_kibyte() { awk 'BEGIN{printf "%.0f", '"$1"' / 1024}'; }
calc_sum() { local s=0; for i in "$@"; do s=$((s + i)); done; echo ${s}; }

# Virtualization check
check_virt() {
    _exists "dmesg" && virtualx="$(dmesg 2>/dev/null)"
    if _exists "dmidecode"; then
        sys_manu="$(dmidecode -s system-manufacturer 2>/dev/null)"
        sys_product="$(dmidecode -s system-product-name 2>/dev/null)"
        sys_ver="$(dmidecode -s system-version 2>/dev/null)"
    fi
    
    if grep -qa docker /proc/1/cgroup; then virt="Docker"
    elif grep -qa lxc /proc/1/cgroup; then virt="LXC"
    elif grep -qa container=lxc /proc/1/environ; then virt="LXC"
    elif [[ -f /proc/user_beancounters ]]; then virt="OpenVZ"
    elif [[ "${virtualx}" == *kvm-clock* ]] || [[ "${sys_product}" == *KVM* ]] || [[ "${sys_manu}" == *QEMU* ]]; then virt="KVM"
    elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]] || [[ "${sys_product}" == *"VMware Virtual Platform"* ]]; then virt="VMware"
    elif [[ "${virtualx}" == *"Parallels Software International"* ]]; then virt="Parallels"
    elif [[ "${virtualx}" == *VirtualBox* ]]; then virt="VirtualBox"
    elif [[ -e /proc/xen ]]; then
        grep -q "control_d" "/proc/xen/capabilities" 2>/dev/null && virt="Xen-Dom0" || virt="Xen-DomU"
    elif [ -f "/sys/hypervisor/type" ] && grep -q "xen" "/sys/hypervisor/type"; then virt="Xen"
    elif [[ "${sys_manu}" == *"Microsoft Corporation"* ]] && [[ "${sys_product}" == *"Virtual Machine"* ]]; then
        [[ "${sys_ver}" == *"7.0"* || "${sys_ver}" == *"Hyper-V" ]] && virt="Hyper-V" || virt="Microsoft Virtual Machine"
    else virt="Dedicated"; fi
}

# IPv4 info
ipv4_info() {
    local org city country region
    org="$(wget -q -T10 -O- http://ipinfo.io/org 2>/dev/null)"
    city="$(wget -q -T10 -O- http://ipinfo.io/city 2>/dev/null)"
    country="$(wget -q -T10 -O- http://ipinfo.io/country 2>/dev/null)"
    region="$(wget -q -T10 -O- http://ipinfo.io/region 2>/dev/null)"
    [[ -n "${org}" ]] && echo " Organization       : $(_blue "${org}")"
    [[ -n "${city}" && -n "${country}" ]] && echo " Location           : $(_blue "${city} / ${country}")"
    [[ -n "${region}" ]] && echo " Region             : $(_yellow "${region}")"
    [[ -z "${org}" ]] && echo " Region             : $(_red "No ISP detected")"
}

# Install speedtest
install_speedtest() {
    if [ ! -e "./speedtest-cli/speedtest" ]; then
        local sysarch="$(uname -m)" sys_bit=""
        [ "${sysarch}" = "unknown" ] || [ "${sysarch}" = "" ] && sysarch="$(arch)"
        case "${sysarch}" in
            x86_64) sys_bit="x86_64";;
            i386|i686) sys_bit="i386";;
            armv8|armv8l|aarch64|arm64) sys_bit="aarch64";;
            armv7|armv7l) sys_bit="armhf";;
            armv6) sys_bit="armel";;
            *) _red "Error: Unsupported architecture (${sysarch}).\n" && exit 1;;
        esac
        
        url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        
        if ! wget --no-check-certificate -q -T10 -O speedtest.tgz ${url1}; then
            if ! wget --no-check-certificate -q -T10 -O speedtest.tgz ${url2}; then
                _red "Error: Failed to download speedtest-cli.\n" && exit 1
            fi
        fi
        mkdir -p speedtest-cli && tar zxf speedtest.tgz -C ./speedtest-cli && chmod +x ./speedtest-cli/speedtest && rm -f speedtest.tgz
    fi
    printf "%-18s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency"
}

print_intro() {
    echo "-------------------- A Bench.sh Script By Teddysun -------------------"
    echo " Version            : $(_green v2025-05-08)"
    echo " Usage              : $(_red "wget -qO- https://benchmark.bibica.net | bash")"
}

# Get system info
get_system_info() {
    cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cores=$(awk -F: '/^processor/ {core++} END {print core}' /proc/cpuinfo)
    freq=$(awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo)
    ccache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
    cpu_aes=$(grep -i 'aes' /proc/cpuinfo); cpu_virt=$(grep -Ei 'vmx|svm' /proc/cpuinfo)
    
    tram=$(calc_size "$(LANG=C free | awk '/Mem/ {print $2}')")
    uram=$(calc_size "$(LANG=C free | awk '/Mem/ {print $3}')")
    swap=$(calc_size "$(LANG=C free | awk '/Swap/ {print $2}')")
    uswap=$(calc_size "$(LANG=C free | awk '/Swap/ {print $3}')")
    
    up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime)
    _exists "w" && load=$(LANG=C w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//') || load=$(LANG=C uptime | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    opsy=$(get_opsy); arch=$(uname -m)
    _exists "getconf" && lbit=$(getconf LONG_BIT) || { echo "${arch}" | grep -q "64" && lbit="64" || lbit="32"; }
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

# Print system info
print_system_info() {
    [ -n "$cname" ] && echo " CPU Model          : $(_blue "$cname")" || echo " CPU Model          : $(_blue "CPU model not detected")"
    [ -n "$freq" ] && echo " CPU Cores          : $(_blue "$cores @ $freq MHz")" || echo " CPU Cores          : $(_blue "$cores")"
    [ -n "$ccache" ] && echo " CPU Cache          : $(_blue "$ccache")"
    [ -n "$cpu_aes" ] && echo " AES-NI             : $(_green "\xe2\x9c\x93 Enabled")" || echo " AES-NI             : $(_red "\xe2\x9c\x97 Disabled")"
    [ -n "$cpu_virt" ] && echo " VM-x/AMD-V         : $(_green "\xe2\x9c\x93 Enabled")" || echo " VM-x/AMD-V         : $(_red "\xe2\x9c\x97 Disabled")"
    echo " Total Disk         : $(_yellow "$disk_total_size") $(_blue "($disk_used_size Used)")"
    echo " Total Mem          : $(_yellow "$tram") $(_blue "($uram Used)")"
    [ "$swap" != "0" ] && echo " Total Swap         : $(_blue "$swap ($uswap Used)")"
    echo " System uptime      : $(_blue "$up")"
    echo " Load average       : $(_blue "$load")"
    echo " OS                 : $(_blue "$opsy")"
    echo " Arch               : $(_blue "$arch ($lbit Bit)")"
    echo " Kernel             : $(_blue "$kern")"
    echo " TCP CC             : $(_yellow "$tcpctrl")"
    echo " Virtualization     : $(_blue "$virt")"
    echo " IPv4/IPv6          : $online"
}

# I/O test
print_io_test() {
    freespace=$(df -m . | awk 'NR==2 {print $4}')
    [ -z "${freespace}" ] && freespace=$(df -m . | awk 'NR==3 {print $3}')
    if [ "${freespace}" -gt 1024 ]; then
        writemb=2048
        io1=$(io_test ${writemb}); echo " I/O Speed(1st run) : $(_yellow "$io1")"
        io2=$(io_test ${writemb}); echo " I/O Speed(2nd run) : $(_yellow "$io2")"
        io3=$(io_test ${writemb}); echo " I/O Speed(3rd run) : $(_yellow "$io3")"
        
        ioraw1=$(echo "$io1" | awk 'NR==1 {print $1}'); [[ "$(echo "$io1" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw1=$(awk 'BEGIN{print '"$ioraw1"' * 1024}')
        ioraw2=$(echo "$io2" | awk 'NR==1 {print $1}'); [[ "$(echo "$io2" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw2=$(awk 'BEGIN{print '"$ioraw2"' * 1024}')
        ioraw3=$(echo "$io3" | awk 'NR==1 {print $1}'); [[ "$(echo "$io3" | awk 'NR==1 {print $2}')" == "GB/s" ]] && ioraw3=$(awk 'BEGIN{print '"$ioraw3"' * 1024}')
        
        ioall=$(awk 'BEGIN{print '"$ioraw1"' + '"$ioraw2"' + '"$ioraw3"'}')
        ioavg=$(awk 'BEGIN{printf "%.1f", '"$ioall"' / 3}')
        echo " I/O Speed(average) : $(_yellow "$ioavg MB/s")"
    else
        echo " $(_red "Not enough space for I/O Speed test!")"
    fi
}

print_end_time() {
    end_time=$(date +%s); time=$((end_time - start_time))
    if [ ${time} -gt 60 ]; then
        min=$((time / 60)); sec=$((time % 60))
        echo " Finished in        : ${min} min ${sec} sec"
    else
        echo " Finished in        : ${time} sec"
    fi
    echo " Timestamp          : $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

# Check dependencies
! _exists "wget" && _red "Error: wget command not found.\n" && exit 1
! _exists "free" && _red "Error: free command not found.\n" && exit 1

# Network connectivity check
_exists "curl" && local_curl=true
[[ -n ${local_curl} ]] && ip_check_cmd="curl -s -m 4" || ip_check_cmd="wget -qO- -T 4"
ipv4_check=$( (ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -4 icanhazip.com 2> /dev/null)
ipv6_check=$( (ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || ${ip_check_cmd} -6 icanhazip.com 2> /dev/null)
[[ -z "$ipv4_check" && -z "$ipv6_check" ]] && _yellow "Warning: Both IPv4 and IPv6 connectivity were not detected.\n"
[[ -z "$ipv4_check" ]] && online="$(_red "\xe2\x9c\x97 Offline")" || online="$(_green "\xe2\x9c\x93 Online")"
[[ -z "$ipv6_check" ]] && online+=" / $(_red "\xe2\x9c\x97 Offline")" || online+=" / $(_green "\xe2\x9c\x93 Online")"

# Base64 encoding with fallbacks
base64_encode() {
    local input_file="$1"
    if command -v base64 >/dev/null 2>&1; then base64 -w 0 "$input_file" 2>/dev/null
    elif command -v openssl >/dev/null 2>&1; then openssl base64 -in "$input_file" -A 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then python3 -c "import base64; print(base64.b64encode(open('$input_file', 'rb').read()).decode())" 2>/dev/null
    elif command -v python >/dev/null 2>&1; then python -c "import base64; print(base64.b64encode(open('$input_file', 'rb').read()).decode())" 2>/dev/null
    else return 1; fi
}

# Strip ANSI and special characters
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g' | sed 's/â //g' | sed 's/â //g' | sed 's/✓/[OK]/g' | sed 's/✗/[FAIL]/g' | tr -d '\r'
}

upload_results() {
    local results_file="/tmp/benchmark_results_$$" results_clean="/tmp/benchmark_clean_$$"
    
    # Capture and display benchmark output
    {
        print_intro; next; print_system_info; ipv4_info; next; print_io_test; next
        install_speedtest && speed && rm -fr speedtest-cli
        next; print_end_time; next
    } | tee "$results_file"
    
    # Create clean version for upload
    strip_ansi < "$results_file" > "$results_clean"
    
    local encoded_data response benchmark_url
    encoded_data=$(base64_encode "$results_clean")
    
    if [[ -n "$encoded_data" && ${#encoded_data} -lt 50000 ]]; then
        # Try API upload
        if _exists "curl"; then
            response=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -H "User-Agent: BenchScript/2.0" \
                --connect-timeout 10 --max-time 30 \
                -d "{\"data\":\"$encoded_data\"}" \
                https://benchmark.bibica.net/api/upload 2>/dev/null)
            
            if echo "$response" | grep -q '"success":true' && echo "$response" | grep -q '"url"'; then
                benchmark_url=$(echo "$response" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p')
            fi
        fi
        
        # Fallback method if API failed or curl not available
        [[ -z "$benchmark_url" ]] && benchmark_url="https://benchmark.bibica.net/#${encoded_data}"
        
        _yellow "Benchmark completed"
        echo
        echo -n "Short URL: " && _blue "$benchmark_url"
    else
        echo
        _red "Cannot generate shareable URL - Results too large or encoding failed"
    fi
    
	echo
    # Cleanup
    rm -rf speedtest-cli benchtest_* ./*.log ./speedtest.log /tmp/benchmark_* /tmp/speedtest* 2>/dev/null
}

# Main execution
start_time=$(date +%s)
get_system_info
check_virt
upload_results
