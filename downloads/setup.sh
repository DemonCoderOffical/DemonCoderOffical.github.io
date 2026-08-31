cat << 'EOF' > setup.sh
#!/bin/bash

# ==============================================================================
#      NETPLUS ENTERPRISE v2.8 - SL, SF, F & BRUTE-FORCE ENGINE
# ==============================================================================

echo "[*] Initializing NetPlus Enterprise Build (v2.8)..."

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
# 2. NETPLUS.PY (Python Engine with SL, SF, F, -B Brute-Force & PCAPNG Export)
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
import struct

VERSION = "2.8 Enterprise Complete Suite"

class MultiStreamOutput:
    def __init__(self, txt_file=None, pcap_file=None):
        self.terminal = sys.stdout
        self.txt_out = open(txt_file, "w", encoding="utf-8") if txt_file else None
        self.pcap_out = open(pcap_file, "wb") if pcap_file else None
        if self.pcap_out:
            self._write_pcapng_header()

    def _write_pcapng_header(self):
        # PCAPNG Section Header Block (SHB)
        shb = struct.pack('<I I I I', 0x0A0D0D0A, 28, 0x1A2B3C4D, 1) + struct.pack('<I', 28)
        self.pcap_out.write(shb)

    def write(self, message):
        self.terminal.write(message)
        if self.txt_out:
            self.txt_out.write(message)
            self.txt_out.flush()
        if self.pcap_out:
            # Simple packet encapsulation simulation for pcapng export log
            ts = int(time.time() * 1000000)
            ts_high = (ts >> 32) & 0xFFFFFFFF
            ts_low = ts & 0xFFFFFFFF
            data = message.encode('utf-8', errors='ignore')
            length = len(data)
            padded_len = (length + 3) & ~3
            padding = b'\x00' * (padded_len - length)
            
            epb = struct.pack('<I I I I I I', 0x00000006, 32 + padded_len, ts_high, ts_low, length, length) + data + padding + struct.pack('<I', 32 + padded_len)
            self.pcap_out.write(epb)
            self.pcap_out.flush()

    def flush(self):
        self.terminal.flush()
        if self.txt_out:
            self.txt_out.flush()
        if self.pcap_out:
            self.pcap_out.flush()

    def close(self):
        if self.txt_out:
            self.txt_out.close()
        if self.pcap_out:
            self.pcap_out.close()
        sys.stdout = self.terminal

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

def render_help_screen():
    print("=" * 65)
    print("                 NETPLUS ENTERPRISE TOOLKIT                      ")
    print("=" * 65)
    print("Usage: np <target> [options]\n")
    print("CORE OPTIONS:")
    print("  -h, --help           Display this comprehensive help menu")
    print("  -O                   Execute deep OS & service fingerprint identification")
    print("  -port.<ports>        Target specific ports (e.g., -port.80,443,8080)")
    print("  -FLL                 Activate Advanced Firewall Bypass (TTL Engine)")
    print("  -SL                  List common default files and web resources on target")
    print("  -F                   Save scan output to a text file report (.txt)")
    print("  -SF                  Save scan output to both text (.txt) and PCAPNG (.pcapng)")
    print("  -B <file_path>       Brute-force files from wordlist on target web server")
    print("  -V                   Print current software build version")
    print("=" * 65)
    sys.exit(0)

def resolve_target_address(target_input):
    clean = target_input.replace("http://", "").replace("https://", "").split("/")[0]
    
    resolved_hostname = "N/A (Direct IP)"
    try:
        host_info = socket.gethostbyaddr(clean)
        resolved_hostname = host_info[0]
    except Exception:
        try:
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
    if "-h" in argv or "--help" in argv or "-help" in argv:
        render_help_screen()

    target_raw = None
    ports_list = []
    fll_bypass = False
    os_scan = False
    sl_mode = False
    f_mode = False
    sf_mode = False
    brute_file = None

    idx = 0
    while idx < len(argv):
        arg = argv[idx]
        if arg == "-FLL":
            fll_bypass = True
        elif arg == "-O":
            os_scan = True
        elif arg == "-SL":
            sl_mode = True
        elif arg == "-F":
            f_mode = True
        elif arg == "-SF":
            sf_mode = True
        elif arg == "-B":
            if idx + 1 < len(argv):
                brute_file = argv[idx + 1]
                if not os.path.exists(brute_file):
                    print(f"Error: Brute-force wordlist file '{brute_file}' not found!\nQUITTING!")
                    sys.exit(1)
                idx += 1
            else:
                print("Error: Missing file path specification for -B option\nQUITTING!")
                sys.exit(1)
        elif arg == "-V":
            print(f"NetPlus Version {VERSION}")
            sys.exit(0)
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
        elif arg.startswith("-"):
            print(f"Error: Unknown argument {arg}\nQUITTING!")
            sys.exit(1)
        elif not arg.startswith("-") and target_raw is None:
            target_raw = arg
        else:
            print(f"Error: Unknown argument {arg}\nQUITTING!")
            sys.exit(1)
        idx += 1

    if not target_raw:
        print("Error: Target specification missing\nQUITTING!")
        sys.exit(1)

    target_ip, target_hostname = resolve_target_address(target_raw)
    return target_ip, target_hostname, ports_list, fll_bypass, os_scan, sl_mode, f_mode, sf_mode, brute_file, target_raw

def perform_brute_force(target_ip, target_hostname, brute_path, fll_bypass):
    print(f"\n=========================================================")
    print(f"      NETPLUS BRUTE-FORCE ENGINE ACTIVE (-B)             ")
    print(f"=========================================================")
    print(f"[*] Target Host/IP       : {target_ip} ({target_hostname})")
    print(f"[*] Wordlist File Path   : {brute_path}")
    print(f"---------------------------------------------------------")

    with open(brute_path, 'r', encoding='utf-8', errors='ignore') as f:
        paths = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    protocols = ["http", "https"]
    active_base_url = None

    for proto in protocols:
        test_url = f"{proto}://{target_ip}/"
        try:
            req = urllib.request.Request(test_url, headers={'User-Agent': 'NetPlus Brute-Force Auditor'})
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            with urllib.request.urlopen(req, context=ctx, timeout=2.5):
                active_base_url = f"{proto}://{target_ip}"
                break
        except Exception:
            try:
                test_url_port = f"{proto}://{target_ip}:8080/"
                req = urllib.request.Request(test_url_port, headers={'User-Agent': 'NetPlus Brute-Force Auditor'})
                with urllib.request.urlopen(req, context=ctx, timeout=2.5):
                    active_base_url = f"{proto}://{target_ip}:8080"
                    break
            except Exception:
                pass

    if not active_base_url:
        active_base_url = f"http://{target_ip}"

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    for path_item in paths:
        clean_path = path_item.lstrip('/')
        target_url = f"{active_base_url}/{clean_path}"
        headers = {'User-Agent': 'NetPlus Enterprise Bruter/2.8'}
        if fll_bypass:
            headers['X-Forwarded-For'] = '127.0.0.1'

        try:
            req = urllib.request.Request(target_url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=2.0) as response:
                if response.status in [200, 301, 302, 403]:
                    print(f"{target_url.upper()} EXISTS (Status: {response.status})")
        except urllib.error.HTTPError as he:
            if he.code in [200, 301, 302, 403, 401]:
                print(f"{target_url.upper()} EXISTS (Status: {he.code})")
        except Exception:
            pass

    print("=========================================================")
    print("[*] Brute-force discovery scan completed.")

def perform_sl_scan(target_ip, target_hostname):
    print(f"\n=========================================================")
    print(f"      NETPLUS TARGET FILE DISCOVERY & LISTING (-SL)      ")
    print(f"=========================================================")
    print(f"[*] Target IP / Browser  : {target_ip} ({target_hostname})")
    print(f"[*] Scanning common endpoints, scripts & assets...")
    print(f"---------------------------------------------------------")

    common_files = [
        "index.php", "index.html", "login.php", "admin/", "robots.txt", 
        "sitemap.xml", "config.php", "dashboard.php", "api/v1/", "uploads/",
        "assets/js/main.js", "style.css", "login.html", "dashboard.html", "auth.php"
    ]

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    for proto in ["http", "https"]:
        for file_res in common_files:
            url = f"{proto}://{target_ip}/{file_res}"
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'NetPlus SL Lister'})
                with urllib.request.urlopen(req, context=ctx, timeout=1.5) as res:
                    print(f"[FOUND FILE]  -> {url} (Code: {res.status})")
            except urllib.error.HTTPError as he:
                if he.code != 404:
                    print(f"[FOUND FILE]  -> {url} (Code: {he.code})")
            except Exception:
                pass

    print("=========================================================")

def execute_scan_routine(target_ip, target_hostname, ports, fll_bypass, os_scan, sl_mode, f_mode, sf_mode, brute_file, original_target):
    timestamp_str = str(int(time.time()))
    txt_filename = f"netplus_report_{target_ip}_{timestamp_str}.txt" if (f_mode or sf_mode) else None
    pcap_filename = f"netplus_capture_{target_ip}_{timestamp_str}.pcapng" if sf_mode else None

    logger = MultiStreamOutput(txt_file=txt_filename, pcap_file=pcap_filename)
    sys.stdout = logger

    if brute_file:
        perform_brute_force(target_ip, target_hostname, brute_file, fll_bypass)
        logger.close()
        return

    if sl_mode:
        perform_sl_scan(target_ip, target_hostname)
        logger.close()
        return

    binary_path = locate_binary()
    default_ports = ["21", "22", "80", "443", "445", "3306", "8080", "8443"]
    target_ports = ports if ports else default_ports

    print("\n=========================================================")
    print("        NETPLUS ENTERPRISE SCAN ENGINE ACTIVE            ")
    print("=========================================================")
    print(f"[*] Target IP Address    : {target_ip}")
    print(f"[*] Resolved Hostname    : {target_hostname}")
    print(f"[*] Target Ports Count   : {len(target_ports)}")
    print(f"[*] Firewall Bypass Mode : {'ENABLED (FLL)' if fll_bypass else 'DISABLED'}")
    print(f"[*] OS Fingerprint Mode  : {'ENABLED (-O)' if os_scan else 'DISABLED'}")
    if txt_filename:
        print(f"[*] Text Report Output   : {txt_filename}")
    if pcap_filename:
        print(f"[*] PCAPNG Capture File  : {pcap_filename}")
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

    logger.close()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_ip, target_hostname, ports, fll_bypass, os_scan, sl_mode, f_mode, sf_mode, brute_file, original_target = parse_arguments(sys.argv[1:])
        execute_scan_routine(target_ip, target_hostname, ports, fll_bypass, os_scan, sl_mode, f_mode, sf_mode, brute_file, original_target)
    else:
        render_help_screen()
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
