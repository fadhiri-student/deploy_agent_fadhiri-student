# deploy_agent_fadhiri-student

A shell script (`deploy_agent.sh`) that deploys, runs and archives the logs of the Student Attendance Tracker (`attendance_checker.py`). The Python file is never modified, everything is done with shell scripting around it.

## Repository layout

- `deploy_agent.sh` - the master script
- `README.md` - this file
- `templates/` - the original, unmodified `attendance_checker.py`, `assets.csv` and `config.json`

## Requirements

- bash
- python3
- zip

The script checks for python3 and zip when it starts and stops with a clear message if one is missing.

## How to run it and pick a feature

    chmod +x deploy_agent.sh
    ./deploy_agent.sh

I chose an **interactive menu**. The script shows this menu and loops until you choose Exit:

    1) Deploy the application
    2) Run the application
    3) Archive the log files
    4) Exit

## Feature 1: Deploy

1. **Pre-flight check:** python3 (version is printed) and zip must be installed, and the three template files must exist.
2. **Project name:** asked with `read`. Only letters, numbers, `-` and `_` are accepted. The project is created as `attendance_tracker_{name}/`. If that folder already exists the script asks whether to overwrite it, and if the answer is not `y` it stops without changing anything.
3. **Structure created:**

        attendance_tracker_{name}/
        ├── attendance_checker.py
        ├── Helpers/
        │   ├── assets.csv
        │   └── config.json
        └── reports/

4. **Roster:** the user picks how to build `Helpers/assets.csv`:
    - **Option A (copy):** asks how many students (1 to 10) and copies that many rows plus the header from `templates/assets.csv`.
    - **Option B (generate):** asks how many students (1 to 15) and builds the rows in the script from arrays of names and emails, with Attendance Count and Absence Count both starting at 0.
5. **total_sessions stays consistent with the roster.** `total_sessions` means all sessions including today's, so it must be one more than the prior sessions recorded. The template students have 4 prior sessions, so Option A sets `total_sessions` to 5. A fresh roster has no prior sessions, so Option B sets it to 1. The script does this automatically with `sed` and does not ask.
6. **Permissions:** `chmod +x` on `attendance_checker.py` and `chmod 600` on `Helpers/config.json` (owner read/write only, because it holds the grading thresholds). The script prints the permissions it set with `ls -l`.
7. **Threshold update:** the script asks if the thresholds should be changed. If yes, it reads a new `warning` (default 75) and `failure` (default 50). Pressing Enter keeps the default. Each value must be a whole number from 0 to 100, and failure must be lower than warning, otherwise the script asks again. After validation, `sed` edits only the `"warning": <number>` and `"failure": <number>` lines in place, so the file is not reformatted or reordered.
8. **Verification run:** the deploy ends by starting the application (Feature 2). If it starts and the roster and config load, the setup is correct.

## Feature 2: Run

Menu option 2 asks for the project name and runs `python3 attendance_checker.py` from inside `attendance_tracker_{name}/`. The terminal is handed to the instructor to mark each student present or absent. If the project does not exist, the script says so and returns to the menu.

## Feature 3: Archive the logs

Menu option 3 asks for the project name and archives the logs from the last run. Each log goes into its own folder with a timestamp (`YYYYMMDD_HHMMSS`) in the file name:

    attendance_tracker_{name}/
    └── archives/
        ├── attendance/
        │   └── attendance_20261014_084840.log
        └── absent/
            └── absent_20261014_084840.log

- `reports/attendance.log` is copied to `archives/attendance/`.
- `reports/absent.log` is copied to `archives/absent/`.
- The script prints each archived file and its path.
- If a log does not exist (for example nobody was absent, so there is no `absent.log`), the script reports that and continues without crashing. If neither log exists it says nothing was archived.
- The logs are **copied**, not moved, so the originals stay in `reports/`. Every copy has a different timestamp, so archives are never overwritten.

## Ctrl+C and Ctrl+Z during deployment

While Feature 1 is running, the script traps **SIGINT** (Ctrl+C) and **SIGTSTP** (Ctrl+Z). This is the archive trigger for interrupted deployments. When either signal arrives, the script:

1. prints that the deployment was interrupted,
2. zips whatever exists of `attendance_tracker_{name}/` into `attendance_tracker_{name}_archive.zip` using the `zip` command,
3. deletes the incomplete project folder so no half-made directory is left behind,
4. closes the script cleanly (exit code 130).

If the interrupt happens before anything was created (for example while it is still asking for the name), there is nothing to zip and the script just says so. A folder that already existed is never deleted by the handler, because the overwrite question is answered before the script starts building.

The trap is turned off before the verification run, so it applies to the shell script only and not to a marking session in `attendance_checker.py`. If a prompt ever receives no input (end of input, Ctrl+D), the script treats it like an interruption.

### How to test it

1. Run `./deploy_agent.sh`, choose `1` and give a name such as `demo`.
2. At the "Choose A or B" or "How many students" prompt, press **Ctrl+C** (or **Ctrl+Z**).
3. The script prints the interruption message, saves the zip and removes the folder.
4. Check the result:

        ls -d attendance_tracker_demo
        ls -l attendance_tracker_demo_archive.zip
        python3 -m zipfile -l attendance_tracker_demo_archive.zip

The first command should say "No such file or directory", because the folder was removed. The other two should show the zip and its contents.

### What the .zip contains

Whatever had been created when the interrupt came. For an interrupt during the roster step it holds:

    attendance_tracker_demo/
    attendance_tracker_demo/attendance_checker.py
    attendance_tracker_demo/Helpers/
    attendance_tracker_demo/Helpers/config.json
    attendance_tracker_demo/reports/

## How I tested the deployed structure

- Deployed projects with Option A (3 students) and Option B (4 students) and checked the layout with `find attendance_tracker_test | sort`.
- Checked the permissions with `ls -l` (`-rwxr-xr-x` for the checker and `-rw-------` for config.json).
- Checked `cat Helpers/config.json` to see that `total_sessions` was 5 for Option A and 1 for Option B, and that only the warning and failure lines changed after a threshold update.
- Tried bad input: empty and invalid project names, a name that already exists (answering n and y), a non-numeric student count, a count above the maximum, a letter other than A or B, text or out-of-range numbers for thresholds, and failure higher than warning.
- Ran the application after deployment, marked students, and confirmed that `assets.csv` counts changed and that `reports/attendance.log` and `reports/absent.log` were created.
- Ran the archive feature with both logs, with only one log (no `absent.log`), and with a project that does not exist.
- Tested Ctrl+C and Ctrl+Z by hand and checked that the zip exists, that its contents are correct, and that the folder is gone.
