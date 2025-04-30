import os
import pandas as pd
import argparse
# Step 1: Set up argument parsing
parser = argparse.ArgumentParser(description="Obtain the outputs of previous week and pass them as inputs for next week.")
parser.add_argument("--base_input_dir", required=True, help="Path base to current model")
parser.add_argument("--current_week_folder", required=True, help="Path to the folder of the current week")
parser.add_argument("--current_week_uc_output_file_path", required=True, help="Path to output folder containing the optimal UC")
parser.add_argument("--current_week_dispatch_input_path", required=True, help="Path to input folder for dispatch")
args = parser.parse_args()

# Step 2: Construct paths
current_week_output_uc_commit_file_path = os.path.join(args.base_input_dir, args.current_week_uc_output_file_path, "CommitGen.csv")
current_week_output_uc_dispatch_file_path = os.path.join(args.base_input_dir, args.current_week_uc_output_file_path, "StartupGenCapacity.csv")
current_week_inputs_uc_predetermined_commit_file_path = os.path.join(args.base_input_dir, args.current_week_dispatch_input_path, "gen_unit_commitment_predetermined.csv")
current_week_inputs_uc_predetermined_startup_file_path = os.path.join(args.base_input_dir, args.current_week_dispatch_input_path, "gen_unit_start_up_predetermined.csv")

# Step 3: Read the CSV file
try:
    data_commit = pd.read_csv(current_week_output_uc_commit_file_path)
    data_start_up = pd.read_csv(current_week_output_uc_dispatch_file_path)
except FileNotFoundError:
    raise FileNotFoundError(f"The file does not exist!")

# Step 4: Modify the DataFrame
data_commit.rename(columns={'CommitGen': 'unit_commitment_predetermined'}, inplace=True)
data_start_up.rename(columns={'StartupGenCapacity': 'unit_start_up_predetermined'}, inplace=True)

# Step 5: Save the modified data to the output folder
data_commit.to_csv(current_week_inputs_uc_predetermined_commit_file_path, index=False)
data_start_up.to_csv(current_week_inputs_uc_predetermined_startup_file_path, index=False)
print(f"Modified files saved as new inputs")
