import os
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import venv
import threading

# -------------------------------------------------------
# Konfiguration
# -------------------------------------------------------
VENV_DIR = ".venv"
PYTHON_EXE = os.path.join(VENV_DIR, "Scripts", "pythonw.exe") if os.name == "nt" else os.path.join(VENV_DIR, "bin", "python")
PIP_EXE = os.path.join(VENV_DIR, "Scripts", "pip.exe") if os.name == "nt" else os.path.join(VENV_DIR, "bin", "pip")
REQUIREMENTS = "requirements.txt"
SCRIPT_NAME = "cm108ah.py"

# -------------------------------------------------------
# Fensterbasis
# -------------------------------------------------------
root = tk.Tk()
root.title("v0.6 – Dark Gradient Edition")
root.geometry("780x750")
root.resizable(False, False)
root.configure(bg="#14141a")

# -------------------------------------------------------
# Variablen
# -------------------------------------------------------
config_path_var = tk.StringVar()
status_var = tk.StringVar(value="Starte...")
progress_value = tk.IntVar(value=0)
enable_usb_ids_var = tk.IntVar(value=0)
enable_hid_bit_var = tk.IntVar(value=0)

# -------------------------------------------------------
# Farbverlauf-Header
# -------------------------------------------------------
header = tk.Canvas(root, height=80, highlightthickness=0)
header.pack(fill="x")
for i in range(780):
    r = int(0x00 + (0x4C - 0x00) * i / 780)
    g = int(0xBC + (0xAF - 0xBC) * i / 780)
    b = int(0xD4 + (0x50 - 0xD4) * i / 780)
    color = f"#{r:02x}{g:02x}{b:02x}"
    header.create_line(i, 0, i, 80, fill=color)

header.create_text(390, 40, text="⚙️ SAULink9 ATPI EEPROM Tool", fill="white",
                   font=("Segoe UI", 16, "bold"))

# -------------------------------------------------------
# Styles
# -------------------------------------------------------
style = ttk.Style()
style.theme_use("clam")
style.configure("Card.TFrame", background="#1e1e27", relief="flat")
style.configure("TLabel", background="#1e1e27", foreground="#e0e0e0", font=("Segoe UI", 10))
style.configure("TProgressbar", thickness=20, troughcolor="#2b2b38", background="#4CAF50")

# Glow-Button-Stile
style.configure("Accent.TButton",
                background="#4CAF50", foreground="white", font=("Segoe UI", 10, "bold"),
                padding=8, relief="flat")
style.map("Accent.TButton",
          background=[("active", "#6FE173"), ("pressed", "#3D944A")])

style.configure("Alt.TButton",
                background="#00BCD4", foreground="white", font=("Segoe UI", 10, "bold"),
                padding=8, relief="flat")
style.map("Alt.TButton",
          background=[("active", "#26C6DA"), ("pressed", "#0BA0B5")])

# -------------------------------------------------------
# Schattenrahmen-Helfer
# -------------------------------------------------------
def create_card(parent, **kwargs):
    shadow = tk.Frame(parent, bg="#0b0b10")
    shadow.pack(padx=8, pady=8)
    frame = ttk.Frame(shadow, style="Card.TFrame", **kwargs)
    frame.pack(padx=3, pady=3)
    return frame

# -------------------------------------------------------
# Layout
# -------------------------------------------------------
frame_top = create_card(root)
frame_middle = create_card(root)
frame_log = create_card(root)
frame_bottom = create_card(root)

# -------------------------------------------------------
# Top Frame – Datei-Auswahl
# -------------------------------------------------------
ttk.Label(frame_top, text="Konfigurationsdatei:").grid(row=0, column=0, sticky="w", padx=5, pady=8)
entry = ttk.Entry(frame_top, textvariable=config_path_var, width=60)
entry.grid(row=0, column=1, padx=5)
ttk.Button(frame_top, text="📁 Durchsuchen", style="Alt.TButton",
           command=lambda: config_path_var.set(
               filedialog.askopenfilename(filetypes=[("YAML-Dateien", "*.yaml")])
           )).grid(row=0, column=2, padx=5)

# -------------------------------------------------------
# Middle Frame – Aktionen + Flags (statisch)
# -------------------------------------------------------
ttk.Button(frame_middle, text="🔍 Geräte auflisten", style="Alt.TButton", width=30,
           command=lambda: run_in_thread(list_devices)).pack(pady=6)

ttk.Button(frame_middle, text="⚙️ EEPROM programmieren", style="Accent.TButton", width=30,
           command=lambda: run_in_thread(program_eeprom)).pack(pady=6)

ttk.Label(frame_middle, text="Optionale Flags für EEPROM:", font=("Segoe UI", 10, "bold"),
          background="#1e1e27", foreground="#e0e0e0").pack(pady=(10, 0))

# ----------------- tk.Checkbutton für statische Dark-Checkboxen -----------------
chk_usb = tk.Checkbutton(frame_middle, text="USB IDs aktivieren",
                         variable=enable_usb_ids_var,
                         bg="#1e1e27", fg="#e0e0e0",
                         selectcolor="#1e1e27", activebackground="#1e1e27",
                         font=("Segoe UI", 10))
chk_usb.pack(pady=2, anchor="w")

chk_hid = tk.Checkbutton(frame_middle, text="HID Bit aktivieren",
                         variable=enable_hid_bit_var,
                         bg="#1e1e27", fg="#e0e0e0",
                         selectcolor="#1e1e27", activebackground="#1e1e27",
                         font=("Segoe UI", 10))
chk_hid.pack(pady=2, anchor="w")

# -------------------------------------------------------
# Logfeld mit Scrollbar und Rahmen
# -------------------------------------------------------
log_frame_inner = tk.Frame(frame_log, bg="#121218", bd=2, relief="groove")
log_frame_inner.pack(fill="both", expand=True, padx=5, pady=5)

scroll = ttk.Scrollbar(log_frame_inner)
scroll.pack(side="right", fill="y")

log_text = tk.Text(
    log_frame_inner,
    height=16,
    bg="#121218",
    fg="#a0e8ff",
    insertbackground="white",
    font=("Consolas", 10),
    wrap="word",
    yscrollcommand=scroll.set,
    bd=2,
    relief="sunken"
)
scroll.config(command=log_text.yview)
log_text.pack(fill="both", expand=True, padx=3, pady=3)

log_text.insert("end", "🌙 Tool gestartet...\n")
log_text.config(state="disabled")

def log(msg, tag=None):
    log_text.config(state="normal")
    log_text.insert("end", msg + "\n", tag)
    log_text.see("end")
    log_text.config(state="disabled")

log_text.tag_config("success", foreground="#7CFC00")
log_text.tag_config("error", foreground="#ff6b6b")
log_text.tag_config("info", foreground="#00E5FF")

# -------------------------------------------------------
# Bottom Frame – Fortschritt & Status
# -------------------------------------------------------
progress = ttk.Progressbar(frame_bottom, orient="horizontal", mode="determinate",
                           length=720, variable=progress_value)
progress.pack(pady=8)
ttk.Label(frame_bottom, textvariable=status_var, foreground="#aaaaaa",
          background="#1e1e27").pack()

# -------------------------------------------------------
# Logik-Funktionen
# -------------------------------------------------------
def update_status(text, progress_val=None):
    status_var.set(text)
    if progress_val is not None:
        progress_value.set(progress_val)
    root.update_idletasks()

def run_in_thread(func):
    disable_buttons()
    threading.Thread(target=lambda: safe_run(func), daemon=True).start()

def safe_run(func):
    try:
        func()
    except Exception as e:
        log(f"❌ Fehler: {e}", "error")
        messagebox.showerror("Fehler", str(e))
    finally:
        enable_buttons()
        update_status("Bereit.", 0)

def disable_buttons():
    for child in frame_middle.winfo_children():
        child.config(state="disabled")

def enable_buttons():
    for child in frame_middle.winfo_children():
        child.config(state="normal")

# -------------------------------------------------------
# Hauptaktionen
# -------------------------------------------------------
def ensure_virtualenv():
    update_status("Überprüfe virtuelle Umgebung...", 10)
    setup_marker = os.path.join(VENV_DIR, ".setup_done")

    if not os.path.exists(VENV_DIR):
        log("🔧 Erstelle virtuelle Umgebung...", "info")
        venv.EnvBuilder(with_pip=True).create(VENV_DIR)
        update_status("Virtuelle Umgebung erstellt.", 30)
    else:
        log("✅ Virtuelle Umgebung gefunden.", "success")
        update_status("Virtuelle Umgebung gefunden.", 30)

    # Pip aktualisieren
    log("🔄 Aktualisiere pip...", "info")
    subprocess.run([PYTHON_EXE, "-m", "pip", "install", "--upgrade", "pip", "--disable-pip-version-check"],
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log("✅ pip ist aktuell.", "success")

    if not os.path.exists(REQUIREMENTS):
        log("⚠️ Keine requirements.txt gefunden.", "error")
        update_status("Keine requirements.txt gefunden.", 100)
        return

    if os.path.exists(setup_marker) and os.path.getmtime(setup_marker) > os.path.getmtime(REQUIREMENTS):
        log("✅ Alle Pakete bereits installiert. (Übersprungen)", "success")
        update_status("Virtuelle Umgebung bereit.", 100)
        return

    with open(REQUIREMENTS) as f:
        pkgs = [line.strip() for line in f if line.strip()]

    total = len(pkgs)
    if total == 0:
        log("⚠️ requirements.txt ist leer.", "error")
        return

    for i, pkg in enumerate(pkgs, 1):
        update_status(f"Installiere {pkg}...", int(30 + 60 * i / total))
        progress_value.set(int(30 + 60 * i / total))
        root.update_idletasks()
        log(f"📦 Installiere {pkg}", "info")

        proc = subprocess.Popen([PIP_EXE, "--disable-pip-version-check", "install", pkg],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in proc.stdout:
            log(line.strip())
        proc.wait()

        if proc.returncode != 0:
            log(f"❌ Fehler bei Installation von {pkg}", "error")
        else:
            log(f"✅ {pkg} installiert.", "success")

    with open(setup_marker, "w") as f:
        f.write("ok")

    progress_value.set(100)
    update_status("Setup abgeschlossen.", 100)
    log("🎉 Virtuelle Umgebung bereit.\n", "success")

def list_devices():
    update_status("Suche Geräte...", 40)
    progress_value.set(40)
    root.update_idletasks()
    log("🔍 Geräte werden gesucht...", "info")
    proc = subprocess.Popen([PYTHON_EXE, SCRIPT_NAME, "list"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        log(line.strip())
    proc.wait()
    progress_value.set(100)
    update_status("Geräteliste abgeschlossen.", 100)
    log("✅ Geräte aufgelistet.\n", "success")

def program_eeprom():
    config = config_path_var.get()
    if not config:
        messagebox.showwarning("Fehler", "Bitte YAML-Datei auswählen.")
        return

    update_status("Programmiere EEPROM...", 50)
    progress_value.set(50)
    root.update_idletasks()
    log(f"⚙️ Starte EEPROM-Programmierung mit {os.path.basename(config)} ...", "info")

    args = [PYTHON_EXE, SCRIPT_NAME, "program", config]
    if enable_usb_ids_var.get():
        args += ["--enable-usb-ids", "1"]
    if enable_hid_bit_var.get():
        args += ["--enable-hid-bit", "1"]

    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        log(line.strip())
    code = proc.wait()

    progress_value.set(100)
    update_status("Fertig.", 100)
    if code == 0:
        log("✅ EEPROM erfolgreich programmiert!", "success")
        messagebox.showinfo("Erfolg", "EEPROM wurde erfolgreich programmiert!")
    else:
        log("❌ Fehler bei EEPROM-Programmierung.", "error")
        messagebox.showerror("Fehler", "Fehler bei EEPROM-Programmierung.")

# -------------------------------------------------------
# Start
# -------------------------------------------------------
run_in_thread(ensure_virtualenv)
root.mainloop()
