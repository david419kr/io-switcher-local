import tkinter as tk
import time
import pyswitcherio
from gui import SwitchApp

root = tk.Tk()
app = SwitchApp(root)

# Ensure mac is set
app.mac_var.set('00:11:22:33:44:55')

# Monkeypatch IOSwitcher to raise immediately
class Bad:
    def __init__(self, *a, **k):
        raise RuntimeError('simulated init failure')

pyswitcherio.IOSwitcher = Bad

# Trigger toggle (this will start a background thread)
app.on_action(1, 'on')

# Run the event loop briefly to let scheduled callbacks run
start = time.time()
while time.time() - start < 1.0:
    root.update()
    time.sleep(0.05)

print('status label:', app.status_label.cget('text'))
root.destroy()