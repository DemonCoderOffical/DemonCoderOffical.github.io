# VoidCoderStudio.github.io

Netplus is a free open source tool. [Start here](https://voidcoderstudio.github.io) for more info [➔ Go to docs page](https://VoidCoderStudio.github.io/docs) founded and issue [press here](https://VoidCoderStudio.github.io/submit)

## What is NetPlus?

NetPlus is an ultimate multi-language networking toolkit designed for network analysis, port scanning, and OS fingerprinting. It combines a high-performance C++ backend engine with a Python command-line interface (CLI) and interactive console to deliver fast, lightweight network utilities.

## What Can NetPlus Do?

* **Port Scanning:** Scans target IPs for common default ports (such as FTP, SSH, HTTP, HTTPS, SMB, and MySQL) or targets specific custom ports using `-port.<PORT>`.
* **Service & Banner Grabbing:** Identifies open services and retrieves server banners (like HTTP server versions) directly from open ports.
* **OS Fingerprinting:** Performs TTL analysis via ping to estimate whether a target operating system is Linux/Unix-like, Windows, or a custom network device.
* **Firewall Bypass:** Supports a `-FLL` flag for advanced packet handling techniques like packet fragmentation and header spoofing.

## How to Use It

* **CLI Standard Scan:** Run `np <IP>` in your terminal to scan default ports and perform OS detection.
* **Custom Port Scan:** Run `np <IP> -port.<PORT>` to query a specific port (e.g., `np 192.168.1.1 -port.80`).
* **Firewall Bypass Scan:** Run `np -FLL <IP> -port.<PORT>` to activate packet fragmentation features.
* **Interactive Mode:** Run `np` without arguments to launch the interactive text-based console menu.
