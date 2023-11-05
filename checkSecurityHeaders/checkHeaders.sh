#!/bin/bash

# Get command line arguments
domain_file=$1
headers_file=$2

# Output file
output_file="output.md"


# Initialize empty arrays for headers and expected_values
declare -a headers
declare -a expected_values

# Read the headers and expected values from the headers file
while IFS=',' read -r header expected_value; do
    headers+=("$header")
    expected_values+=("$expected_value")
done < "$headers_file"

# Number of headers to check
header_count=${#headers[@]}

# Start the output file with the headers
header_row="| Domain "
header_divider="| --- "
for (( i=0; i<$header_count; i++ )); do
    header_row+="| ${headers[$i]} "
    header_divider+="| --- "
done
echo -e "$header_row|" > $output_file
echo -e "$header_divider|" >> $output_file

# Iterate over each domain
while read -r domain; do
  # Store the result for each domain
  result="| $domain "

  # Check for timeout first with curl command
  timeout_check=$(curl -sI -m 5 "https://$domain" > /dev/null || echo "Timeout")

  if [[ $timeout_check == "Timeout" ]]; then
    # If timeout occurs, print Timeout for all headers
    for (( i=0; i<$header_count; i++ )); do
        result+="| Timeout "
    done
  else
    # Iterate over each header
    echo $domain
    for (( i=0; i<$header_count; i++ )); do
      # Fetch the headers from the domain and grep for the header
      # ^[Hh] tells grep to match the start of the line with either a capital H or a lowercase h
      # This way, grep will only match lines that start with the exact header name
      header_value=$(curl -sI "https://$domain" | grep -i "^${headers[$i]}:")

      # Remove newline characters and trim leading/trailing white space
      header_value=$(echo "${header_value#*:}" | tr -d '\n\r' | xargs)
      echo "${headers[$i]} -> $header_value"

      # Check if the header is found and if the value matches the expected value
      if [[ "${expected_values[$i]}" == "ANY" && -n "$header_value" ]]; then
        # Add a check mark to the result - ANY -> the header is present with any value
        result+="| ✓ Any "
      elif [[ "${expected_values[$i]}" == "NONE" && -z "$header_value" ]]; then
        # Add a check mark to the result
        result+="| ✓ Absent"
      elif [[ "${expected_values[$i]}" == "NONE" && -n "$header_value" ]]; then
        # Add the actual value of the header to the result
        result+="| $header_value "
      elif [[ -n "$header_value" && "$header_value" == *"${expected_values[$i]}"* ]]; then
        # Add a check mark to the result
        result+="| ✓ "
      elif [ -n "$header_value" ]; then
        # Add an 'x' to the result
        result+="| x "
      else
        # Add a "Not found" to the result
        result+="| Not found "
      fi
    done
  fi
  # Write the result to the output file
  echo -e "$result|" >> $output_file

done < "$domain_file"
