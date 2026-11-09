# Setup:
# 1. Install packages using command line
#      pip install requests matplotlib
# 2. Create amber.ini file as follows:
#      token = YOUR_API_TOKEN
#      id = YOUR_SITE_ID
#      state = SA

import os, json, re, subprocess, threading, time, base64, winsound, math
from functools import partial
from operator import itemgetter
import tkinter as tk
from tkinter import messagebox, simpledialog
from datetime import datetime, timezone, timedelta
import matplotlib.dates as mdates
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
from matplotlib.lines import Line2D
from matplotlib.patches import Patch, Rectangle
from matplotlib.ticker import MaxNLocator
try:
    import requests
except ImportError as e:
    requests = None
    REQUESTS_IMPORT_ERROR = e

# Ensure all file operations use the absolute path of the script directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")  # cached API responses live here
os.makedirs(DATA_DIR, exist_ok=True)
ACTION_FG = "#8be9fd"  # blue used for clickable header controls
PRICE_LABEL_WIDTH = 16  # field-name column width in the price tab
PRICE_TRACES = ("Buy", "Buy (Controlled)", "Sell", "Uncertainty")  # legend entries, in plot order
USAGE_TRACES = ("Imported", "Imported (Controlled)", "Exported")
HEADER_ICON_FONT = ("Segoe UI Emoji", 11, "bold")  # same emoji font as the speaker buttons
GEAR_FONT = ("Segoe UI Symbol", 12, "bold")  # text-style symbol, so use a symbol font

# ==================== CONFIGURATION ====================
ESTIMATED_INTERVAL = 2.0
LIVE_INTERVAL = 60.0
BACKGROUND_POLL_INTERVAL = 300.0

DEFAULT_BUY_LOW_THRESH = 0.0
DEFAULT_BUY_HIGH_THRESH = 60.0
DEFAULT_SELL_LOW_THRESH = 0.0
DEFAULT_SELL_HIGH_THRESH = 30.0

BUY_BANDS = (  # (limit, include_limit, text colour, background)
    (-10.0, False, "#000000", "#50fa7b"),
    (0.0, False, "#50fa7b", "#252526"),
    (30.0, True, "#f1fa8c", "#252526"),
    (100.0, True, "#ff5555", "#252526"),
)
BUY_BAND_ABOVE = ("#ffffff", "#ff5555")

SELL_BANDS = (
    (-10.0, False, "#ffffff", "#ff5555"),
    (0.0, False, "#ff5555", "#252526"),
    (30.0, True, "#f1fa8c", "#252526"),
    (100.0, True, "#50fa7b", "#252526"),
)
SELL_BAND_ABOVE = ("#000000", "#50fa7b")
# =======================================================


def beep(freq=800, duration=200):
    try:
        winsound.Beep(freq, duration)
    except Exception:
        pass

class ToolTip:
    """Simple tooltip helper for Tkinter widgets."""
    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tip_window = None
        widget.bind("<Enter>", self.show_tip)
        widget.bind("<Leave>", self.hide_tip)

    def show_tip(self, event=None):
        if self.tip_window:
            return
        text = self.text() if callable(self.text) else self.text
        if not text:
            return
        x = self.widget.winfo_rootx() + 20
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 5
        self.tip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        label = tk.Label(
            tw,
            text=text,
            justify="left",
            anchor="w",
            wraplength=360,
            background="#ffffe0",
            foreground="#000000",
            relief="solid",
            borderwidth=1,
        )
        label.pack(ipadx=1, ipady=1)

    def hide_tip(self, event=None):
        tw = self.tip_window
        self.tip_window = None
        if tw:
            tw.destroy()

def log_error(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{timestamp}] {msg}\n"
    log_path = os.path.join(SCRIPT_DIR, "amber_monitor.log")
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(formatted)
    except Exception as e:
        print(f"Logging failed: {e}")

def enforce_single_instance():
    """Kills any other running instances of this script via system process list."""
    current_pid = os.getpid()
    script_name = os.path.basename(__file__)
    try:
        if os.name == 'nt':
            escaped_script_name = script_name.replace("'", "''")
            cmd = (
                "$ErrorActionPreference = 'Stop'; "
                f"$currentPid = {current_pid}; "
                f"$scriptName = '{escaped_script_name}'; "
                "$anc = @(); $p = $currentPid; while ($p -and $anc -notcontains $p) { $anc += $p; $p = (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $p)).ParentProcessId }; "
                "$procs = Get-CimInstance Win32_Process | Where-Object { "
                "$_.Name -match '^python(w|[0-9.]*)?\\.exe$' -and "
                "$_.CommandLine -like ('*' + $scriptName + '*') -and "
                "$_.ProcessId -ne $currentPid -and $_.ProcessId -notin $anc }; "
                "foreach ($p in $procs) { "
                "try { "
                "Stop-Process -Id $p.ProcessId -Force; "
                "Wait-Process -Id $p.ProcessId "
                "} catch { "
                "if (Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue) { throw } "
                "} }"
            )
            result = subprocess.run(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", cmd],
                capture_output=True,
                text=True,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
                timeout=15,
            )
            if result.returncode:
                details = result.stderr.strip() or result.stdout.strip()
                log_error(f"Singleton check warning: PowerShell exited with {result.returncode}: {details}")
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
        log_error(f"Singleton check warning: {e}")

def load_ini_config():
    token, site_id, state = "", "", ""
    ini_path = os.path.join(SCRIPT_DIR, "amber.ini")
    if not os.path.exists(ini_path):
        default_content = "token = \nid = \nstate = sa\n"
        try:
            with open(ini_path, "w", encoding="utf-8") as f:
                f.write(default_content)
            log_error("amber.ini not found. Created default template.")
        except Exception as e:
            log_error(f"Failed to write amber.ini: {e}")
    else:
        try:
            with open(ini_path, "r", encoding="utf-8") as f:
                txt = f.read()
                if (m := re.search(r'^\s*token\s*=\s*(\S+)', txt, re.M)): token = m.group(1)
                if (m := re.search(r'^\s*id\s*=\s*(\S+)', txt, re.M)): site_id = m.group(1)
                if (m := re.search(r'^\s*state\s*=\s*(\S+)', txt, re.M)): state = m.group(1).upper()
        except Exception as e:
            log_error(f"Error reading amber.ini: {e}")
            
    return token, site_id, state


def format_age(seconds):
    """Return a compact age label: seconds under 90s, minutes under 90m, otherwise hours."""
    if seconds is None:
        return "--"
    if seconds < 90:
        return f"{int(seconds)}s"
    if seconds < 90 * 60:
        return f"{seconds / 60:.1f}m"
    return f"{seconds / 3600:.1f}h"


class AmberMonitorApp:
    def __init__(self, root):
        enforce_single_instance()
        self.root = root
        self.root.title("Amber Monitor")
        
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

        self.token, self.site_id, self.state = load_ini_config()
        
        w, h = 500, 944
        screen_w = root.winfo_screenwidth()
        screen_h = root.winfo_screenheight()
        w = min(w, screen_w)
        h = min(h, screen_h)
        x = max(0, screen_w - w - 40)
        y = min(40, screen_h - h)
        self.root.geometry(f"{w}x{h}+{x}+{y}")
        
        self.root.resizable(True, True)
        self.root.configure(bg="#1e1e1e")
        self.root.option_add("*foreground", "#ffffff")
        self.root.option_add("*background", "#252526")
        self.root.option_add("*Font", "Arial 10 bold")

        self.content_canvas = tk.Canvas(root, bg="#1e1e1e", highlightthickness=0)
        scrollbar = tk.Scrollbar(root, orient="vertical", command=self.content_canvas.yview)
        self.content_canvas.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side="right", fill="y")
        self.content_canvas.pack(side="left", fill="both", expand=True)
        self.content_frame = tk.Frame(self.content_canvas, bg="#1e1e1e")
        self.content_window = self.content_canvas.create_window(
            (0, 0), window=self.content_frame, anchor="nw"
        )
        self.content_frame.bind("<Configure>", self._update_scroll_region)
        self.content_canvas.bind("<Configure>", self._resize_content_window)
        self.plot_widget_ids = set()
        self.section_frames = {}  # title -> outer frame, in display order
        self.section_vars = {}  # title -> BooleanVar for the view menu
        self.field_vars = {}  # (section, field) -> BooleanVar for sub-options
        self.view_popup = None
        self.root.bind_all(
            "<MouseWheel>",
            self._on_mousewheel
        )

        self.live_interval = LIVE_INTERVAL

        self.last_sites_fetch_timestamp = None
        self.last_fetch_timestamp = None
        self.last_renewables_timestamp = None
        self.last_prices_today_timestamp = None
        self.last_usage_timestamp = None
        self.prices_today_table = []

        self.season_name = "--"
        self.period_name = "--"
        self.is_estimated = True
        self.high_freq = False
        self.last_poll_ts = 0.0
        self.price_fetch_busy = False
        self.last_sec_val = None
        self.last_beep_second = -1
        self.last_plot_second = None
        self.last_usage_hour = None
        self.fetch_failed = {k: False for k in ("sites", "current", "renewables", "prices_today", "usage")}
        self.current_interval_start = None
        self.live_since_ts = None
        self.live_since_str = None
        self.last_buy = None
        self.last_sell = None
        
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
        self.current_controlled_val = None

        self.buy_c_low_enabled = False
        self.buy_c_low_thresh = DEFAULT_BUY_LOW_THRESH

        self.buy_c_high_enabled = False
        self.buy_c_high_thresh = DEFAULT_BUY_HIGH_THRESH
        
        # --- Outside Section: System Time & Next Period ---
        top_info_frame = tk.Frame(self.content_frame, bg="#1e1e1e")
        top_info_frame.pack(fill="x", padx=8, pady=4)
        tk.Label(top_info_frame, text="System time:").pack(side="left")
        self.lbl_ctime = tk.Label(top_info_frame, text="--:--:--")
        self.lbl_ctime.pack(side="left", padx=(4, 10))
        tk.Label(top_info_frame, text="(update").pack(side="left")
        self.lbl_next_val = tk.Label(top_info_frame, text="--s")
        self.lbl_next_val.pack(side="left")
        tk.Label(top_info_frame, text=")").pack(side="left")
        self.gear_button = tk.Button(
            top_info_frame, text="⚙", font=GEAR_FONT, width=2, height=1, padx=0, pady=0,
            bg="#1e1e1e", fg=ACTION_FG, relief="flat", activebackground="#2d2d2d",
            activeforeground=ACTION_FG, command=self._show_view_menu,
        )
        self.gear_button.pack(side="right", padx=4)
        
        self.btn_speaker = self._make_alert_button(
            top_info_frame, "sound_enabled", "Beep when countdown reaches 0", padx=4, bg="#1e1e1e",
        )


        # --- Sites Section ---
        def populate_sites(body):
            self.lbl_network = self._make_row(body, "Network:", "--")
            self.lbl_site_status = self._make_row(body, "Status:", "--")
            self.lbl_tariff = self._make_row(body, "Tariff:", "--")

        self.lbl_up_sites = self._make_collapsible_section(
            self.content_frame, "Sites", self.manual_refresh_sites, "sites.json", "startup / manual", populate_sites,
            self._sites_request_urls
        )

        # --- Prices Section ---
        def populate_prices(body):
            self.lbl_season = self._make_row(body, "Season:", self.season_name, label_width=PRICE_LABEL_WIDTH)
            self.lbl_period = self._make_row(body, "Period:", self.period_name, label_width=PRICE_LABEL_WIDTH)
            
            status_frame = tk.Frame(body)
            status_frame.pack(anchor="w", pady=1)
            lbl_status_title = tk.Label(status_frame, text="Status:", width=PRICE_LABEL_WIDTH, anchor="e")
            lbl_status_title.pack(side="left")
            
            self.lbl_status = tk.Label(status_frame, text=" --")
            self.lbl_status.pack(side="left")
            
            self.btn_est_speaker = self._make_alert_button(
                status_frame, "est_sound_enabled", "Beep if status is not LIVE", padx=4,
            )

            # Buy Price Row
            buy_frame = tk.Frame(body)
            buy_frame.pack(anchor="w", pady=1)
            tk.Label(buy_frame, text="Buy Price:", width=PRICE_LABEL_WIDTH, anchor="e").pack(side="left")
            self.lbl_buy = tk.Label(buy_frame, text=" -- (c/kWh)")
            self.lbl_buy.pack(side="left")

            # Controlled load is optional: many accounts have no such channel, so this row can show N/A
            controlled_frame = tk.Frame(body)
            controlled_frame.pack(anchor="w", pady=1)
            tk.Label(controlled_frame, text="Buy (Controlled):", width=PRICE_LABEL_WIDTH, anchor="e").pack(side="left")
            self.lbl_buy_controlled = tk.Label(controlled_frame, text=" N/A")
            self.lbl_buy_controlled.pack(side="left")
            self.btn_buy_c_low = self._make_alert_button(
                controlled_frame, "buy_c_low_enabled",
                lambda: f"Beep if controlled price drops below {self.buy_c_low_thresh}.\nRight-click to change threshold.",
                padx=4, threshold_attr="buy_c_low_thresh",
                threshold_prompt="Alert when controlled value drops BELOW this threshold:",
            )
            self.btn_buy_c_high = self._make_alert_button(
                controlled_frame, "buy_c_high_enabled",
                lambda: f"Beep if controlled price rises above {self.buy_c_high_thresh}.\nRight-click to change threshold.",
                padx=0, threshold_attr="buy_c_high_thresh",
                threshold_prompt="Alert when controlled value rises ABOVE this threshold:",
            )
            self.btn_buy_low = self._make_alert_button(
                buy_frame, "buy_low_enabled",
                lambda: f"Beep if value drops below {self.buy_low_thresh}.\nRight-click to change threshold.",
                padx=4, threshold_attr="buy_low_thresh",
                threshold_prompt="Alert when value drops BELOW this threshold:",
            )
            self.btn_buy_high = self._make_alert_button(
                buy_frame, "buy_high_enabled",
                lambda: f"Beep if value rises above {self.buy_high_thresh}.\nRight-click to change threshold.",
                padx=0, threshold_attr="buy_high_thresh",
                threshold_prompt="Alert when value rises ABOVE this threshold:",
            )

            # Sell Price Row
            sell_frame = tk.Frame(body)
            sell_frame.pack(anchor="w", pady=1)
            tk.Label(sell_frame, text="Sell Price:", width=PRICE_LABEL_WIDTH, anchor="e").pack(side="left")
            self.lbl_sell = tk.Label(sell_frame, text=" -- (c/kWh)")
            self.lbl_sell.pack(side="left")
            self.btn_sell_low = self._make_alert_button(
                sell_frame, "sell_low_enabled",
                lambda: f"Left-click to enable/disable alert. Right-click to change threshold (below {self.sell_low_thresh}).",
                padx=4, threshold_attr="sell_low_thresh",
                threshold_prompt="Alert when value drops BELOW this threshold:",
            )
            self.btn_sell_high = self._make_alert_button(
                sell_frame, "sell_high_enabled",
                lambda: f"Left-click to enable/disable alert. Right-click to change threshold (above {self.sell_high_thresh}).",
                padx=0, threshold_attr="sell_high_thresh",
                threshold_prompt="Alert when value rises ABOVE this threshold:",
            )

        # Renewables Section
        def populate_ren(body):
            self.lbl_ren_val = self._make_row(body, "Renewables:", "--%")

        self.lbl_up_ren = self._make_collapsible_section(
            self.content_frame, "Renewables", self.manual_refresh_renewables, "renewables.json", f"{int(BACKGROUND_POLL_INTERVAL)}s", populate_ren,
            self._renewables_request_urls
        )

        self.lbl_up_main = self._make_collapsible_section(
            self.content_frame, "Recent Prices", self.manual_refresh_prices, "prices.json", lambda: f"{int(self.live_interval)}s", populate_prices,
            self._current_prices_request_urls
        )

        # Combined actual and forecast prices
        def populate_prices_today(body):
            self.prices_today_plot = self._make_plot_canvas(body, resizable=True)
            self.prices_today_plot.show_current_time = True

        self.lbl_up_prices_today = self._make_collapsible_section(
            self.content_frame,
            "Price History and Forecast",
            self.manual_refresh_prices_today,
            ("forecast_5min.json", "forecast_30min.json"),
            f"{int(BACKGROUND_POLL_INTERVAL)}s", populate_prices_today, self._prices_today_request_urls
        )

        # Usage Section
        def populate_usage(body):
            self.lbl_usage_date = tk.Label(body, text="")
            self.usage_plot = self._make_plot_canvas(body, resizable=True)
            self.usage_plot.show_current_time = True

        self.lbl_up_usage = self._make_collapsible_section(
            self.content_frame, "Usage History", self.manual_refresh_usage, ("usage_today.json", "usage_yesterday.json", "usage_two_days_ago.json"), "hour, on the hour", populate_usage,
            self._usage_request_urls
        )


        # Sub-options in the gear menu: each field's row frame, in display order
        self.sub_fields = {
            "Sites": [
                ("Network", self.lbl_network.master),
                ("Status", self.lbl_site_status.master),
                ("Tariff", self.lbl_tariff.master),
            ],
            "Recent Prices": [
                ("Season", self.lbl_season.master),
                ("Period", self.lbl_period.master),
                ("Status", self.lbl_status.master),
                ("Buy Price", self.lbl_buy.master),
                ("Buy (Controlled)", self.lbl_buy_controlled.master),
                ("Sell Price", self.lbl_sell.master),
            ],
        }
        self.sub_traces = {
            "Price History and Forecast": PRICE_TRACES,
            "Usage History": USAGE_TRACES,
        }
        self.trace_vars = {
            section: {name: tk.BooleanVar(value=True) for name in names}
            for section, names in self.sub_traces.items()
        }
        for section, fields in self.sub_fields.items():
            for field, _ in fields:
                self.field_vars[(section, field)] = tk.BooleanVar(value=True)
        self.show_prices_today_plot()
        self.show_usage_plot()
        self._sync_plot_x_limits(self.prices_today_plot)
        self.root.after_idle(self.root.deiconify)
        self.root.after_idle(self.root.lift)

        if not self.token or not self.site_id:
            log_error("Missing credentials in amber.ini")
            self.lbl_status.config(text=" Config Error", fg="#ff5555")
        else:
            for fetch in (self.fetch_sites, self.fetch_renewables, self.fetch_prices_today, self.fetch_usage):
                self._run_async(fetch)
            self._start_price_fetch(from_poll=True)
            self._start_periodic(200, self._poll_tick)
            self._start_periodic(int(BACKGROUND_POLL_INTERVAL * 1000), self._background_tick)
            self._start_periodic(1000, self._usage_tick)
            self._start_periodic(50, self._ticker_tick)

    def _update_scroll_region(self, event):
        self.content_canvas.configure(scrollregion=self.content_canvas.bbox("all"))

    def _resize_content_window(self, event):
        self.content_canvas.itemconfigure(self.content_window, width=event.width)

    @staticmethod
    def _configure_icon_button(button, bg="#1e1e1e"):
        button.configure(
            font=("Segoe UI Emoji", 11, "bold"),
            bg=bg,
            fg="#888888",
            activeforeground="#888888",
            padx=0,
            pady=0,
            borderwidth=0,
            highlightthickness=0,
            justify="center",
            compound="center",
        )

    def _make_row(self, parent, label_text, val_text, label_width=12):
        f = tk.Frame(parent)
        f.pack(anchor="w", pady=1)
        lbl = tk.Label(f, text=label_text, width=label_width, anchor="e")
        lbl.pack(side="left")
        
        val_lbl = tk.Label(f, text=f" {val_text}")
        val_lbl.pack(side="left")
        return val_lbl

    def _make_plot_canvas(self, parent, resizable=False):
        figure = Figure(figsize=(5.5, 2.2), dpi=100, facecolor="#252526")
        figure.subplots_adjust(
            left=0.135,
            right=0.975,
            top=1 - 0.35 / figure.get_figheight(),
            bottom=0.10,
        )
        axes = figure.add_subplot(111)
        axes.set_facecolor("#252526")
        canvas = FigureCanvasTkAgg(figure, master=parent)
        plot_widget = canvas.get_tk_widget()
        plot_widget.pack(fill="x", expand=True, pady=(1, 0))
        self.plot_widget_ids.add(plot_widget.winfo_id())
        canvas.plot_y_label = ""
        canvas.trace_visible = {}  # legend name -> bool; missing means shown
        canvas.plot_y_range_padding = None
        canvas.plot_series = []
        canvas.plot_axes = axes
        canvas.plot_current_time_line = None
        canvas.plot_resize_start = None
        canvas.plot_navigation = {
            "drag": None,
            "selection": None,
            "view": None,
            "home_view": None,
            "marker": None,
        }
        if resizable:
            resize_handle = tk.Frame(parent, height=8, cursor="sb_v_double_arrow")
            resize_handle.pack(fill="x", pady=(0, 0))
            resize_handle.pack_propagate(False)
            resize_handle.bind("<Button-1>", partial(self._start_plot_resize, canvas))
            resize_handle.bind("<B1-Motion>", partial(self._resize_plot, canvas))
            ToolTip(resize_handle, "Drag to resize plot")
        canvas.get_tk_widget().config(cursor="crosshair")
        canvas.get_tk_widget().bind(
            "<Double-Button-1>", partial(self._plot_double_click, canvas)
        )
        canvas.mpl_connect("button_press_event", partial(self._plot_button_press, canvas))
        canvas.mpl_connect("motion_notify_event", partial(self._plot_motion, canvas))
        canvas.mpl_connect("button_release_event", partial(self._plot_button_release, canvas))
        canvas.mpl_connect("scroll_event", partial(self._plot_scroll, canvas))
        return canvas

    @staticmethod
    def _start_plot_resize(canvas, event):
        canvas.plot_resize_start = (event.y_root, canvas.get_tk_widget().winfo_height())

    @staticmethod
    def _resize_plot(canvas, event):
        if canvas.plot_resize_start is None:
            return
        start_y, start_height = canvas.plot_resize_start
        height = max(160, min(1000, start_height + event.y_root - start_y))
        widget = canvas.get_tk_widget()
        widget.configure(height=height)
        width_inches = canvas.figure.get_figwidth()
        canvas.figure.set_size_inches(width_inches, height / canvas.figure.dpi, forward=True)
        canvas.figure.subplots_adjust(
            top=1 - 0.35 / canvas.figure.get_figheight()
        )
        canvas.draw_idle()

    def _on_mousewheel(self, event):
        if event.widget.winfo_id() not in self.plot_widget_ids:
            self.content_canvas.yview_scroll(int(-event.delta / 120), "units")
        return "break"

    def _make_collapsible_section(self, parent_outer, title_text, refresh_command, open_filename, interval_desc, populate_body_callback, request_urls):
        outer = tk.Frame(parent_outer, bd=1, relief="solid")
        outer.pack(fill="x", padx=6, pady=2)
        self.section_frames[title_text] = outer
        self.section_vars[title_text] = tk.BooleanVar(value=True)
        
        header_frame = tk.Frame(outer, bg="#2d2d2d")
        header_frame.pack(fill="x", padx=1, pady=1)
        
        body_frame = tk.Frame(outer)
        body_frame.pack(fill="x", padx=6, pady=4)
        
        populate_body_callback(body_frame)
        
        tk.Label(header_frame, text=title_text, fg="#ffffff", bg="#2d2d2d").pack(side="left", padx=6)
        
        # Open data file button
        btn_open = tk.Button(header_frame, text="{}", width=3, height=1, padx=0, pady=0, bg="#2d2d2d", fg=ACTION_FG, relief="flat", activebackground="#3d3d3d", activeforeground=ACTION_FG, font=HEADER_ICON_FONT, command=partial(self.open_data_file, open_filename))
        btn_open.pack(side="right", padx=2)
        open_filenames = open_filename if isinstance(open_filename, (tuple, list)) else (open_filename,)
        ToolTip(btn_open, "Open " + ", ".join(open_filenames))

        btn_copy_request = tk.Button(header_frame, text="🗐", width=2, height=1, padx=0, pady=0, bg="#2d2d2d", fg=ACTION_FG, relief="flat", activebackground="#3d3d3d", activeforeground=ACTION_FG, font=HEADER_ICON_FONT)
        btn_copy_request.pack(side="right", padx=2)
        btn_copy_request.config(
            command=partial(self.copy_request_to_clipboard, request_urls, btn_copy_request)
        )
        ToolTip(btn_copy_request, "Copy API cURL request, including the API token.")

        # Time since update counter
        lbl_up = tk.Label(header_frame, text="--", fg=ACTION_FG, bg="#2d2d2d", cursor="hand2")
        lbl_up.pack(side="right", padx=4)
        lbl_up.bind("<Button-1>", refresh_command)
        lbl_up.bind("<Button-3>", self.change_polling_rate)
        
        ToolTip(lbl_up, lambda: f"Time since update. Updated every {interval_desc() if callable(interval_desc) else interval_desc}.\nLeft-click to update now.\nRight-click to set polling interval.")

        return lbl_up

    def _show_view_menu(self):
        # A Toplevel popup rather than tk.Menu: Windows menus ignore custom checkmark colours
        if self.view_popup is not None:
            self.view_popup.destroy()
        popup = tk.Toplevel(self.root)
        self.view_popup = popup
        popup.wm_overrideredirect(True)
        popup.configure(bg="#252526", bd=1, relief="solid")
        popup.bind("<FocusOut>", lambda e: self._close_view_menu())
        for title in self.section_vars:
            self._add_view_row(popup, title, indent=0)
            for field, _ in self.sub_fields.get(title, ()):
                self._add_view_row(popup, (title, field), indent=1)
            for trace in self.sub_traces.get(title, ()):
                self._add_view_row(popup, (title, trace), indent=1)
        # Right-justify under the gear: measure the popup after layout, then align its right edge to the button
        popup.update_idletasks()
        gear_right = self.gear_button.winfo_rootx() + self.gear_button.winfo_width()
        x = max(0, gear_right - popup.winfo_reqwidth())
        y = self.gear_button.winfo_rooty() + self.gear_button.winfo_height()
        popup.wm_geometry(f"+{x}+{y}")
        popup.focus_force()

    def _add_view_row(self, popup, key, indent):
        row = tk.Label(
            popup, text="", bg="#252526", fg="#ffffff", font=("Arial", 10),
            anchor="w", padx=8 + 18 * indent, pady=2,
        )
        row.pack(fill="x")
        row.bind("<Button-1>", partial(self._on_view_row_click, key, row))
        row.bind("<Enter>", lambda e, r=row: r.config(bg="#3d3d3d"))
        row.bind("<Leave>", lambda e, r=row: r.config(bg="#252526"))
        self._refresh_view_row(key, row, indent)

    def _var_for(self, key):
        """Section key is a title; sub-row key is (section, field or trace)."""
        if isinstance(key, tuple):
            section, name = key
            if section in self.sub_traces and name in self.sub_traces[section]:
                return self.trace_vars[section][name]
            return self.field_vars[(section, name)]
        return self.section_vars[key]

    def _refresh_view_row(self, key, row, indent=0):
        mark = "☑" if self._var_for(key).get() else "☐"
        label = key if not isinstance(key, tuple) else key[1]
        row.config(text=f"{mark}  {label}", font=("Segoe UI Symbol", 10))

    def _on_view_row_click(self, key, row, event=None):
        var = self._var_for(key)
        var.set(not var.get())
        self._refresh_view_row(key, row, 1 if isinstance(key, tuple) else 0)
        if isinstance(key, tuple):
            section, name = key
            if section in self.sub_traces and name in self.sub_traces[section]:
                self._redraw_for_trace(section)
            else:
                self._set_field_visible(section, name)
        else:
            self._set_section_visible(key)

    def _close_view_menu(self):
        if self.view_popup is not None:
            self.view_popup.destroy()
            self.view_popup = None

    def _set_field_visible(self, section, field):
        fields = self.sub_fields[section]
        frame = dict(fields)[field]
        if not self.field_vars[(section, field)].get():
            frame.pack_forget()
            self._fit_window_height()
            return
        if frame.winfo_manager():
            return
        # Re-insert before the next visible field so the original order is kept
        names = [name for name, _ in fields]
        later = names[names.index(field) + 1:]
        next_frame = next(
            (dict(fields)[n] for n in later if dict(fields)[n].winfo_manager()), None,
        )
        if next_frame is None:
            frame.pack(anchor="w", pady=1)
        else:
            frame.pack(anchor="w", pady=1, before=next_frame)
        self._fit_window_height()

    def _redraw_for_trace(self, section):
        canvas = self.prices_today_plot if section == "Price History and Forecast" else self.usage_plot
        self._draw_plot_canvas(canvas)

    def _trace_on(self, canvas, name):
        """Trace visibility for a canvas; traces default to shown."""
        titles = {id(self.prices_today_plot): "Price History and Forecast", id(self.usage_plot): "Usage History"}
        section = titles.get(id(canvas))
        if section is None or section not in self.trace_vars:
            return True
        var = self.trace_vars[section].get(name)
        return True if var is None else var.get()

    def _set_section_visible(self, title):
        frame = self.section_frames[title]
        if not self.section_vars[title].get():
            frame.pack_forget()
            self._fit_window_height()
            return
        if frame.winfo_manager():
            return
        # Re-insert before the next visible section so the original order is kept
        later = list(self.section_frames)[list(self.section_frames).index(title) + 1:]
        next_frame = next(
            (self.section_frames[t] for t in later if self.section_frames[t].winfo_manager()), None,
        )
        if next_frame is None:
            frame.pack(fill="x", padx=6, pady=2)
        else:
            frame.pack(fill="x", padx=6, pady=2, before=next_frame)
        self._on_section_shown(title)
        self._fit_window_height()

    def _fit_window_height(self):
        """Grow or shrink the window to fit visible sections, capped at the screen height."""
        self.root.update_idletasks()
        content_h = self.content_frame.winfo_reqheight()
        screen_h = self.root.winfo_screenheight()
        # Keep 40px for the taskbar/title bar; anything taller scrolls inside the canvas
        target = min(content_h, screen_h - 40)
        self.root.geometry(f"{self.root.winfo_width()}x{max(200, target)}")

    def _visible(self, title):
        return self.section_vars[title].get()

    def _want_current_prices(self):
        # Current prices also drive the Recent Prices graph, so keep polling while that graph is shown
        return self._visible("Recent Prices") or self._visible("Price History and Forecast")

    def _on_section_shown(self, title):
        """Fetch a section once when it is re-enabled; its timer takes over from there."""
        if not (self.token and self.site_id):
            return
        refresh = {
            "Sites": self.manual_refresh_sites,
            "Renewables": self.manual_refresh_renewables,
            "Recent Prices": self.manual_refresh_prices,
            "Price History and Forecast": self.manual_refresh_prices_today,
            "Usage History": self.manual_refresh_usage,
        }
        refresh[title]()

    def change_polling_rate(self, event=None):
        val = simpledialog.askfloat(" ", "Set polling interval (sec):", initialvalue=self.live_interval, minvalue=1.0, maxvalue=3600.0)
        if val is not None:
            self.live_interval = float(val)

    def _load_plot_records(self, filename):
        file_path = os.path.join(DATA_DIR, filename)
        with open(file_path, "r", encoding="utf-8") as f:
            records = json.load(f)
        if not isinstance(records, list):
            raise ValueError(f"{filename} does not contain a list of records")
        return records

    @staticmethod
    def _as_utc_datetime(value):
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)

    @staticmethod
    def _five_minute_start(value):
        return datetime.fromtimestamp(
            int(value.timestamp() // 300) * 300, tz=timezone.utc
        )

    @staticmethod
    def _optional_number(value):
        try:
            number = float(value)
        except (TypeError, ValueError):
            return None
        return number if math.isfinite(number) else None

    def _plot_channel_series(
        self, records, name, color, value_key, channel_type, negate=False,
        duration_minutes_key=None,
    ):
        points = []
        for record in records:
            if not isinstance(record, dict) or record.get("channelType") != channel_type:
                continue
            timestamp = record.get("nemTime") or record.get("startTime")
            value = record.get(value_key)
            if not timestamp or value is None:
                continue
            try:
                point_time = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
                point_value = float(value)
            except (AttributeError, TypeError, ValueError):
                continue
            if not math.isfinite(point_value):
                continue
            if duration_minutes_key is not None:
                duration_minutes = self._optional_number(record.get(duration_minutes_key))
                if duration_minutes is None or duration_minutes <= 0:
                    continue
                point_value /= duration_minutes / 60
            points.append((point_time.timestamp(), -point_value if negate else point_value))
        points.sort(key=itemgetter(0))
        return {"name": name, "color": color, "points": points}

    def _build_prices_today_table(self, records_5m, records_30m):
        table = {}
        five_minute_slots = set()

        def extract(record):
            if not isinstance(record, dict):
                return None
            interval_type = record.get("type", record.get("Type"))
            if interval_type not in ("ActualInterval", "CurrentInterval", "ForecastInterval"):
                return None
            try:
                start_time = self._five_minute_start(self._as_utc_datetime(record["startTime"]))
            except (KeyError, AttributeError, TypeError, ValueError):
                return None

            advanced = record.get("advancedPrice")
            if not isinstance(advanced, dict):
                advanced = {}
            per_kwh = self._optional_number(record.get("perKwh"))
            is_actual = interval_type == "ActualInterval" or (
                interval_type == "CurrentInterval" and record.get("estimate") is False
            )
            actual = per_kwh if is_actual else None
            predicted = self._optional_number(advanced.get("predicted"))
            if predicted is None and not is_actual:
                predicted = per_kwh
            low = self._optional_number(advanced.get("low"))
            high = self._optional_number(advanced.get("high"))
            if record.get("channelType") == "feedIn" and low is not None and high is not None:
                low, high = min(low, high), max(low, high)
            return {
                "startTime": start_time,
                "type": interval_type,
                "channelType": record.get("channelType"),
                "actual": actual,
                "predicted": predicted,
                "low": low,
                "high": high,
            }

        for record in records_5m:
            row = extract(record)
            if row is None or not row["channelType"]:
                continue
            key = (row["startTime"], row["channelType"])
            table[key] = row
            five_minute_slots.add(row["startTime"])

        for record in records_30m:
            row = extract(record)
            if row is None or not row["channelType"]:
                continue
            slot_start = datetime.fromtimestamp(
                int(row["startTime"].timestamp() // 1800) * 1800, tz=timezone.utc
            )
            slots = [
                slot_start + timedelta(minutes=minute)
                for minute in range(0, 30, 5)
            ]
            if any(slot in five_minute_slots for slot in slots):
                continue

            for slot in slots:
                resampled = dict(row)
                resampled["startTime"] = slot
                key = (slot, row["channelType"])
                table.setdefault(key, resampled)

        return sorted(
            table.values(),
            key=itemgetter("startTime", "channelType")
        )

    @staticmethod
    def _series_points(item):
        if "points" in item:
            return item["points"]
        return [
            point
            for key in ("actual_points", "predicted_points", "low_points", "high_points")
            for point in item.get(key, ())
        ]

    @staticmethod
    def _infer_plot_interval(points):
        timestamps = sorted({timestamp for timestamp, _ in points})
        intervals = [
            current - previous
            for previous, current in zip(timestamps, timestamps[1:])
            if current > previous
        ]
        if not intervals:
            return None
        intervals.sort()
        middle = len(intervals) // 2
        if len(intervals) % 2:
            return intervals[middle]
        return (intervals[middle - 1] + intervals[middle]) / 2

    @staticmethod
    def _extend_plot_points(points, interval):
        if not points or interval is None:
            return points
        return [*points, (points[-1][0] + interval, points[-1][1])]

    def _prices_today_series(self, table):
        series = []
        for channel, name, color, negate in (
            ("general", "Buy", "#ff8080", False),
            ("controlledLoad", "Buy (Controlled)", "#f1fa8c", False),
            ("feedIn", "Sell", "#50fa7b", True),
        ):
            rows = [row for row in table if row["channelType"] == channel]
            item = {
                "name": name,
                "color": color,
                "actual_points": [],
                "predicted_points": [],
                "low_points": [],
                "high_points": [],
            }
            for row in rows:
                timestamp = row["startTime"].timestamp()
                if row["actual"] is not None:
                    item["actual_points"].append((timestamp, -row["actual"] if negate else row["actual"]))
                elif row["predicted"] is not None:
                    item["predicted_points"].append((timestamp, -row["predicted"] if negate else row["predicted"]))

                low, high = row["low"], row["high"]
                if low is not None and high is not None:
                    if negate:
                        low, high = -high, -low
                    item["low_points"].append((timestamp, low))
                    item["high_points"].append((timestamp, high))

            series.append(item)
        return series

    @staticmethod
    def _remember_plot_view(canvas):
        axes = canvas.plot_axes
        canvas.plot_navigation["view"] = (axes.get_xlim(), axes.get_ylim())

    def _sync_plot_x_limits(self, source_canvas):
        target_canvas = (
            self.usage_plot
            if source_canvas is self.prices_today_plot
            else self.prices_today_plot
        )
        x_limits = source_canvas.plot_axes.get_xlim()
        target_axes = target_canvas.plot_axes
        if target_axes.get_xlim() == x_limits:
            return

        target_axes.set_xlim(*x_limits)
        target_canvas.plot_navigation["view"] = (
            x_limits,
            target_axes.get_ylim(),
        )
        target_canvas.draw_idle()

    def _plot_double_click(self, canvas, event):
        widget_height = canvas.get_tk_widget().winfo_height()
        if canvas.plot_axes.bbox.contains(event.x, widget_height - event.y):
            self._reset_plot_view(canvas)

    def _reset_plot_view(self, canvas):
        navigation = canvas.plot_navigation
        selection = navigation.get("selection")
        if selection is not None:
            selection.remove()
        navigation.update(drag=None, selection=None, view=None)
        self._draw_plot_canvas(canvas)
        target_canvas = (
            self.usage_plot
            if canvas is self.prices_today_plot
            else self.prices_today_plot
        )
        target_navigation = target_canvas.plot_navigation
        target_selection = target_navigation.get("selection")
        if target_selection is not None:
            target_selection.remove()
        target_navigation.update(drag=None, selection=None)
        target_home_view = target_navigation.get("home_view")
        if target_home_view is not None:
            target_axes = target_canvas.plot_axes
            target_axes.set_xlim(*canvas.plot_axes.get_xlim())
            target_axes.set_ylim(*target_home_view[1])
            target_navigation["view"] = (
                target_axes.get_xlim(), target_axes.get_ylim()
            )
            target_canvas.draw_idle()

    @staticmethod
    def _draw_plot_marker(canvas):
        for artist in canvas.plot_navigation.get("marker_artists", ()):
            artist.remove()
        canvas.plot_navigation["marker_artists"] = []
        marker = canvas.plot_navigation.get("marker")
        if marker is None:
            return

        point_time = datetime.fromtimestamp(marker["timestamp"])
        axes = canvas.plot_axes
        x_midpoint = sum(axes.get_xlim()) / 2
        y_midpoint = sum(axes.get_ylim()) / 2
        x_offset = -10 if mdates.date2num(point_time) > x_midpoint else 10
        y_offset = -12 if marker["value"] > y_midpoint else 12
        point, = axes.plot(
            [point_time], [marker["value"]],
            marker="o", markersize=7,
            markerfacecolor=marker["color"], markeredgecolor="#ffffff",
            markeredgewidth=1.2, linestyle="none", zorder=12,
        )
        annotation = axes.annotate(
            marker["text"],
            xy=(point_time, marker["value"]),
            xytext=(x_offset, y_offset),
            textcoords="offset points",
            ha="right" if x_offset < 0 else "left",
            va="top" if y_offset < 0 else "bottom",
            multialignment="left",
            fontfamily="monospace",
            color="#ffffff",
            fontsize=9,
            bbox={
                "boxstyle": "round,pad=0.4",
                "facecolor": "#252526",
                "edgecolor": marker["color"],
                "alpha": 0.95,
            },
            arrowprops={"arrowstyle": "->", "color": marker["color"]},
            zorder=13,
        )
        canvas.plot_navigation["marker_artists"] = [point, annotation]

    @staticmethod
    def _plot_step_series(axes, points, color, linewidth, zorder):
        axes.plot(
            [datetime.fromtimestamp(timestamp) for timestamp, _ in points],
            [value for _, value in points],
            color=color,
            linewidth=linewidth,
            linestyle="-",
            drawstyle="steps-post",
            zorder=zorder,
        )

    def _plot_button_press(self, canvas, event):
        axes = canvas.plot_axes
        if event.inaxes is not axes:
            return
        if getattr(event, "dblclick", False):
            return
        if event.x is None or event.y is None:
            return

        navigation = canvas.plot_navigation
        if event.button == 1 and event.xdata is not None and event.ydata is not None:
            selection = Rectangle(
                (event.xdata, event.ydata), 0, 0,
                facecolor="#8be9fd", edgecolor="#8be9fd",
                linewidth=1, alpha=0.2, zorder=20,
            )
            axes.add_patch(selection)
            navigation["drag"] = {
                "kind": "zoom",
                "pixel": (event.x, event.y),
                "data": (event.xdata, event.ydata),
            }
            navigation["selection"] = selection
            canvas.draw_idle()
        elif event.button in (2, 3):
            navigation["drag"] = {
                "kind": "pan",
                "pixel": (event.x, event.y),
                "xlim": axes.get_xlim(),
                "ylim": axes.get_ylim(),
            }

    @staticmethod
    def _plot_drag_mode(start_pixel, current_pixel):
        dx = abs(current_pixel[0] - start_pixel[0])
        dy = abs(current_pixel[1] - start_pixel[1])
        if dy < 8:
            return "x"
        if dx < 8:
            return "y"
        return "xy"

    def _plot_motion(self, canvas, event):
        navigation = canvas.plot_navigation
        drag = navigation.get("drag")
        if drag is None or event.x is None or event.y is None:
            return

        axes = canvas.plot_axes
        if drag["kind"] == "zoom":
            bbox = axes.bbox
            current_pixel = (
                min(max(event.x, bbox.x0), bbox.x1),
                min(max(event.y, bbox.y0), bbox.y1),
            )
            x0, y0 = drag["data"]
            x1, y1 = axes.transData.inverted().transform(current_pixel)
            mode = self._plot_drag_mode(drag["pixel"], current_pixel)
            if mode == "x":
                y0, y1 = axes.get_ylim()
            elif mode == "y":
                x0, x1 = axes.get_xlim()
            selection = navigation["selection"]
            selection.set_bounds(min(x0, x1), min(y0, y1), abs(x1 - x0), abs(y1 - y0))
            canvas.draw_idle()
        else:
            start_x, start_y = drag["pixel"]
            bbox = axes.bbox
            x_range = drag["xlim"][1] - drag["xlim"][0]
            y_range = drag["ylim"][1] - drag["ylim"][0]
            x_shift = (event.x - start_x) * x_range / bbox.width
            y_shift = (event.y - start_y) * y_range / bbox.height
            axes.set_xlim(drag["xlim"][0] - x_shift, drag["xlim"][1] - x_shift)
            axes.set_ylim(drag["ylim"][0] - y_shift, drag["ylim"][1] - y_shift)
            self._remember_plot_view(canvas)
            self._sync_plot_x_limits(canvas)
            canvas.draw_idle()

    def _plot_button_release(self, canvas, event):
        navigation = canvas.plot_navigation
        drag = navigation.get("drag")
        if drag is None or event.button not in (1, 2, 3):
            return

        navigation["drag"] = None
        if drag["kind"] == "pan":
            if event.x is not None and event.y is not None and max(
                abs(event.x - drag["pixel"][0]),
                abs(event.y - drag["pixel"][1]),
            ) < 5:
                navigation["marker"] = None
                self._draw_plot_marker(canvas)
                canvas.draw_idle()
            return

        selection = navigation.get("selection")
        if selection is not None:
            selection.remove()
        navigation["selection"] = None

        start_pixel = drag["pixel"]
        end_pixel = (event.x, event.y)
        if event.x is None or event.y is None or max(
            abs(end_pixel[0] - start_pixel[0]),
            abs(end_pixel[1] - start_pixel[1]),
        ) < 5:
            canvas.draw_idle()
            self._inspect_plot_point(canvas, event)
            return

        axes = canvas.plot_axes
        bbox = axes.bbox
        end_pixel = (
            min(max(end_pixel[0], bbox.x0), bbox.x1),
            min(max(end_pixel[1], bbox.y0), bbox.y1),
        )
        x0, y0 = drag["data"]
        x1, y1 = axes.transData.inverted().transform(end_pixel)
        mode = self._plot_drag_mode(start_pixel, end_pixel)
        if mode in ("x", "xy") and abs(x1 - x0) > 0:
            axes.set_xlim(min(x0, x1), max(x0, x1))
        if mode in ("y", "xy") and abs(y1 - y0) > 0:
            axes.set_ylim(min(y0, y1), max(y0, y1))
        self._remember_plot_view(canvas)
        self._sync_plot_x_limits(canvas)
        canvas.draw_idle()

    def _plot_scroll(self, canvas, event):
        axes = canvas.plot_axes
        if event.inaxes is not axes or event.xdata is None or event.ydata is None:
            return

        scale = 1.2 ** (-event.step)
        x0, x1 = axes.get_xlim()
        y0, y1 = axes.get_ylim()
        new_xlim = (
            event.xdata - (event.xdata - x0) * scale,
            event.xdata + (x1 - event.xdata) * scale,
        )
        new_ylim = (
            event.ydata - (event.ydata - y0) * scale,
            event.ydata + (y1 - event.ydata) * scale,
        )
        home_view = canvas.plot_navigation.get("home_view")
        if event.step < 0 and home_view is not None:
            new_xlim = self._clamp_plot_limits(new_xlim, home_view[0])
            new_ylim = self._clamp_plot_limits(new_ylim, home_view[1])
        axes.set_xlim(*new_xlim)
        axes.set_ylim(*new_ylim)
        self._remember_plot_view(canvas)
        self._sync_plot_x_limits(canvas)
        canvas.draw_idle()

    @staticmethod
    def _clamp_plot_limits(limits, home_limits):
        home_min, home_max = home_limits
        span = min(limits[1] - limits[0], home_max - home_min)
        center = (limits[0] + limits[1]) / 2
        minimum = max(home_min, min(center - span / 2, home_max - span))
        return minimum, minimum + span

    def _inspect_plot_point(self, canvas, event):
        axes = canvas.plot_axes
        if event.inaxes is not axes or event.x is None or event.y is None or event.xdata is None:
            return
        closest = None
        for item in (i for i in canvas.plot_series if self._trace_on(canvas, i["name"])):
            for series_name, points, color in (
                ("Actual", item.get("actual_points", item.get("points", ())), item["color"]),
                ("Predicted", item.get("predicted_points", ()), item["color"]),
                ("Low", item.get("low_points", ()), item["color"]),
                ("High", item.get("high_points", ()), item["color"]),
            ):
                for timestamp, value in points:
                    x_value = mdates.date2num(datetime.fromtimestamp(timestamp))
                    point_x, point_y = axes.transData.transform((x_value, value))
                    distance = (point_x - event.x) ** 2 + (point_y - event.y) ** 2
                    if closest is None or distance < closest[0]:
                        closest = (
                            distance, item, series_name, timestamp, value,
                        )

        if closest is None:
            return
        _, item, series_name, timestamp, value = closest
        name = item["name"]
        color = item["color"]
        point_time = datetime.fromtimestamp(timestamp)
        unit = "c/kWh" if "Price" in canvas.plot_y_label else "kW"
        if series_name in ("Low", "High"):
            predicted_point = next(
                (
                    point for point in item.get("predicted_points", ())
                    if point[0] == timestamp
                ),
                None,
            )
            marker_value = predicted_point[1] if predicted_point else value
            values_by_name = {
                "high": next(
                    (point[1] for point in item.get("high_points", ()) if point[0] == timestamp),
                    None,
                ),
                "med": predicted_point[1] if predicted_point else None,
                "low": next(
                    (point[1] for point in item.get("low_points", ()) if point[0] == timestamp),
                    None,
                ),
            }
            value_labels = [
                (f"{name} {label}", point_value)
                for label, point_value in values_by_name.items()
                if point_value is not None
            ]
            label_width = max((len(label) for label, _ in value_labels), default=0)
            value_lines = [
                f"{label:<{label_width}}: {point_value:.2f} {unit}"
                for label, point_value in value_labels
            ]
        else:
            marker_value = value
            qualifier = "med" if series_name == "Predicted" else series_name.lower()
            value_label = name if series_name == "Actual" else f"{name} {qualifier}"
            value_lines = [f"{value_label}: {value:.2f} {unit}"]

        canvas.plot_navigation["marker"] = {
            "timestamp": timestamp,
            "value": marker_value,
            "color": color,
            "text": (
                f"{point_time:%Y-%m-%d}  {point_time:%H:%M}\n"
                + "\n".join(value_lines)
            ),
        }
        self._draw_plot_marker(canvas)
        canvas.draw_idle()

    def _draw_plot_canvas(self, canvas):
        axes = canvas.plot_axes
        saved_view = canvas.plot_navigation.get("view")
        axes.clear()
        canvas.plot_navigation["marker_artists"] = []
        canvas.plot_current_time_line = None
        axes.set_facecolor("#252526")
        series = [
            item for item in canvas.plot_series
            if self._series_points(item) and self._trace_on(canvas, item["name"])
        ]
        if not series:
            axes.text(
                0.5, 0.5, "No data available to plot.",
                color="#cfcfcf", ha="center", va="center",
                transform=axes.transAxes
            )
            canvas.draw_idle()
            return

        all_points = [point for item in series for point in self._series_points(item)]
        plot_interval = self._infer_plot_interval(all_points)
        minimum_time = min(point[0] for point in all_points)
        maximum_time = max(point[0] for point in all_points)
        if plot_interval is not None:
            maximum_time += plot_interval
        if getattr(canvas, "show_current_time", False):
            now = time.time()
            minimum_time = min(minimum_time, now)
            maximum_time = max(maximum_time, now)
        min_x = datetime.fromtimestamp(minimum_time)
        max_x = datetime.fromtimestamp(maximum_time)
        if min_x == max_x:
            min_x -= timedelta(minutes=5)
            max_x += timedelta(minutes=5)
        axes.set_xlim(min_x, max_x)

        minimum_value = min(point[1] for point in all_points)
        maximum_value = max(point[1] for point in all_points)
        value_range = maximum_value - minimum_value
        if canvas.plot_y_range_padding is not None:
            value_padding = value_range * canvas.plot_y_range_padding if value_range else 1
            axes.set_ylim(minimum_value - value_padding, maximum_value + value_padding)
        else:
            value_padding = max(value_range * 0.08, 1)
            axes.set_ylim(
                min(0, minimum_value - value_padding),
                max(0, maximum_value + value_padding),
            )
        axes.margins(x=0.01)
        canvas.plot_navigation["home_view"] = (axes.get_xlim(), axes.get_ylim())
        if saved_view is not None:
            axes.set_xlim(*saved_view[0])
            if canvas.plot_y_range_padding is None:
                axes.set_ylim(*saved_view[1])
        axes.yaxis.set_major_locator(
            MaxNLocator(nbins=6, steps=[1, 2, 2.5, 5, 10])
        )
        date_locator = mdates.AutoDateLocator(
            minticks=6, maxticks=12, interval_multiples=True
        )
        date_locator.intervald[mdates.MINUTELY].append(60)
        axes.xaxis.set_major_locator(date_locator)
        axes.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
        axes.grid(True, color="#454545", linewidth=0.6)
        axes.tick_params(axis="both", colors="#cfcfcf", labelsize=10)
        axes.set_ylabel(canvas.plot_y_label, color="#ffffff", fontsize=10)
        for spine in axes.spines.values():
            spine.set_color("#777777")

        staged_series = any("actual_points" in item for item in series)
        # Draw order (back to front): Buy (Controlled), then Sell, then Buy on top. Legend order is unchanged.
        draw_rank = {name: rank for rank, name in enumerate(("Buy (Controlled)", "Sell", "Buy"))}
        for item in sorted(series, key=lambda s: draw_rank.get(s["name"], len(draw_rank))):
            zorder = 2 + draw_rank.get(item["name"], len(draw_rank))
            low_points = item.get("low_points", ())
            high_points = item.get("high_points", ())
            if (len(low_points) == len(high_points) and len(low_points) > 1
                    and self._trace_on(canvas, "Uncertainty")):
                low_points = self._extend_plot_points(low_points, plot_interval)
                high_points = self._extend_plot_points(high_points, plot_interval)
                band_times = [datetime.fromtimestamp(timestamp) for timestamp, _ in low_points]
                axes.fill_between(
                    band_times,
                    [value for _, value in low_points],
                    [value for _, value in high_points],
                    color=item["color"],
                    alpha=0.5,
                    linewidth=0,
                    step="post",
                    zorder=zorder,
                )

            for points, linewidth in (
                (item.get("actual_points", item.get("points", ())), 1.8),
                (item.get("predicted_points", ()), 0.9),
            ):
                if points:
                    self._plot_step_series(
                        axes,
                        self._extend_plot_points(points, plot_interval),
                        item["color"],
                        linewidth,
                        zorder + 0.1,
                    )

        legend_handles = [
            Line2D([], [], color=item["color"], linewidth=2, label=item["name"])
            for item in series
        ]
        if staged_series and self._trace_on(canvas, "Uncertainty"):
            legend_handles.extend((
                Patch(facecolor="#cfcfcf", alpha=0.5, label="Uncertainty"),
            ))
        axes.legend(
            handles=legend_handles,
            loc="lower center",
            bbox_to_anchor=(0.5, 1.01),
            ncol=4,
            fontsize=9,
            frameon=False,
            labelcolor="#ffffff",
            columnspacing=0.8,
            handletextpad=0.35,
            borderaxespad=0.1,
        )
        if getattr(canvas, "show_current_time", False):
            canvas.plot_current_time_line = axes.axvline(
                datetime.now(), color="#ff5555", linewidth=0.8, zorder=10
            )
        self._draw_plot_marker(canvas)
        canvas.draw_idle()
        self._sync_plot_x_limits(canvas)

    @staticmethod
    def _update_plot_current_time(canvas, timestamp):
        line = canvas.plot_current_time_line
        if line is None:
            return
        current_time = datetime.fromtimestamp(timestamp)
        line.set_xdata([current_time, current_time])
        canvas.draw_idle()

    def _set_plot_data(self, canvas, y_label, series, y_range_padding=None):
        canvas.plot_y_label = y_label
        canvas.plot_series = series
        canvas.plot_y_range_padding = y_range_padding
        self._draw_plot_canvas(canvas)

    def _display_prices_today_table(self, table):
        self.prices_today_table = table
        self._set_plot_data(
            self.prices_today_plot, "Price (c/kWh)",
            self._prices_today_series(table)
        )

    def show_prices_today_plot(self):
        try:
            records_5m = self._load_plot_records("forecast_5min.json")
            records_30m = self._load_plot_records("forecast_30min.json")
        except (OSError, ValueError, json.JSONDecodeError) as e:
            self.prices_today_table = []
            self._set_plot_data(self.prices_today_plot, "Price (c/kWh)", [])
            if not isinstance(e, FileNotFoundError):
                log_error(f"Failed to load Prices (Today) data: {e}")
            return

        self._display_prices_today_table(
            self._build_prices_today_table(records_5m, records_30m)
        )

    def show_usage_plot(self):
        records = []
        # Usage can be delayed at day boundaries, so fall back to an older day.
        for filename in ("usage_yesterday.json", "usage_two_days_ago.json"):
            try:
                records = self._load_plot_records(filename)
            except FileNotFoundError:
                continue
            except (OSError, ValueError, json.JSONDecodeError) as e:
                log_error(f"Failed to load usage plot data from {filename}: {e}")
                continue
            if records:
                break

        channel_names = (
            ("general", "Imported", "#ff8080"),
            ("controlledLoad", "Imported (Controlled)", "#f1fa8c"),
            ("feedIn", "Exported", "#50fa7b")
        )
        series = [
            self._plot_channel_series(
                records, label, color, "kwh", channel, duration_minutes_key="duration"
            )
            for channel, label, color in channel_names
        ]
        self._set_plot_data(
            self.usage_plot, "Rate (kW)", series, y_range_padding=0.05
        )

    def _set_usage_status(self, text):
        self.lbl_usage_date.config(text=text)
        if text:
            self.lbl_usage_date.pack(anchor="w", before=self.usage_plot.get_tk_widget())
        else:
            self.lbl_usage_date.pack_forget()

    def _refresh_usage_plot(self):
        self._set_usage_status("")
        self.show_usage_plot()

    def open_data_file(self, filename):
        filenames = filename if isinstance(filename, (tuple, list)) else (filename,)
        for name in filenames:
            full_path = os.path.join(DATA_DIR, name)
            try:
                if os.path.exists(full_path):
                    if os.name == 'nt':
                        os.startfile(full_path)
                    else:
                        subprocess.run(['xdg-open' if os.name != 'darwin' else 'open', full_path])
                else:
                    log_error(f"Data file not found: {full_path}")
            except Exception as e:
                log_error(f"Failed to open file {full_path}: {e}")

    @staticmethod
    def _save_json(filename, data):
        with open(os.path.join(DATA_DIR, filename), "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)

    def _api_headers(self):
        return {"Authorization": f"Bearer {self.token}", "Accept": "application/json"}

    def _sites_request_urls(self):
        return ["https://api.amber.com.au/v1/sites"]

    def _renewables_request_urls(self):
        return [f"https://api.amber.com.au/v1/state/{self.state.lower()}/renewables/current"]

    def _prices_today_request_urls(self):
        return [
            f"https://api.amber.com.au/v1/sites/{self.site_id}/prices/current?previous=576&next=12&resolution=5",
            f"https://api.amber.com.au/v1/sites/{self.site_id}/prices/current?previous=0&next=48&resolution=30",
        ]

    def _usage_request_urls(self, days=None):
        if days is None:
            today = datetime.now().date()
            days = (today, today - timedelta(days=1))
        return [
            f"https://api.amber.com.au/v1/sites/{self.site_id}/usage?startDate={day:%Y-%m-%d}&endDate={day:%Y-%m-%d}"
            for day in days
        ]

    def _current_prices_request_urls(self):
        return [f"https://api.amber.com.au/v1/sites/{self.site_id}/prices/current"]

    @staticmethod
    def _shell_quote(value):
        return '"' + value + '"'

    def copy_request_to_clipboard(self, request_urls, button):
        if not self.token:
            messagebox.showerror("Copy request", "No API token is configured in amber.ini.")
            return

        try:
            headers = self._api_headers()
            commands = []
            for url in request_urls():
                arguments = ["--request", "GET", "--url", url]
                for name, value in headers.items():
                    arguments.extend(["--header", f"{name}: {value}"])
                commands.append("curl.exe " + " ".join(self._shell_quote(arg) for arg in arguments))

            self.root.clipboard_clear()
            self.root.clipboard_append("\n".join(commands))
            self.root.update()
        except Exception as e:
            log_error(f"Failed to copy API request to clipboard: {e}")
            messagebox.showerror("Copy request", f"Could not copy the request to the clipboard:\n{e}")

    def fetch_sites(self):
        url = self._sites_request_urls()[0]
        headers = self._api_headers()
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                try:
                    data = res.json()
                    self._save_json("sites.json", data)
                    
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
                        status = target_site.get("status", "--")
                        
                        tariff = "--"
                        channels = target_site.get("channels", [])
                        if channels and isinstance(channels, list):
                            for ch in channels:
                                if ch.get("tariff"):
                                    tariff = ch.get("tariff")
                                    break

                        self.root.after(
                            0, self._update_site_labels, network, status, tariff
                        )
                    self.last_sites_fetch_timestamp = time.time()
                    self._set_fetch_failed("sites", False)
                except Exception as e:
                    log_error(f"Failed to process sites JSON: {e}")
                return data
            else:
                self._set_fetch_failed("sites", True)
                log_error(f"Sites API Error {res.status_code}")
        except Exception as e:
            self._set_fetch_failed("sites", True)
            log_error(f"Sites fetch exception: {e}")
        return None

    def _update_site_labels(self, network, status, tariff):
        self.lbl_network.config(text=f" {network}")
        self.lbl_site_status.config(text=f" {status}")
        self.lbl_tariff.config(text=f" {tariff}")

    def fetch_renewables(self):
        url = self._renewables_request_urls()[0]
        headers = self._api_headers()
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                data = res.json()
                self._save_json("renewables.json", data)
                
                ren_val = None
                if isinstance(data, list) and len(data) > 0:
                    ren_val = data[0].get("renewables", data[0].get("renewable"))
                elif isinstance(data, dict):
                    ren_val = data.get("renewables", data.get("renewable"))
                if ren_val is not None:
                    self.root.after(0, self.lbl_ren_val.config, {"text": f" {ren_val:.0f}%"})

                self.last_renewables_timestamp = time.time()
                self._set_fetch_failed("renewables", False)
            else:
                self._set_fetch_failed("renewables", True)
                log_error(f"Renewables API Error {res.status_code}")
        except Exception as e:
            self._set_fetch_failed("renewables", True)
            log_error(f"Renewables fetch exception: {e}")

    def fetch_prices_today(self):
        headers = self._api_headers()
        try:
            url_5m, url_30m = self._prices_today_request_urls()
            responses = []
            for url in (url_5m, url_30m):
                res = requests.get(url, headers=headers, timeout=10)
                if res.status_code != 200:
                    self._set_fetch_failed("prices_today", True)
                    log_error(f"Prices (Today) API Error {res.status_code}: {url}")
                    return
                data = res.json()
                if not isinstance(data, list):
                    raise ValueError(f"Prices (Today) API returned a non-list response: {url}")
                responses.append(data)

            table = self._build_prices_today_table(responses[0], responses[1])
            for filename, data in (
                ("forecast_5min.json", responses[0]),
                ("forecast_30min.json", responses[1]),
            ):
                self._save_json(filename, data)

            self.last_prices_today_timestamp = time.time()
            self._set_fetch_failed("prices_today", False)
            self.root.after(0, self._display_prices_today_table, table)
        except Exception as e:
            self._set_fetch_failed("prices_today", True)
            log_error(f"Prices (Today) fetch exception: {e}")

    def fetch_usage(self):
        today = datetime.now().date()
        days = (
            today,
            today - timedelta(days=1),
            today - timedelta(days=2),
        )
        filenames = (
            "usage_today.json",
            "usage_yesterday.json",
            "usage_two_days_ago.json",
        )
        urls = self._usage_request_urls(days)
        headers = self._api_headers()
        try:
            responses = []
            usage_failed = False
            for day, url in zip(days, urls):
                res = requests.get(url, headers=headers, timeout=10)
                if res.status_code != 200:
                    usage_failed = True
                    log_error(f"Usage API Error {res.status_code} for {day:%Y-%m-%d}")
                    continue

                data = res.json()
                if not isinstance(data, list):
                    raise ValueError(f"Usage API returned a non-list response for {day:%Y-%m-%d}")
                responses.append((day, data))

            if not responses:
                self._set_fetch_failed("usage", True)
                self.root.after(0, self._set_usage_status, " Usage API error")
                return

            for day, data in responses:
                filename = filenames[days.index(day)]
                file_path = os.path.join(DATA_DIR, filename)
                if not data and os.path.exists(file_path):
                    try:
                        with open(file_path, "r", encoding="utf-8") as f:
                            cached_data = json.load(f)
                        if isinstance(cached_data, list) and cached_data:
                            data = cached_data
                    except (OSError, ValueError, json.JSONDecodeError) as e:
                        log_error(f"Failed to read cached usage data from {filename}: {e}")
                self._save_json(filename, data)
            self.last_usage_timestamp = time.time()
            self._set_fetch_failed("usage", usage_failed)

            self.root.after(0, self._refresh_usage_plot)
        except Exception as e:
            self._set_fetch_failed("usage", True)
            log_error(f"Usage fetch exception: {e}")
            self.root.after(0, self._set_usage_status, " Usage fetch failed")

    def fetch_data(self):
        url = self._current_prices_request_urls()[0]
        headers = self._api_headers()
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                try:
                    data = res.json()
                    self._save_json("prices.json", data)
                except Exception as e:
                    log_error(f"Failed to write prices JSON: {e}")
                self._set_fetch_failed("current", False)
                return res.json()
            
            err_msg = f"API Error {res.status_code}: Too many requests" if res.status_code == 429 else f"API Error {res.status_code}"
            self._set_fetch_failed("current", True)
            log_error(err_msg)
            return {"error": err_msg}
        except requests.exceptions.RequestException as e:
            err_msg = "Connection Exception"
            self._set_fetch_failed("current", True)
            log_error(f"{err_msg}: {e}")
            return {"error": err_msg}
        except Exception as e:
            err_msg = "Unexpected Error"
            self._set_fetch_failed("current", True)
            log_error(f"{err_msg}: {e}")
            return {"error": err_msg}


    def process_data(self, data):
        if not data: return False
        
        if isinstance(data, dict) and "error" in data:
            err_text = data["error"]
            self.root.after(
                0,
                self.lbl_status.config,
                {"text": f" {err_text}", "fg": "#ff5555", "bg": "#252526"},
            )
            return False

        buy_val, sell_val, controlled_val, is_live, start_str = None, None, None, False, None
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
            elif interval.get("channelType") == "controlledLoad":
                controlled_val = interval.get("perKwh")
            elif interval.get("channelType") == "feedIn":
                if interval.get("perKwh") is not None:
                    sell_val = -interval.get("perKwh")

        live_interval_started = is_live and (
            self.is_estimated or start_str != self.current_interval_start
        )

        if start_str != self.current_interval_start:
            self.current_interval_start = start_str
            self.live_since_ts = self.live_since_str = None

        if is_live:
            if buy_val is not None: self.last_buy = buy_val
            if sell_val is not None: self.last_sell = sell_val
            if controlled_val is not None: self.last_buy_controlled = controlled_val
            if not self.live_since_ts:
                self.live_since_ts, self.live_since_str = time.time(), time.strftime("%H:%M:%S")
        else:
            self.live_since_ts = self.live_since_str = None

        self.current_buy_val = buy_val
        self.current_controlled_val = controlled_val
        self.current_sell_val = sell_val

        self.is_estimated = not is_live
        self.root.after(0, self.update_ui, buy_val, sell_val, self.is_estimated, controlled_val)
        if live_interval_started and self._visible("Price History and Forecast"):
            self.manual_refresh_prices_today()
        return is_live

    def update_ui(self, buy, sell, estimated, controlled=None):
        if estimated:
            self.lbl_status.config(text=" ESTIMATE", fg="#ff5555", bg="#252526")
        else:
            status_text = f" LIVE (since {self.live_since_str})" if self.live_since_str else " LIVE"
            self.lbl_status.config(text=status_text, fg="#50fa7b", bg="#252526")

        self._style_price(self.lbl_buy, buy, self.last_buy, estimated, is_buy=True)
        self._style_price(self.lbl_sell, sell, self.last_sell, estimated, is_buy=False)
        self._style_price(
            self.lbl_buy_controlled, controlled, getattr(self, "last_buy_controlled", None),
            estimated, is_buy=True,
        )

        self.last_fetch_timestamp = time.time()

    @staticmethod
    def _price_colours(val, is_buy):
        bands, above = (BUY_BANDS, BUY_BAND_ABOVE) if is_buy else (SELL_BANDS, SELL_BAND_ABOVE)
        for limit, include_limit, fg, bg in bands:
            if val < limit or (include_limit and val == limit):
                return fg, bg
        return above

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
            fg, bg = self._price_colours(val, is_buy)
            lbl.config(text=text, fg=fg, bg=bg)


    def _run_async(self, fn):
        threading.Thread(target=fn, daemon=True).start()

    def manual_refresh_sites(self, event=None):
        self._run_async(self.fetch_sites)

    def _start_periodic(self, interval_ms, tick):
        """Run tick() on the Tk main thread every interval_ms without blocking the UI."""
        def runner():
            self.root.after(interval_ms, runner)
            try:
                tick()
            except Exception as e:
                log_error(f"{tick.__name__} failed: {e}")
        self.root.after(interval_ms, runner)

    def _start_price_fetch(self, from_poll=False):
        if from_poll:
            self.price_fetch_busy = True
        threading.Thread(target=self._price_fetch_worker, args=(from_poll,), daemon=True).start()

    def _price_fetch_worker(self, from_poll):
        data = self.fetch_data()
        self.root.after(0, self._handle_price_data, data, from_poll)

    def _handle_price_data(self, data, from_poll):
        try:
            if not data:
                return
            is_live = self.process_data(data)
            if from_poll and is_live and self.high_freq:
                self.high_freq = False
        finally:
            if from_poll:
                self.price_fetch_busy = False

    def manual_refresh_prices(self, event=None):
        self._start_price_fetch()

    def manual_refresh_renewables(self, event=None):
        self._run_async(self.fetch_renewables)

    def manual_refresh_prices_today(self, event=None):
        self._run_async(self.fetch_prices_today)

    def manual_refresh_usage(self, event=None):
        self._run_async(self.fetch_usage)

    def _make_alert_button(self, parent, enabled_attr, tooltip, padx, threshold_attr=None, threshold_prompt=None, bg="#252526"):
        button = tk.Button(parent, text="🔈", width=2, height=1, padx=0, pady=0, fg="#888888", relief="flat", activebackground="#3d3d3d", activeforeground="#888888")
        self._configure_icon_button(button, bg=bg)
        button.config(command=partial(self._toggle_alert, enabled_attr, button))
        button.pack(side="left", padx=padx)
        if threshold_attr:
            button.bind("<Button-3>", partial(self._edit_threshold, threshold_attr, threshold_prompt))
        ToolTip(button, tooltip)
        return button

    def _toggle_alert(self, enabled_attr, button):
        enabled = not getattr(self, enabled_attr)
        setattr(self, enabled_attr, enabled)
        color = "#50fa7b" if enabled else "#888888"
        icon = "🔊" if enabled else "🔈"
        button.config(text=icon, fg=color, activeforeground=color)

    def _edit_threshold(self, threshold_attr, prompt, event=None):
        val = simpledialog.askfloat("Alert threshold", prompt, initialvalue=getattr(self, threshold_attr))
        if val is not None:
            setattr(self, threshold_attr, val)

    @staticmethod
    def _set_button_color(button, color):
        button.config(fg=color, activeforeground=color)

    def _set_alert_button(self, button, enabled, triggered):
        self._set_button_color(button, "#ff5555" if triggered else ("#50fa7b" if enabled else "#888888"))

    def _poll_tick(self):
        if not self._want_current_prices():
            return
        now = datetime.now()
        t_sec = time.time()
        should_poll = False

        if self.is_estimated:
            if t_sec - self.last_poll_ts >= ESTIMATED_INTERVAL: should_poll = True
        else:
            if now.minute % 5 == 0 and now.second == 0: self.high_freq = True
            if self.high_freq:
                if t_sec - self.last_poll_ts >= self.live_interval: should_poll = True
            elif now.second == 1 and t_sec - self.last_poll_ts >= self.live_interval: should_poll = True

        if should_poll and not self.price_fetch_busy:
            self.last_poll_ts = t_sec
            self._start_price_fetch(from_poll=True)

    def _background_tick(self):
        # Read Tk variables here on the UI thread; the worker only gets plain booleans
        renewables, recent = self._visible("Renewables"), self._visible("Price History and Forecast")
        if renewables or recent:
            self._run_async(partial(self._background_fetch, renewables, recent))

    def _background_fetch(self, renewables, recent):
        if renewables:
            self.fetch_renewables()
        if recent:
            self.fetch_prices_today()

    def _usage_tick(self):
        now = datetime.now()
        hour_key = now.strftime("%Y-%m-%d %H")
        if now.minute == 0 and hour_key != self.last_usage_hour and self._visible("Usage History"):
            self.last_usage_hour = hour_key
            self._run_async(self.fetch_usage)

    def _ticker_tick(self):
        now = datetime.now()
        now_ts = time.time()

        plot_second = int(now_ts)
        if plot_second != self.last_plot_second:
            self.last_plot_second = plot_second
            self._update_plot_current_time(self.prices_today_plot, now_ts)
            self._update_plot_current_time(self.usage_plot, now_ts)

        m = now.minute
        s = now.second
        seconds_left = 300 - ((m % 5) * 60 + s)
        if seconds_left <= 0:
            seconds_left = 300

        if seconds_left == 300 and self.last_sec_val == 1 and self.sound_enabled:
            beep(1000, 300)
        self.last_sec_val = seconds_left

        is_5s_mark = (s % 5 == 0 and s != self.last_beep_second)
        if is_5s_mark:
            self.last_beep_second = s

        self._set_alert_button(self.btn_speaker, self.sound_enabled, False)

        alert_states = (
            (self.btn_est_speaker, self.est_sound_enabled, self.is_estimated and self.est_sound_enabled, 800),
            (self.btn_buy_low, self.buy_low_enabled, self.buy_low_enabled and self.current_buy_val is not None and self.current_buy_val < self.buy_low_thresh, 700),
            (self.btn_buy_high, self.buy_high_enabled, self.buy_high_enabled and self.current_buy_val is not None and self.current_buy_val > self.buy_high_thresh, 1200),
            (self.btn_buy_c_low, self.buy_c_low_enabled, self.buy_c_low_enabled and self.current_controlled_val is not None and self.current_controlled_val < self.buy_c_low_thresh, 700),
            (self.btn_buy_c_high, self.buy_c_high_enabled, self.buy_c_high_enabled and self.current_controlled_val is not None and self.current_controlled_val > self.buy_c_high_thresh, 1200),
            (self.btn_sell_low, self.sell_low_enabled, self.sell_low_enabled and self.current_sell_val is not None and self.current_sell_val < self.sell_low_thresh, 700),
            (self.btn_sell_high, self.sell_high_enabled, self.sell_high_enabled and self.current_sell_val is not None and self.current_sell_val > self.sell_high_thresh, 1200),
        )
        for button, enabled, triggered, freq in alert_states:
            self._set_alert_button(button, enabled, triggered)
            if is_5s_mark and triggered:
                beep(freq, 200)

        self._update_ticker_ui(seconds_left, now_ts)

    def _set_fetch_failed(self, key, failed):
        self.fetch_failed[key] = failed

    def _update_ticker_ui(self, seconds_left, timestamp):
        self.lbl_ctime.config(text=time.strftime("%H:%M:%S"))
        self.lbl_next_val.config(text=f"-{seconds_left}s")
        for label, last_ts, key in (
            (self.lbl_up_sites, self.last_sites_fetch_timestamp, "sites"),
            (self.lbl_up_main, self.last_fetch_timestamp, "current"),
            (self.lbl_up_ren, self.last_renewables_timestamp, "renewables"),
            (self.lbl_up_prices_today, self.last_prices_today_timestamp, "prices_today"),
            (self.lbl_up_usage, self.last_usage_timestamp, "usage"),
        ):
            label.config(
                text=format_age(timestamp - last_ts if last_ts else None),
                fg="#ff5555" if self.fetch_failed[key] else ACTION_FG,
            )


if __name__ == "__main__":
    if requests is None:
        log_error(f"CRITICAL ERROR: Missing required library 'requests'. Details: {REQUESTS_IMPORT_ERROR}")
        raise REQUESTS_IMPORT_ERROR

    try:
        root = tk.Tk()
        app = AmberMonitorApp(root)
        root.mainloop()
    except Exception as e:
        log_error(f"CRITICAL ERROR: Unhandled exception during startup: {e}")
        raise