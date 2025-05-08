#!/bin/bash

# LEToolkit Live - Log Analyzer Tool
# Purpose: Analyze system logs to help diagnose boot and system issues

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to get target system mount point
get_target_system() {
    print_header "Target System Selection"
    
    # List all mounted filesystems
    echo -e "${YELLOW}Available mounted filesystems:${NC}"
    df -h | grep -v "tmpfs\|udev\|devtmpfs"
    
    echo -e "\n${YELLOW}Please enter the mount point of the target system (e.g., /mnt/target):${NC}"
    read -p "Mount point: " TARGET_SYSTEM
    
    if [ ! -d "$TARGET_SYSTEM" ]; then
        echo -e "${RED}Error: Invalid mount point${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Target system set to: $TARGET_SYSTEM${NC}"
}

# Function to analyze log file
analyze_log() {
    local log_file="$1"
    local log_name="$2"
    
    if [ -f "$log_file" ]; then
        print_header "Analyzing $log_name"
        
        # Count total errors
        local total_errors=$(grep -i "fail\|error\|critical\|fatal" "$log_file" | wc -l)
        echo -e "${YELLOW}Total errors found: $total_errors${NC}"
        
        if [ "$total_errors" -gt 0 ]; then
            # Get most common errors
            echo -e "\n${CYAN}Most common errors:${NC}"
            grep -i "fail\|error\|critical\|fatal" "$log_file" | \
                sort | uniq -c | sort -nr | head -n 10 | \
                awk -v red="$RED" -v yellow="$YELLOW" -v nc="$NC" \
                '{printf "%s%4d%s - %s\n", yellow, $1, nc, $0}'
            
            # Get recent errors
            echo -e "\n${CYAN}Recent errors:${NC}"
            grep -i "fail\|error\|critical\|fatal" "$log_file" | tail -n 5 | \
                awk -v red="$RED" -v nc="$NC" \
                '{gsub(/fail|error|critical|fatal/, red "&" nc, $0); print}'
        fi
    else
        echo -e "${RED}Log file not found: $log_file${NC}"
    fi
}

# Function to analyze journal logs
analyze_journal() {
    print_header "Analyzing System Journal"
    
    # Get journal errors
    local journal_errors=$(chroot "$TARGET_SYSTEM" journalctl -p err -b 2>/dev/null)
    
    if [ -n "$journal_errors" ]; then
        echo -e "${YELLOW}Journal errors found:${NC}"
        echo "$journal_errors" | \
            awk -v red="$RED" -v yellow="$YELLOW" -v nc="$NC" \
            '{gsub(/fail|error|critical|fatal/, red "&" nc, $0); print}'
    else
        echo -e "${GREEN}No journal errors found${NC}"
    fi
}

# Function to analyze dmesg
analyze_dmesg() {
    print_header "Analyzing dmesg"
    
    # Get dmesg errors
    local dmesg_errors=$(chroot "$TARGET_SYSTEM" dmesg -T 2>/dev/null | grep -i "fail\|error\|critical\|fatal")
    
    if [ -n "$dmesg_errors" ]; then
        echo -e "${YELLOW}dmesg errors found:${NC}"
        echo "$dmesg_errors" | \
            awk -v red="$RED" -v yellow="$YELLOW" -v nc="$NC" \
            '{gsub(/fail|error|critical|fatal/, red "&" nc, $0); print}'
    else
        echo -e "${GREEN}No dmesg errors found${NC}"
    fi
}

# Main execution
echo -e "${GREEN}LEToolkit Live - Log Analyzer Tool${NC}"

# Check if running as root
check_root

# Get target system mount point
get_target_system

# Analyze various log files
analyze_log "$TARGET_SYSTEM/var/log/syslog" "System Log"
analyze_log "$TARGET_SYSTEM/var/log/boot.log" "Boot Log"
analyze_log "$TARGET_SYSTEM/var/log/auth.log" "Authentication Log"
analyze_log "$TARGET_SYSTEM/var/log/kern.log" "Kernel Log"

# Analyze journal and dmesg
analyze_journal
analyze_dmesg

echo -e "\n${GREEN}Log analysis complete.${NC}"
echo -e "${YELLOW}Note: Some errors might be normal during boot or system operation.${NC}" 
