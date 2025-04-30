import pandas as pd
import matplotlib.pyplot as plt
import os

base_input_dir = os.path.join(os.getcwd(), "sen_model")

noisy_file = os.path.join(base_input_dir, "inputs_opp/loads_modified.csv")

# Step 1: Load the CSV file
data = pd.read_csv(noisy_file)

# Step 2: Group by datetime and calculate the sum of noisy values
data['TIMEPOINT'] = pd.to_datetime(data['TIMEPOINT'], format='%Y%m%d%H')  # Ensure datetime is in proper format
data['year'] = data['TIMEPOINT'].dt.year
grouped_data_original = data.groupby(['TIMEPOINT', 'year'])['zone_demand_mw'].sum().reset_index()
grouped_data_noisy = data.groupby(['TIMEPOINT', 'year'])['value_with_noise'].sum().reset_index()

unique_years = data['year'].unique()

for year in unique_years:
    yearly_data_original = grouped_data_original[grouped_data_original['year'] == year]
    yearly_data_noisy = grouped_data_noisy[grouped_data_noisy['year'] == year]
    
    plt.figure(figsize=(10, 6))
    plt.plot(yearly_data_original['TIMEPOINT'], yearly_data_original['zone_demand_mw'], color='b', label='Demanda real')
    plt.plot(yearly_data_noisy['TIMEPOINT'], yearly_data_noisy['value_with_noise'], color='r', label='Demanda pronóstico')
    plt.title(f'Demanda real vs pronóstico {year}')
    plt.xlabel('Fecha')
    plt.ylabel('Demanda')
    plt.grid(True)
    plt.tight_layout()
    plt.show()
# Step 3: Plot the sum of noisy values over time
# plt.figure(figsize=(10, 6))
# plt.scatter(grouped_data_original['TIMEPOINT'], grouped_data_original['zone_demand_mw'], color='b', label='Demanda real')
# plt.scatter(grouped_data_noisy['TIMEPOINT'], grouped_data_noisy['value_with_noise'], color='r', label='Demanda pronóstico')
# plt.title('Demanda real vs pronóstico')
# plt.xlabel('Fecha')
# plt.ylabel('Demanda')
# plt.grid(True)
# plt.legend()
# plt.tight_layout()
# plt.show()