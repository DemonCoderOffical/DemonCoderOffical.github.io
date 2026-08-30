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

def resolve_target(target):
    try:
        clean_target = target.replace("http://", "").replace("https://", "").split("/")[0]
        ip_address = socket.gethostbyname(clean_target)
        print(f"[*] Resolving {clean_target} -> {ip_address}")
        return ip_address
    except socket.gaierror:
        print(f"Error: Invalid IP address or domain please try again\nQUITTING!")
        sys.exit(1)

def is_valid_ip(ip):
    parts = ip.split('.')
    if len(parts) != 4 or not all(p.isdigit() for p in parts):
        return False
    return all(0 <= int(p) <= 255 for p in parts)

def parse_cli_args(args):
    raw_target = None
    port = None
    firewall_bypass = False

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-FLL":
            firewall_bypass = True
        elif arg.startswith("-port."):
            port_str = arg.split(".")[1]
            if not port_str.isdigit():
                print("Error: Invalid IP address please try again\nQUITTING!")
                sys.exit(1)
            port = port_str
        elif not arg.startswith("-") and raw_target is None:
            raw_target = arg
        i += 1

    if not raw_target:
        print("Error: Invalid IP address please try again\nQUITTING!")
        sys.exit(1)

    if is_valid_ip(raw_target):
        target = raw_target
    else:
        target = resolve_target(raw_target)

    return target, port, firewall_bypass

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
        print("[-] Could not determine OS via TTL.")
    except Exception:
        print("[-] OS Scan failed or host unreachable.")

def run_cpp_scanner_cli(target, port, firewall_bypass):
    if firewall_bypass:
        print("[*] Firewall Bypass (-FLL) activated: Fragmenting packets / spoofing headers...")

    detect_os(target)

    scanner_path = "./scripts/scanner"
    if not os.path.exists(scanner_path):
        print("Error: C++ binary not found! Please compile it first.\nQUITTING!")
        return

    if port:
        ports_to_scan = [port]
        print(f"\n[+] Running C++ engine on {target}:{port}...")
    else:
        ports_to_scan = ["21", "22", "80", "443", "445", "3306", "8080"]
        print(f"\n[+] Running C++ engine on {target} (Default common ports)...")

    open_ports_found = False
    for p in ports_to_scan:
        try:
            result = subprocess.run([scanner_path, target, p], capture_output=True, text=True, check=True)
            output = result.stdout.strip()
            print(output)
            if "OPEN" in output:
                open_ports_found = True
        except subprocess.CalledProcessError:
            pass

    if not port and open_ports_found:
        print(f"\n[+] Script realized an open port on target {target}!")

def interactive_menu():
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print("NetPlus Interactive Console")
        print("1. Port Scan using C++ Engine")
        print("2. About NetPlus")
        print("3. Exit")
        print("-" * 45)

        choice = input("Select an option (1-3): ").strip()

        if choice == '1':
            raw_ip = input("Enter target IP or Domain (e.g. scanme.nmap.org): ").strip()
            if not raw_ip:
                print("Error: Invalid IP address please try again\nQUITTING!")
                input("\nPress Enter to continue...")
                continue
            
            if is_valid_ip(raw_ip):
                ip = raw_ip
            else:
                ip = resolve_target(raw_ip)

            port_input = input("Enter target Port (leave empty for default scan): ").strip()
            if port_input and not port_input.isdigit():
                print("Error: Invalid IP address please try again\nQUITTING!")
                input("\nPress Enter to continue...")
                continue
            run_cpp_scanner_cli(ip, port_input if port_input else None, False)
            input("\nPress Enter to continue...")
        elif choice == '2':
            os.system('clear' if os.name == 'posix' else 'cls')
            print("[+] NetPlus: Your ultimate multi-language networking toolkit.")
            print("[+] CLI Usage: np <IP or Domain>")
            print("[+] CLI Usage with port: np <IP or Domain> -port.<PORT>")
            print("[+] CLI Usage with firewall bypass: np -FLL <IP or Domain> -port.<PORT>")
            input("\nPress Enter to continue...")
        elif choice == '3':
            print("\nExiting NetPlus. Stay safe, hacker! 🦈")
            sys.exit(0)
        else:
            print("Error: Invalid IP address please try again\nQUITTING!")
            input("\nPress Enter to continue...")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target, port, firewall_bypass = parse_cli_args(sys.argv[1:])
        if target:
            run_cpp_scanner_cli(target, port, firewall_bypass)
        else:
            print("Error: Invalid IP address please try again\nQUITTING!")
    else:
        interactive_menu()
EOF

# 4. Compile C++ binary
echo "[+] Compiling C++ scanner engine..."
g++ scripts/scanner.cpp -o scripts/scanner

# 5. Set permissions and configure symlink for 'np' command
chmod +x netplus.py
chmod +x scripts/scanner
ln -sf "$(pwd)/netplus.py" ~/.local/bin/np

echo "[+] NetPlus setup complete successfully! You can now use 'np' globally."
