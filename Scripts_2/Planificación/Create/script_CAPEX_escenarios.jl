using CSV
using DataFrames

tec = "CAES"
scenario = "Bajo"

# Lee el archivo CSV (cambia 'tu_archivo.csv' por el nombre de tu archivo)
df = CSV.File("C:/Users/sandr/OneDrive/Documentos/Pasantía_CENTRA/Switch/SEN_PELP/Base de Datos PELP 2023-2027 Informe Preliminar_v2/Acelerando la Transición Energética/Input/Acelerando la Transición Energética_gen_inv_cost/gen_inv_cost.csv") |> DataFrame
df.time = string.(df.time)
# Filtra el DataFrame para seleccionar solo los escenarios "Bajo"
filtered_df = df[df.scenario .== "$scenario", :]

# Define los años de interés
years_of_interest = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

# Convierte los años a strings para realizar la comparación
years_of_interest_str = string.(years_of_interest)

# Crea un vector para almacenar los valores de "CAES_Pichirropulli500_4h"
values_vector = []

# Llena el vector con los valores de la columna "CAES_Pichirropulli500_4h" basados en el tiempo
for year_str in years_of_interest_str
    # Verifica si los primeros 4 caracteres de "Time" son equivalentes al año
    filtered_df2 = filter(row -> occursin("$year_str", string(row.time)), filtered_df)
    println(filtered_df2.time)
    push!(values_vector, filtered_df2[!,:CAES_Pichirropulli500_4h]...)
end

# Imprimir el vector resultante
println("Valores de CAES_Pichirropulli500_4h para los años dados: ", values_vector)
vector_proyeccion = []
for i in 1:length(values_vector)
    push!(vector_proyeccion, values_vector[i]/values_vector[1])
end
println(vector_proyeccion)

#ingresar acá valor de CAPEX de la tecnología al 2024
valor_CAPEX = 2000 #valor Ref
vector_proyeccion_CAPEX = vector_proyeccion*valor_CAPEX
vector_proyeccion_CAPEX_df = DataFrame(proyeccion_CAPEX = vector_proyeccion_CAPEX)
CSV.write("C:/Users/sandr/OneDrive/Documentos/Pasantía_CENTRA/Switch/SEN_PELP/Reference_NDC/CAPEX_$tec$scenario.csv", vector_proyeccion_CAPEX_df)