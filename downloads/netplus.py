import socket
import sys
import tkinter as tk
from tkinter import scrolledtext

class NetPlusGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("NetPlus v0.3 - Terminal GUI")
        self.root.geometry("700x500")
        self.root.configure(bg="#0f0f0f")

        # شاشة العرض السوداء (تطابق شكل التيرمينال)
        self.text_area = scrolledtext.ScrolledText(
            root, wrap=tk.WORD, bg="#000000", fg="#00ff00", 
            insertbackground="white", font=("Consolas", 11)
        )
        self.text_area.pack(padx=10, pady=10, fill=tk.BOTH, expand=True)

        # حقل إدخال الأوامر (يعمل مثل الـ Terminal prompt)
        self.cmd_entry = tk.Entry(root, font=("Consolas", 12), bg="#1c1c1c", fg="#00ff00", insertbackground="white")
        self.cmd_entry.pack(padx=10, pady=(0, 10), fill=tk.X)
        self.cmd_entry.bind("<Return>", self.handle_command)
        self.cmd_entry.focus_set()

        # الحالة الداخلية للبرنامج (لتتبع هل نحن في القائمة الرئيسية أم داخل SCAN)
        self.state = "main"

        # طباعة البانر الأولي والترحيب
        self.print_banner()
        self.print_main_help()
        self.prompt_main()

    def write(self, text):
        self.text_area.configure(state='normal')
        self.text_area.insert(tk.END, text + "\n")
        self.text_area.configure(state='disabled')
        self.text_area.see(tk.END)

    def print_banner(self):
        banner_text = """    _  _      _   ___ _             
    | \| |___ | |_| _ \ |_  _ ___ ___ 
    | .` / -_)|  _|  _/ | || (_-^{\\-_)
    |_|\_\___| \__|_| |_|\_,_/__/\\___|
    [ NetPlus v0.3 - Network Toolkit ]"""
        self.write(banner_text)

    def print_main_help(self):
        self.write("\nMain Commands available:")
        self.write("  1      - General Info / About")
        self.write("  2      - SCAN (Type 'help' inside for scan examples)")
        self.write("  exit   - Exit the tool")

    def prompt_main(self):
        self.write("\nNP> ",)

    def prompt_scan(self):
        self.write("\nNP(scan)> ")

    def handle_command(self, event):
        cmd = self.cmd_entry.get().strip()
        self.cmd_entry.delete(0, tk.END)

        # طباعة الأمر الذي كتبه المستخدم على الشاشة السوداء
        if self.state == "main":
            self.write(f"NP> {cmd}")
        else:
            self.write(f"NP(scan)> {cmd}")

        cmd_lower = cmd.lower()

        if self.state == "main":
            if cmd_lower == 'help':
                self.print_main_help()
            elif cmd_lower == '1':
                self.write("[*] NetPlus v0.3 - Developed for advanced network management.")
            elif cmd_lower == '2':
                self.write("\n[+] Scan mode activated.")
                self.write("Type 'help' to see scan examples and options, or type 'back' to return.")
                self.state = "scan"
            elif cmd_lower == 'exit':
                self.write("[-] Exiting NetPlus...")
                self.root.after(1000, self.root.quit)
            else:
                self.write(f"[-] Unknown command: '{cmd}'. Type 'help' for options.")
            
            if self.state == "main":
                self.prompt_main()
            else:
                self.prompt_scan()

        elif self.state == "scan":
            if cmd_lower == 'help':
                self.write("----------------------------------------")
                self.write(" SCAN OPTIONS & HELP:")
                self.write("  [1] Quick Ping Scan - Checks active hosts.")
                self.write("  [2] Port Scan       - Scans standard ports.")
                self.write("  [3] Interface Info  - Shows local IP details.")
                self.write("----------------------------------------")
            elif cmd_lower == 'back':
                self.state = "main"
                self.print_main_help()
                self.prompt_main()
            elif cmd_lower == '3':
                hostname = socket.gethostname()
                local_ip = socket.gethostbyname(hostname)
                self.write(f"[*] Hostname: {hostname} | Local IP: {local_ip}")
            else:
                self.write("[-] Unknown scan command. Type 'help' for options.")
            
            if self.state == "scan":
                self.prompt_scan()

if __name__ == "__main__":
    root = tk.Tk()
    app = NetPlusGUI(root)
    root.mainloop()
