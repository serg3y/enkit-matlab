# Setup:
# 1. Install packages using command line
#      pip install requests
# 2. Create amber.ini file as follows:
#      token = YOUR_API_TOKEN
#      id = YOUR_SITE_ID

import os, json, re, subprocess, threading, time, base64, winsound
import tkinter as tk
from tkinter import simpledialog
from datetime import datetime, timezone

# ==================== CONFIGURATION ====================
# Polling intervals (in seconds)
ESTIMATED_INTERVAL = 2.0
LIVE_INTERVAL = 60.0

# Default Alert Thresholds (c/kWh)
DEFAULT_BUY_LOW_THRESH = 0.0
DEFAULT_BUY_HIGH_THRESH = 30.0
DEFAULT_SELL_LOW_THRESH = 0.0
DEFAULT_SELL_HIGH_THRESH = 10.0

# Buy Pricing Tiers: (Threshold, Foreground Color, Background Color)
BUY_VAL_1, BUY_FG_1, BUY_BG_1 = -10.0, "#000000", "#50fa7b"
BUY_VAL_2, BUY_FG_2, BUY_BG_2 =   0.0, "#50fa7b", "#252526"
BUY_VAL_3, BUY_FG_3, BUY_BG_3 =  30.0, "#f1fa8c", "#252526"
BUY_VAL_4, BUY_FG_4, BUY_BG_4 = 100.0, "#ff5555", "#252526"
BUY_FG_EXT, BUY_BG_EXT        =        "#ffffff", "#ff5555"

# Sell Pricing Tiers: (Threshold, Foreground Color, Background Color)
SELL_VAL_1, SELL_FG_1, SELL_BG_1 = -10.0, "#ffffff", "#ff5555"
SELL_VAL_2, SELL_FG_2, SELL_BG_2 =   0.0, "#ff5555", "#252526"
SELL_VAL_3, SELL_FG_3, SELL_BG_3 =  30.0, "#f1fa8c", "#252526"
SELL_VAL_4, SELL_FG_4, SELL_BG_4 = 100.0, "#50fa7b", "#252526"
SELL_FG_EXT, SELL_BG_EXT        =        "#000000", "#50fa7b"
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
        with open("amber_monitor.log", "a") as f: f.write(formatted)
    except Exception: pass

def load_ini_config():
    token, site_id, state, ini_nmi, ini_active_from = "", "", "SA", "", ""
    ini_path = "amber.ini"
    if not os.path.exists(ini_path):
        default_content = "token = \nid = \nstate = sa\nnmi = \nactiveFrom = \n"
        try:
            with open(ini_path, "w") as f:
                f.write(default_content)
            log_error("amber.ini not found. Created default template.")
        except Exception as e:
            log_error(f"Failed to write amber.ini: {e}")
    else:
        try:
            with open(ini_path, "r") as f:
                txt = f.read()
                if (m := re.search(r'^\s*token\s*=\s*(\S+)', txt, re.M)): token = m.group(1)
                if (m := re.search(r'^\s*id\s*=\s*(\S+)', txt, re.M)): site_id = m.group(1)
                if (m := re.search(r'^\s*state\s*=\s*(\S+)', txt, re.M)): state = m.group(1).upper()
                if (m := re.search(r'^\s*nmi\s*=\s*(\S+)', txt, re.M)): ini_nmi = m.group(1)
                if (m := re.search(r'^\s*activeFrom\s*=\s*(\S+)', txt, re.M)): ini_active_from = m.group(1)
        except Exception as e:
            log_error(f"Error reading amber.ini: {e}")
            
    return token, site_id, state, ini_nmi, ini_active_from

class AmberMonitorApp:
    def __init__(self, root):
        enforce_single_instance()
        self.root = root
        self.root.title("Amber Monitor")
        
        # Load custom app icon from Base64 string
        try:
            icon_data = base64.b64decode(
                "R0lGODlhEwATALMAANnZ2cLG0EdTcYSMoAoaQgD/qAWMdQLGjgdTW"
                "////////////////////////////yH5BAEAAAAALAAAAAATABMAAARd"
                "EMgJgriD6km695s0fGSXUWNZBpTqcmQhFwYpSHFxGPJBAqmO7MNDfC"
                "wfWsznCRIQhdKwKUgak9FmAEucdnBY3Sz7BZR4Mij5ZHaVKFu3h4W"
                "SE0Lg0g0/CQwEdBsRADs="
            )
            self.app_icon = tk.PhotoImage(data=icon_data)
            self.root.iconphoto(True, self.app_icon)
        except Exception as e:
            log_error(f"Icon load warning: {e}")

        self.token, self.site_id, self.state, self.ini_nmi, self.ini_active_from = load_ini_config()
        
        # Window dimensions and top-right positioning
        w, h = 390, 475
        screen_w = root.winfo_screenwidth()
        x = screen_w - w - 40
        y = 40
        self.root.geometry(f"{w}x{h}+{x}+{y}")
        
        self.root.resizable(False, False)
        self.root.configure(bg="#1e1e1e")
        
        self.last_sites_fetch_timestamp = None
        self.last_fetch_timestamp = None
        self.season_name = "--"
        self.period_name = "--"
        self.is_estimated = True
        self.high_freq = False
        self.current_interval_start = None
        self.live_since_ts = None
        self.live_since_str = None
        self.last_buy = None
        self.last_sell = None
        self.last_nem = None
        
        # Sound states and thresholds from config
        self.sound_enabled = False
        self.est_sound_enabled = False

        self.buy_low_enabled = False
        self.buy_low_thresh = DEFAULT_BUY_LOW_THRESH

        self.buy_high_enabled = False
        self.buy_high_thresh = DEFAULT_BUY_HIGH_THRESH

        self.sell_low_enabled = False
        self.sell_low_thresh = DEFAULT_SELL_LOW_THRESH

        self.sell_high_enabled = False
        self.sell_high_thresh = DEFAULT_SELL_HIGH_THRESH

        self.current_buy_val = None
        self.current_sell_val = None
        
        font = ("Arial", 11, "bold")
        
        # --- Outside Section: PC Time & Next Period ---
        top_info_frame = tk.Frame(root, bg="#1e1e1e")
        top_info_frame.pack(fill="x", padx=6, pady=4)
        
        self.lbl_ctime = self._make_row(top_info_frame, "PC Time:", "--:--:--", font, bg="#1e1e1e")
        
        # Next Period row with speaker toggle button
        next_frame = tk.Frame(top_info_frame, bg="#1e1e1e")
        next_frame.pack(anchor="w", pady=1)
        lbl_next_title = tk.Label(next_frame, text="Next Period:", font=font, fg="#ffffff", bg="#1e1e1e", width=12, anchor="e")
        lbl_next_title.pack(side="left")
        
        self.lbl_next_val = tk.Label(next_frame, text=" --s", font=font, fg="#ffffff", bg="#1e1e1e")
        self.lbl_next_val.pack(side="left")
        
        def toggle_sound():
            self.sound_enabled = not self.sound_enabled
            btn_speaker.config(text="🔊" if self.sound_enabled else "🔇", fg="#50fa7b" if self.sound_enabled else "#ffffff")

        btn_speaker = tk.Button(next_frame, text="🔇", font=("Arial", 11), bg="#1e1e1e", fg="#ffffff", bd=0, relief="flat", activebackground="#2d2d2d", activeforeground="#ffffff", command=toggle_sound)
        btn_speaker.pack(side="left", padx=8)
        ToolTip(btn_speaker, lambda: "Toggle alert beep when period countdown reaches 0s")
        self.btn_speaker = btn_speaker
        
        # --- Sites Section ---
        sites_outer_frame = tk.Frame(root, bg="#252526", bd=1, relief="solid")
        sites_outer_frame.pack(fill="x", padx=6, pady=2)
        
        sites_header_frame = tk.Frame(sites_outer_frame, bg="#2d2d2d")
        sites_header_frame.pack(fill="x", padx=1, pady=1)
        
        sites_title_lbl = tk.Label(sites_header_frame, text="Sites", font=("Arial", 10, "bold"), fg="#8be9fd", bg="#2d2d2d")
        sites_title_lbl.pack(side="left", anchor="w", padx=4)
        
        sites_refresh_btn = tk.Button(sites_header_frame, text="🔄", font=("Arial", 11), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.manual_refresh_sites)
        sites_refresh_btn.pack(side="right", anchor="ne", padx=4)
        ToolTip(sites_refresh_btn, lambda: "Refresh sites data")

        self.lbl_up_sites = tk.Label(sites_header_frame, text="Updated: --s", font=("Arial", 9, "italic"), fg="#a0a0a0", bg="#2d2d2d")
        self.lbl_up_sites.pack(side="right", anchor="e", padx=4)
        
        sites_body_frame = tk.Frame(sites_outer_frame, bg="#252526")
        sites_body_frame.pack(fill="x", padx=6, pady=6)
        
        self.lbl_network = self._make_row(sites_body_frame, "Network:", "--", font, bg="#252526")
        self.lbl_nmi = self._make_row(sites_body_frame, "NMI:", self.ini_nmi or "--", font, bg="#252526")
        self.lbl_active_from = self._make_row(sites_body_frame, "Active From:", self.ini_active_from or "--", font, bg="#252526")
        self.lbl_site_status = self._make_row(sites_body_frame, "Status:", "--", font, bg="#252526")
        self.lbl_tariff = self._make_row(sites_body_frame, "Tariff:", "--", font, bg="#252526")

        # --- Prices Section ---
        outer_frame = tk.Frame(root, bg="#252526", bd=1, relief="solid")
        outer_frame.pack(fill="x", padx=6, pady=2)
        
        header_frame = tk.Frame(outer_frame, bg="#2d2d2d")
        header_frame.pack(fill="x", padx=1, pady=1)
        
        title_lbl = tk.Label(header_frame, text="Prices", font=("Arial", 10, "bold"), fg="#8be9fd", bg="#2d2d2d")
        title_lbl.pack(side="left", anchor="w", padx=4)
        
        refresh_btn = tk.Button(header_frame, text="🔄", font=("Arial", 11), bg="#2d2d2d", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=self.manual_refresh_prices)
        refresh_btn.pack(side="right", anchor="ne", padx=4)
        ToolTip(refresh_btn, lambda: "Refresh prices data")

        self.lbl_up_main = tk.Label(header_frame, text="Updated: --s", font=("Arial", 9, "italic"), fg="#a0a0a0", bg="#2d2d2d")
        self.lbl_up_main.pack(side="right", anchor="e", padx=4)
        
        body_frame = tk.Frame(outer_frame, bg="#252526")
        body_frame.pack(fill="x", padx=6, pady=6)
        
        self.lbl_season = self._make_row(body_frame, "Season:", self.season_name, font, bg="#252526")
        self.lbl_period = self._make_row(body_frame, "Period:", self.period_name, font, bg="#252526")
        
        # Status row with estimated beep speaker toggle
        status_frame = tk.Frame(body_frame, bg="#252526")
        status_frame.pack(anchor="w", pady=1)
        lbl_status_title = tk.Label(status_frame, text="Status:", font=font, fg="#ffffff", bg="#252526", width=12, anchor="e")
        lbl_status_title.pack(side="left")
        
        self.lbl_status = tk.Label(status_frame, text=" --", font=font, fg="#ffffff", bg="#252526")
        self.lbl_status.pack(side="left")
        
        def toggle_est_sound():
            self.est_sound_enabled = not self.est_sound_enabled
            btn_est_speaker.config(text="🔊" if self.est_sound_enabled else "🔇", fg="#50fa7b" if self.est_sound_enabled else "#ffffff")

        btn_est_speaker = tk.Button(status_frame, text="🔇", font=("Arial", 11), bg="#252526", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_est_sound)
        btn_est_speaker.pack(side="left", padx=8)
        ToolTip(btn_est_speaker, lambda: "Toggle alert beep every 5s while status is Estimated")
        self.btn_est_speaker = btn_est_speaker

        # --- Buy Price Row with 2 Threshold Speakers ---
        buy_frame = tk.Frame(body_frame, bg="#252526")
        buy_frame.pack(anchor="w", pady=1)
        lbl_buy_title = tk.Label(buy_frame, text="Buy Price:", font=font, fg="#ffffff", bg="#252526", width=12, anchor="e")
        lbl_buy_title.pack(side="left")
        self.lbl_buy = tk.Label(buy_frame, text=" -- (c/kWh)", font=font, fg="#ffffff", bg="#252526")
        self.lbl_buy.pack(side="left")

        def toggle_buy_low():
            if not self.buy_low_enabled:
                val = simpledialog.askfloat("Alert threshold", "Alert when value drops BELOW this threshold:", initialvalue=self.buy_low_thresh)
                if val is not None:
                    self.buy_low_thresh = val
                    self.buy_low_enabled = True
                    btn_buy_low.config(text="🔊", fg="#50fa7b")
            else:
                self.buy_low_enabled = False
                btn_buy_low.config(text="🔇", fg="#ffffff")

        def toggle_buy_high():
            if not self.buy_high_enabled:
                val = simpledialog.askfloat("Alert threshold", "Alert when value rises ABOVE this threshold:", initialvalue=self.buy_high_thresh)
                if val is not None:
                    self.buy_high_thresh = val
                    self.buy_high_enabled = True
                    btn_buy_high.config(text="🔊", fg="#50fa7b")
            else:
                self.buy_high_enabled = False
                btn_buy_high.config(text="🔇", fg="#ffffff")

        btn_buy_low = tk.Button(buy_frame, text="🔇", font=("Arial", 11), bg="#252526", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_buy_low)
        btn_buy_low.pack(side="left", padx=4)
        ToolTip(btn_buy_low, lambda: f"Alert when value drops BELOW {self.buy_low_thresh}")
        self.btn_buy_low = btn_buy_low

        btn_buy_high = tk.Button(buy_frame, text="🔇", font=("Arial", 11), bg="#252526", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_buy_high)
        btn_buy_high.pack(side="left", padx=2)
        ToolTip(btn_buy_high, lambda: f"Alert when value rises ABOVE {self.buy_high_thresh}")
        self.btn_buy_high = btn_buy_high

        # --- Sell Price Row with 2 Threshold Speakers ---
        sell_frame = tk.Frame(body_frame, bg="#252526")
        sell_frame.pack(anchor="w", pady=1)
        lbl_sell_title = tk.Label(sell_frame, text="Sell Price:", font=font, fg="#ffffff", bg="#252526", width=12, anchor="e")
        lbl_sell_title.pack(side="left")
        self.lbl_sell = tk.Label(sell_frame, text=" -- (c/kWh)", font=font, fg="#ffffff", bg="#252526")
        self.lbl_sell.pack(side="left")

        def toggle_sell_low():
            if not self.sell_low_enabled:
                val = simpledialog.askfloat("Alert threshold", "Alert when value drops BELOW this threshold:", initialvalue=self.sell_low_thresh)
                if val is not None:
                    self.sell_low_thresh = val
                    self.sell_low_enabled = True
                    btn_sell_low.config(text="🔊", fg="#50fa7b")
            else:
                self.sell_low_enabled = False
                btn_sell_low.config(text="🔇", fg="#ffffff")

        def toggle_sell_high():
            if not self.sell_high_enabled:
                val = simpledialog.askfloat("Alert threshold", "Alert when value rises ABOVE this threshold:", initialvalue=self.sell_high_thresh)
                if val is not None:
                    self.sell_high_thresh = val
                    self.sell_high_enabled = True
                    btn_sell_high.config(text="🔊", fg="#50fa7b")
            else:
                self.sell_high_enabled = False
                btn_sell_high.config(text="🔇", fg="#ffffff")

        btn_sell_low = tk.Button(sell_frame, text="🔇", font=("Arial", 11), bg="#252526", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_sell_low)
        btn_sell_low.pack(side="left", padx=4)
        ToolTip(btn_sell_low, lambda: f"Alert when value drops BELOW {self.sell_low_thresh}")
        self.btn_sell_low = btn_sell_low

        btn_sell_high = tk.Button(sell_frame, text="🔇", font=("Arial", 11), bg="#252526", fg="#ffffff", bd=0, relief="flat", activebackground="#3d3d3d", activeforeground="#ffffff", command=toggle_sell_high)
        btn_sell_high.pack(side="left", padx=2)
        ToolTip(btn_sell_high, lambda: f"Alert when value rises ABOVE {self.sell_high_thresh}")
        self.btn_sell_high = btn_sell_high

        self.lbl_nem = self._make_row(body_frame, "NEM Price:", "-- (c/kWh)", font, bg="#252526")

        if not self.token or not self.site_id:
            log_error("Missing credentials in amber.ini")
            self.lbl_status.config(text=" Config Error", fg="#ff5555")
        else:
            threading.Thread(target=self.fetch_sites, daemon=True).start()
            threading.Thread(target=self.poll_loop, daemon=True).start()
            threading.Thread(target=self.ticker_loop, daemon=True).start()

    def _make_row(self, parent, label_text, val_text, font, bg):
        f = tk.Frame(parent, bg=bg)
        f.pack(anchor="w", pady=1)
        lbl = tk.Label(f, text=label_text, font=font, fg="#ffffff", bg=bg, width=12, anchor="e")
        lbl.pack(side="left")
        
        val_lbl = tk.Label(f, text=f" {val_text}", font=font, fg="#ffffff", bg=bg)
        val_lbl.pack(side="left")
        return val_lbl

    def fetch_sites(self):
        url = "https://api.amber.com.au/v1/sites"
        headers = {"Authorization": f"Bearer {self.token}", "Accept": "application/json"}
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                try:
                    data = res.json()
                    with open("amber_monitor_sites.json", "w", encoding="utf-8") as f:
                        json.dump(data, f, indent=4)
                    
                    target_site = None
                    if isinstance(data, list):
                        for s in data:
                            if s.get("id") == self.site_id:
                                target_site = s
                                break
                    elif isinstance(data, dict) and data.get("id") == self.site_id:
                        target_site = data

                    if target_site:
                        network = target_site.get("network", "--")
                        nmi = target_site.get("nmi", self.ini_nmi or "--")
                        status = target_site.get("status", "--")
                        active_from = self.ini_active_from or "--"
                        
                        tariff = "--"
                        channels = target_site.get("channels", [])
                        if channels and isinstance(channels, list):
                            for ch in channels:
                                if ch.get("tariff"):
                                    tariff = ch.get("tariff")
                                    break

                        self.root.after(0, lambda: [
                            self.lbl_network.config(text=f" {network}"),
                            self.lbl_nmi.config(text=f" {nmi}"),
                            self.lbl_active_from.config(text=f" {active_from}"),
                            self.lbl_site_status.config(text=f" {status}"),
                            self.lbl_tariff.config(text=f" {tariff}")
                        ])
                    self.last_sites_fetch_timestamp = time.time()
                except Exception as e:
                    log_error(f"Failed to process sites JSON: {e}")
                return data
            else:
                log_error(f"Sites API Error {res.status_code}")
        except Exception as e:
            log_error(f"Sites fetch exception: {e}")
        return None

    def fetch_data(self):
        url = f"https://api.amber.com.au/v1/sites/{self.site_id}/prices/current"
        headers = {"Authorization": f"Bearer {self.token}", "Accept": "application/json"}
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                try:
                    data = res.json()
                    with open("amber_monitor_prices.json", "w", encoding="utf-8") as f:
                        json.dump(data, f, indent=4)
                except Exception as e:
                    log_error(f"Failed to write prices JSON: {e}")
                return res.json()
            
            err_msg = f"API Error {res.status_code}: Too many requests" if res.status_code == 429 else f"API Error {res.status_code}"
            log_error(err_msg)
            return {"error": err_msg}
        except requests.exceptions.RequestException as e:
            err_msg = "Connection Exception"
            log_error(f"{err_msg}: {e}")
            return {"error": err_msg}
        except Exception as e:
            err_msg = "Unexpected Error"
            log_error(f"{err_msg}: {e}")
            return {"error": err_msg}

    def process_data(self, data):
        if not data: return False
        
        if isinstance(data, dict) and "error" in data:
            err_text = data["error"]
            self.root.after(0, lambda: self.lbl_status.config(text=f" {err_text}", fg="#ff5555", bg="#252526"))
            return False

        buy_val, sell_val, spot_val, is_live, start_str = None, None, None, False, None
        now_utc = datetime.now(timezone.utc)
        
        intervals = [i for i in data if i.get("startTime") and i.get("endTime") and 
                     datetime.fromisoformat(i["startTime"].replace("Z", "+00:00")) <= now_utc < datetime.fromisoformat(i["endTime"].replace("Z", "+00:00"))]
        target = intervals if intervals else data

        for interval in target:
            if not start_str: start_str = interval.get("startTime")
            if interval.get("type") in ("CurrentInterval", "ActualInterval") and not interval.get("estimate", False):
                is_live = True
            
            if interval.get("tariffInformation"):
                t_info = interval["tariffInformation"]
                self.season_name = t_info.get("season", self.season_name)
                self.period_name = t_info.get("period", self.period_name)
                self.lbl_season.config(text=f" {self.season_name}")
                self.lbl_period.config(text=f" {self.period_name}")
                
            if interval.get("channelType") == "general":
                buy_val = interval.get("perKwh")
                spot_val = interval.get("spotPerKwh")
            elif interval.get("channelType") == "feedIn":
                if interval.get("perKwh") is not None:
                    sell_val = -interval.get("perKwh")

        if start_str != self.current_interval_start:
            self.current_interval_start = start_str
            self.live_since_ts = self.live_since_str = None

        if is_live:
            if buy_val is not None: self.last_buy = buy_val
            if sell_val is not None: self.last_sell = sell_val
            if spot_val is not None: self.last_nem = spot_val
            if not self.live_since_ts:
                self.live_since_ts, self.live_since_str = time.time(), time.strftime("%H:%M:%S")
        else:
            self.live_since_ts = self.live_since_str = None

        self.current_buy_val = buy_val
        self.current_sell_val = sell_val

        self.is_estimated = not is_live
        self.root.after(0, lambda: self.update_ui(buy_val, sell_val, spot_val, self.is_estimated))
        return is_live

    def update_ui(self, buy, sell, spot, estimated):
        if estimated:
            self.lbl_status.config(text=" ESTIMATE", fg="#ff5555", bg="#252526")
        else:
            status_text = f" LIVE (since {self.live_since_str})" if self.live_since_str else " LIVE"
            self.lbl_status.config(text=status_text, fg="#50fa7b", bg="#252526")

        self._style_price(self.lbl_buy, buy, self.last_buy, estimated, is_buy=True)
        self._style_price(self.lbl_sell, sell, self.last_sell, estimated, is_buy=False)
        self._style_nem(self.lbl_nem, spot, self.last_nem, estimated)

        self.last_fetch_timestamp = time.time()

    def _style_price(self, lbl, val, last_val, estimated, is_buy):
        if val is None:
            lbl.config(text=" N/A", fg="#888888", bg="#252526")
            return
            
        if estimated:
            if last_val is not None:
                text = f" est. {val:.2f}, last {last_val:.2f} (c/kWh)"
            else:
                text = f" est. {val:.2f} (c/kWh)"
            lbl.config(text=text, fg="#888888", bg="#252526")
        else:
            text = f" {val:.2f} (c/kWh)"
            
            if is_buy:
                if val < BUY_VAL_1:   fg, bg = BUY_FG_1, BUY_BG_1
                elif val < BUY_VAL_2:  fg, bg = BUY_FG_2, BUY_BG_2
                elif val <= BUY_VAL_3: fg, bg = BUY_FG_3, BUY_BG_3
                elif val <= BUY_VAL_4: fg, bg = BUY_FG_4, BUY_BG_4
                else:                  fg, bg = BUY_FG_EXT, BUY_BG_EXT
            else:
                if val < SELL_VAL_1:   fg, bg = SELL_FG_1, SELL_BG_1
                elif val < SELL_VAL_2:  fg, bg = SELL_FG_2, SELL_BG_2
                elif val <= SELL_VAL_3: fg, bg = SELL_FG_3, SELL_BG_3
                elif val <= SELL_VAL_4: fg, bg = SELL_FG_4, SELL_BG_4
                else:                  fg, bg = SELL_FG_EXT, SELL_BG_EXT
                
            lbl.config(text=text, fg=fg, bg=bg)

    def _style_nem(self, lbl, val, last_val, estimated):
        if val is None:
            lbl.config(text=" N/A", fg="#888888", bg="#252526")
            return
            
        if estimated:
            if last_val is not None:
                text = f" est. {val:.2f}, last {last_val:.2f} (c/kWh)"
            else:
                text = f" est. {val:.2f} (c/kWh)"
            lbl.config(text=text, fg="#888888", bg="#252526")
        else:
            text = f" {val:.2f} (c/kWh)"
            lbl.config(text=text, fg="#ffffff", bg="#252526")

    def manual_refresh_sites(self):
        threading.Thread(target=self.fetch_sites, daemon=True).start()

    def manual_refresh_prices(self):
        threading.Thread(target=lambda: self.process_data(self.fetch_data()), daemon=True).start()

    def manual_refresh(self):
        self.manual_refresh_sites()
        self.manual_refresh_prices()

    def poll_loop(self):
        if (data := self.fetch_data()): self.process_data(data)
        last_poll = 0
        while True:
            now = datetime.now()
            t_sec = time.time()
            should_poll = False
            
            if self.is_estimated:
                if t_sec - last_poll >= ESTIMATED_INTERVAL: should_poll = True
            else:
                if now.minute % 5 == 0 and now.second == 0: self.high_freq = True
                if self.high_freq:
                    if t_sec - last_poll >= LIVE_INTERVAL: should_poll = True
                elif now.second == 1 and t_sec - last_poll >= LIVE_INTERVAL: should_poll = True

            if should_poll:
                last_poll = t_sec
                if (data := self.fetch_data()):
                    if self.process_data(data) and self.high_freq:
                        self.high_freq = False
            time.sleep(0.2)

    def ticker_loop(self):
        last_sec_val = None
        last_beep_second = -1
        while True:
            now = datetime.now()
            now_ts = time.time()
            
            m = now.minute
            s = now.second
            seconds_left = 300 - ((m % 5) * 60 + s)
            if seconds_left <= 0:
                seconds_left = 300
                
            # Period countdown beep (at 0s)
            if seconds_left == 300 and last_sec_val == 1 and self.sound_enabled:
                try:
                    winsound.Beep(1000, 300)
                except Exception:
                    pass
            
            last_sec_val = seconds_left

            # Evaluate alert conditions and handle 5-second interval beeps + highlights
            is_5s_mark = (s % 5 == 0 and s != last_beep_second)
            if is_5s_mark:
                last_beep_second = s

            # 1. Period countdown speaker color
            self.root.after(0, lambda: self.btn_speaker.config(fg="#50fa7b" if self.sound_enabled else "#ffffff"))

            # 2. Estimated status alert
            est_tripped = self.is_estimated and self.est_sound_enabled
            est_active = self.est_sound_enabled
            self.root.after(0, lambda tripped=est_tripped, active=est_active: self.btn_est_speaker.config(
                fg="#ff5555" if tripped else ("#50fa7b" if active else "#ffffff")
            ))
            if is_5s_mark and est_tripped:
                try:
                    winsound.Beep(800, 200)
                except Exception:
                    pass

            # 3. Buy Low alert
            buy_low_tripped = self.buy_low_enabled and self.current_buy_val is not None and self.current_buy_val < self.buy_low_thresh
            buy_low_active = self.buy_low_enabled
            self.root.after(0, lambda tripped=buy_low_tripped, active=buy_low_active: self.btn_buy_low.config(
                fg="#ff5555" if tripped else ("#50fa7b" if active else "#ffffff")
            ))
            if is_5s_mark and buy_low_tripped:
                try:
                    winsound.Beep(700, 200)
                except Exception:
                    pass

            # 4. Buy High alert
            buy_high_tripped = self.buy_high_enabled and self.current_buy_val is not None and self.current_buy_val > self.buy_high_thresh
            buy_high_active = self.buy_high_enabled
            self.root.after(0, lambda tripped=buy_high_tripped, active=buy_high_active: self.btn_buy_high.config(
                fg="#ff5555" if tripped else ("#50fa7b" if active else "#ffffff")
            ))
            if is_5s_mark and buy_high_tripped:
                try:
                    winsound.Beep(1200, 200)
                except Exception:
                    pass

            # 5. Sell Low alert
            sell_low_tripped = self.sell_low_enabled and self.current_sell_val is not None and self.current_sell_val < self.sell_low_thresh
            sell_low_active = self.sell_low_enabled
            self.root.after(0, lambda tripped=sell_low_tripped, active=sell_low_active: self.btn_sell_low.config(
                fg="#ff5555" if tripped else ("#50fa7b" if active else "#ffffff")
            ))
            if is_5s_mark and sell_low_tripped:
                try:
                    winsound.Beep(700, 200)
                except Exception:
                    pass

            # 6. Sell High alert
            sell_high_tripped = self.sell_high_enabled and self.current_sell_val is not None and self.current_sell_val > self.sell_high_thresh
            sell_high_active = self.sell_high_enabled
            self.root.after(0, lambda tripped=sell_high_tripped, active=sell_high_active: self.btn_sell_high.config(
                fg="#ff5555" if tripped else ("#50fa7b" if active else "#ffffff")
            ))
            if is_5s_mark and sell_high_tripped:
                try:
                    winsound.Beep(1200, 200)
                except Exception:
                    pass
            
            self.root.after(0, lambda sl=seconds_left, nts=now_ts: [
                self.lbl_ctime.config(text=f" {time.strftime('%H:%M:%S')}"),
                self.lbl_next_val.config(text=f" {sl}s"),
                self.lbl_up_sites.config(text=f"Updated: {int(nts - self.last_sites_fetch_timestamp) if self.last_sites_fetch_timestamp else '--'}s"),
                self.lbl_up_main.config(text=f"Updated: {int(nts - self.last_fetch_timestamp) if self.last_fetch_timestamp else '--'}s")
            ])
            time.sleep(0.05)

if __name__ == "__main__":
    try:
        import requests
    except ImportError as e:
        log_error(f"CRITICAL ERROR: Missing required library 'requests'. Details: {e}")
        raise

    try:
        root = tk.Tk()
        app = AmberMonitorApp(root)
        root.mainloop()
    except Exception as e:
        log_error(f"CRITICAL ERROR: Unhandled exception during startup: {e}")
        raise