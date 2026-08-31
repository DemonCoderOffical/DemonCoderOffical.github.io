cat << 'EOF' > setup.sh
#!/bin/bash

# ==============================================================================
#      NETPLUS ENTERPRISE ULTIMATE v2.6 - HOSTNAME RESOLUTION & FINGERPRINT
# ==============================================================================

echo "[*] Initializing NetPlus Enterprise Build (v2.6)..."

# ------------------------------------------------------------------------------
# 1. SCANNER.CPP (High-Performance C++ Socket Engine)
# ------------------------------------------------------------------------------
cat << 'EOF_CPP' > scanner.cpp
#include <iostream>
#include <string>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netdb.h>
#include <chrono>
#include <fcntl.h>
#include <netinet/ip.h>

int main(int argc, char* argv[]) {
    if (argc < 3) return 1;

    std::string target = argv[1];
    int port = std::stoi(argv[2]);
    bool bypass = (argc > 3 && std::string(argv[3]) == "FLL");

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return 1;

    int flags = fcntl(sock, F_GETFL, 0);
    fcntl(sock, F_SETFL, flags | O_NONBLOCK);

    if (bypass) {
        int ttl_val = 64;
        setsockopt(sock, IPPROTO_IP, IP_TTL, &ttl_val, sizeof(ttl_val));
    }

    struct sockaddr_in serv_addr;
    std::memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    if (inet_pton(AF_INET, target.c_str(), &serv_addr.sin_addr) <= 0) {
        close(sock);
        return 1;
    }

    auto start_time = std::chrono::high_resolution_clock::now();
    int res = connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
    
    fd_set fdset;
    FD_ZERO(&fdset);
    FD_SET(sock, &fdset);

    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 500000;

    if (res < 0) {
        if (errno == EINPROGRESS) {
            int select_res = select(sock + 1, NULL, &fdset, NULL, &tv);
            if (select_res > 0) {
                int err = 0;
                socklen_t lon = sizeof(err);
                if (getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &lon) < 0 || err) {
                    close(sock);
                    std::cout << "[-] Port " << port << " is CLOSED\n";
                    return 1;
                }
            } else {
                close(sock);
                std::cout << "[-] Port " << port << " is CLOSED (Timeout)\n";
                return 1;
            }
        } else {
            close(sock);
            std::cout << "[-] Port " << port << " is CLOSED\n";
            return 1;
        }
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed = end_time - start_time;

    std::cout << "[+] Port " << port << " is OPEN (" << elapsed.count() << "ms)" 
              << (bypass ? " [FLL Bypass Active]" : "") << "\n";

    close(sock);
    return 0;
}
EOF_CPP
echo "[+] scanner.cpp generated."

# ------------------------------------------------------------------------------
# 2. NETPLUS.PY (Python Engine with Automatic Hostname & Server Fingerprint)
# ------------------------------------------------------------------------------
cat << 'EOF_PY' > netplus.py
#!/usr/bin/env python3
import os
import sys
import subprocess
import socket
import time
import ssl
import urllib.request

VERSION = "2.6 Enterprise Hostname Edition"

def locate_binary():
    paths = [
        "/usr/local/bin/scanner",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "scanner"),
        os.path.expanduser("~/../usr/bin/scanner"),
        "scanner"
    ]
    for p in paths:
        if os.path.exists(p):
            return p
    return "scanner"

def resolve_target_address(target_input):
    clean = target_input.replace("http://", "").replace("https://", "").split("/")[0]
    
    # Try to fetch Hostname (Reverse DNS lookup) if an IP address is provided
    resolved_hostname = "N/A (Direct IP)"
    try:
        host_info = socket.gethostbyaddr(clean)
        resolved_hostname = host_info[0]
    except Exception:
        try:
            # If input is a domain name, get IP and verify hostname
            ip_addr = socket.gethostbyname(clean)
            resolved_hostname = clean
            clean = ip_addr
        except socket.gaierror:
            pass

    if validate_ip_format(clean):
        return clean, resolved_hostname
        
    try:
        resolved_ip = socket.gethostbyname(clean)
        return resolved_ip, clean
    except socket.gaierror:
        print(f"Error: Invalid IP address or domain name specification -> {target_input}\nQUITTING!")
        sys.exit(1)

def validate_ip_format(ip_str):
    octets = ip_str.split('.')
    if len(octets) != 4 or not all(o.isdigit() for o in octets):
        return False
    return all(0 <= int(o) <= 255 for o in octets)

def parse_arguments(argv):
    target_raw = None
    ports_list = []
    fll_bypass = False

    idx = 0
    while idx < len(argv):
        arg = argv[idx]
        if arg == "-FLL":
            fll_bypass = True
        elif arg.startswith("-port."):
            section = arg.replace("-port.", "", 1)
            for chunk in section.split(","):
                if "-" in chunk:
                    bounds = chunk.split("-")
                    if len(bounds) == 2 and bounds[0].isdigit() and bounds[1].isdigit():
                        for p in range(int(bounds[0]), int(bounds[1]) + 1):
                            ports_list.append(str(p))
                elif chunk.isdigit():
                    ports_list.append(chunk)
        elif not arg.startswith("-") and target_raw is None:
            target_raw = arg
        idx += 1

    if not target_raw:
        print("Error: Target specification missing\nQUITTING!")
        sys.exit(1)

    target_ip, target_hostname = resolve_target_address(target_raw)
    return target_ip, target_hostname, ports_list, fll_bypass, target_raw

def inspect_running_server(target_ip, port, fll_bypass, original_target):
    print(f"\n    [🔍] Initiating deep service fingerprinting on {target_ip}:{port}...")
    
    protocols = ["http", "https"]
    for proto in protocols:
        url = f"{proto}://{target_ip}:{port}/"
        headers = {'User-Agent': 'NetPlus Enterprise Auditor/2.6'}
        
        if fll_bypass:
            headers['X-Forwarded-For'] = '127.0.0.1'
            headers['Via'] = '1.1 NetPlus-Enterprise-Gateway'

        try:
            req = urllib.request.Request(url, headers=headers)
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            with urllib.request.urlopen(req, context=ctx, timeout=3) as response:
                srv = response.headers.get('Server', 'Hidden / Custom Web Server')
                powered = response.headers.get('X-Powered-By', 'Not Specified')
                
                print(f"        [+] Protocol Verified     : {proto.upper()}")
                print(f"        [+] Running Server Daemon : {srv}")
                print(f"        [+] Backend Technology    : {powered}")
                print(f"        [+] HTTP Response Status  : {response.status} {response.reason}")
                return
        except urllib.error.HTTPError as he:
            srv = he.headers.get('Server', 'Hidden / Custom Web Server')
            print(f"        [+] Protocol Verified     : {proto.upper()} (HTTP Status Error)")
            print(f"        [+] Running Server Daemon : {srv}")
            print(f"        [+] Response Error Code   : {he.code} {he.reason}")
            return
        except Exception:
            pass

    try:
        sock_banner = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock_banner.settimeout(2.0)
        sock_banner.connect((target_ip, int(port)))
        raw_data = sock_banner.recv(1024).decode('utf-8', errors='ignore').strip()
        sock_banner.close()
        if raw_data:
            print(f"        [+] Raw Banner Captured   : {raw_data}")
        else:
            print(f"        [-] Raw Service Status    : Port open but silent daemon")
    except Exception:
        print(f"        [-] Service Fingerprint   : Standard TCP Listener")

def execute_scan_routine(target_ip, target_hostname, ports, fll_bypass, original_target):
    binary_path = locate_binary()
    if not os.path.exists(binary_path):
        print(f"Error: C++ core engine binary missing at '{binary_path}'!")
        return

    default_ports = ["21", "22", "80", "443", "445", "3306", "8080", "8443"]
    target_ports = ports if ports else default_ports

    print("\n=========================================================")
    print("        NETPLUS ENTERPRISE SCAN ENGINE ACTIVE            ")
    print("=========================================================")
    print(f"[*] Target IP Address    : {target_ip}")
    print(f"[*] Resolved Hostname    : {target_hostname}")
    print(f"[*] Target Ports Count   : {len(target_ports)}")
    print(f"[*] Firewall Bypass Mode : {'ENABLED (FLL)' if fll_bypass else 'DISABLED'}")
    print(f"---------------------------------------------------------")

    time_start = time.time()
    active_open_ports = []

    for current_port in target_ports:
        try:
            cmd_args = [binary_path, target_ip, current_port]
            if fll_bypass:
                cmd_args.append("FLL")

            process_res = subprocess.run(cmd_args, capture_output=True, text=True, check=True)
            output_line = process_res.stdout.strip()
            print(output_line)

            if "OPEN" in output_line:
                active_open_ports.append(current_port)
                inspect_running_server(target_ip, current_port, fll_bypass, original_target)
        except subprocess.CalledProcessError:
            pass

    elapsed_duration = time.time() - time_start
    print("\n" + "=" * 57)
    print("                NETPLUS EXECUTION SUMMARY                ")
    print("=" * 57)
    print(f"[+] Target IP Audited         : {target_ip}")
    print(f"[+] Target Hostname           : {target_hostname}")
    print(f"[+] Open Services Discovered  : {len(active_open_ports)}")
    if active_open_ports:
        print(f"[+] Identified Active Ports   : {', '.join(active_open_ports)}")
    print(f"[+] Total Elapsed Runtime     : {elapsed_duration:.2f} seconds")
    print("=" * 57)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_ip, target_hostname, ports, fll_bypass, original_target = parse_arguments(sys.argv[1:])
        execute_scan_routine(target_ip, target_hostname, ports, fll_bypass, original_target)
EOF_PY
echo "[+] netplus.py generated."

# ------------------------------------------------------------------------------
# 3. COMPILATION & INSTALLATION
# ------------------------------------------------------------------------------
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g++ -O3 "$CURRENT_DIR/scanner.cpp" -o "$CURRENT_DIR/scanner"

if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; then
    cp "$CURRENT_DIR/scanner" "$PREFIX/bin/scanner"
    chmod +x "$PREFIX/bin/scanner"
    cp "$CURRENT_DIR/netplus.py" "$PREFIX/bin/np"
    chmod +x "$PREFIX/bin/np"
    echo "[+] Installed successfully in Termux!"
else
    sudo cp "$CURRENT_DIR/scanner" /usr/local/bin/scanner
    sudo chmod +x /usr/local/bin/scanner
    sudo cp "$CURRENT_DIR/netplus.py" /usr/local/bin/np
    sudo chmod +x /usr/local/bin/np
    echo "[+] Installed globally successfully!"
fi
EOF
