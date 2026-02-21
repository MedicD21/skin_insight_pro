import os

# The directory containing the files to be renamed
directory_path = '/Users/manuel/Workspace/git/HPI/AMLS/ACNE04/Classification/filtered/small_1024_renamed'

# Mapping of original substrings to their new values
rename_map = {
    'acne0': 'acnezero',
    'acne1': 'acnesmall',
    'acne2': 'acnemedium',
    'acne3': 'acnestrong'
}

# Iterate over all files in the directory
for filename in os.listdir(directory_path):
    # Check if the file is a JPEG image
    if filename.endswith('.jpg'):
        # For each mapping, check if the substring is in the filename
        for original, new in rename_map.items():
            if original in filename:
                # Construct the new filename
                new_filename = filename.replace(original, new)
                # Construct the full old and new file paths
                old_file_path = os.path.join(directory_path, filename)
                new_file_path = os.path.join(directory_path, new_filename)
                # Rename the file
                os.rename(old_file_path, new_file_path)
                print(f'Renamed "{filename}" to "{new_filename}"')
                break  # Stop checking after the first match

print("Renaming complete.")
