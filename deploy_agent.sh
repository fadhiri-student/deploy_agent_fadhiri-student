#!/bin/bash

cd "$(dirname "$0")"

project_dir=""
deploying="no"

check_tools() {
    if ! command -v python3 > /dev/null; then
        echo "Error: python3 is not installed."
        exit 1
    fi
    if ! command -v zip > /dev/null; then
        echo "Error: zip is not installed."
        exit 1
    fi
    python3 --version
    echo "python3 and zip are installed."
}

handle_interrupt() {
    echo ""
    echo "Deployment was interrupted."
    if [ "$deploying" = "yes" ] && [ -d "$project_dir" ]; then
        zip -r -q "${project_dir}_archive.zip" "$project_dir"
        rm -rf "$project_dir"
        echo "Saved what was created so far in ${project_dir}_archive.zip"
        echo "Removed the incomplete folder."
    else
        echo "Nothing was created yet."
    fi
    echo "Closing the script."
    exit 130
}

deploy_project() {
    echo "Deploy is not built yet."
}

run_application() {
    echo "Run is not built yet."
}

archive_logs() {
    echo "Archive is not built yet."
}

show_menu() {
    echo ""
    echo "===== Attendance Tracker Deploy Agent ====="
    echo "1) Deploy the application"
    echo "2) Run the application"
    echo "3) Archive the log files"
    echo "4) Exit"
}

check_tools

while true; do
    show_menu
    read -p "Choose an option (1-4): " choice
    case "$choice" in
        1) deploy_project ;;
        2) run_application ;;
        3) archive_logs ;;
        4) echo "Goodbye."; exit 0 ;;
        *) echo "Invalid choice, please enter 1, 2, 3 or 4." ;;
    esac
done
