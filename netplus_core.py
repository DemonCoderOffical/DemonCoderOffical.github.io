import socket
import subprocess
import sys

def banner():
    print("""
    _  _      _   ___ _             
    | \| |___ | |_| _ \ |_  _ ___ ___ 
    | .` / -_)|  _|  _/ | || (_-</ -_)
    |_|\_\___| \__|_| |_|\_,_/__/\___|
    [ NetPlus v0.3 - Network Toolkit ]
    """)

def run_scan():
    print("\n[+] Scanning local network interfaces...")
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print(f"[*] Hostname: {hostname}")
    print(f"[*] Local IP: {local_ip}")
    print("[*] Status: Interface active and ready.")

def main():
    banner()
    while True:
        choice = input("\nNP> ").strip().lower()
        
        if choice == 'help':
            print("Commands available:")
            print("  scan   - Run local interface scan")
            print("  exit   - Exit the tool")
        elif choice == 'scan':
            run_scan()
        elif choice == 'exit':
            print("[-] Exiting NetPlus...")
            sys.exit()
        else:
            print(f"[-] Unknown command: '{choice}'. Type 'help' for options.")

if __name__ == "__main__":
    main()
