#!/bin/bash

# Input file
input_file=$1
meta=$2
headers=$3


# Temporary variable to store the current sequence
current_seq=""
used_headers=""
# Read the input file line by line

for header in $headers; do

    header_mod="${header// /_}"
    header_mod="${header_mod//-/}"
    header_mod="${header_mod//\,/}"
    header_mod="${header_mod//\//}"

    filename="$(echo "$header_mod" | tr -d '[:space:]').fa"
    filename="${filename//>/}"

    awk -v id="$header" -v RS='>' '$1 == id {print ">"$0}' $input_file > $filename

done

