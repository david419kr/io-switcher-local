import tkinter as tk
import time
from types import SimpleNamespace
import gui

# Monkeypatch BleakScanner.discover
class FakeScanner:
    @staticmethod
    def discover(timeout=5.0):
        return [SimpleNamespace(name='SWITCHER_M_01', address='AA:BB:CC:DD:EE:01'),
                SimpleNamespace(name='Other', address='11:22:33:44:55:66'),
                SimpleNamespace(name='SWITCHER_M_02', address='AA:BB:CC:DD:EE:02')]

import bleak
bleak.BleakScanner = FakeScanner

root = tk.Tk()
app = gui.SwitchApp(root)

app.find_devices()
# let background thread run
start = time.time()
while time.time() - start < 1.0:
    root.update()
    time.sleep(0.05)

# Check that the scan window exists and has result rows
win = getattr(app, '_scan_window', None)
assert win is not None
frame = app._scan_results_frame
children = frame.winfo_children()
print('children count:', len(children))
for c in children:
    cls = c.winfo_class()
    text = ''
    try:
        text = c.cget('text')
    except Exception:
        pass
    print('child:', c, cls, repr(text))

# Find first row frame (if any) and click its Use button
row_frames = [c for c in children if isinstance(c, tk.Frame)]
if row_frames:
    r = row_frames[0]
    first_use_btn = [c for c in r.winfo_children() if isinstance(c, tk.Button) and c.cget('text')=='Use'][0]
    first_use_btn.invoke()
    print('MAC set to', app.mac_var.get())
else:
    print('No row frames to test Use button')

root.destroy()