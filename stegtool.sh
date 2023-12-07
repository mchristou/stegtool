#!/bin/bash

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

install_command() {
	local command_name="$1"
	if ! command_exists "$command_name"; then
		echo "Installing $command_name..."
		if [[ "$command_name" == "steghide" ]]; then
			sudo apt-get install steghide
		elif [[ "$command_name" == "outguess" ]]; then
			sudo apt-get install outguess
		elif [[ "$command_name" == "stegseek" ]]; then
			sudo apt-get install stegseek
		else
			echo "Unsupported tool: $command_name"
			exit 1
		fi
	fi
}

extract_data_with_steghide() {
	local image_file="$1"
	local password="$2"

	steghide extract -sf "$image_file" -p "$password"
	if [ $? -eq 0 ]; then
		echo "Data extracted successfully using steghide."
		return 0
	else
		echo "Data extraction using steghide with the provided password unsuccessful. Trying outguess..."
		extract_data_with_outguess "$image_file" "$password"
		return $?
	fi
}

extract_data_with_outguess() {
	local image_file="$1"
	local password="$2"

	if [ -n "$password" ]; then
		outguess -k "$password" -r "$image_file"
	else
		outguess -r "$image_file"
	fi

	if [ $? -eq 0 ]; then
		echo "Data extracted successfully using outguess."
		return 0
	else
		if [ -n "$password" ]; then
			echo "Data extraction using outguess with the provided password also unsuccessful."
		fi
		return 1
	fi
}

extract_data_with_stegseek() {
	local image_file="$1"
	local wordlist_file="$2"

	if [ "${image_file##*.}" == "jpg" ] && [ -n "$wordlist_file" ]; then
		stegseek "$image_file" "$wordlist_file"
	else
		echo "Wordlist not provided or image is not a jpg. Skipping stegseek."
		return 1
	fi

	if [ $? -eq 0 ]; then
		echo "Data extracted successfully using stegseek."
		return 0
	else
		echo "Data extraction using stegseek unsuccessful."
		return 1
	fi
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	echo "Usage: $0 <image_file> [password] [wordlist.txt]"
	exit 0
fi

if [ $# -lt 1 ]; then
	echo "Usage: $0 <image_file> [password] [wordlist.txt]"
	exit 1
fi

image_file="$1"
password="$2"
wordlist_file="$3"

install_command "steghide"
install_command "stegseek"

if [ -n "$password" ]; then
	echo "Extracting data using steghide..."
	extract_data_with_steghide "$image_file" "$password"
	if [ $? -ne 0 ]; then
		echo "Data extraction using steghide unsuccessful."
	fi
else
	echo "Password not provided. Trying outguess..."
	install_command "outguess"

	extract_data_with_outguess "$image_file" "$password"
	if [ $? -ne 0 ]; then
		echo "Data extraction using outguess unsuccessful."
	fi
fi

echo "Trying stegseek..."
extract_data_with_stegseek "$image_file" "$wordlist_file"
if [ $? -ne 0 ]; then
	echo "Data extraction using stegseek unsuccessful."
fi
