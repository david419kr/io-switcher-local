import tkinter as tk
import time
import pyswitcherio
from gui import SwitchApp

results = []

class DummyIOSwitcher:
    def __init__(self, mac, device, type=1):
        results.append(('init', mac, type))
    async def turn_on(self):
        results.append(('on',))
        return True
    async def turn_off(self):
        results.append(('off',))
        return True

pyswitcherio.IOSwitcher = DummyIOSwitcher

root = tk.Tk()
app = SwitchApp(root)
app.mac_var.set('00:11:22:33:44:55')
# set device config to 2-gang so both switches visible
app.type_var.set(2)
app.on_type_change()

# Press Switch1 ON
app.on_action(1, 'on')
# Let background thread run
start = time.time()
while time.time() - start < 1.0:
    root.update()
    time.sleep(0.01)

# Press Switch2 ON
app.on_action(2, 'on')
start = time.time()
while time.time() - start < 1.0:
    root.update()
    time.sleep(0.01)

print('results:', results)
root.destroy()