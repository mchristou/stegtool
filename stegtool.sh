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
    else
      echo "Unsupported tool: $command_name"
      exit 1
    fi
  fi
}

extract_data_with_steghide() {
  local image_file="$1"
  local password="$2"
  local extracted_file="output.txt"

  steghide extract -sf "$image_file" -p "$password" -xf "$extracted_file"
  if [ $? -eq 0 ]; then
    echo "Data extracted successfully using steghide."
    echo "The extracted data is located in: $extracted_file"
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
  local extracted_file="output.txt"

  if [ -n "$password" ]; then
    outguess -k "$password" -r "$image_file" "$extracted_file"
  else
    outguess -r "$image_file" "$extracted_file"
  fi

  if [ $? -eq 0 ]; then
    echo "Data extracted successfully using outguess."
    echo "The extracted data is located in: $extracted_file"
    return 0
  else
    if [ -n "$password" ]; then
      echo "Data extraction using outguess with the provided password also unsuccessful."
    fi
    return 1
  fi
}

if [ $# -lt 1 ]; then
  echo "Usage: $0 <image_file> [password]"
  exit 1
fi

image_file="$1"
password="$2"

install_command "steghide"

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

