using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf
using Statistics

# Cargar el archivo CSV en un DataFrame
df = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase1/TA/variable_capacity_factors_sin_cuatridias.csv", DataFrame)

# Mostrar el número de filas antes del filtrado
println("Número de filas antes del filtrado: $(nrow(df))")

# Filtrar el DataFrame para eliminar las filas donde "timepoint" contiene "2020"
df.timepoint = string.(df.timepoint)
df = filter(row -> !occursin("2020", row.timepoint), df)

# Reemplazar "2023" con "2024" al inicio de los strings en la columna "timepoint"
for row in eachrow(df)
    if startswith(row.timepoint, "2023")
        row.timepoint = replace(row.timepoint, "2023" => "2024"; count=1)
    end
end

# Mostrar el número de filas después del filtrado
println("Número de filas después del filtrado: $(nrow(df))")

# Guardar el DataFrame filtrado en un nuevo archivo CSV (opcional)
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase1/TA/variable_capacity_factors_sin_cuatridias.csv", df)

println("Archivo CSV filtrado y guardado exitosamente.")

# Nuevas operaciones para filtrar df basado en df2
df1_original = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase1/TA/variable_capacity_factors_sin_cuatridias.csv", DataFrame) #guardo el df1 original
df1_original.timepoint = string.(df1_original.timepoint)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sinsib/Sensibilidades/OK/Corridos/CasoBase/RL/inputs/variable_capacity_factors.csv", DataFrame)
df2.timepoint = string.(df2.timepoint)

# Función para concatenar las columnas "GENERATION_PROJECT" y "timepoint" como strings
function concatenar_columnas(df::DataFrame)
    return [string(row.GENERATION_PROJECT, row.timepoint) for row in eachrow(df)]
end

# Obtener las combinaciones de columnas "GENERATION_PROJECT" y "timepoint" de df2
combinaciones_df2 = Set(concatenar_columnas(df2)) # Usar un Set para una búsqueda más rápida

# Filtrar las filas de df1_original donde las combinaciones de las columnas "GENERATION_PROJECT" y "timepoint" están en las combinaciones de df2
df1_filtrado = filter(row -> string(row.GENERATION_PROJECT, row.timepoint) in combinaciones_df2, df1_original)

# Guardar el DataFrame filtrado en un nuevo archivo CSV
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase1/TA/variable_capacity_factors_sin_cuatridias.csv", df1_filtrado) #guardo el df1 filtrado

println("Archivo CSV filtrado basado en df2 y guardado exitosamente en C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase1/TA_filtrado.csv.")
