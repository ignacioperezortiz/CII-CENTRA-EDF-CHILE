import os
import subprocess
import sys
# parent_dir = os.path.abspath(os.getcwd())
# sys.path.append(parent_dir)
# from Julia_create_csv_scripts import global_vars

# Construct the path to the input directory
base_input_dir = os.path.join(os.getcwd(), "escenarios/CasoBase/RL/")
base_python_scripts_dir = os.path.join(os.getcwd(), "Julia_create_csv_scripts/run_scenario_multi_year")

# base_input_dir = "sen_model"
output_dir = "outputs"
script_to_process_outputs = "process_outputs.py"  # Your custom script for preparing inputs

# list_of_periods = [2030,2031,2033,2040,2050]
# list_of_periods = [2029,2030,2031,2033,2040,2050]
list_of_periods = [2029]
# list_of_periods = [2031,2033,]
starting_week_index = 0

daily = True
if daily == True:
    max_period_index = 365
else:
    max_period_index = 52


# Function to run the Switch Planning Model
def run_switch_model(input_folder, output_folder, base_model_dir):
    command = ["switch", "solve", "--full-traceback","--inputs-dir", input_folder, "--outputs-dir", output_folder]
    result = subprocess.run(command, cwd=base_model_dir, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error in solving scenario: {result.stderr}")
        with open(os.path.join(base_model_dir, output_folder, "solver_result.txt"), "w") as result_file:
            result_file.write(result.stderr)
    else:
        print(f"Scenario solved successfully")
        # print(f"Scenario solved successfully: {result.stdout}")
        with open(os.path.join(base_model_dir, output_folder, "solver_result.txt"), "w") as result_file:
            result_file.write(result.stdout)

for period in list_of_periods:
    print(f"CURRENTLY RUNNING PERIOD: {period}")
    if period != list_of_periods[0]:
        starting_week_index = 0
    print(f"Iniciando en el indice: {starting_week_index}")
    # Automation process
    scenario_inputs = [f"inputs_{period}/{week}" for week in range(starting_week_index, max_period_index)]
    for i, scenario in enumerate(scenario_inputs):
        print(f"CURRENTLY RUNNING WEEK: {scenario}")
        #RUN UC model
        input_path_uc = os.path.join(scenario, f"inputs_unit_commitment")
        output_path_uc = os.path.join(scenario, f"outputs_unit_commitment")
        #Solo desde segunda semana
        if i >= 1 or period != list_of_periods[0]:
            print(f"Traspassing state of charge to UC")
            #Pass 24th hour state of charge as initial state for next unit commitment
            command = ["python", "pass_dispatch_exit_status_to_next_week_UC.py", "--base_input_dir", base_input_dir, "--previous_week_outputs_folder", output_path_dispatch, "--current_week_inputs_folder", scenario]
            result = subprocess.run(command, cwd=base_python_scripts_dir, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"Error in solving scenario: {result.stderr}")
            else:
                print(f"Scenario solved successfully: {result.stdout}")
        
        print(f"Running UC")
        run_switch_model(input_path_uc, output_path_uc, base_input_dir)

        #Pass unit commitment as inputs of dispatch
        print(f"Passing UC state to dispatch")
        input_path_dispatch = os.path.join(scenario, f"inputs_dispatch")
        output_path_dispatch = os.path.join(scenario, f"outputs_dispatch")
        command = ["python", "pass_unit_commitment_to_week_dispatch.py", "--base_input_dir", base_input_dir, "--current_week_folder", str(i), "--current_week_uc_output_file_path", output_path_uc, "--current_week_dispatch_input_path", input_path_dispatch]
        result = subprocess.run(command, cwd=base_python_scripts_dir, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error in solving scenario: {result.stderr}")
        else:
            print(f"Scenario solved successfully: {result.stdout}")
        #RUN Dispatch model
        
        print(f"Running Dispatch")
        run_switch_model(input_path_dispatch, output_path_dispatch, base_input_dir)