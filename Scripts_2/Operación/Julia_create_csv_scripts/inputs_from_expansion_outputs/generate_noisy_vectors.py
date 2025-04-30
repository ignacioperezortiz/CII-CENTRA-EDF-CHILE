import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os
import sys
# parent_dir = os.path.abspath(os.getcwd())
# sys.path.append(parent_dir)
# from Julia_create_csv_scripts import global_vars

list_of_periods = [2024,2026,2029,2030,2031,2033,2040,2050]

daily = True
if daily == True:
    max_period_index = 365
else:
    max_period_index = 52

base_input_dir = os.path.join(os.getcwd(), "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CasoBase_N/CN/")

print("Armando los vectores con ruido de demanda")
for period in list_of_periods:
    print(f"CURRENTLY RUNNING PERIOD: {period}")
    # Automation process
    scenario_inputs = [f"inputs_{period}/{week}" for week in range(0, max_period_index)]
    for week_scenario in scenario_inputs:
        print(f"CURRENTLY RUNNING WEEK INDEX: {week_scenario}")
        # Se lee el dataframe de demandas
        temp_df = pd.read_csv(os.path.join(base_input_dir, week_scenario, "inputs_dispatch", "loads.csv"))
        # Se genera el vector de ruido a agregar a la demanda "real"
        noise = np.random.normal(loc=-0.0543, scale=0.0322, size=len(temp_df))
        temp_df['zone_demand_mw'] = temp_df['zone_demand_mw'] * (1+noise)
        # Se guarda el documento con el ruido aplicado
        temp_df.to_csv(os.path.join(base_input_dir, week_scenario, "inputs_unit_commitment", "loads.csv"), index=False)


print("Armando los vectores con ruido de generacion renovable")
for period in list_of_periods:
    print(f"CURRENTLY RUNNING PERIOD: {period}")
    # Automation process
    scenario_inputs = [f"inputs_{period}/{week}" for week in range(0, max_period_index)]
    for week_scenario in scenario_inputs:
        print(f"CURRENTLY RUNNING WEEK INDEX: {week_scenario}")
        # Se lee el dataframe de demandas
        gen_info_df = pd.read_csv(os.path.join(base_input_dir, week_scenario, "inputs_dispatch", "gen_info.csv"))
        temp_df = pd.read_csv(os.path.join(base_input_dir, week_scenario, "inputs_dispatch", "variable_capacity_factors.csv"))
        # Factor de planta junto a la tecnologia correspondiente
        variable_capacity_technology_df = pd.merge(temp_df, gen_info_df[["GENERATION_PROJECT", "gen_tech"]], on="GENERATION_PROJECT")
        # Se obtiene un dataframe correspondiente por tecnología
        variable_capacity_technology_solar_df = variable_capacity_technology_df[variable_capacity_technology_df["gen_tech"]=="PV"][["GENERATION_PROJECT","timepoint","gen_max_capacity_factor"]]
        variable_capacity_technology_wind_df = variable_capacity_technology_df[variable_capacity_technology_df["gen_tech"]=="WIND"][["GENERATION_PROJECT","timepoint","gen_max_capacity_factor"]]
        variable_capacity_technology_hydro_df = variable_capacity_technology_df[variable_capacity_technology_df["gen_tech"]=="HYDRO"][["GENERATION_PROJECT","timepoint","gen_max_capacity_factor"]]
        # Se genera el vector de ruido a agregar a la demanda "real"
        noise_solar = np.random.normal(loc=0.0105, scale=0.0897, size=len(variable_capacity_technology_solar_df))
        noise_wind = np.random.normal(loc=-0.0219, scale=0.1042, size=len(variable_capacity_technology_wind_df))
        noise_hydro = np.random.normal(loc=0.0157, scale=0.0862, size=len(variable_capacity_technology_hydro_df))
        # Se generan los vectores con error para cada dataframe
        variable_capacity_technology_solar_df['gen_max_capacity_factor'] = variable_capacity_technology_solar_df['gen_max_capacity_factor'] * (1+noise_solar)
        variable_capacity_technology_wind_df['gen_max_capacity_factor'] = variable_capacity_technology_wind_df['gen_max_capacity_factor'] * (1+noise_wind)
        variable_capacity_technology_hydro_df['gen_max_capacity_factor'] = variable_capacity_technology_hydro_df['gen_max_capacity_factor'] * (1+noise_hydro)
        # Se genera el dataframe consolidado
        noisy_variable_capacity_df = pd.concat([variable_capacity_technology_solar_df, variable_capacity_technology_wind_df, variable_capacity_technology_hydro_df], ignore_index=True)
        # Se guarda el documento con el ruido aplicado
        noisy_variable_capacity_df.to_csv(os.path.join(base_input_dir, week_scenario, "inputs_unit_commitment", "variable_capacity_factors.csv"), index=False)

# consolidated_data['TIMEPOINT'] = pd.to_datetime(consolidated_data['TIMEPOINT'], format='%Y%m%d%H')
# consolidated_data['year'] = consolidated_data['TIMEPOINT'].dt.year
# # Step 1: Load the CSV file
# # input_file = os.path.join(base_input_dir, "inputs_opp/loads.csv")
# # output_file = os.path.join(base_input_dir, "inputs_opp/loads_modified.csv")
# # data = pd.read_csv(input_file)

# # Step 2: Generate white noise
# # Assuming 'value' is the column to modify, and 'zone' and 'datetime' are identifiers
# # np.random.seed(42)  # Set a seed for reproducibility
# noise = np.random.normal(loc=-0.0543, scale=0.0322, size=len(consolidated_data))  # Mean=1, Std Dev=2

# # Step 3: Add noise to the 'value' column
# # consolidated_data['noise_value'] = noise
# consolidated_data['value_with_noise'] = consolidated_data['zone_demand_mw'] * (1+noise)

# grouped_data = consolidated_data.groupby(['TIMEPOINT', 'year'])[['zone_demand_mw', 'value_with_noise']].sum().reset_index()

# unique_years = consolidated_data['year'].unique()

# for year in unique_years:
#     yearly_data = grouped_data[grouped_data['year'] == year]
    
#     plt.figure(figsize=(10, 6))
#     plt.plot(yearly_data['TIMEPOINT'], yearly_data['zone_demand_mw'], label='Demanda original', color='blue')
#     plt.plot(yearly_data['TIMEPOINT'], yearly_data['value_with_noise'], label='Demanda pronosticada', color='orange')
#     plt.title(f'Demanda real vs pronóstico {year}')
#     plt.xlabel('Fecha')
#     plt.ylabel('Demanda')
#     plt.grid(True)
#     plt.tight_layout()
#     plt.show()

# Step 4: Save the modified DataFrame to a new CSV file
# data.to_csv(output_file, index=False)

# print(f"Modified file saved as {output_file}")


