using DataFrames
using CSV

# Crear dos DataFrames de ejemplo
df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_build_costAlto.csv", DataFrame)
df2 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/gen_build_costMedio.csv", DataFrame) # Cambié el último valor para que sean distintos

# Función para comparar dos DataFrames
# Función para comparar dos DataFrames
function comparar_dataframes(df1::DataFrame, df2::DataFrame)
    if size(df1) != size(df2)
        println("Los DataFrames tienen diferentes dimensiones.")
        return
    end

    # Compara cada elemento y almacena las diferencias
    diferencias = DataFrame(row=Int[], col=Int[], valor_df1=Any[], valor_df2=Any[])
    
    for i in 1:size(df1, 1)
        for j in 1:size(df1, 2)
            if df1[i, j] != df2[i, j]
                push!(diferencias, (i, j, df1[i, j], df2[i, j]))
            end
        end
    end

    if isempty(diferencias)
        println("Los DataFrames son iguales.")
    else
        println("Los DataFrames son distintos. Diferencias encontradas:")
        println(diferencias)
    end
end

# Llamar a la función para comparar df1 y df2
comparar_dataframes(df1, df2)

# csv iguales

# pvgen
# thermalgen
# windgen
# power
# max_wind_penetration
# max_pv_penetration
# load
# hydrogenerator
# generator
# fuel
# ess
# cspgen
# busbar
# gen inv costs
# fuel prices
# factors
# demand

# csv distintos
# pmax
# branch
# co2 emission tax
