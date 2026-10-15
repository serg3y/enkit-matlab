# Setup:
# pip install tkinterdnd2

import os, sys, base64, subprocess, time, tkinter as tk
from tkinter import ttk, filedialog, messagebox
from tkinterdnd2 import DND_FILES, TkinterDnD

def enforce_single_instance():
    """Silently terminates older running instances using system process queries."""
    current_pid, script_name = os.getpid(), os.path.basename(__file__)
    try:
        if os.name == 'nt':
            cmd = (
                f"powershell -Command \""
                f"$currentPid = {current_pid}; "
                f"$procs = Get-CimInstance Win32_Process | Where-Object {{$_.Name -match 'python' -and $_.CommandLine -like '*{script_name}*' -and $_.ProcessId -ne $currentPid}}; "
                f"foreach ($p in $procs) {{ Stop-Process -Id $p.ProcessId -Force }}"
                f"\""
            )
            subprocess.run(cmd, capture_output=True, shell=True, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        else:
            import getpass
            output = subprocess.run(f"pgrep -u {getpass.getuser()} -f '{script_name}'", shell=True, capture_output=True, text=True)
            if output.stdout:
                for p_id in output.stdout.strip().split('\n'):
                    if p_id.isdigit() and int(p_id) != current_pid:
                        os.kill(int(p_id), 9)
        time.sleep(0.3)
    except Exception:
        pass

class ImageEncoderApp:
    def __init__(self, root):
        enforce_single_instance()
        self.root = root
        self.root.title("Image Encoder")
        self.root.geometry("330x320")
        self.root.minsize(310, 290)

        self.file_path_var = tk.StringVar()
        self.width_var, self.height_var = tk.StringVar(value="16"), tk.StringVar(value="16")
        self.encoding_var = tk.StringVar(value="Base64")

        self.create_widgets()
        
        for widget in (self.root, self.drop_frame, self.drop_label):
            widget.drop_target_register(DND_FILES)
            widget.dnd_bind('<<Drop>>', self.handle_file_drop)

    def create_widgets(self):
        pad = tk.Frame(self.root, padx=8, pady=8)
        pad.pack(fill=tk.BOTH, expand=True)

        pad.grid_columnconfigure(0, weight=1)
        pad.grid_rowconfigure(5, weight=1)

        btn_w, btn_font = 9, ("Arial", 8, "bold")
        row_pad = 5

        # 1. Drop Zone
        self.drop_frame = tk.Frame(pad, bg="#eef0f2", bd=1, relief="solid")
        self.drop_frame.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, row_pad))
        
        self.drop_label = tk.Label(self.drop_frame, text="📥 Drag & Drop Image", bg="#eef0f2", fg="#333333", font=("Arial", 9), pady=6)
        self.drop_label.pack(fill=tk.BOTH, expand=True)

        # 2. File Path & Browse
        self.file_entry = tk.Entry(pad, textvariable=self.file_path_var, font=("Arial", 9))
        self.file_entry.grid(row=1, column=0, sticky="ew", padx=(0, 4), pady=(0, row_pad))
        
        tk.Button(pad, text="Browse...", command=self.browse_file, width=btn_w, font=btn_font).grid(row=1, column=1, sticky="e", pady=(0, row_pad))

        # 3. Encoding Dropdown
        enc_sub = tk.Frame(pad)
        enc_sub.grid(row=2, column=0, sticky="w", pady=(0, row_pad))
        
        tk.Label(enc_sub, text="Encoding :", font=("Arial", 9, "bold")).pack(side=tk.LEFT, padx=(0, 4))
        self.encoding_combo = ttk.Combobox(enc_sub, textvariable=self.encoding_var, values=["Base64"], state="readonly", width=12, font=("Arial", 9))
        self.encoding_combo.pack(side=tk.LEFT)

        # 4. Resolution & Encode
        res_sub = tk.Frame(pad)
        res_sub.grid(row=3, column=0, sticky="w", pady=(0, row_pad))
        
        tk.Label(res_sub, text="Resolution :", font=("Arial", 9, "bold")).pack(side=tk.LEFT, padx=(0, 4))
        self.width_entry = tk.Entry(res_sub, textvariable=self.width_var, font=("Arial", 9), width=3)
        self.width_entry.pack(side=tk.LEFT, padx=(0, 2))
        tk.Label(res_sub, text="W", font=("Arial", 9, "bold")).pack(side=tk.LEFT, padx=(0, 4))
        self.height_entry = tk.Entry(res_sub, textvariable=self.height_var, font=("Arial", 9), width=3)
        self.height_entry.pack(side=tk.LEFT, padx=(0, 2))
        tk.Label(res_sub, text="H", font=("Arial", 9, "bold")).pack(side=tk.LEFT)

        tk.Button(pad, text="Encode", bg="#2e7d32", fg="white", font=btn_font, width=btn_w, command=self.generate).grid(row=3, column=1, sticky="e", pady=(0, row_pad))

        # 5. Output & Copy
        tk.Label(pad, text="Output:", font=("Arial", 9, "bold")).grid(row=4, column=0, sticky="w", pady=(0, row_pad))
        
        self.copy_btn = tk.Button(pad, text="Copy", font=btn_font, width=btn_w, command=self.copy_to_clipboard, state=tk.DISABLED)
        self.copy_btn.grid(row=4, column=1, sticky="e", pady=(0, row_pad))

        # 6. Text Box
        self.code_text = tk.Text(pad, height=4, font=("Courier", 8), wrap=tk.WORD)
        self.code_text.grid(row=5, column=0, columnspan=2, sticky="nsew")

    def handle_file_drop(self, event):
        path = event.data.strip('{}')
        if os.path.isfile(path):
            self.file_path_var.set(path)
        else:
            messagebox.showerror("Error", "Dropped item is not a valid file.")

    def browse_file(self):
        if filename := filedialog.askopenfilename(filetypes=[("Image Files", "*.png;*.gif;*.ppm;*.pgm"), ("All Files", "*.*")]):
            self.file_path_var.set(filename)

    def copy_to_clipboard(self):
        content = self.code_text.get("1.0", tk.END).strip()
        if content:
            self.root.clipboard_clear()
            self.root.clipboard_append(content)
            # Select all text as visual feedback
            self.code_text.tag_remove("sel", "1.0", tk.END)
            self.code_text.tag_add("sel", "1.0", "end-1c")
            self.code_text.focus_set()

    def generate(self):
        path = self.file_path_var.get().strip()
        if not path or not os.path.exists(path):
            messagebox.showerror("Error", "Please select a valid image file first.")
            return

        try:
            w, h = int(self.width_var.get()), int(self.height_var.get())
            if w <= 0 or h <= 0: raise ValueError("Must be greater than zero.")

            img = tk.PhotoImage(file=path, master=self.root)
            resampled = img.subsample(max(1, img.width() // w), max(1, img.height() // h))
            
            resampled.write("temp.gif", format="gif")
            with open("temp.gif", "rb") as f:
                encoded = base64.b64encode(f.read()).decode('utf-8')
            if os.path.exists("temp.gif"): os.remove("temp.gif")

            self.code_text.delete("1.0", tk.END)
            self.code_text.insert("1.0", encoded)
            self.copy_btn.config(state=tk.NORMAL)

        except Exception as e:
            messagebox.showerror("Error", f"Encoding failed: {e}")

if __name__ == "__main__":
    root = TkinterDnD.Tk()
    ImageEncoderApp(root)
    root.mainloop()