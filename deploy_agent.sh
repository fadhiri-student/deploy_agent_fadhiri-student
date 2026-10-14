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

ask_project_name() {
    while true; do
        read -p "Enter a name for the project: " name
        case "$name" in
            "") echo "The name cannot be empty." ;;
            *[!A-Za-z0-9_-]*) echo "Please use only letters, numbers, - and _" ;;
            *) break ;;
        esac
    done

    project_dir="attendance_tracker_$name"

    if [ -d "$project_dir" ]; then
        echo "The folder $project_dir already exists."
        read -p "Do you want to overwrite it? (y/n): " answer
        if [ "$answer" != "y" ]; then
            echo "Deployment cancelled. Nothing was changed."
            return 1
        fi
        rm -rf "$project_dir" || { echo "Error: could not remove the old folder."; return 1; }
    fi
    return 0
}

create_structure() {
    deploying="yes"
    mkdir -p "$project_dir/Helpers" "$project_dir/reports"
    if [ $? -ne 0 ]; then
        echo "Error: could not create the folders (permission denied?)."
        rm -rf "$project_dir"
        deploying="no"
        return 1
    fi

    cp templates/attendance_checker.py "$project_dir/"
    cp templates/config.json "$project_dir/Helpers/"
    if [ $? -ne 0 ]; then
        echo "Error: could not copy the template files."
        rm -rf "$project_dir"
        deploying="no"
        return 1
    fi

    echo "Created the folders and copied attendance_checker.py and config.json."
    return 0
}

ask_count() {
    max=$1
    while true; do
        read -p "How many students (1-$max)? " count
        case "$count" in
            ""|*[!0-9]*)
                echo "Please enter a number."
                continue
                ;;
        esac
        if [ "$count" -ge 1 ] && [ "$count" -le "$max" ]; then
            break
        fi
        echo "The number must be between 1 and $max."
    done
}

build_roster() {
    while true; do
        echo ""
        echo "How do you want to build the student list?"
        echo "A) Copy students from the template"
        echo "B) Generate a fresh list (everyone starts at 0)"
        read -p "Choose A or B: " option
        option=$(echo "$option" | tr 'a-z' 'A-Z')
        if [ "$option" = "A" ] || [ "$option" = "B" ]; then
            break
        fi
        echo "Please type A or B."
    done

    roster="$project_dir/Helpers/assets.csv"
    config="$project_dir/Helpers/config.json"

    if [ "$option" = "A" ]; then
        template_rows=$(( $(wc -l < templates/assets.csv) - 1 ))
        ask_count "$template_rows"
        head -n $((count + 1)) templates/assets.csv > "$roster" || return 1
        sessions=5
    else
        names=("Amara Uwase" "Brian Mugisha" "Carine Ingabire" "David Nkusi" "Eric Habimana" "Fiona Mukamana" "Grace Uwimana" "Henry Niyonzima" "Irene Kayitesi" "Jean Bosco" "Kevin Mutesi" "Linda Umutoni" "Moses Byiringiro" "Nadine Iradukunda" "Olivier Hakizimana")
        emails=("amara@example.com" "brian@example.com" "carine@example.com" "david@example.com" "eric@example.com" "fiona@example.com" "grace@example.com" "henry@example.com" "irene@example.com" "jean@example.com" "kevin@example.com" "linda@example.com" "moses@example.com" "nadine@example.com" "olivier@example.com")

        ask_count "${#names[@]}"
        echo "Email,Names,Attendance Count,Absence Count" > "$roster" || return 1
        for ((i = 0; i < count; i++)); do
            echo "${emails[$i]},${names[$i]},0,0" >> "$roster"
        done
        sessions=1
    fi

    sed -i "s/\"total_sessions\": [0-9]*/\"total_sessions\": $sessions/" "$config" || return 1

    echo "Roster created with $count students."
    grep "total_sessions" "$config"
    return 0
}

set_permissions() {
    chmod +x "$project_dir/attendance_checker.py" && chmod 600 "$project_dir/Helpers/config.json"
    if [ $? -ne 0 ]; then
        echo "Error: could not set the file permissions."
        return 1
    fi
    echo "Permissions set:"
    ls -l "$project_dir/attendance_checker.py" "$project_dir/Helpers/config.json"
    return 0
}

ask_threshold() {
    while true; do
        read -p "New $1 threshold (default $2): " value
        if [ -z "$value" ]; then
            value=$2
        fi
        case "$value" in
            *[!0-9]*)
                echo "Please enter a whole number."
                continue
                ;;
            ????*)
                echo "That number is too big."
                continue
                ;;
        esac
        if [ "$value" -ge 0 ] && [ "$value" -le 100 ]; then
            break
        fi
        echo "The number must be between 0 and 100."
    done
}

update_thresholds() {
    config="$project_dir/Helpers/config.json"

    read -p "Do you want to update the attendance thresholds? (y/n): " answer
    if [ "$answer" != "y" ]; then
        echo "Keeping the default thresholds (warning 75, failure 50)."
        return 0
    fi

    while true; do
        ask_threshold "warning" 75
        warning=$value
        ask_threshold "failure" 50
        failure=$value
        if [ "$failure" -lt "$warning" ]; then
            break
        fi
        echo "Failure must be lower than warning. Please enter both again."
    done

    sed -i "s/\"warning\": [0-9]*/\"warning\": $warning/" "$config" || return 1
    sed -i "s/\"failure\": [0-9]*/\"failure\": $failure/" "$config" || return 1

    echo "Thresholds updated:"
    grep -E '"warning"|"failure"' "$config"
    return 0
}

start_app() {
    (cd "$1" && python3 attendance_checker.py)
}

deploy_project() {
    trap handle_interrupt SIGINT SIGTSTP

    if ask_project_name && create_structure && build_roster && set_permissions && update_thresholds; then
        deploying="no"
        trap - SIGINT SIGTSTP
        echo ""
        echo "Deployment finished. Starting the app to check that it works..."
        start_app "$project_dir"
        return
    fi

    if [ "$deploying" = "yes" ]; then
        echo "Deployment failed, removing the incomplete folder."
        rm -rf "$project_dir"
    fi
    deploying="no"
    trap - SIGINT SIGTSTP
}

run_application() {
    read -p "Enter the name of the project to run: " name
    project_dir="attendance_tracker_$name"
    if [ ! -d "$project_dir" ]; then
        echo "Error: $project_dir was not found. Deploy it first."
        return
    fi
    start_app "$project_dir"
}

archive_logs() {
    read -p "Enter the name of the project to archive: " name
    project_dir="attendance_tracker_$name"
    if [ ! -d "$project_dir" ]; then
        echo "Error: $project_dir was not found. Deploy it first."
        return
    fi

    stamp=$(date +%Y%m%d_%H%M%S)
    archived=0

    if [ -f "$project_dir/reports/attendance.log" ]; then
        mkdir -p "$project_dir/archives/attendance"
        target="$project_dir/archives/attendance/attendance_$stamp.log"
        if cp "$project_dir/reports/attendance.log" "$target"; then
            echo "Archived attendance.log -> $target"
            archived=1
        else
            echo "Error: could not archive attendance.log"
        fi
    else
        echo "No attendance.log found, skipping it."
    fi

    if [ -f "$project_dir/reports/absent.log" ]; then
        mkdir -p "$project_dir/archives/absent"
        target="$project_dir/archives/absent/absent_$stamp.log"
        if cp "$project_dir/reports/absent.log" "$target"; then
            echo "Archived absent.log -> $target"
            archived=1
        else
            echo "Error: could not archive absent.log"
        fi
    else
        echo "No absent.log found (maybe nobody was absent), skipping it."
    fi

    if [ "$archived" -eq 0 ]; then
        echo "Nothing was archived. Run the application first."
    fi
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
    read -p "Choose an option (1-4): " choice || { echo ""; echo "No more input. Goodbye."; exit 0; }
    case "$choice" in
        1) deploy_project ;;
        2) run_application ;;
        3) archive_logs ;;
        4) echo "Goodbye."; exit 0 ;;
        *) echo "Invalid choice, please enter 1, 2, 3 or 4." ;;
    esac
done
