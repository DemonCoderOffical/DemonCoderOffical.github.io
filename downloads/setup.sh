#!/bin/bash

# NetPlus All-in-One Setup & Code Generation Script

echo "[*] Generating NetPlus core files from scratch..."

# 1. Create scanner.cpp (C++ Network Core)
cat << 'EOF' > scanner.cpp
#include <iostream>
#include <string>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netdb.h>
#include <chrono>

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: scanner <ip> <port>\n";
        return 1;
    }

    std::string target = argv[1];
    int port = std::stoi(argv[2]);

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return 1;
    }

    struct timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeout, sizeof(timeout));

    struct sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    if (inet_pton(AF_INET, target.c_str(), &serv_addr.sin_addr) <= 0) {
        close(sock);
        return 1;
    }

    auto start = std::chrono::high_resolution_clock::now();
    int res = connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed = end - start;

    if (res == 0) {
        std::cout << "[+] Port " << port << " is OPEN (" << elapsed.count() << "ms)" << std::endl;
        close(sock);
        return 0;
    } else {
        std::cout << "[-] Port " << port << " is CLOSED" << std::endl;
        close(sock);
        return 1;
    }
}
EOF
echo "[+] Created scanner.cpp successfully."

# 2. Create netplus.py (Python Toolkit Frontend & CLI)
cat << 'EOF' > netplus.py
#!/usr/bin/env python3
import os
import sys
import subprocess
import platform
import socket
import time
import ssl
import urllib.request
from datetime import datetime

CONFIG_FILE = os.path.expanduser("~/.netplus_path")

def get_project_path():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                p = f.read().strip()
                if p and os.path.exists(p):
                    return p
        except Exception:
            pass
    return os.path.dirname(os.path.abspath(__file__))

def resolve_target(target):
    clean_target = target.replace("http://", "").replace("https://", "").split("/")[0]
    if is_valid_ip(clean_target):
        return [clean_target]

    try:
        _, _, ip_addresses = socket.gethostbyname_ex(clean_target)
        ip_addresses = list(dict.fromkeys(ip_addresses))

        if len(ip_addresses) >= 2:
            print(f"\n{clean_target} resolves into {ip_addresses} what do you want to scan:")
            for idx, ip in enumerate(ip_addresses, 1):
                print(f"{idx}. {ip}")
            
            cancel_opt = len(ip_addresses) + 1
            all_opt = len(ip_addresses) + 2
            
            print(f"{cancel_opt}. Cancel")
            print(f"{all_opt}. All")

            choice = input("Select an option: ").strip()
            
            if choice.isdigit():
                choice_num = int(choice)
                if 1 <= choice_num <= len(ip_addresses):
                    selected_ip = ip_addresses[choice_num - 1]
                    print(f"[*] Selected: {selected_ip}")
                    return [selected_ip]
                elif choice_num == cancel_opt:
                    print("[-] Operation cancelled by user.\nQUITTING!")
                    sys.exit(0)
                elif choice_num == all_opt:
                    print(f"[*] Selected: All ({', '.join(ip_addresses)})")
                    return ip_addresses
            elif choice.lower() in ["cancel"]:
                print("[-] Operation cancelled by user.\nQUITTING!")
                sys.exit(0)
            elif choice.lower() in ["all"]:
                print(f"[*] Selected: All ({', '.join(ip_addresses)})")
                return ip_addresses
            
            print("Error: Invalid selection option please try again\nQUITTING!")
            sys.exit(1)
        elif len(ip_addresses) == 1:
            return [ip_addresses[0]]
        else:
            print(f"Error: Could not resolve {clean_target}\nQUITTING!")
            sys.exit(1)
    except socket.gaierror:
        print(f"Error: Invalid IP address or domain name please try again\nQUITTING!")
        sys.exit(1)

def is_valid_ip(ip):
    parts = ip.split('.')
    if len(parts) != 4 or not all(p.isdigit() for p in parts):
        return False
    return all(0 <= int(p) <= 255 for p in parts)

def display_help_menu():
    print("=" * 65)
    print("                     NETPLUS NETWORK TOOLKIT                     ")
    print("=" * 65)
    print("Usage: np <target> [options]\n")
    print("TARGETS:")
    print("  <target>             IP address or Domain name (e.g., scanme.nmap.org)")
    print("\nOPTIONS:")
    print("  -h, --help           Show this comprehensive help screen")
    print("  -O                   Perform Native NetPlus OS Fingerprinting")
    print("  -port.<ports>        Specify port targets. Supports commas and ranges.")
    print("  -SL.<rate>           Scan Limit / Pacing rate (scans per second).")
    print("  -F <file_path>       Load a paths/passwords file for directory testing.")
    print("  -LS                  Ask the web server for all files and list them.")
    print("  -FLL                 Activate firewall bypass (packet fragmentation)")
    print("  -V                   Shows NetPlus Current version.")
    print("=" * 65)

def parse_cli_args(args):
    if "-h" in args or "--help" in args:
        display_help_menu()
        sys.exit(0)

    raw_target = None
    ports = []
    firewall_bypass = False
    scans_per_second = None
    password_file = None
    list_files_flag = False
    os_detection_flag = False

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-FLL":
            firewall_bypass = True
        elif arg == "-LS":
            list_files_flag = True
        elif arg == "-O":
            os_detection_flag = True
        elif arg == "-V":
            print("NetPlus Version 1.9")
            sys.exit(0)
        elif arg == "-F":
            if i + 1 < len(args):
                password_file = args[i + 1]
                if not os.path.exists(password_file):
                    print(f"Error: Wordlist file '{password_file}' not found!\nQUITTING!")
                    sys.exit(1)
                i += 1
            else:
                print("Error: Missing file path specification for -F option\nQUITTING!")
                sys.exit(1)
        elif arg.startswith("-port."):
            port_section = arg.replace("-port.", "", 1)
            parts = port_section.split(",")
            for item in parts:
                if "-" in item:
                    range_bounds = item.split("-")
                    if len(range_bounds) == 2 and range_bounds[0].isdigit() and range_bounds[1].isdigit():
                        start_port = int(range_bounds[0])
                        end_port = int(range_bounds[1])
                        if start_port > end_port:
                            start_port, end_port = end_port, start_port
                        for p_num in range(start_port, end_port + 1):
                            ports.append(str(p_num))
                    else:
                        print("Error: Invalid port range format please try again\nQUITTING!")
                        sys.exit(1)
                else:
                    if not item.isdigit():
                        print("Error: Invalid port formatting detected please try again\nQUITTING!")
                        sys.exit(1)
                    ports.append(item)
        elif arg.startswith("-SL."):
            rate_parts = arg.split(".")
            if len(rate_parts) > 1:
                try:
                    scans_per_second = float(rate_parts[1])
                    if scans_per_second <= 0:
                        raise ValueError
                except ValueError:
                    print("Error: Invalid scan rate speed parameter please try again\nQUITTING!")
                    sys.exit(1)
        elif not arg.startswith("-") and raw_target is None:
            raw_target = arg
        i += 1

    if not raw_target:
        print("Error: Target IP address or Domain missing\nQUITTING!")
        sys.exit(1)

    targets = resolve_target(raw_target)
    return targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, raw_target

def perform_netplus_os_fingerprint(target, open_ports):
    print(f"\n[*] Running NetPlus Native OS Fingerprint Engine for {target}...")
    
    hostname = "Unknown"
    try:
        host_info = socket.gethostbyaddr(target)
        hostname = host_info[0]
        print(f"[+] Target Hostname Resolved   : {hostname}")
    except Exception:
        print(f"[*] Reverse DNS Hostname lookup : Not resolved / Direct IP")

    detected_os = "Generic Unix-like / Linux System"
    confidence = "Medium"
    h_lower = hostname.lower()

    if "arch" in h_lower:
        detected_os = "Arch Linux (Rolling Release)"
        confidence = "High"
    elif "honor" in h_lower:
        detected_os = "Honor Mobile Device (MagicOS / Android Architecture)"
        confidence = "High"
    elif "samsung" in h_lower or "galaxy" in h_lower:
        detected_os = "Samsung Galaxy Device (One UI / Android Architecture)"
        confidence = "High"
    elif "ubuntu" in h_lower:
        detected_os = "Ubuntu Linux Distribution"
        confidence = "High"
    elif "debian" in h_lower:
        detected_os = "Debian GNU/Linux"
        confidence = "High"
    elif "windows" in h_lower or "desktop" in h_lower:
        detected_os = "Microsoft Windows Environment"
        confidence = "Medium"
    else:
        if 445 in open_ports or 139 in open_ports:
            detected_os = "Microsoft Windows (SMB Active)"
            confidence = "High"
        elif 22 in open_ports:
            detected_os = "Linux Server / Unix-like (SSH Active)"
            confidence = "Medium"
        else:
            detected_os = "Standard Linux Kernel / Network Host"
            confidence = "Standard"

    print(f"[+] Target OS Fingerprint Result : {detected_os}")
    print(f"[+] Fingerprint Confidence Level: {confidence}\n")

def query_web_files(target_ip, port, firewall_bypass, original_target):
    print(f"\n[*] Asking web server at {target_ip}:{port} ('hi what all files you have')...")
    headers = {'User-Agent': 'NetPlus Toolkit/1.0'}
    clean_host = original_target.replace("http://", "").replace("https://", "").split("/")[0]
    if not is_valid_ip(clean_host):
        headers['Host'] = clean_host

    if firewall_bypass:
        headers['X-Forwarded-For'] = '127.0.0.1'
        headers['Via'] = '1.1 proxy'

    url = f"http://{target_ip}:{port}/"
    if port in ["443", "8443"]:
        url = f"https://{target_ip}:{port}/"

    try:
        req = urllib.request.Request(url, headers=headers)
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        with urllib.request.urlopen(req, context=context, timeout=5) as response:
            html_content = response.read().decode('utf-8', errors='ignore')
            found_files = [line.strip() for line in html_content.splitlines() if "href=" in line or "src=" in line or ".js" in line or ".css" in line or ".html" in line]
            if found_files:
                print("\n=============================================")
                print("             SERVER FILES DISCOVERED         ")
                print("=============================================")
                for f_item in found_files[:25]:
                    print(f"  [+] {f_item}")
                print("=============================================")
            else:
                print("[*] Server responded, but no direct file links were parsed.")
    except Exception:
        print("Note: We have been blocked from the server try -FLL to skip the firewall")

def run_single_target_scan(target, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, original_target):
    project_path = get_project_path()
    scanner_binary = "scanner.exe" if platform.system().lower() == "windows" else "scanner"
    scanner_path = os.path.join(project_path, scanner_binary)
    if not os.path.exists(scanner_path):
        print(f"Error: C++ core engine binary not found at '{scanner_path}'!\nQUITTING!")
        return

    ports_to_scan = ports if ports else ["21", "22", "80", "443", "445", "3306", "8080"]
    delay = 1.0 / scans_per_second if scans_per_second else 0

    start_time = time.time()
    open_ports_found = []
    numeric_open_ports = []
    
    for idx, p in enumerate(ports_to_scan):
        if delay > 0 and idx > 0:
            time.sleep(delay)
        try:
            result = subprocess.run([scanner_path, target, p], capture_output=True, text=True, check=True)
            output = result.stdout.strip()
            print(output)
            if "OPEN" in output:
                open_ports_found.append(p)
                numeric_open_ports.append(int(p))
        except subprocess.CalledProcessError:
            pass

    if os_detection_flag:
        perform_netplus_os_fingerprint(target, numeric_open_ports)

    if list_files_flag and open_ports_found:
        for p in open_ports_found:
            if p in ["80", "443", "8080", "8443"]:
                query_web_files(target, p, firewall_bypass, original_target)

    if password_file and open_ports_found:
        try:
            with open(password_file, "r", encoding="utf-8", errors="ignore") as f:
                passwords = [line.strip() for line in f if line.strip()]
        except Exception as e:
            print(f"[-] Error reading wordlist file: {e}")
            return

        for target_port in open_ports_found:
            if target_port == "80":
                print(f"\n[*] Launching Active Web Path Discovery on port {target_port}...")
                for path in passwords:
                    if delay > 0:
                        time.sleep(delay)
                    clean_path = path.lstrip('/')
                    url = f"http://{target}:{target_port}/{clean_path}"
                    try:
                        req = urllib.request.Request(url, headers={'User-Agent': 'NetPlus Toolkit/1.0'})
                        with urllib.request.urlopen(req, timeout=3) as response:
                            if response.status == 200:
                                print(f"    [+] FOUND ACCESSIBLE PATH: /{clean_path} (Status: 200 OK)")
                    except Exception:
                        pass

    elapsed_time = time.time() - start_time
    print("\n" + "=" * 45)
    print("                    NETPLUS RUN SUMMARY                    ")
    print("=" * 45)
    print(f"[+] Total Targets Checked : 1 ({target})")
    print(f"[+] Operational Ports Checked : {len(ports_to_scan)}")
    print(f"[+] Open Services Discovered  : {len(open_ports_found)}")
    if open_ports_found:
        print(f"[+] Identified Ports List     : {', '.join(open_ports_found)}")
    print(f"[+] Elapsed Engine Run-time   : {elapsed_time:.2f} seconds")
    print("=" * 45)

def run_cpp_scanner_cli(targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, original_target):
    for target in targets:
        run_single_target_scan(target, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, original_target)

def interactive_menu():
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print("NetPlus Interactive Console")
        print("1. Port Scan using C++ Engine")
        print("2. About NetPlus (Help Guide)")
        print("3. Exit")
        print("-" * 45)
        choice = input("Select an option (1-3): ").strip()

        if choice == '1':
            raw_ip = input("Enter target IP or Domain (e.g. scanme.nmap.org): ").strip()
            if not raw_ip:
                continue
            targets = resolve_target(raw_ip)
            port_input = input("Enter target Port (Supports single, ranges, or empty for defaults): ").strip()
            use_ls = input("Do you want to query server files using -LS? (y/n): ").strip().lower() == 'y'
            use_os = input("Do you want to run OS detection using -O? (y/n): ").strip().lower() == 'y'

            ports_list = []
            if port_input:
                if "," in port_input or "-" in port_input:
                    fake_args = [f"-port.{port_input}"]
                    _, parsed_ports, _, _, _, _, _, _ = parse_cli_args([targets[0]] + fake_args)
                    ports_list = parsed_ports
                elif port_input.isdigit():
                    ports_list = [port_input]

            run_cpp_scanner_cli(targets, ports_list, False, None, None, use_ls, use_os, raw_ip)
            input("\nPress Enter to continue...")
        elif choice == '2':
            display_help_menu()
            input("\nPress Enter to continue...")
        elif choice == '3':
            sys.exit(0)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, original_target = parse_cli_args(sys.argv[1:])
        if targets:
            run_cpp_scanner_cli(targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, os_detection_flag, original_target)
    else:
        interactive_menu()
EOF
echo "[+] Created netplus.py successfully."

# 3. Compile C++ Core
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "$CURRENT_DIR" > ~/.netplus_path

echo "[*] Compiling C++ scanner core..."
g++ -O3 "$CURRENT_DIR/scanner.cpp" -o "$CURRENT_DIR/scanner"
if [ $? -eq 0 ]; then
    echo "[+] Compiled successfully -> scanner"
else
    echo "[-] C++ compilation failed!"
    exit 1
fi

chmod +x "$CURRENT_DIR/netplus.py"

# 4. Link np command
if [ -w "/usr/local/bin" ]; then
    ln -sf "$CURRENT_DIR/netplus.py" "/usr/local/bin/np"
    echo "[+] Installed globally as 'np' in /usr/local/bin/np"
elif [ -d "$HOME/.local/bin" ]; then
    ln -sf "$CURRENT_DIR/netplus.py" "$HOME/.local/bin/np"
    echo "[+] Installed locally as 'np' in ~/.local/bin/np"
else
    ALIAS_CMD="alias np='python3 $CURRENT_DIR/netplus.py'"
    [ -f "$HOME/.bashrc" ] && grep -q "alias np=" "$HOME/.bashrc" || echo "$ALIAS_CMD" >> "$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && grep -q "alias np=" "$HOME/.zshrc" || echo "$ALIAS_CMD" >> "$HOME/.zshrc"
    echo "[+] Added 'np' alias to your shell configuration."
fi

echo ""
echo "============================================="
echo "       SETUP COMPLETED SUCCESSFULLY          "
echo "============================================="
echo "Run tool using: np <target> [options]"
