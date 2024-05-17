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
    else
        echo "Data extraction with $tool failed."
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
    local output_dir="${image_file%.*}_results"
    echo $output_dir

    mkdir $output_dir
    cp $image_file $output_dir
    cd $output_dir

    install_command "steghide"
    install_command "outguess"
    install_command "stegseek"
    install_command "binwalk"
    install_command "exiftool"

    exiftool $image_file >> exiftool.output
    strings -n 6 $image_file >> strings.output
    file $image_file >> file.output

    if [ -n "$password" ]; then
        extract_data steghide extract -sf "$image_file" -p "$password"
       	extract_data outguess -k "$password" -r "$image_file" outguess.output
    else
        extract_data outguess -r "$image_file" output.txt
    fi

    if [ "${image_file##*.}" == "jpg" ]; then 
	    if [ -n "$wordlist_file" ]; then
        	extract_data stegseek "$image_file" "$wordlist_file"
    	    else
	        local rockyou_path=$(find / -name "rockyou.txt" 2>/dev/null -print -quit)
        	extract_data stegseek "$image_file" "$rockyou_path"
	    fi
    fi

    extract_data binwalk --run-as=root --extract --matryoshka --directory=tmp_binwalk_extraction "$image_file"
}

main "$@"
