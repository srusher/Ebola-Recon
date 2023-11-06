#!/bin/bash

# Input file
input_file=$1
meta=$2
headers=$3


# Temporary variable to store the current sequence
current_seq=""
used_headers=""
# Read the input file line by line
while IFS= read -r line; do

    if [[ $line == ">"* ]]; then
        # If the line starts with ">", it's a sequence header
        # Create a new split file with the sequence header as the filename
        line="${line// /_}"
        line="${line//-/}"
        line="${line//\,/}"
        line="${line//\//}"

        filename="$(echo "$line" | tr -d '[:space:]').fa"
        filename="${filename//>/}"

        for i in $headers; do

            result=$(echo "$filename" | grep "$i")
            
            if [ ! -z "$result" ]; then

                if [ ! -z $(echo $used_headers | grep "$filename") ]; then
                    dup_header="true"
                else
                    dup_header="false"
                fi

                if [[ $dup_header == "false" ]]; then

                    filename="$meta"_$filename
                    >$filename
                    echo $line >> $filename
                    used_headers="$used_headers "$line

                fi

            fi
        
        done
        
    else

        for i in $headers; do
            
            result=$(echo "$filename" | grep "$i")

            if [ ! -z "$result" ]; then

                if [[ $dup_header == "false" ]]; then
                
                    current_seq="$line"
                    echo $current_seq >> $filename
                    break

                fi

            fi

        done        

    fi
done < "$input_file"

