#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1 || dpkg -l | grep "$1" >/dev/null 2>&1
}

declare -A package_install_commands=(
    [apt-get]="sudo apt-get install -y"
)

install_command() {
    local command_name="$1"
    if ! command_exists "$command_name"; then
        echo "Installing $command_name..."
        for pm in "${!package_install_commands[@]}"; do
            if command_exists "$pm"; then
                ${package_install_commands[$pm]} "$command_name"
                return
            fi
        done
        echo "Package manager not supported or $command_name cannot be installed."
        exit 1
    fi
}

extract_data() {
    local tool="$1"
    shift
    local args=("$@")

    echo "Attempting data extraction with $tool..."
    if "$tool" "${args[@]}"; then
        echo "Data extracted successfully using $tool."
        return 0
    else
        echo "Data extraction with $tool failed."
        return 1
    fi
}

main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: $0 <image_file> [password] [wordlist.txt]"
        exit 0
    fi

    if [ $# -lt 1 ]; then
        echo "Error: Image file not specified."
        echo "Usage: $0 <image_file> [password] [wordlist.txt]"
        exit 1
    fi

    local image_file="$1"
    local password="$2"
    local wordlist_file="$3"

    install_command "steghide"
    install_command "outguess"
    install_command "stegseek"
    install_command "binwalk"

    if [ -n "$password" ]; then
        extract_data steghide -sf "$image_file" -p "$password" || extract_data outguess -k "$password" -r "$image_file" output.txt
    else
        extract_data outguess -r "$image_file" output.txt
    fi

    if [ "${image_file##*.}" == "jpg" ] && [ -n "$wordlist_file" ]; then
        extract_data stegseek "$image_file" "$wordlist_file"
    fi

    extract_data binwalk --run-as=root --extract --matryoshka --directory=tmp_binwalk_extraction "$image_file"
    
    read -p "Do you want to remove the temporary extraction directory (tmp_binwalk_extraction)? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf tmp_binwalk_extraction
        echo "Temporary directory removed."
    fi
}

main "$@"
