using CSV
using DataFrames

# Leer los archivos CSV en DataFrames
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba)/inputs/variable_capacity_factors.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba)/inputs/gen_build_predetermined.csv", DataFrame)

# Obtener los valores únicos de GENERATION_PROJECT en df2
gen_projects_df2 = unique(df2.GENERATION_PROJECT)

# Filtrar filas que cumplan con las condiciones:
# 1. Generación con "FV_" en "GENERATION_PROJECT" y "2024" en "timepoint"
# 2. Generación con "Eolica_" en "GENERATION_PROJECT" y "2024" en "timepoint"
# 3. GENERATION_PROJECT no esté contenido en los valores de GENERATION_PROJECT en df2

df_filtrado = filter(row -> !((!(row.GENERATION_PROJECT in gen_projects_df2) && startswith(string(row.timepoint), "2024"))), df)

# Guardar el DataFrame filtrado en un nuevo archivo CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/EEN + EEC + (Transición aceleradaprueba)/inputs/variable_capacity_factors2.csv", df_filtrado)