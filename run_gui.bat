@echo off
REM Run the GUI using the virtual environment's python
cd /d "%~dp0"
venv\Scripts\python.exe gui.py
pause
