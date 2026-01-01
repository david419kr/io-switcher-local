import tkinter as tk
import time
import gui

root = tk.Tk()
app = gui.SwitchApp(root)

# Simulate opening scan window
app._scan_window = tk.Toplevel(app.root)
app._scan_window.title('test')
app._scan_results_frame = tk.Frame(app._scan_window)
app._scan_results_frame.pack()

results = [('SWITCHER_M_01', 'AA:BB:CC:DD:EE:01'), ('SWITCHER_M_02', 'AA:BB:CC:DD:EE:02')]
app._show_scan_results(results)

root.update()
children = app._scan_results_frame.winfo_children()
print('children len', len(children))
for c in children:
    print('child', c, c.winfo_class())
    for cc in c.winfo_children():
        print(' - sub', cc, cc.winfo_class(), getattr(cc, 'cget', lambda k: None)('text'))

# simulate pressing Use on first entry
first_row = children[0]
use_btn = [c for c in first_row.winfo_children() if c.winfo_class()=='Button' and c.cget('text')=='Use'][0]
use_btn.invoke()
print('mac now', app.mac_var.get())

root.destroy()