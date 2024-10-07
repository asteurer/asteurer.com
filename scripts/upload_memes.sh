#!/bin/bash

# Thanks ChatGPT

# Set the directory to the first argument, or use the current directory if not provided
DIR="${1:-.}"
PASSWORD=$(op item get auth_memes_client --vault asteurer.com_apps --fields label=password --reveal)
USERNAME=$(op item get auth_memes_client --vault asteurer.com_apps --fields label=username --reveal)

# Check if the specified directory exists and is indeed a directory
if [[ ! -d "$DIR" ]]; then
    echo "Error: '$DIR' is not a directory or does not exist."
    exit 1
fi

# Loop through all items in the directory
# The nullglob option ensures that the loop doesn't execute if no files match
shopt -s nullglob
for file in "$DIR"/*; do
    # Check if it's a regular file (not a directory or other type)
    if [[ -f "$file" ]]; then
        # Extract the base filename without the directory path
        filename="$(basename -- "$file")"
        IMG_TYPE="n/a"
        # Convert the filename to lowercase to make the check case-insensitive
        filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

        # Check if the filename contains .png or .jpg
        if [[ "$filename_lower" == *".png"* ]]; then
            IMG_TYPE="image/png"
        elif [[ "$filename_lower" == *".jpg"* ]]; then
            IMG_TYPE="image/jpeg"
        else
            continue
        fi

        curl \
            --request PUT \
            -H "content-type: $IMG_TYPE" \
            --data-binary @"$file" \
            https://$USERNAME:$PASSWORD@asteurer.com/memes-api/
    fi
done
shopt -u nullglob  # Disable nullglob to return to default behavior

exit 0
