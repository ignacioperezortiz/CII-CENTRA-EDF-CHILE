# script to change the power output of the solar fields for CSP generators to allow the generation of 4 consectutive days with 
# variation of the renewable resources.

# genera el csv de demanda, debe seleccionarse la GENERATION_P.
using CSV
using DataFrames
using Dates
using Statistics
using Random

df1 = CSV.read("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Inputs_LDES_Preliminar5/inputs/sf_power_output.csv", DataFrame)

# Crear un DataFrame vacío donde iremos concatenando los resultados
all_df = DataFrame()

# Obtener los valores únicos de GENERATION_PROJECT
csp_gens = unique(df.GENERATION_PROJECT)

# Iterar sobre cada GENERATION_PROJECT
for gen in csp_gens
    # Filtrar el DataFrame para este proyecto
    gen_df = filter(row -> row.GENERATION_PROJECT == gen, df1)
    
    # Obtener el valor máximo de csp_sf_power_output_mwt
    max_value = maximum(gen_df.csp_sf_power_output_mwt)
    
    # Normalizar la columna csp_sf_power_output_mwt
    gen_df.csp_sf_power_output_mwt .= gen_df.csp_sf_power_output_mwt ./ max_value
    
    # Concatenar este DataFrame con el DataFrame grande
    append!(all_df, gen_df)
end
println(all_df)
df = all_df

# Función para calcular el promedio de cada bloque de 4 horas (de 0-3, 4-7, ..., 20-23)
function calcular_promedios_4_horas(dia_df)
    promedios = Float64[]
    for i in 1:4:96
        # Tomamos las 4 primeras horas de cada día
        # println(dia_df.csp_sf_power_output_mwt[i:min(i+3, end)])
        if i <= 24
            push!(promedios, mean(dia_df.csp_sf_power_output_mwt[i:min(i+3, end)]))
        elseif 25 <= i <= 72
            push!(promedios, 0)
        else
            push!(promedios, mean(dia_df.csp_sf_power_output_mwt[i-72:min(i-72+3, end)]))
        end
    end
    return promedios
end

# Obtener las zonas de carga únicas (sin usar groupby)
GENERATION_PROJECT = unique(df.GENERATION_PROJECT)

# Iterar sobre cada GENERATION_P
for GENERATION_P in GENERATION_PROJECT
    # Filtrar el DataFrame para cada GENERATION_P
    GENERATION_P_df = filter(row -> row.GENERATION_PROJECT == GENERATION_P, df)
    
    # Obtener los años únicos en los timepoints de este GENERATION_P
    años = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    # Iterar sobre cada año
    for año in años
        # Filtrar los datos para el año actual
        year_df = filter(row -> string(row.timepoint)[1:4] == string(año), GENERATION_P_df)
        # println(year_df)

        # Procesar los días 4, 8 y 12
        for día in ["04", "08", "12"]
            # Filtrar los timepoints correspondientes al día actual
            day_df = filter(row -> string(row.timepoint)[5:6] == día, year_df)
            
            # Para los días previos (1-4, 5-8, 9-12), calculamos el promedio cada 4 horas
            if día == "04"
                # Para el día 4, calculamos los promedios de los días 1-4
                dias_previos = filter(row -> parse(Int, string(row.timepoint)[5:6]) <= 4, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            elseif día == "08"
                # Para el día 8, calculamos los promedios de los días 5-8
                dias_previos = filter(row -> parse(Int, string(row.timepoint)[5:6]) >= 5 && parse(Int, string(row.timepoint)[5:6]) <= 8, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            elseif día == "12"
                # Para el día 12, calculamos los promedios de los días 9-12
                dias_previos = filter(row -> parse(Int, string(row.timepoint)[5:6]) >= 9 && parse(Int, string(row.timepoint)[5:6]) <= 12, year_df)
                # println(dias_previos)
                promedios_previos = calcular_promedios_4_horas(dias_previos)
                # println(promedios_previos)
            end
            # Asegurarnos de que estamos distribuyendo los promedios correctamente
            for (i, timepoint) in enumerate(day_df.timepoint)
                # Crear una condición booleana para buscar el índice
                condition = (df.GENERATION_PROJECT .== GENERATION_P) .& (df.timepoint .== day_df.timepoint[i])

                # Encontrar el índice donde se cumple la condición
                idx = findall(condition)

                # Asegurarnos de que el número de promedios sea suficiente
                if !isempty(idx) && i <= length(promedios_previos)
                    df.csp_sf_power_output_mwt[idx[1]] = promedios_previos[i]
                else
                    println("Índice fuera de rango para los promedios")
                end
            end
        end
    end
end

# Guardar el archivo con los valores actualizados
CSV.write("C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/sf_power_output.csv", df)