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
