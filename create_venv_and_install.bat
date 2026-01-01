@echo off
REM Create a virtual environment named 'venv' and install dependencies from requirements.txt
cd /d "%~dp0"
if not exist venv (
    echo Creating virtual environment 'venv'...
    python -m venv venv
) else (
    echo Virtual environment 'venv' already exists. Skipping creation.
)

necho Upgrading pip in the venv...
venv\Scripts\python -m pip install --upgrade pip

echo Installing dependencies from requirements.txt...
if exist requirements.txt (
    venv\Scripts\python -m pip install -r requirements.txt
) else (
    echo requirements.txt not found. Please create it or run pip install manually.
)

echo Done. To activate the venv in cmd.exe, run:
echo    venv\Scripts\activate
echo Then you can run the GUI with:
echo    python gui.py
pause