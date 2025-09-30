import tkinter as tk
from tkinter import ttk, simpledialog, messagebox, scrolledtext
import serial
import serial.tools.list_ports
import time
import threading

class EEPROM_GUI:
    def __init__(self, master):
        self.master = master
        master.title("CM108 EEPROM Utility GUI v1.0")
        master.geometry("750x550")
        master.resizable(False, False)

        # Globale Schriftgröße
        default_font = ("Arial", 14)
        self.master.option_add("*Font", default_font)

        # Stil für mittelgroße Buttons
        style = ttk.Style()
        style.configure("Medium.TButton", font=("Arial", 14), padding=5)

        # Serial Frame
        serial_frame = ttk.LabelFrame(master, text="Verbindung")
        serial_frame.pack(fill="x", padx=10, pady=5)

        ttk.Label(serial_frame, text="COM-Port:").pack(side="left", padx=5, pady=5)
        self.port_var = tk.StringVar()
        self.port_menu = ttk.Combobox(serial_frame, textvariable=self.port_var, values=self.list_ports(), width=12, font=("Arial", 14))
        self.port_menu.pack(side="left", padx=5)

        self.connect_button = ttk.Button(serial_frame, text="Verbinden", style="Medium.TButton", command=self.connect)
        self.connect_button.pack(side="left", padx=5)

        self.disconnect_button = ttk.Button(serial_frame, text="Trennen", style="Medium.TButton", command=self.disconnect)
        self.disconnect_button.pack(side="left", padx=5)

        self.status_label = ttk.Label(serial_frame, text="Nicht verbunden", foreground="red", font=("Arial", 14))
        self.status_label.pack(side="left", padx=10)

        # Aktionen Frame
        action_frame = ttk.LabelFrame(master, text="Aktionen")
        action_frame.pack(fill="x", padx=10, pady=5)

        self.read_button = ttk.Button(action_frame, text="Product String lesen", style="Medium.TButton", command=self.read_product)
        self.read_button.pack(fill="x", padx=5, pady=3)

        self.write_button = ttk.Button(action_frame, text="Product String schreiben", style="Medium.TButton", command=self.write_product)
        self.write_button.pack(fill="x", padx=5, pady=3)

        self.dump_button = ttk.Button(action_frame, text="EEPROM Hex-Dump", style="Medium.TButton", command=self.dump_eeprom)
        self.dump_button.pack(fill="x", padx=5, pady=3)

        self.erase_button = ttk.Button(action_frame, text="EEPROM löschen", style="Medium.TButton", command=self.erase_eeprom)
        self.erase_button.pack(fill="x", padx=5, pady=3)

        # Ausgabe Frame (größeres Scrollfeld)
        output_frame = ttk.LabelFrame(master, text="Ausgabe")
        output_frame.pack(fill="both", expand=True, padx=10, pady=5)

        self.output = scrolledtext.ScrolledText(output_frame, width=80, height=25, font=("Courier", 14))
        self.output.pack(fill="both", expand=True)

        # Fortschrittsbalken
        self.progress = ttk.Progressbar(master, orient="horizontal", mode="indeterminate")
        self.progress.pack(fill="x", padx=10, pady=5)

        self.ser = None
        self.set_buttons_state("disabled")  # Buttons standardmäßig deaktiviert

    # ------------------------ Hilfsfunktionen ------------------------
    def list_ports(self):
        return [port.device for port in serial.tools.list_ports.comports()]

    def set_buttons_state(self, state="normal"):
        self.read_button.config(state=state)
        self.write_button.config(state=state)
        self.dump_button.config(state=state)
        self.erase_button.config(state=state)

    def append_output(self, text):
        self.output.insert(tk.END, text)
        self.output.see(tk.END)

    def run_in_thread(self, target, *args):
        thread = threading.Thread(target=target, args=args)
        thread.start()

    # ------------------------ Verbindung ------------------------
    def connect(self):
        port = self.port_var.get()
        if not port:
            messagebox.showwarning("Warnung", "Bitte COM-Port auswählen")
            return
        try:
            self.ser = serial.Serial(port, 115200, timeout=1)
            time.sleep(2)  # Arduino Reset warten
            self.status_label.config(text=f"Verbunden", foreground="green")
            self.append_output(f"Verbunden mit {port}\n")
            self.set_buttons_state("normal")
        except Exception as e:
            messagebox.showerror("Fehler", str(e))
            self.status_label.config(text="Nicht verbunden", foreground="red")

    def disconnect(self):
        if self.ser:
            try:
                self.ser.close()
                self.ser = None
                self.status_label.config(text="Nicht verbunden", foreground="red")
                self.append_output("Verbindung getrennt.\n")
                self.set_buttons_state("disabled")
            except Exception as e:
                messagebox.showerror("Fehler", f"Fehler beim Trennen: {e}")

    # ------------------------ Arduino-Kommandos ------------------------
    def send_command(self, cmd, wait=0.1):
        if not self.ser:
            messagebox.showwarning("Warnung", "Bitte zuerst verbinden")
            return ""
        self.ser.write(cmd.encode())
        time.sleep(wait)
        output = ""
        while self.ser.in_waiting:
            output += self.ser.read(self.ser.in_waiting).decode(errors='ignore')
        return output

    def read_product(self):
        self.run_in_thread(self._read_product)

    def _read_product(self):
        self.progress.start()
        self.append_output("Lesen des Product Strings...\n")
        out = self.send_command('R')
        if out:
            self.append_output(out + "\n")
        self.progress.stop()

    def write_product(self):
        s = simpledialog.askstring("Eingabe", "Neuen Product String eingeben (max 30 Zeichen):")
        if s:
            if len(s) > 30:
                s = s[:30]
            self.run_in_thread(self._write_product, s)

    def _write_product(self, s):
        self.progress.start()
        self.send_command('W')
        for c in s:
            self.ser.write(c.encode())
        self.ser.write(b'\n')
        time.sleep(0.5)
        out = ""
        while self.ser.in_waiting:
            out += self.ser.read(self.ser.in_waiting).decode(errors='ignore')
        self.append_output(out + "\n")
        self.progress.stop()

    def dump_eeprom(self):
        self.run_in_thread(self._dump_eeprom)

    def _dump_eeprom(self):
        self.progress.start()
        self.append_output("EEPROM Hex-Dump...\n")
        out = self.send_command('V', wait=2)
        if out:
            self.append_output(out + "\n")
        self.progress.stop()

    def erase_eeprom(self):
        confirm = messagebox.askyesno("Bestätigung", "EEPROM wirklich löschen?")
        if confirm:
            self.run_in_thread(self._erase_eeprom)

    def _erase_eeprom(self):
        self.progress.start()
        out = self.send_command('E', wait=1)
        if out:
            self.append_output(out + "\n")
        self.progress.stop()


if __name__ == "__main__":
    root = tk.Tk()
    gui = EEPROM_GUI(root)
    root.mainloop()
