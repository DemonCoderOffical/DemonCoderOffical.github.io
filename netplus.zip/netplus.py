import socket
import sys

def banner():
    print("""
    _  _      _   ___ _             
    | \| |___ | |_| _ \ |_  _ ___ ___ 
    | .` / -_)|  _|  _/ | || (_-</ -_)
    |_|\_\___| \__|_| |_|\_,_/__/\___|
    [ NetPlus v0.3 - Network Toolkit ]
    """)

def scan_help():
    print("----------------------------------------")
    print(" SCAN OPTIONS & HELP:")
    print("  [1] Quick Ping Scan - Checks active hosts.")
    print("  [2] Port Scan       - Scans standard ports.")
    print("  [3] Interface Info  - Shows local IP details.")
    print("----------------------------------------")

def run_scan():
    print("\n[+] Scan mode activated.")
    print("Type 'help' to see scan examples and options, or type 'back' to return.")
    while True:
        sub_choice = input("NP(scan)> ").strip().lower()
        if sub_choice == 'help':
            scan_help()
        elif sub_choice == 'back':
            break
        elif sub_choice == '3':
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            print(f"[*] Hostname: {hostname} | Local IP: {local_ip}")
        else:
            print("[-] Unknown scan command. Type 'help' for options.")

def main():
    banner()
    while True:
        choice = input("\nNP> ").strip().lower()

        if choice == 'help':
            print("Main Commands available:")
            print("  1      - General Info / About")
            print("  2      - SCAN (Type 'help' inside for scan examples)")
            print("  exit   - Exit the tool")
        elif choice == '1':
            print("[*] NetPlus v0.3 - Developed for advanced network management.")
        elif choice == '2':
            run_scan()
        elif choice == 'exit':
            print("[-] Exiting NetPlus...")
            sys.exit()
        else:
            print(f"[-] Unknown command: '{choice}'. Type 'help' for options.")

if __name__ == "__main__":
    main()