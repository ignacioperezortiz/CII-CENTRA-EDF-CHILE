import os
import pandas as pd
import argparse

# Step 1: Set up argument parsing
parser = argparse.ArgumentParser(description="Obtain the outputs of previous week and pass them as inputs for next week.")
parser.add_argument("--base_input_dir", required=True, help="Path base to current model")
parser.add_argument("--previous_week_outputs_folder", required=True, help="Path to the folder containing the input CSV file")
parser.add_argument("--current_week_inputs_folder", required=True, help="Path to the folder to save the modified CSV file")
args = parser.parse_args()

base_columns = ["GENERATION_PROJECT", "timepoint", "state_of_charge"]

#Se deben leer los archivos de TES, TES-CSP y storage_dispatch 
# Step 2: Construct paths
previous_week_outputs_path = os.path.join(args.base_input_dir, args.previous_week_outputs_folder)
current_week_inputs_path = os.path.join(args.base_input_dir, args.current_week_inputs_folder)

tes_state_of_charge_file_path = os.path.join(previous_week_outputs_path, "TES_StateOfCharge.csv")
tescsp_state_of_charge_file_path = os.path.join(previous_week_outputs_path, "TESCSP_StateOfCharge.csv")
store_state_of_charge_file_path = os.path.join(previous_week_outputs_path, "StateOfCharge.csv")

gen_info_current_week_file_path_uc = os.path.join(current_week_inputs_path, "inputs_unit_commitment/gen_info.csv")
gen_info_current_week_file_path_dispatch = os.path.join(current_week_inputs_path, "inputs_dispatch/gen_info.csv")

# Step 3: Read the CSV files
try:
    data_tes = pd.read_csv(tes_state_of_charge_file_path)
    data_tes.columns = base_columns
except FileNotFoundError:
    data_tes = pd.DataFrame(columns=base_columns)
try:
    data_csp = pd.read_csv(tescsp_state_of_charge_file_path)
    data_csp.columns = base_columns
except FileNotFoundError:
    data_csp = pd.DataFrame(columns=base_columns)
try:
    data_store = pd.read_csv(store_state_of_charge_file_path)
    data_store.columns = base_columns
except FileNotFoundError:
    data_store = pd.DataFrame(columns=base_columns)

#STORE
data_store['timepoint'] = pd.to_datetime(data_store['timepoint'], format='%Y%m%d%H')

# Filter rows where the hour ends with 00
data_store = data_store[data_store['timepoint'].dt.hour == 23]

sorted_df = data_store.sort_values(by=['GENERATION_PROJECT', 'timepoint'])

second_timepoint_df = sorted_df.groupby('GENERATION_PROJECT').nth(0)

store_state_charge_dict = second_timepoint_df.set_index(['GENERATION_PROJECT'])['state_of_charge'].to_dict()

#TES
data_tes['timepoint'] = pd.to_datetime(data_tes['timepoint'], format='%Y%m%d%H')

# Filter rows where the hour ends with 00
data_tes = data_tes[data_tes['timepoint'].dt.hour == 23]

sorted_df = data_tes.sort_values(by=['GENERATION_PROJECT', 'timepoint'])

second_timepoint_df = sorted_df.groupby('GENERATION_PROJECT').nth(0)

tes_store_state_charge_dict = second_timepoint_df.set_index(['GENERATION_PROJECT'])['state_of_charge'].to_dict()

#CSP
data_csp['timepoint'] = pd.to_datetime(data_csp['timepoint'], format='%Y%m%d%H')

# Filter rows where the hour ends with 00
data_csp = data_csp[data_csp['timepoint'].dt.hour == 23]

sorted_df = data_csp.sort_values(by=['GENERATION_PROJECT', 'timepoint'])

second_timepoint_df = sorted_df.groupby('GENERATION_PROJECT').nth(0)

csp_store_state_charge_dict = second_timepoint_df.set_index(['GENERATION_PROJECT'])['state_of_charge'].to_dict()

# Limit the values to a minimum of 0
store_state_charge_dict = {key: max(0, value) for key, value in store_state_charge_dict.items()}
tes_store_state_charge_dict = {key: max(0, value) for key, value in tes_store_state_charge_dict.items()}
csp_store_state_charge_dict = {key: max(0, value) for key, value in csp_store_state_charge_dict.items()}

# Step 4: Modify the DataFrame (example: add a new column)
data_gen_info = pd.read_csv(gen_info_current_week_file_path_uc)

data_gen_info['storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(store_state_charge_dict).fillna(".")
data_gen_info['tes_storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(tes_store_state_charge_dict).fillna(".")
data_gen_info['csp_storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(csp_store_state_charge_dict).fillna(".")

# Step 5: Save the modified data to the output folder
data_gen_info.to_csv(os.path.join(current_week_inputs_path, "inputs_unit_commitment/gen_info.csv"), index=False)

data_gen_info = pd.read_csv(gen_info_current_week_file_path_dispatch)

data_gen_info['storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(store_state_charge_dict).fillna(".")
data_gen_info['tes_storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(tes_store_state_charge_dict).fillna(".")
data_gen_info['csp_storage_initial_charge_state'] = data_gen_info['GENERATION_PROJECT'].map(csp_store_state_charge_dict).fillna(".")

data_gen_info.to_csv(os.path.join(current_week_inputs_path, "inputs_dispatch/gen_info.csv"), index=False)
print(f"Modified file saved to: {current_week_inputs_path}")
