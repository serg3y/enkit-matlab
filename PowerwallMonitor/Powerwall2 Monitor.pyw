# Setup:
# 1. Install packages using command line
#      pip install requests
# 2. Create powerwall2.ini file as follows:
#      host = 192.168.1.27
#      email = YOUR_EMAIL
#      password = YOUR_GATEWAY_PASSWORD
#      timeZone = Australia/Adelaide

import os, json, re, subprocess, threading, time, base64, winsound, warnings
import tkinter as tk
from tkinter import simpledialog
from datetime import datetime, timezone
import requests

# Suppress unverified HTTPS request warnings for local gateway self-signed certificate
warnings.filterwarnings("ignore")

# ==================== CONFIGURATION ====================
# Polling intervals (in seconds)
POLL_INTERVAL = 10.0
FAST_POLL_INTERVAL = 2.0

# Application Icon (Base64 Encoded)
APP_ICON_BASE64 = "R0lGODlhEAAQANUAANnZ2fXo6vHCyO6lsO2hrO+xu/PV2ff09fTb3uRUad4XNd4aOOI6VOdoe+qDkuqIl+h4iOROY+AoQ98iP+2eqvf19fTg4uAtSPC5wO2gq+I+Vt4WNPf29ul/jt8dOudrffLR1uhxguAnQuRNYt4YNt8cOd8hPvHEyt8bOd4aN+dvge6kr/Tf4t8fPPXm6ORPZPXl5+AmQuZhdO6ttt8mQfbz8+hzg/G/xvbx8eExTOl+jvLM0P///////////////yH5BAEAAAAALAAAAAAQABAAAAZrQIBQGBAMCAXDYShEJBQLRsPxgEQkigmlYrlgMpqNggPoKDwfUEgEGCkUpJLCdFKgUm9FRahaCRd5LEItLkxDL3mGigAEiYtMMG8xj4ZvMpRMbzOYQzQKNZxCNgqhQjckpQA4OakAOq07i0EAOw=="

# Default Alert Thresholds
DEFAULT_SOC_LOW_THRESH = 20.0
DEFAULT_SOC_HIGH_THRESH = 90.0
DEFAULT_BAT_LOW_THRESH = 0.0
DEFAULT_BAT_HIGH_THRESH = 5.0
DEFAULT_GRID_LOW_THRESH = 0.0
DEFAULT_GRID_HIGH_THRESH = 5.0
DEFAULT_LOAD_LOW_THRESH = 0.0
DEFAULT_LOAD_HIGH_THRESH = 5.0
# =======================================================

class ToolTip:
    """Simple tooltip helper for Tkinter widgets."""
    def __init__(self, widget, text_callback):
        self.widget = widget
        self.text_callback = text_callback
        self.tip_window = None
        widget.bind("<Enter>", self.show_tip)
        widget.bind("<Leave>", self.hide_tip)

    def show_tip(self, event=None):
        if self.tip_window:
            return
        text = self.text_callback()
        if not text:
            return
        x = self.widget.winfo_rootx() + 20
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 5
        self.tip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        label = tk.Label(tw, text=text, background="#ffffe0", foreground="#000000", relief="solid", borderwidth=1, font=("Arial", 9))
        label.pack(ipadx=1, ipady=1)

    def hide_tip(self, event=None):
        tw = self.tip_window
        self.tip_window = None
        if tw:
            tw.destroy()

def enforce_single_instance():
    """Kills any other running instances of this script via system process list."""
    current_pid = os.getpid()
    script_name = os.path.basename(__file__)
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
            user = getpass.getuser()
            output = subprocess.run(f"pgrep -u {user} -f '{script_name}'", shell=True, capture_output=True, text=True)
            if output.stdout:
                for p_id in output.stdout.strip().split('\n'):
                    if p_id.isdigit() and int(p_id) != current_pid:
                        os.kill(int(p_id), 9)
        time.sleep(0.5)
    except Exception as e:
        print(f"Singleton check warning: {e}")

def log_error(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{timestamp}] {msg}\n"
    try:
        with open("powerwall2_monitor.log", "a") as f: f.write(formatted)
    except Exception: pass

def load_ini_config():
    host, email, password, time_zone = "192.168.1.27", "", "", "Australia/Adelaide"
    ini_path = "powerwall2.ini"
    if not os.path.exists(ini_path):
        default_content = "host = 192.168.1.27\nemail = \npassword = \ntimeZone = Australia/Adelaide\n"
        try:
            with open(ini_path, "w") as f:
                f.write(default_content)
            log_error("powerwall2.ini not found. Created default template.")
        except Exception as e:
            log_error(f"Failed to write powerwall2.ini: {e}")
    else:
        try:
            with open(ini_path, "r") as f:
                txt = f.read()
                if (m := re.search(r'^\s*host\s*=\s*(\S+)', txt, re.M)): host = m.group(1)
                if (m := re.search(r'^\s*email\s*=\s*(\S+)', txt, re.M)): email = m.group(1)
                if (m := re.search(r'^\s*password\s*=\s*(\S+)', txt, re.M)): password = m.group(1)
                if (m := re.search(r'^\s*timeZone\s*=\s*([^\r\n]+)', txt, re.M)): time_zone = m.group(1).strip()
        except Exception as e:
            log_error(f"Error reading powerwall2.ini: {e}")
            
    return host, email, password, time_zone

def save_debug_file(filename, data):
    try:
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
    except Exception:
        pass

class PowerwallMonitorApp:
    def __init__(self, root):
        enforce_single_instance()
        self.root = root
        self.root.title("Powerwall2 Monitor")
        
        # Load custom app icon from top-level configuration Base64 string
        try:
            icon_data = base64.b64decode(APP_ICON_BASE64)
            self.app_icon = tk.PhotoImage(data=icon_data)
            self.root.iconphoto(True, self.app_icon)
        except Exception as e:
            log_error(f"Icon load warning: {e}")

        self.host, self.email, self.password, self.time_zone = load_ini_config()
        
        # Window dimensions and top-right positioning
        w, h = 390, 480
        screen_w = root.winfo_screenwidth()
        x = screen_w - w - 40
        y = 40
        self.root.geometry(f"{w}x{h}+{x}+{y}")
        
        self.root.resizable(False, False)
        self.root.configure(bg="#1e1e1e")
        
        self.session = requests.Session()
        self.session.verify = False  # Ignore self-signed SSL cert on local gateway
        
        # Polling rate state variable
        self.poll_interval = POLL_INTERVAL

        # Timestamps for updated indicators per section
        self.ts_aggregates = None
        self.ts_soe = None
        self.ts_grid_status = None
        
        # Cached data states & live metric values for alerts
        self.cached_aggregates = {}
        self.cached_soe = {}
        self.cached_grid_status = {}
        self.current_soc = None
        self.current_bat_kw = None
        self.current_grid_kw = None
        self.current_load_kw = None

        # Alert configuration states
        self.soc_alert1 = {"enabled": False, "thresh": DEFAULT_SOC_LOW_THRESH, "btn": None, "mode": "below"}
        self.soc_alert2 = {"enabled": False, "thresh": DEFAULT_SOC_HIGH_THRESH, "btn": None, "mode": "above"}

        self.bat_alert1 = {"enabled": False, "thresh": DEFAULT_BAT_LOW_THRESH, "btn": None, "mode": "below"}
        self.bat_alert2 = {"enabled": False, "thresh": DEFAULT_BAT_HIGH_THRESH, "btn": None, "mode": "above"}

        self.grid_alert1 = {"enabled": False, "thresh": DEFAULT_GRID_LOW_THRESH, "btn": None, "mode": "below"}
        self.grid_alert2 = {"enabled": False, "thresh": DEFAULT_GRID_HIGH_THRESH, "btn": None, "mode": "above"}

        self.load_alert1 = {"enabled": False, "thresh": DEFAULT_LOAD_LOW_THRESH, "btn": None, "mode": "below"}
        self.load_alert2 = {"enabled": False, "thresh": DEFAULT_LOAD_HIGH_THRESH, "btn": None, "mode": "above"}
        
        font = ("Arial", 11, "bold")
        
        # --- Outside Section: PC Time & Gateway Info ---
        top_info_frame = tk.Frame(root, bg="#1e1e1e")
        top_info_frame.pack(fill="x", padx=6, pady=4)
        
        self.lbl_ctime = self._make_row(top_info_frame, "PC Time:", "--:--:--", font, bg="#1e1e1e")
        self.lbl_host = self._make_row(top_info_frame, "Gateway IP:", self.host or "N/A", font, bg="#1e1e1e")
        self.lbl_tz = self._make_row(top_info_frame, "Timezone:", self.time_zone, font, bg="#1e1e1e")

        # --- Section 1: Grid Status ---
        grid_outer = tk.Frame(root, bg="#252526", bd=1, relief="solid")
        grid_outer.pack(fill="x", padx=6, pady=2)
        
        grid_header = tk.Frame(grid_outer, bg="#2d2d2d")
        grid_header.pack(fill="x", padx=1, pady=1)
        
        tk.Label(grid_header, text="Grid Status", font=("Arial", 10, "bold"), fg="#8be9fd", bg="#2d2d2d").pack(side="left", anchor="w", padx=4)
        tk.Button(grid_header, text="⚙", font=("Arial", 9), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.change_polling_rate).pack(side="right", anchor="ne", padx=2)
        tk.Button(grid_header, text="🔄", font=("Arial", 11), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.manual_refresh_grid).pack(side="right", anchor="ne", padx=2)
        
        self.lbl_up_grid = tk.Label(grid_header, text="Updated: --s", font=("Arial", 9, "italic"), fg="#a0a0a0", bg="#2d2d2d")
        self.lbl_up_grid.pack(side="right", anchor="e", padx=4)
        
        grid_body = tk.Frame(grid_outer, bg="#252526")
        grid_body.pack(fill="x", padx=6, pady=6)
        
        self.lbl_grid_status = self._make_row(grid_body, "Grid State:", "--", font, bg="#252526")
        self.lbl_grid_services = self._make_row(grid_body, "Grid Services:", "--", font, bg="#252526")

        # --- Section 2: Meters & Aggregates ---
        agg_outer = tk.Frame(root, bg="#252526", bd=1, relief="solid")
        agg_outer.pack(fill="x", padx=6, pady=2)
        
        agg_header = tk.Frame(agg_outer, bg="#2d2d2d")
        agg_header.pack(fill="x", padx=1, pady=1)
        
        tk.Label(agg_header, text="Meters & Aggregates", font=("Arial", 10, "bold"), fg="#8be9fd", bg="#2d2d2d").pack(side="left", anchor="w", padx=4)
        tk.Button(agg_header, text="⚙", font=("Arial", 9), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.change_polling_rate).pack(side="right", anchor="ne", padx=2)
        tk.Button(agg_header, text="🔄", font=("Arial", 11), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.manual_refresh_aggregates).pack(side="right", anchor="ne", padx=2)
        
        self.lbl_up_agg = tk.Label(agg_header, text="Updated: --s", font=("Arial", 9, "italic"), fg="#a0a0a0", bg="#2d2d2d")
        self.lbl_up_agg.pack(side="right", anchor="e", padx=4)
        
        agg_body = tk.Frame(agg_outer, bg="#252526")
        agg_body.pack(fill="x", padx=6, pady=6)
        
        self.lbl_solar = self._make_row(agg_body, "Solar:", "-- kW", font, bg="#252526")
        self.lbl_battery = self._make_row_with_speakers(agg_body, "Battery:", "-- kW", font, bg="#252526", alert_config_1=self.bat_alert1, alert_config_2=self.bat_alert2)
        self.lbl_grid = self._make_row_with_speakers(agg_body, "Grid:", "-- kW", font, bg="#252526", alert_config_1=self.grid_alert1, alert_config_2=self.grid_alert2)
        self.lbl_home = self._make_row_with_speakers(agg_body, "Home Load:", "-- kW", font, bg="#252526", alert_config_1=self.load_alert1, alert_config_2=self.load_alert2)
        self.lbl_freq = self._make_row(agg_body, "Frequency:", "-- Hz", font, bg="#252526")

        # --- Section 3: State of Energy (SOE) ---
        soe_outer = tk.Frame(root, bg="#252526", bd=1, relief="solid")
        soe_outer.pack(fill="x", padx=6, pady=2)
        
        soe_header = tk.Frame(soe_outer, bg="#2d2d2d")
        soe_header.pack(fill="x", padx=1, pady=1)
        
        tk.Label(soe_header, text="State of Energy (SOE)", font=("Arial", 10, "bold"), fg="#8be9fd", bg="#2d2d2d").pack(side="left", anchor="w", padx=4)
        tk.Button(soe_header, text="⚙", font=("Arial", 9), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.change_polling_rate).pack(side="right", anchor="ne", padx=2)
        tk.Button(soe_header, text="🔄", font=("Arial", 11), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.manual_refresh_soe).pack(side="right", anchor="ne", padx=2)
        
        self.lbl_up_soe = tk.Label(soe_header, text="Updated: --s", font=("Arial", 9, "italic"), fg="#a0a0a0", bg="#2d2d2d")
        self.lbl_up_soe.pack(side="right", anchor="e", padx=4)
        
        soe_body = tk.Frame(soe_outer, bg="#252526")
        soe_body.pack(fill="x", padx=6, pady=6)
        
        self.lbl_soc = self._make_row_with_speakers(soe_body, "Battery SOC:", "--%", font, bg="#252526", alert_config_1=self.soc_alert1, alert_config_2=self.soc_alert2)

        if not self.host or not self.password:
            log_error("Missing host or password in powerwall2.ini")
            self.lbl_grid_status.config(text=" Config Error", fg="#ff5555")
        else:
            threading.Thread(target=self.login_loop, daemon=True).start()
            threading.Thread(target=self.manual_refresh, daemon=True).start()
            threading.Thread(target=self.poll_loop, daemon=True).start()
            threading.Thread(target=self.ticker_loop, daemon=True).start()

    def change_polling_rate(self):
        val = simpledialog.askfloat("Set polling rate (sec)", "Set polling rate (sec):", initialvalue=self.poll_interval, minvalue=0.5, maxvalue=3600.0)
        if val is not None:
            self.poll_interval = float(val)

    def _make_row(self, parent, label_text, val_text, font, bg):
        f = tk.Frame(parent, bg=bg)
        f.pack(anchor="w", pady=1)
        lbl = tk.Label(f, text=label_text, font=font, fg="#ffffff", bg=bg, width=14, anchor="e")
        lbl.pack(side="left")
        
        val_lbl = tk.Label(f, text=f" {val_text}", font=font, fg="#ffffff", bg=bg)
        val_lbl.pack(side="left")
        return val_lbl

    def _make_row_with_speakers(self, parent, label_text, val_text, font, bg, alert_config_1, alert_config_2):
        f = tk.Frame(parent, bg=bg)
        f.pack(anchor="w", pady=1)
        lbl = tk.Label(f, text=label_text, font=font, fg="#ffffff", bg=bg, width=14, anchor="e")
        lbl.pack(side="left")
        
        val_lbl = tk.Label(f, text=f" {val_text}", font=font, fg="#ffffff", bg=bg)
        val_lbl.pack(side="left")

        # Speaker button 1
        def toggle_spk1():
            cfg = alert_config_1
            if not cfg["enabled"]:
                val = simpledialog.askfloat("Alert Threshold", f"Alert when {label_text} drops BELOW this threshold:", initialvalue=cfg["thresh"])
                if val is not None:
                    cfg["thresh"] = val
                    cfg["enabled"] = True
                    btn1.config(text="🔊", fg="#50fa7b")
            else:
                cfg["enabled"] = False
                btn1.config(text="🔇", fg="#ffffff")

        btn1 = tk.Button(f, text="🔇", font=("Arial", 11, "bold"), bg=bg, fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_spk1)
        btn1.pack(side="left", padx=6)
        ToolTip(btn1, lambda: f"Alert when drops below {alert_config_1['thresh']}")
        alert_config_1["btn"] = btn1

        # Speaker button 2
        def toggle_spk2():
            cfg = alert_config_2
            if not cfg["enabled"]:
                val = simpledialog.askfloat("Alert Threshold", f"Alert when {label_text} rises ABOVE this threshold:", initialvalue=cfg["thresh"])
                if val is not None:
                    cfg["thresh"] = val
                    cfg["enabled"] = True
                    btn2.config(text="🔊", fg="#50fa7b")
            else:
                cfg["enabled"] = False
                btn2.config(text="🔇", fg="#ffffff")

        btn2 = tk.Button(f, text="🔇", font=("Arial", 11, "bold"), bg=bg, fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_spk2)
        btn2.pack(side="left", padx=2)
        ToolTip(btn2, lambda: f"Alert when rises above {alert_config_2['thresh']}")
        alert_config_2["btn"] = btn2

        return val_lbl

    def login(self):
        url = f"https://{self.host}/api/login/Basic"
        payload = {
            "username": "customer",
            "password": self.password,
            "email": self.email
        }
        try:
            res = self.session.post(url, json=payload, timeout=10)
            if res.status_code == 200:
                return True
            log_error(f"Login Error {res.status_code}: {res.text}")
            return False
        except Exception as e:
            log_error(f"Login Exception: {e}")
            return False

    def login_loop(self):
        while True:
            self.login()
            time.sleep(3600)

    def fetch_endpoint(self, endpoint):
        url = f"https://{self.host}{endpoint}"
        try:
            res = self.session.get(url, timeout=5)
            if res.status_code == 401:
                if self.login():
                    res = self.session.get(url, timeout=5)
            
            if res.status_code == 200:
                return res.json()
            return {"error": f"API Error {res.status_code}"}
        except requests.exceptions.RequestException as e:
            return {"error": "Connection Exception"}
        except Exception as e:
            return {"error": "Unexpected Error"}

    def poll_loop(self):
        while True:
            has_all_data = self.ts_aggregates and self.ts_soe and self.ts_grid_status
            if not has_all_data:
                time.sleep(FAST_POLL_INTERVAL)
            else:
                now_t = time.time()
                sleep_duration = self.poll_interval - (now_t % self.poll_interval)
                if sleep_duration <= 0:
                    sleep_duration = self.poll_interval
                time.sleep(sleep_duration)

            self.refresh_aggregates()
            self.refresh_soe()
            self.refresh_grid()

    def refresh_aggregates(self):
        res = self.fetch_endpoint("/api/meters/aggregates")
        if isinstance(res, dict) and "error" not in res:
            self.cached_aggregates = res
            self.ts_aggregates = time.time()
            save_debug_file("powerwall2_monitor_meters_aggregates.json", res)
            self.compile_and_process()

    def refresh_soe(self):
        res = self.fetch_endpoint("/api/system_status/soe")
        if isinstance(res, dict) and "error" not in res:
            self.cached_soe = res
            self.ts_soe = time.time()
            save_debug_file("powerwall2_monitor_soe.json", res)
            self.compile_and_process()

    def refresh_grid(self):
        res = self.fetch_endpoint("/api/system_status/grid_status")
        if isinstance(res, dict) and "error" not in res:
            self.cached_grid_status = res
            self.ts_grid_status = time.time()
            save_debug_file("powerwall2_monitor_grid_status.json", res)
            self.compile_and_process()

    def compile_and_process(self):
        data = {
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "aggregates": self.cached_aggregates,
            "soe": self.cached_soe,
            "grid_status": self.cached_grid_status
        }
        self.root.after(0, lambda: self.update_ui(data))

    def update_ui(self, data):
        agg = data.get("aggregates", {})
        solar_w = agg.get("solar", {}).get("instant_power", 0) or agg.get("solar_power", 0) or 0
        battery_w = agg.get("battery", {}).get("instant_power", 0) or agg.get("battery_power", 0) or 0
        grid_w = (
            agg.get("grid", {}).get("instant_power", 0) or 
            agg.get("grid_power", 0) or 
            agg.get("site", {}).get("instant_power", 0)
        )
        load_w = agg.get("load", {}).get("instant_power", 0) or agg.get("load_power", 0) or 0
        freq = agg.get("solar", {}).get("frequency", 0) or agg.get("grid", {}).get("frequency", 50.0) or 50.0

        solar_kw = solar_w / 1000.0
        battery_kw = battery_w / 1000.0
        grid_kw = grid_w / 1000.0
        load_kw = load_w / 1000.0

        soe = data.get("soe", {})
        soc = soe.get("percentage", 0) or soe.get("percentage_charged", 0) or 0

        # Cache values for alert checking in ticker loop
        self.current_soc = soc
        self.current_bat_kw = battery_kw
        self.current_grid_kw = grid_kw
        self.current_load_kw = load_kw

        gs = data.get("grid_status", {})
        grid_status = gs.get("grid_status", "Unknown")
        grid_services = gs.get("grid_services_active", False)

        # Update Grid Status UI elements
        status_str = str(grid_status).lower()
        if any(ok in status_str for ok in ("up", "connected", "active", "normal", "systemgridconnected")):
            self.lbl_grid_status.config(text=f" {grid_status}", fg="#50fa7b")
        else:
            self.lbl_grid_status.config(text=f" {grid_status}", fg="#ff5555")
        self.lbl_grid_services.config(text=f" {'Active' if grid_services else 'Inactive'}", fg="#ffffff")

        # Update Meters & Aggregates UI elements
        self.lbl_solar.config(text=f" {solar_kw:.3f} kW", fg="#50fa7b" if solar_kw > 0 else "#ffffff")
        if battery_kw < 0:
            self.lbl_battery.config(text=f" {abs(battery_kw):.3f} kW (Charging)", fg="#50fa7b")
        elif battery_kw > 0:
            self.lbl_battery.config(text=f" {battery_kw:.3f} kW (Discharging)", fg="#f1fa8c")
        else:
            self.lbl_battery.config(text=f" {battery_kw:.3f} kW (Idle)", fg="#ffffff")

        if grid_kw > 0:
            self.lbl_grid.config(text=f" {grid_kw:.3f} kW (Importing)", fg="#ff5555")
        elif grid_kw < 0:
            self.lbl_grid.config(text=f" {abs(grid_kw):.3f} kW (Exporting)", fg="#50fa7b")
        else:
            self.lbl_grid.config(text=f" {grid_kw:.3f} kW (Idle)", fg="#ffffff")

        self.lbl_home.config(text=f" {load_kw:.3f} kW", fg="#ffffff")
        self.lbl_freq.config(text=f" {freq:.2f} Hz", fg="#ffffff")

        # Update State of Energy (SOE) UI elements
        self.lbl_soc.config(text=f" {soc:.1f}%", fg="#f1fa8c" if soc > 20 else "#ff5555")

    def manual_refresh_aggregates(self):
        threading.Thread(target=self.refresh_aggregates, daemon=True).start()

    def manual_refresh_soe(self):
        threading.Thread(target=self.refresh_soe, daemon=True).start()

    def manual_refresh_grid(self):
        threading.Thread(target=self.refresh_grid, daemon=True).start()

    def manual_refresh(self):
        self.refresh_aggregates()
        self.refresh_soe()
        self.refresh_grid()

    def ticker_loop(self):
        last_beep_second = -1
        while True:
            now = datetime.now()
            now_ts = time.time()
            s = now.second
            
            # Check if we are on a 5-second boundary (e.g., :00, :05, :10, etc.)
            is_5s_mark = (s % 5 == 0 and s != last_beep_second)
            if is_5s_mark:
                last_beep_second = s

            # Evaluate each alert pair
            any_alert = False
            for val, cfg1, cfg2 in [
                (self.current_soc, self.soc_alert1, self.soc_alert2),
                (self.current_bat_kw, self.bat_alert1, self.bat_alert2),
                (self.current_grid_kw, self.grid_alert1, self.grid_alert2),
                (self.current_load_kw, self.load_alert1, self.load_alert2)
            ]:
                for cfg in [cfg1, cfg2]:
                    if not cfg["btn"]:
                        continue

                    if not cfg["enabled"]:
                        self.root.after(0, lambda c=cfg: c["btn"].config(fg="#ffffff"))
                        continue

                    tripped = False
                    if val is not None:
                        if cfg["mode"] == "below" and val < cfg["thresh"]:
                            tripped = True
                        elif cfg["mode"] == "above" and val > cfg["thresh"]:
                            tripped = True

                    # Active = green (#50fa7b) if untripped, Red (#ff5555) if tripped
                    color = "#ff5555" if tripped else "#50fa7b"
                    self.root.after(0, lambda c=cfg, col=color: c["btn"].config(fg=col))

                    if tripped:
                        any_alert = True

            # Play beep sound exactly on the 5-second mark if any threshold is tripped
            if is_5s_mark and any_alert:
                try:
                    winsound.Beep(900, 150)
                except Exception:
                    pass

            def format_age(ts):
                if not ts: return "--s"
                elapsed = int(now_ts - ts)
                return f"{elapsed}s"

            up_agg = format_age(self.ts_aggregates)
            up_soe = format_age(self.ts_soe)
            up_grid = format_age(self.ts_grid_status)

            self.root.after(0, lambda u1=up_agg, u2=up_soe, u3=up_grid: [
                self.lbl_ctime.config(text=f" {time.strftime('%H:%M:%S')}"),
                self.lbl_up_agg.config(text=f"Updated: {u1}"),
                self.lbl_up_soe.config(text=f"Updated: {u2}"),
                self.lbl_up_grid.config(text=f"Updated: {u3}")
            ])
            time.sleep(0.05)

if __name__ == "__main__":
    try:
        root = tk.Tk()
        app = PowerwallMonitorApp(root)
        root.mainloop()
    except Exception as e:
        log_error(f"CRITICAL ERROR: Unhandled exception during startup: {e}")
        raise