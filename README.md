# VoidCoderStudio.github.io

Netplus is a free open source tool. [Start here](https://voidcoderstudio.github.io) for more info [➔ Go to docs page](https://VoidCoderStudio.github.io/docs) founded and issue [press here](https://VoidCoderStudio.github.io/submit)

## What is NetPlus?

NetPlus is an ultimate multi-language networking toolkit designed for network analysis, port scanning, and OS fingerprinting. It combines a high-performance C++ backend engine with a Python command-line interface (CLI) and interactive console to deliver fast, lightweight network utilities.
# Security & Transparency Policy

Thank you for using software from VoidCoderStudio. We prioritize user privacy, data isolation, and system security.

## Our Security Commitments

* **No Administrator Privileges Required:** Our software and installation scripts it only requires root for install required apps like g++ for the compiler run entirely within user space. We will never ask you to run our code using `sudo` or administrator rights.
* **Complete Data Isolation:** Our application directories are fully self-contained. The installation script only creates and modifies files inside its own designated folder and will not touch, modify, or view files elsewhere on your operating system.
* **Zero Data Collection:** We do not track you, collect metrics, or transmit any user data to external servers. Your data stays entirely on your local machine.
* **100% Readable Code:** We pledge never to use obfuscation, hidden binaries, or encrypted scripts. Every line of our source code is open, transparent, and easy to audit.

## Verifying Build Integrity

Before running any downloadable packages or releases, we encourage you to:
1. Verify the code directly in this repository.
2. Run the code inside an isolated environment (like GitHub Codespaces or a Docker container) if you wish to audit it first.

## Reporting a Vulnerability

If you discover a security bug, vulnerability, or a false-positive flag from an antivirus scanner, please do not open a public issue. Instead, contact the maintainer directly or open a draft security advisory via GitHub so we can patch it safely

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
# Security & Transparency Policy

Thank you for using software from VoidCoderStudio. We prioritize user privacy, data isolation, and system security.
<video width="100%" controls>
  <source src="showcase.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
