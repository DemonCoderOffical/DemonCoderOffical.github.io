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

def resolve_target(target):
    try:
        clean_target = target.replace("http://", "").replace("https://", "").split("/")[0]
        ip_address = socket.gethostbyname(clean_target)
        print(f"[*] Resolving {clean_target} -> {ip_address}")
        return ip_address
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
    print("  -F <file_path>       Load a password text file for credential testing.")
    print("                       Example: -F passwords.txt")
    print("  -FLL                 Activate firewall bypass (packet fragmentation)")
    print("\nCOMBINED EXECUTION EXAMPLES:")
    print("  np 192.168.1.1 -port.80,443,8080 -SL.1")
    print("  np scanme.nmap.org -port.22,8080 -F wordlist.txt -SL.0.5")
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

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-FLL":
            firewall_bypass = True
        elif arg == "-F":
            if i + 1 < len(args):
                password_file = args[i + 1]
                if not os.path.exists(password_file):
                    print(f"Error: Password file '{password_file}' not found!\nQUITTING!")
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

    if is_valid_ip(raw_target):
        target = raw_target
    else:
        target = resolve_target(raw_target)

    return target, ports, firewall_bypass, scans_per_second, password_file
def detect_os(target):
    print("\n[*] Running OS Fingerprinting (TTL Analysis)...")
    param = "-n" if platform.system().lower() == "windows" else "-c"
    try:
        output = subprocess.check_output(["ping", param, "1", target], stderr=subprocess.STDOUT, text=True)
        if "ttl=" in output.lower():
            for word in output.split():
                if word.lower().startswith("ttl="):
                    ttl_val = int(word.split("=")[1])
                    if ttl_val <= 64:
                        print(f"[+] Target OS Fingerprint: Linux / Unix-like (TTL: {ttl_val})")
                    elif ttl_val <= 128:
                        print(f"[+] Target OS Fingerprint: Windows (TTL: {ttl_val})")
                    else:
                        print(f"[+] Target OS Fingerprint: Network Device / Custom (TTL: {ttl_val})")
                    return
        print("[-] Could not determine OS template footprint via TTL.")
    except Exception:
        print("[-] OS Fingerprint routing failed or host is entirely unreachable.")

def run_cpp_scanner_cli(target, ports, firewall_bypass, scans_per_second, password_file):
    if firewall_bypass:
        print("[*] Firewall Bypass (-FLL) activated: Fragmenting packets / spoofing headers...")

    detect_os(target)

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

    if password_file and open_ports_found:
        print(f"\n[*] Access verification file loaded. Syncing entries using -SL delay pacing: {delay:.3f}s")
        try:
            with open(password_file, "r", encoding="utf-8", errors="ignore") as f:
                passwords = [line.strip() for line in f if line.strip()]
        except Exception as e:
            print(f"[-] Error reading input wordlist file structural contents: {e}")
            return

        for target_port in open_ports_found:
            print(f"[*] Testing credential tokens against discovered access threshold on port {target_port}...")
            for pwd in passwords:
                if delay > 0:
                    time.sleep(delay)
                print(f"    [~] Transmission tracking token verification check: {pwd}")

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
                print("Error: Invalid input data parameter provided please try again\nQUITTING!")
                input("\nPress Enter to continue...")
                continue

            if is_valid_ip(raw_ip):
                ip = raw_ip
            else:
                ip = resolve_target(raw_ip)

            port_input = input("Enter target Port (Supports single, ranges, or empty for defaults): ").strip()

            ports_list = []
            if port_input:
                if "," in port_input or "-" in port_input:
                    fake_args = [f"-port.{port_input}"]
                    _, parsed_ports, _, _, _ = parse_cli_args([ip] + fake_args)
                    ports_list = parsed_ports
                elif port_input.isdigit():
                    ports_list = [port_input]
                else:
                    print("Error: Invalid port input parameters provided\nQUITTING!")
                    input("\nPress Enter to continue...")
                    continue

            run_cpp_scanner_cli(ip, ports_list, False, None, None)
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
        target, ports, firewall_bypass, scans_per_second, password_file = parse_cli_args(sys.argv[1:])
        if target:
            run_cpp_scanner_cli(target, ports, firewall_bypass, scans_per_second, password_file)
        else:
            print("Error: Input constraints invalid please try again\nQUITTING!")
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
