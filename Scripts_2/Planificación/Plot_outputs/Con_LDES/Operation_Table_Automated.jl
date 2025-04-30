using DataFrames, CSV, Dates

# Directorio base de los datos
datapath = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sinsib/Sensibilidades/OK/Corridos/"

# Directorios y escenarios a iterar
directories = ["CasoBase", "Ausencia_Diesel&GNL", "BESS_Construccion_Masiva", "BESS_Construccion_Masiva2", "Biomasa_reconversion", "Costos_BESS_A5", "Costos_BESS_D5", "Costos_GNL_A5", "Costos_GNL_D5", "Entrada_Ampliacion_Transmision", "PSP_2029", "PSP_2033", "Sin_PSP_10H"]
scenarios = ["RL", "CN", "TA"]

# Crear el DataFrame inicial
items = ["Energía no servida", "Recortes", "Recortes %", "Emisiones CO2 anual (MM)", "Energía movida por BESS anual",
    "Energía movida por LDES", "Energía total demandada (GWh)", "Capacidad instalada Generación", "Capacidad instalada BESS", "Capacidad instalada LDES",
    "Generación bruta", "Participación renovable", "Participación renovable variable", "Costos marginales", "Congestiones sistémicas", "Participación renovable energía", "Participación renovable variable energía"]

# Nuevo orden de los items
new_order = ["Capacidad instalada Generación", "Capacidad instalada LDES", "Capacidad instalada BESS", "Participación renovable", "Participación renovable variable", "Generación bruta", "Energía movida por LDES", "Energía movida por BESS anual", "Participación renovable energía", "Participación renovable variable energía", "Recortes", "Recortes %", "Energía no servida", "Energía total demandada (GWh)", "Emisiones CO2 anual (MM)", "Costos marginales"]

# Función para leer archivos CSV y manejar errores
function read_csv_with_error_handling(filepath)
    try
        return CSV.read(filepath, DataFrame)
    catch e
        println("Error al leer el archivo: $filepath.  Error: $e")
        return nothing # Devuelve nothing en caso de error
    end
end

for directory in directories
    for scenario in scenarios
        # Crear un nuevo DataFrame para cada escenario
        df = DataFrame(Item = items)
        # Agregar las columnas de los años
        for year in ["2024", "2026", "2029", "2030", "2031", "2033", "2040", "2050"]
            df[!, Symbol(year)] = fill(0.0, length(items))
        end


        # Construir la ruta base para este escenario
        base_path = joinpath(datapath, directory, scenario)

        # Leer los archivos CSV usando la función con manejo de errores
        df_demanda = read_csv_with_error_handling(joinpath(base_path, "outputs/electricity_cost.csv"))
        df_emissions = read_csv_with_error_handling(joinpath(base_path, "outputs/emissions.csv"))
        dispatch_annual_summary = read_csv_with_error_handling(joinpath(base_path, "outputs/dispatch_annual_summary.csv"))
        df_dispatch = read_csv_with_error_handling(joinpath(base_path, "outputs/DispatchGen.csv"))
        df_limits = read_csv_with_error_handling(joinpath(base_path, "inputs/variable_capacity_factors.csv"))
        df_genbuild = read_csv_with_error_handling(joinpath(base_path, "outputs/dispatch_gen_annual_summary.csv"))
        df_timeseries = read_csv_with_error_handling(joinpath(base_path, "inputs/timeseries.csv"))
        df_Unserved_load = read_csv_with_error_handling(joinpath(base_path, "outputs/UnservedLoad.csv")) # Leer el archivo UnservedLoad.csv

        # Si algún archivo no se pudo leer, continuar con el siguiente escenario
        if any(isnothing, [df_demanda, df_emissions, dispatch_annual_summary, df_dispatch, df_limits, df_genbuild, df_timeseries, df_Unserved_load]) # Añadir df_Unserved_load a la lista de archivos a verificar
            println("Uno o más archivos no se pudieron leer para $directory/$scenario. Continuando con el siguiente escenario.")
            continue
        end

        println("Procesando datos para $directory/$scenario") # Para debug

        # Llenar la fila "Energía total demandada (GWh)" y "Costos marginales"
        for row in eachrow(df_demanda)
            period = string(row.PERIOD)
            if period in names(df)
                df[df.Item .== "Energía total demandada (GWh)", Symbol(period)] .+= row.SystemDemandPerYear_MWh / 1000
                df[df.Item .== "Costos marginales", Symbol(period)] .+= row.EnergyCostReal_per_MWh
            end
        end

        # Llenar columna Emisiones CO2 anual
        for row in eachrow(df_emissions)
            period = string(row.PERIOD)
            if period in names(df)
                df[df.Item .== "Emisiones CO2 anual (MM)", Symbol(period)] .+= row.AnnualEmissions_tCO2_per_yr / 1000
            end
        end

        # Llenar columna Energía movida por BESS
        filtered_dispatch = filter(row -> row.gen_tech == "ESS", dispatch_annual_summary)
        for row in eachrow(filtered_dispatch)
            period = string(row.period)
            if period in names(df)
                df[df.Item .== "Energía movida por BESS anual", Symbol(period)] .+= row.Discharge_GWh_typical_yr
            end
        end

        # Llenar columna Energía movida por LDES
        filtered_dispatch2 = filter(row -> row.gen_tech in ["Bomb", "TES", "CAES", "CSP-TES"], dispatch_annual_summary)
        for period in unique(filtered_dispatch2.period)
            total_discharge = sum(filtered_dispatch2[filtered_dispatch2.period .== period, :Discharge_GWh_typical_yr])
            if string(period) in names(df)
                df[df.Item .== "Energía movida por LDES", Symbol(string(period))] .+= total_discharge
            end
        end

        # Llenar fila Capacidad instalada Generación y Generación Bruta
        df_anual_summary3 = filter(row -> row.gen_tech in ["HYDRO", "PV", "TERMO", "WIND"], dispatch_annual_summary)
        for period in unique(df_anual_summary3.period)
            total_capacity = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
            total_gen = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            # total_demand = get(df_demanda, "SystemDemandPerYear_MWh", 0.0) / 1000     # Usar get para evitar error si no existe
            if string(period) in names(df)
                df[df.Item .== "Capacidad instalada Generación", Symbol(string(period))] .+= total_capacity
                df[df.Item .== "Generación bruta", Symbol(string(period))] .+= total_gen
                # df[df.Item .== "Energía total demandada (GWh)", Symbol(string(period))] .+= total_demand # Esto ya se llenó arriba
            end
        end

        # Llenar fila Capacidad instalada LDES
        df_anual_summary4 = filter(row -> row.gen_tech in ["Bomb", "TES", "CAES", "CSP-TES"], dispatch_annual_summary)
        for period in unique(df_anual_summary4.period)
            total_capacity = sum(df_anual_summary4[df_anual_summary4.period .== period, :GenCapacity_MW])
            if string(period) in names(df)
                df[df.Item .== "Capacidad instalada LDES", Symbol(string(period))] .+= total_capacity
            end
        end

        # Llenar fila Capacidad instalada BESS
        df_anual_summary4 = filter(row -> row.gen_tech == "ESS", dispatch_annual_summary) # Corrección: Filtrar por "ESS"
        for period in unique(df_anual_summary4.period)
            total_capacity = sum(df_anual_summary4[df_anual_summary4.period .== period, :GenCapacity_MW])
            if string(period) in names(df)
                df[df.Item .== "Capacidad instalada BESS", Symbol(string(period))] .+= total_capacity
            end
        end

        # Llenar fila participación renovable
        df_anual_summary5 = filter(row -> row.gen_energy_source in ["Hidroelectrica", "Solar_CSP", "Solar_FV", "Biomasa", "Cogeneracion", "Geotermica", "Eolica"], dispatch_annual_summary)
        for period in unique(df_anual_summary5.period)
            total_capacity_ren = sum(df_anual_summary5[df_anual_summary5.period .== period, :GenCapacity_MW])
            total_capacity_all = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
            if string(period) in names(df)
                df[df.Item .== "Participación renovable", Symbol(string(period))] .+= (total_capacity_ren / total_capacity_all) * 100
            end
        end

        # Llenar fila participación renovable variable
        df_anual_summary5 = filter(row -> row.gen_tech in ["PV", "WIND"], dispatch_annual_summary)
        for period in unique(df_anual_summary5.period)
            total_capacity_var = sum(df_anual_summary5[df_anual_summary5.period .== period, :GenCapacity_MW])
            total_capacity_all = sum(df_anual_summary3[df_anual_summary3.period .== period, :GenCapacity_MW])
            if string(period) in names(df)
                df[df.Item .== "Participación renovable variable", Symbol(string(period))] .+= (total_capacity_var / total_capacity_all) * 100
            end
        end

        # Llenar columna Energía movida por renovables
        filtered_dispatch5 = filter(row -> row.gen_energy_source in ["Hidroelectrica", "Solar_CSP", "Solar_FV", "Biomasa", "Cogeneracion", "Geotermica", "Eolica"], dispatch_annual_summary)
        for period in unique(filtered_dispatch5.period)
            total_discharge_ren = sum(filtered_dispatch5[filtered_dispatch5.period .== period, :Energy_GWh_typical_yr])
            total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            if string(period) in names(df)
                df[df.Item .== "Participación renovable energía", Symbol(string(period))] .+= (total_discharge_ren / total_energy) * 100
            end
        end

        # Llenar columna Energía movida por renovables variables
        filtered_dispatch6 = filter(row -> row.gen_tech in ["PV", "WIND"], dispatch_annual_summary)
        for period in unique(filtered_dispatch6.period)
            total_discharge_var = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
            total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            if string(period) in names(df)
                df[df.Item .== "Participación renovable variable energía", Symbol(string(period))] .+= (total_discharge_var / total_energy) * 100
            end
        end

        # Trabajo de archivo df_genbuild para cambiar el nombre de un generador
        for row in eachrow(df_genbuild)
            if row[:generation_project] == "Las AraÃ±as 1 13.2 II"
                row[:generation_project] = "Las Arañas 1 13.2 II"
                row[:gen_dbid] = "Las Arañas 1 13.2 II" # Modifica también la columna gen_dbid
            end
        end

        # Trabajo de archivo dispatch para que solo hayan renovables variables
        unicue = unique(df_limits.GENERATION_PROJECT)
        df_dispatch2 = filter(row -> row.GEN_TPS_1 in unicue, df_dispatch)

        # Crear un diccionario para almacenar la capacidad instalada por generador y periodo
        capacity_dict = Dict{String,Dict{String,Float64}}()

        for row in eachrow(df_genbuild)
            gen_project = row[:generation_project]
            period = string(row[:period])
            capacity = row[:GenCapacity_MW]

            if !haskey(capacity_dict, gen_project)
                capacity_dict[gen_project] = Dict{String,Float64}()
            end

            capacity_dict[gen_project][period] = capacity
        end

        # Añadir la columna de capacidad instalada al dataframe df_dispatch2
        df_dispatch2[:, :Installed_Capacity_MW] = [get(capacity_dict, row[:GEN_TPS_1], Dict{String,Float64}())[string(row[:GEN_TPS_2])[1:4]] for row in eachrow(df_dispatch2)]

        # Crear un diccionario para almacenar el factor de capacidad máxima por generador y punto de tiempo
        capacity_factor_dict = Dict{String,Dict{String,Float64}}()

        for row in eachrow(df_limits)
            gen_project = row[:GENERATION_PROJECT]
            timepoint = string(row[:timepoint])
            capacity_factor = row[:gen_max_capacity_factor]

            if !haskey(capacity_factor_dict, gen_project)
                capacity_factor_dict[gen_project] = Dict{String,Float64}()
            end

            capacity_factor_dict[gen_project][timepoint] = capacity_factor
        end

        # Añadir la columna de factor de capacidad máxima al dataframe df_dispatch2
        df_dispatch2[:, :Max_Capacity_Factor] = [get(capacity_factor_dict, row[:GEN_TPS_1], Dict{String,Float64}())[string(row[:GEN_TPS_2])] for row in eachrow(df_dispatch2)]

        # Añadir la columna de potencial de generación
        df_dispatch2[:, :Generation_Potential] = df_dispatch2[:, :Installed_Capacity_MW] .* df_dispatch2[:, :Max_Capacity_Factor]
        # Añadir la columna de recortes
        df_dispatch2[:, :Recortes] = df_dispatch2[:, :Generation_Potential] .- df_dispatch2[:, :DispatchGen]

        # Crear un nuevo DataFrame para sumar los recortes por punto de tiempo
        df_recortes_totales = combine(groupby(df_dispatch2, :GEN_TPS_2), :Recortes => sum => :Total_Recortes)
        # Crear un nuevo DataFrame para sumar los recortes por punto de tiempo
        df_potencial_generacion_totales = combine(groupby(df_dispatch2, :GEN_TPS_2), :Generation_Potential => sum => :Total_Generacion_Potencial)

        # Expandir la columna GEN_TPS_2 en tres columnas: año, día y hora
        df_recortes_totales[:, :año] = parse.(Int, [string(row[:GEN_TPS_2])[1:4] for row in eachrow(df_recortes_totales)])
        df_recortes_totales[:, :día] = parse.(Int, [string(row[:GEN_TPS_2])[5:6] for row in eachrow(df_recortes_totales)])
        df_recortes_totales[:, :hora] = parse.(Int, [string(row[:GEN_TPS_2])[9:10] for row in eachrow(df_recortes_totales)])

        # Expandir la columna GEN_TPS_2 en tres columnas: año, día y hora
        df_potencial_generacion_totales[:, :año] = parse.(Int, [string(row[:GEN_TPS_2])[1:4] for row in eachrow(df_potencial_generacion_totales)])
        df_potencial_generacion_totales[:, :día] = parse.(Int, [string(row[:GEN_TPS_2])[5:6] for row in eachrow(df_potencial_generacion_totales)])
        df_potencial_generacion_totales[:, :hora] = parse.(Int, [string(row[:GEN_TPS_2])[9:10] for row in eachrow(df_potencial_generacion_totales)])

        # Crear un nuevo DataFrame para sumar los recortes diarios
        df_recortes_diarios = combine(groupby(df_recortes_totales, [:año, :día]), :Total_Recortes => sum => :Total_Recortes_Diarios)

        # Crear un nuevo DataFrame para sumar los recortes diarios
        df_potencial_generacion_totales_diarios = combine(groupby(df_potencial_generacion_totales, [:año, :día]), :Total_Generacion_Potencial => sum => :Total_Generacion_Potencial_Diarios)

        # Añadir una nueva columna con el string concatenado
        df_recortes_diarios[:, :GEN_TPS_2] = [string(row[:año]) * lpad(string(row[:día]), 2, '0') * "23" for row in eachrow(df_recortes_diarios)]

        # Añadir una nueva columna con el string concatenado
        df_potencial_generacion_totales_diarios[:, :GEN_TPS_2] = [string(row[:año]) * lpad(string(row[:día]), 2, '0') * "23" for row in eachrow(df_potencial_generacion_totales_diarios)]

        # df_recortes_diarios
        # Leer el archivo timeseries.csv
        # df_timeseries ya se leyó al principio del loop

        # Crear una nueva columna en df_recortes_diarios para ts_scale_to_period
        df_recortes_diarios[:, :ts_scale_to_period] = Vector{Float64}(undef, nrow(df_recortes_diarios))
        df_recortes_diarios[:, :GEN_TPS_2] = string.(df_recortes_diarios[:, :GEN_TPS_2])
        df_recortes_diarios[:, :ts_scale_to_period] = df_timeseries.ts_scale_to_period[:]
        # df_recortes_diarios

        df_potencial_generacion_totales_diarios[:, :ts_scale_to_period] = Vector{Float64}(undef, nrow(df_potencial_generacion_totales_diarios))
        df_potencial_generacion_totales_diarios[:, :GEN_TPS_2] = string.(df_potencial_generacion_totales_diarios[:, :GEN_TPS_2])
        df_potencial_generacion_totales_diarios[:, :ts_scale_to_period] = df_timeseries.ts_scale_to_period[:]

        # Multiplicar los recortes de los días 4, 8 y 12 por 4
        df_recortes_diarios[df_recortes_diarios[:, :día] .== 4, :Total_Recortes_Diarios] .*= 4
        df_recortes_diarios[df_recortes_diarios[:, :día] .== 8, :Total_Recortes_Diarios] .*= 4
        df_recortes_diarios[df_recortes_diarios[:, :día] .== 12, :Total_Recortes_Diarios] .*= 4

        # Multiplicar los recortes de los días 4, 8 y 12 por 4
        df_potencial_generacion_totales_diarios[df_potencial_generacion_totales_diarios[:, :día] .== 4, :Total_Generacion_Potencial_Diarios] .*= 4
        df_potencial_generacion_totales_diarios[df_potencial_generacion_totales_diarios[:, :día] .== 8, :Total_Generacion_Potencial_Diarios] .*= 4
        df_potencial_generacion_totales_diarios[df_potencial_generacion_totales_diarios[:, :día] .== 12, :Total_Generacion_Potencial_Diarios] .*= 4

        df_recortes_diarios.Total_Recortes_Diarios = df_recortes_diarios.Total_Recortes_Diarios .* df_recortes_diarios.ts_scale_to_period
        # df_recortes_diarios
        df_potencial_generacion_totales_diarios.Total_Generacion_Potencial_Diarios = df_potencial_generacion_totales_diarios.Total_Generacion_Potencial_Diarios .* df_potencial_generacion_totales_diarios.ts_scale_to_period

        # Crear un nuevo DataFrame para sumar los recortes anuales
        df_recortes_anuales = combine(groupby(df_recortes_diarios, :año), :Total_Recortes_Diarios => sum => :Total_Recortes_Anuales)
        df_recortes_anuales.Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales ./ (1000)
        df_recortes_anuales.Total_Recortes_Anuales[1] = df_recortes_anuales.Total_Recortes_Anuales[1] / 2
        df_recortes_anuales.Total_Recortes_Anuales[2] = df_recortes_anuales.Total_Recortes_Anuales[2] / 3
        df_recortes_anuales.Total_Recortes_Anuales[3] = df_recortes_anuales.Total_Recortes_Anuales[3] / 1
        df_recortes_anuales.Total_Recortes_Anuales[4] = df_recortes_anuales.Total_Recortes_Anuales[4] / 1
        df_recortes_anuales.Total_Recortes_Anuales[5] = df_recortes_anuales.Total_Recortes_Anuales[5] / 2
        df_recortes_anuales.Total_Recortes_Anuales[6] = df_recortes_anuales.Total_Recortes_Anuales[6] / 7
        df_recortes_anuales.Total_Recortes_Anuales[7] = df_recortes_anuales.Total_Recortes_Anuales[7] / 10
        df_recortes_anuales.Total_Recortes_Anuales[8] = df_recortes_anuales.Total_Recortes_Anuales[8] / 10

        # Crear un nuevo DataFrame para sumar los recortes anuales
        df_generacion_potencial_anuales = combine(groupby(df_potencial_generacion_totales_diarios, :año), :Total_Generacion_Potencial_Diarios => sum => :Total_Potencial_generacion_Anuales)
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales ./ (1000)
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[1] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[1] / 2
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[2] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[2] / 3
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[3] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[3] / 1
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[4] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[4] / 1
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[5] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[5] / 2
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[6] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[6] / 7
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[7] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[7] / 10
        df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[8] = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[8] / 10

        for period in unique(df_recortes_anuales.año)
            Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales[findfirst(x -> x == period, df_recortes_anuales.año)]
            total_discharge = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
            total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            if string(period) in names(df)
                df[df.Item .== "Recortes", Symbol(string(period))] .+= Total_Recortes_Anuales
                # df[df.Item .== "Recortes %", Symbol(string(period))] .= (Total_Recortes_Anuales./(total_discharge)).*100
            end
        end

        for period in unique(df_recortes_anuales.año)
            total_discharge = sum(filtered_dispatch6[filtered_dispatch6.period .== period, :Energy_GWh_typical_yr])
            total_energy = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            total_gen = sum(df_anual_summary3[df_anual_summary3.period .== period, :Energy_GWh_typical_yr])
            Total_Recortes_Anuales = df_recortes_anuales.Total_Recortes_Anuales[findfirst(x -> x == period, df_recortes_anuales.año)]
            generacion_potencial_anuales = df_generacion_potencial_anuales.Total_Potencial_generacion_Anuales[findfirst(x -> x == period, df_generacion_potencial_anuales.año)]
            if string(period) in names(df)
                df[df.Item .== "Recortes %", Symbol(string(period))] .+= (Total_Recortes_Anuales ./ ((total_discharge / total_energy) .* total_gen) .* 100)
            end
        end

        # Llenar la fila "Energía no servida" del dataframe df
        df_Unserved_load.SetProduct_OrderedSet_2 = string.(df_Unserved_load.SetProduct_OrderedSet_2)
        if df_Unserved_load !== nothing
            for row in eachrow(df_Unserved_load)
                # Tomar los primeros 4 caracteres de la columna "SetProduct_OrderedSet_2"
                year_str = SubString(row.SetProduct_OrderedSet_2, 1, 4)
                year = tryparse(Int, year_str) # Intentar convertir a Int
                if year !== nothing && string(year) in names(df) # Verificar si la conversión fue exitosa y el año está en las columnas de df
                    df[df.Item .== "Energía no servida", Symbol(string(year))] .+= row.UnservedLoad
                end
            end
        end

        # Reordenar el DataFrame
        df = df[indexin(new_order, df.Item), :]

        # Mostrar el DataFrame resultante para cada escenario
        println("Resultados para el escenario: $scenario")
        println(df)

        # Guardar el DataFrame en un archivo CSV para cada escenario
        CSV.write(joinpath(datapath, directory, scenario, "Tabla_Resultados_Energeticos.csv"), df)
    end # Fin del loop de escenarios
end # Fin del loop de directorios
