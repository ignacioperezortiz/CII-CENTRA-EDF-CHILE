# Script for changing GNL fuel costs.

using CSV
using DataFrames

df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Sensibilidades_SinLDES/Costos_GNL_A5/RL/inputs/fuel_supply_curves.csv", DataFrame)

df.unit_cost = df.unit_cost.*1.05
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Sensibilidades_SinLDES/Costos_GNL_A5/RL/inputs/fuel_supply_curves.csv", df)