# Data Preparation:

# Download the SCUT-FBP5500 dataset.
# Run python research/process_data.py to filter for the Caucasian subset and calculate average scores.
# This generates the clean_caucasian_averages.csv used for training.

#Note: This script only gathers ratings for caucasian people from the SCUT-FBP5500 which are around 1500 in total
#If you want to include asian or only asian change this line: startswith('C') to include only A or A too

import pandas as pd

# 1. Load the file
# Replace with your actual file path
file_path = "All_Ratings.xlsx" 
print("Loading Excel file... this might take a second.")
df = pd.read_excel(file_path)

# 2. Filter for Caucasian Only
# We look for filenames starting with 'CF' (Female) or 'CM' (Male)
# str.startswith('C') catches both.
caucasian_df = df[df['Filename'].str.startswith('C')].copy()

print(f"Filtered down to {len(caucasian_df)} raw votes for Caucasians.")

# 3. Calculate the Average (The Magic Step)
# This converts the integers (1, 2, 3...) into decimals (3.45, 4.12...)
grouped_df = caucasian_df.groupby('Filename')['Rating'].mean().reset_index()

# 4. Rename columns for clarity
grouped_df.columns = ['filename', 'average_score']

print(f"Final dataset has {len(grouped_df)} unique images.")
print(grouped_df.head()) # Verify you see decimals now!

# 5. Save this clean version
# Now you have a simple CSV with "image.jpg, 3.45"
grouped_df.to_csv("clean_caucasian_averages.csv", index=False)
print("Saved to clean_caucasian_averages.csv")