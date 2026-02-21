import json
import glob
import re

# Define the folder path containing the JPG files
folder_path = "/Users/manuel/Workspace/git/HPI/AMLS/ACNE04/Classification/filtered/small_1024"

# Define the base prompt
base_prompt = "photo of a person with acne"

# List all jpg files in the folder
jpg_files = glob.glob(f"{folder_path}/*.jpg")

# Open the output file in write mode
output_file_path = folder_path+"/metadata.jsonl"
with open(output_file_path, 'w') as file:
    # Iterate over each jpg file found
    for jpg_file in jpg_files:
        # Extract the filename from the path
        filename = jpg_file.split('/')[-1]
        # Use regex to find the level number in the filename
        match = re.search(r'levle(\d+)_', filename)
        if match:
            # Extract the level number
            level = match.group(1)
            # Construct the prompt based on the level
            prompt = f"{base_prompt}{level}"
            # Create a dictionary for the current entry
            entry = {"file_name": filename, "prompt": prompt}
            # Write the entry to the file in JSONL format
            file.write(json.dumps(entry) + '\n')

print(f"JSONL file created at: {output_file_path}")