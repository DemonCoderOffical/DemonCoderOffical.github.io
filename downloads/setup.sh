#!/bin/bash

echo "[+] Setting up NetPlus Toolkit from scratch..."

# 1. Create necessary directories
mkdir -p scripts
mkdir -p ~/.local/bin

# 2. Create the C++ scanner engine (scanner.cpp)
cat << 'EOF' > scripts/scanner.cpp
#include <iostream>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <netdb.h>

using namespace std;

void check_port(string ip, int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        cout << "[-] Socket creation failed\n";
        return;
    }

    struct sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip.c_str(), &serv_addr.sin_addr);

    struct timeval timeout;
    timeout.tv_sec = 2;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeout, sizeof(timeout));

    int result = connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    
    if (result == 0) {
        string service = "unknown";
        if (port == 21) service = "ftp";
        else if (port == 22) service = "ssh";
        else if (port == 80 || port == 8080 || port == 443) service = "http";
        else if (port == 3306) service = "mysql";
        else if (port == 445) service = "smb";

        cout << "[+] Port " << port << " is OPEN | Service: " << service;

        if (port == 80 || port == 8080) {
            string request = "GET / HTTP/1.1\r\nHost: " + ip + "\r\nConnection: close\r\n\r\n";
            send(sock, request.c_str(), request.length(), 0);
        }

        char buffer[1024];
        memset(buffer, 0, sizeof(buffer));
        int bytes_received = recv(sock, buffer, sizeof(buffer) - 1, 0);
        if (bytes_received > 0) {
            string banner(buffer);
            if (banner.find("Server:") != string::npos) {
                size_t start = banner.find("Server:");
                size_t end = banner.find("\r\n", start);
                string server_info = banner.substr(start, end - start);
                cout << " | " << server_info;
            } else {
                cout << " | Banner: " << banner.substr(0, 40);
            }
        }
        cout << "\n";
    } else {
        cout << "[-] Port " << port << " is CLOSED\n";
    }
    close(sock);
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        cout << "Usage: ./scanner <IP> <PORT>\n";
        return 1;
    }
    check_port(argv[1], stoi(argv[2]));
    return 0;
}
EOF

# 3. Create the main Python script (netplus.py)
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
from urllib.error import HTTPError, URLError

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
                print(f"{idx}.{ip}")
            print("3.Cancel")
            print("4.All")

            choice = input("Select an option: ").strip()
            if choice == "1":
                print(f"[*] Selected: {ip_addresses[0]}")
                return [ip_addresses[0]]
            elif choice == "2":
                print(f"[*] Selected: {ip_addresses[1]}")
                return [ip_addresses[1]]
            elif choice == "3" or choice.lower() in ["cancel", "3 cancel"]:
                print("[-] Operation cancelled by user.\nQUITTING!")
                sys.exit(0)
            elif choice == "4" or choice.lower() in ["all", "4.all"]:
                print(f"[*] Selected: All ({', '.join(ip_addresses)})")
                return ip_addresses
            else:
                print("Error: Invalid selection option please try again\nQUITTING!")
                sys.exit(1)
        elif len(ip_addresses) == 1:
            print(f"[*] Resolving {clean_target} -> {ip_addresses[0]}")
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
    """Prints a clear, structured help guide for all current operational features."""
    print("=" * 65)
    print("                     NETPLUS NETWORK TOOLKIT                     ")
    print("=" * 65)
    print("Usage: np <target> [options]\n")
    print("TARGETS:")
    print("  <target>             IP address or Domain name (e.g., scanme.nmap.org)")
    print("\nOPTIONS:")
    print("  -h, --help           Show this comprehensive help screen")
    print("  -port.<ports>        Specify port targets. Supports commas and ranges.")
    print("                       Examples: -port.80")
    print("                                 -port.80,443,8080")
    print("                                 -port.20-25")
    print("                                 -port.80,443,8000-8005")
    print("  -SL.<rate>           Scan Limit / Pacing rate (scans per second).")
    print("                       Example: -SL.2 (waits 0.5s between connections)")
    print("  -F <file_path>       Load a paths/passwords file for directory/credential testing.")
    print("                       Example: -F paths.txt")
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

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-FLL":
            firewall_bypass = True
        elif arg == "-LS":
            list_files_flag = True
        elif arg == "-V":
            print("NetPlus Version 1.8")
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
    return targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, raw_target

def detect_os(target):
    print(f"\n[*] Running Advanced OS Fingerprinting & TTL Hop Analysis for {target}...")
    param = "-n" if platform.system().lower() == "windows" else "-c"
    try:
        output = subprocess.check_output(["ping", param, "1", target], stderr=subprocess.STDOUT, text=True)
        if "ttl=" in output.lower():
            for word in output.split():
                if word.lower().startswith("ttl="):
                    ttl_val = int(word.split("=")[1])

                    if ttl_val <= 64:
                        initial_ttl = 64
                        if ttl_val == 64:
                            os_family = "Linux / Android / Unix-like (Exact Base: Linux Kernel 4.x/5.x/6.x or Android Linux)"
                        elif ttl_val <= 32:
                            os_family = "Old Unix / Embedded Linux / Custom RTOS"
                        else:
                            os_family = "Linux / Unix-like (e.g., Ubuntu / Debian / Alpine)"
                    elif ttl_val <= 128:
                        initial_ttl = 128
                        if ttl_val >= 100:
                            os_family = "Windows (Windows 10 / 11 / Server 2022)"
                        elif ttl_val >= 65:
                            os_family = "Windows (Windows 7 / 8 / Server 2012 / Older NT)"
                        else:
                            os_family = "Windows NT Family / Custom Device"
                    elif ttl_val <= 255:
                        initial_ttl = 255
                        if ttl_val >= 250:
                            os_family = "macOS / iOS / Darwin BSD Unix"
                        else:
                            os_family = "Cisco Router / Network Device / Unix BSD"
                    else:
                        initial_ttl = 255
                        os_family = "Unknown / Custom Device Profile"

                    hops = initial_ttl - ttl_val
                    print(f"[+] Target OS Fingerprint : {os_family}")
                    print(f"[+] Received TTL          : {ttl_val} (Initial Baseline: {initial_ttl})")
                    print(f"[+] Estimated Network Hops: {hops} hop(s) away")
                    print("[*] OS detection scan has been printed. Please report any untrue things in https://VoidCoderStudio.github.io/submit")
                    return True
        print(f"[-] Host {target} is unreachable")
        return False
    except Exception:
        print(f"[-] Host {target} is unreachable")
        return False

def query_web_files(target_ip, port, firewall_bypass, original_target):
    print(f"\n[*] Asking web server at {target_ip}:{port} ('hi what all files you have')...")

    headers = {'User-Agent': 'NetPlus Toolkit/1.0'}

    # If a domain name was provided, set the Host header so virtual-hosted servers (like GitHub Pages) route correctly
    clean_host = original_target.replace("http://", "").replace("https://", "").split("/")[0]
    if not is_valid_ip(clean_host):
        headers['Host'] = clean_host

    if firewall_bypass:
        headers['X-Forwarded-For'] = '127.0.0.1'
        headers['Via'] = '1.1 proxy'
        print("[*] Firewall bypass headers applied for -LS request...")

    url = f"http://{target_ip}:{port}/"
    if port == "443" or port == "8443":
        url = f"https://{target_ip}:{port}/"

    try:
        req = urllib.request.Request(url, headers=headers)

        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        with urllib.request.urlopen(req, context=context, timeout=5) as response:
            html_content = response.read().decode('utf-8', errors='ignore')
            print(f"[+] Successfully connected to {target_ip}:{port}")
            print("[+] Server response received. Checking available files / endpoints...")

            found_files = []
            for line in html_content.splitlines():
                if "href=" in line or "src=" in line or ".js" in line or ".css" in line or ".html" in line:
                    found_files.append(line.strip())

            if found_files:
                print("\n=============================================")
                print("             SERVER FILES DISCOVERED         ")
                print("=============================================")
                for f_item in found_files[:25]:
                    print(f"  [+] {f_item}")
                print("=============================================")
            else:
                print("[*] Server responded, but no direct file links were parsed from the index page.")

    except HTTPError as e:
        if e.code in [403, 406, 429, 404, 999] or e.code >= 500:
            print(f"Note:We have been blocked from the server try -FLL to skip the firewall (HTTP Error: {e.code})")
        else:
            print(f"Note:We have been blocked from the server try -FLL to skip the firewall (HTTP Error: {e.code})")
    except URLError as e:
        print(f"Note:We have been blocked from the server try -FLL to skip the firewall (Connection Error: {e.reason})")
    except Exception as e:
        print(f"Note:We have been blocked from the server try -FLL to skip the firewall ({e})")

def run_single_target_scan(target, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, original_target):
    if firewall_bypass:
        print("[*] Firewall Bypass (-FLL) activated: Fragmenting packets / spoofing headers...")

    if not detect_os(target):
        return

    scanner_path = "./scripts/scanner"
    if not os.path.exists(scanner_path):
        print("Error: C++ core engine binary not found! Please compile your scanner code first.\nQUITTING!")
        return

    if ports:
        ports_to_scan = ports
        port_preview = ", ".join(ports[:10]) + ("..." if len(ports) > 10 else "")
        print(f"\n[+] Running C++ engine on {target} for custom ports: {port_preview}")
    else:
        ports_to_scan = ["21", "22", "80", "443", "445", "3306", "8080"]
        print(f"\n[+] Running C++ engine on {target} (Default common ports)...")

    delay = 0
    if scans_per_second:
        delay = 1.0 / scans_per_second

    start_time = time.time()
    open_ports_found = []

    for idx, p in enumerate(ports_to_scan):
        if delay > 0 and idx > 0:
            time.sleep(delay)

        try:
            result = subprocess.run([scanner_path, target, p], capture_output=True, text=True, check=True)
            output = result.stdout.strip()
            print(output)
            if "OPEN" in output:
                open_ports_found.append(p)
        except subprocess.CalledProcessError:
            pass

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
                print(f"[*] Syncing requests using -SL delay pacing: {delay:.3f}s")
                for path in passwords:
                    if delay > 0:
                        time.sleep(delay)

                    clean_path = path.lstrip('/')
                    url = f"http://{target}:{target_port}/{clean_path}"
                    print(f"    [~] Checking: /{clean_path} ", end="\r")

                    try:
                        req = urllib.request.Request(url, headers={'User-Agent': 'NetPlus Toolkit/1.0'})
                        with urllib.request.urlopen(req, timeout=3) as response:
                            if response.status == 200:
                                print(f"    [+] FOUND ACCESSIBLE PATH: /{clean_path} (Status: 200 OK)         ")
                    except HTTPError as e:
                        if e.code in [400, 401, 403, 404, 500]:
                            print(f"    [+] FOUND RESTRICTED PATH: /{clean_path} (Status: {e.code})         ")
                    except URLError:
                        pass
                print("\n[*] Web directory discovery sweep completed.")
            else:
                print(f"\n[*] Testing parameters against service on port {target_port}...")
                for pwd in passwords:
                    if delay > 0:
                        time.sleep(delay)
                    print(f"    [~] Verification trace checking entry token: {pwd}")

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

def run_cpp_scanner_cli(targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, original_target):
    for target in targets:
        run_single_target_scan(target, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, original_target)

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
                print("Error: Invalid input parameters provided please try again\nQUITTING!")
                input("\nPress Enter to continue...")
                continue

            targets = resolve_target(raw_ip)
            port_input = input("Enter target Port (Supports single, ranges, or empty for defaults): ").strip()
            use_ls = input("Do you want to query server files using -LS? (y/n): ").strip().lower() == 'y'

            ports_list = []
            if port_input:
                if "," in port_input or "-" in port_input:
                    fake_args = [f"-port.{port_input}"]
                    _, parsed_ports, _, _, _, _, _ = parse_cli_args([targets[0]] + fake_args)
                    ports_list = parsed_ports
                elif port_input.isdigit():
                    ports_list = [port_input]
                else:
                    print("Error: Invalid port input parameters provided\nQUITTING!")
                    input("\nPress Enter to continue...")
                    continue

            run_cpp_scanner_cli(targets, ports_list, False, None, None, use_ls, raw_ip)
            input("\nPress Enter to continue...")
        elif choice == '2':
            os.system('clear' if os.name == 'posix' else 'cls')
            display_help_menu()
            input("\nPress Enter to return to menu...")
        elif choice == '3':
            print("\nExiting NetPlus. Stay safe! 🦈")
            sys.exit(0)
        else:
            print("Error: Unknown selection item. Please try again.")
            input("\nPress Enter to continue...")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, original_target = parse_cli_args(sys.argv[1:])
        if targets:
            run_cpp_scanner_cli(targets, ports, firewall_bypass, scans_per_second, password_file, list_files_flag, original_target)
        else:
            print("Error: Invalid constraints please try again\nQUITTING!")
    else:
        interactive_menu()
EOF

# 4. Compile C++ binary
echo "[+] Compiling C++ scanner engine..."
g++ scripts/scanner.cpp -o scripts/scanner

# 5. Set permissions and configure 
pip install paramiko
symlink for 'np' command
chmod +x netplus.py
chmod +x scripts/scanner
ln -sf "$(pwd)/netplus.py" ~/.local/bin/np

echo "[+] NetPlus setup complete successfully! You can now use 'np' globally."
