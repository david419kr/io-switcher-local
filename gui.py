import asyncio
import json
import logging
import os
import threading
import time
import tkinter as tk
from tkinter import messagebox

import pyswitcherio

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")
LOG_RETRY_MSG = "스위쳐 연결 실패. 다시 시도 남은 횟수"
LOG_FAIL_MSG = "스위쳐 통신 실패.."


class GuiLogHandler(logging.Handler):
    def __init__(self, callback):
        super().__init__()
        self.callback = callback

    def emit(self, record):
        try:
            msg = self.format(record)
        except Exception:
            msg = record.getMessage()
        # Call the GUI callback in a thread-safe way
        self.callback(msg)


class SwitchApp:
    def __init__(self, root):
        self.root = root
        self.root.title("PySwitcherIO GUI")

        # load config
        self.config = self._load_config()
        self.mac_var = tk.StringVar(value=self.config.get("mac", ""))
        self.type_var = tk.IntVar(value=self.config.get("type", 2))  # 1 or 2
        self.invert_var = tk.IntVar(value=1 if self.config.get("invert", False) else 0)

        # UI
        frame = tk.Frame(root, padx=10, pady=10)
        frame.pack(fill=tk.BOTH, expand=True)

        tk.Label(frame, text="MAC Address:").grid(row=0, column=0, sticky="w")
        self.mac_entry = tk.Entry(frame, textvariable=self.mac_var, width=30)
        self.mac_entry.grid(row=0, column=1, sticky="w")
        tk.Button(frame, text="Save MAC", command=self.save_mac).grid(row=0, column=2, padx=5)

        self.type_check = tk.Checkbutton(frame, text="2구 스위처 (체크: 2구, 해제: 1구)", variable=self.type_var, onvalue=2, offvalue=1, command=self.on_type_change)
        self.type_check.grid(row=1, column=0, columnspan=3, sticky="w", pady=(8, 0))

        self.invert_check = tk.Checkbutton(frame, text="ON/OFF 반대로 작동", variable=self.invert_var, command=self.on_invert_change)
        self.invert_check.grid(row=2, column=0, columnspan=3, sticky="w", pady=(4, 10))

        # Switch controls
        # Replace checkboxes with independent ON/OFF buttons (always available to press)
        self.switch1_on_btn = tk.Button(frame, text="Switch1 ON", width=12, command=lambda: self.on_action(1, "on"))
        self.switch1_on_btn.grid(row=3, column=0, sticky="w")
        self.switch1_off_btn = tk.Button(frame, text="Switch1 OFF", width=12, command=lambda: self.on_action(1, "off"))
        self.switch1_off_btn.grid(row=3, column=1, sticky="w")

        self.switch2_on_btn = tk.Button(frame, text="Switch2 ON", width=12, command=lambda: self.on_action(2, "on"))
        self.switch2_on_btn.grid(row=3, column=2, sticky="w")
        self.switch2_off_btn = tk.Button(frame, text="Switch2 OFF", width=12, command=lambda: self.on_action(2, "off"))
        self.switch2_off_btn.grid(row=3, column=3, sticky="w")

        # Initially hide switch2 buttons if type is 1
        if self.type_var.get() == 1:
            self.switch2_on_btn.grid_remove()
            self.switch2_off_btn.grid_remove()

        self.status_label = tk.Label(frame, text="", fg="blue")
        self.status_label.grid(row=4, column=0, columnspan=4, sticky="w", pady=(10, 0))

        # Logging setup
        self.log_handler = GuiLogHandler(self.on_log_message)
        self.log_handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter("%(message)s")
        self.log_handler.setFormatter(formatter)
        logging.getLogger().addHandler(self.log_handler)
        logging.getLogger().setLevel(logging.DEBUG)

        # For monitoring log-based success/failure criteria
        self.monitor_lock = threading.Lock()
        self.current_monitor = None  # dict or None

        # Keep a reference to ioswitcher object per current operation
        self._operation_thread = None

        # Save config on close
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def _load_config(self):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def save_config(self):
        try:
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump({
                    "mac": self.mac_var.get(),
                    "type": self.type_var.get(),
                    "invert": bool(self.invert_var.get()),
                }, f)
        except Exception as e:
            print("Failed to save config:", e)

    def save_mac(self):
        # Just save current config to disk
        self.save_config()
        self.status_label.config(text="MAC saved.")

    def on_type_change(self):
        if self.type_var.get() == 1:
            self.switch2_on_btn.grid_remove()
            self.switch2_off_btn.grid_remove()
        else:
            self.switch2_on_btn.grid()
            self.switch2_off_btn.grid()
        self.save_config()

    def on_invert_change(self):
        self.save_config()

    def on_log_message(self, message: str):
        # This may be called from non-main threads; schedule into mainloop
        self.root.after(1, lambda: self._handle_log_message(message))

    def _handle_log_message(self, message: str):
        # Update status label with latest library log
        self.status_label.config(text=message)

        with self.monitor_lock:
            if self.current_monitor is None:
                return
            m = self.current_monitor
            m["last_log_time"] = time.time()
            # check for messages
            if LOG_FAIL_MSG in message:
                m["seen_fail"] = True
            if LOG_RETRY_MSG in message:
                m["seen_retry"] = True

    def start_monitor(self, operation_desc: str):
        with self.monitor_lock:
            monitor_id = time.time()
            self.current_monitor = {
                "id": monitor_id,
                "start": time.time(),
                "last_log_time": None,
                "seen_retry": False,
                "seen_fail": False,
                "operation": operation_desc,
            }
        # start checker loop
        self._monitor_check()

    def _monitor_check(self):
        with self.monitor_lock:
            m = self.current_monitor
        if m is None:
            return
        now = time.time()
        # If we've seen a failure message, report failure
        if m["seen_fail"]:
            self._on_operation_failed("스위쳐 통신 실패.. 메시지 감지")
            with self.monitor_lock:
                self.current_monitor = None
            return
        # If we've seen retry message and we have not received logs for >=0.5s -> success
        if m["seen_retry"]:
            last = m["last_log_time"] or m["start"]
            if now - last >= 0.5:
                # Consider success, no UI needed as per requirement
                with self.monitor_lock:
                    self.current_monitor = None
                self._on_operation_success()
                return
        # Continue checking
        self.root.after(100, self._monitor_check)

    def _on_operation_success(self):
        # No explicit notification required. Re-enable controls.
        self._enable_controls()
        self.status_label.config(text="작업 성공 (로그 기준)")

    def _on_operation_failed(self, reason: str):
        self._enable_controls()
        # No checkbox state to revert (buttons are stateless)
        self.status_label.config(text=f"실패: {reason}")
        # show simple message dialog
        messagebox.showerror("Operation Failed", "스위쳐 통신 실패..")

    def _disable_controls(self):
        self.switch1_on_btn.config(state=tk.DISABLED)
        self.switch1_off_btn.config(state=tk.DISABLED)
        self.switch2_on_btn.config(state=tk.DISABLED)
        self.switch2_off_btn.config(state=tk.DISABLED)
        self.mac_entry.config(state=tk.DISABLED)
        self.type_check.config(state=tk.DISABLED)
        self.invert_check.config(state=tk.DISABLED)

    def _enable_controls(self):
        self.switch1_on_btn.config(state=tk.NORMAL)
        self.switch1_off_btn.config(state=tk.NORMAL)
        if self.type_var.get() == 2:
            self.switch2_on_btn.config(state=tk.NORMAL)
            self.switch2_off_btn.config(state=tk.NORMAL)
        self.mac_entry.config(state=tk.NORMAL)
        self.type_check.config(state=tk.NORMAL)
        self.invert_check.config(state=tk.NORMAL)

    def on_action(self, switch_index: int, action: str):
        mac = self.mac_var.get().strip()
        if not mac:
            messagebox.showwarning("No MAC", "MAC 주소를 입력하고 저장하세요.")
            return
        invert = bool(self.invert_var.get())
        # Apply invert setting: if invert then flip the requested action
        if invert:
            action = "off" if action == "on" else "on"
        # Disable controls during operation
        self._disable_controls()
        # Start log monitor for this operation
        desc = f"switch{switch_index}_{action}"
        self.start_monitor(desc)
        # Run operation in background thread
        t = threading.Thread(target=self._run_switch_command, args=(mac, self.type_var.get(), switch_index, action))
        t.daemon = True
        t.start()
        self._operation_thread = t

    def _run_switch_command(self, mac: str, type_num: int, switch_index: int, action: str):
        # Ensure switch_index maps to the channel type for IOSwitcher
        # (IOSwitcher uses the 'type' parameter to select channel/key for 1 or 2)
        if switch_index == 2 and type_num == 1:
            # shouldn't happen because UI hides switch2 when type==1, but guard anyway
            msg = "Device configured as 1구인데 Switch 2를 작동하려고 했습니다."
            self.root.after(1, lambda msg=msg: self._on_operation_failed(msg))
            return
        channel_type = 1 if switch_index == 1 else 2
        try:
            io = pyswitcherio.IOSwitcher(mac, None, type=channel_type)
        except Exception as e:
            # Could not construct the object (e.g., scan failed). Treat as failure.
            msg = f"IOSwitcher init error: {e}"
            self.root.after(1, lambda msg=msg: self._on_operation_failed(msg))
            return
        try:
            if action == "on":
                res = asyncio.run(io.turn_on())
            else:
                res = asyncio.run(io.turn_off())
        except Exception as e:
            # Exception during write
            msg = f"Exception: {e}"
            self.root.after(1, lambda msg=msg: self._on_operation_failed(msg))
            return
        # If the library returns False explicitly and no failure logs were emitted, treat as failure
        with self.monitor_lock:
            m = self.current_monitor
            seen_fail = m["seen_fail"] if m else False
            seen_retry = m["seen_retry"] if m else False
        if not res and seen_fail:
            self.root.after(1, lambda: self._on_operation_failed("스위쳐 통신 실패.."))
            return
        # If result is True but we haven't seen retry message, still enable controls
        self.root.after(1, lambda: self._enable_controls())

    def on_close(self):
        self.save_config()
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = SwitchApp(root)
    root.mainloop()
