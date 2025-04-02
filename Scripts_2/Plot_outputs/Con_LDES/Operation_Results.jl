using CSV
using DataFrames
using CairoMakie
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    scenarioo = scenario[end-1:end]
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(joinpath(scenario, "outputs")))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Leer el archivo TES_dispatch.txt
    tes_file_path = joinpath(scenario, "outputs", "TES_dispatch.txt")
    if !isfile(tes_file_path)
        println("Skipping missing TES dispatch file in scenario: $scenario")
        continue
    end
    tes_data = CSV.read(tes_file_path, DataFrame)
    
    # Group TES data by timepoint and sum ChargeTES_MWt
    tes_grouped_data = combine(groupby(tes_data, [:timepoint]), :ChargeTES_MWt => sum)
    tes_grouped_data.period = [parse(Int, split(tp, "-")[1]) for tp in tes_grouped_data.timepoint]
    tes_grouped_data.day = [parse(Int, split(tp, "-")[2]) for tp in tes_grouped_data.timepoint]
    tes_grouped_data.hour = [parse(Int, split(tp, "-")[4][1:2]) for tp in tes_grouped_data.timepoint]
    
    # Leer el archivo dispatch.csv
    dispatch_file = joinpath(scenario, "outputs", "dispatch.csv")
    if !isfile(dispatch_file)
        println("Skipping missing dispatch file in scenario: $scenario")
        continue
    end
    data = CSV.read(dispatch_file, DataFrame)
    
    # Change all string elements in ChargeStorage_MW to 0
    data.ChargeStorage_MW = [x isa String ? 0 : x for x in data.ChargeStorage_MW]
    data.ChargeStorage_MW = [x isa Missing ? 0 : x for x in data.ChargeStorage_MW]
    
    # Sum ChargeStorage_MW to DispatchGen_MW
    data.DispatchGen_MW .+= data.ChargeStorage_MW
    
    # Crear las columnas :period, :day y :hour
    data.period = [parse(Int, split(tp, "-")[1]) for tp in data.timestamp]
    data.day = [parse(Int, split(tp, "-")[2]) for tp in data.timestamp]
    data.hour = [parse(Int, split(tp, "-")[4][1:2]) for tp in data.timestamp]
    
    # Definir colores para cada tecnología
    colors = Dict(
        "Solar_FV" => "#FFD700",     # Amarillo oscuro
        "Hidroelectrica" => "#4682B4",   # Azul acero (Steel Blue)
        "Eolica" => "#32CD32",       # Verde lima (Lime Green)
        "Carbon" => "#696969",       # Gris oscuro
        "Diesel" => "#A9A9A9",       # Gris claro
        "GNL" => "#FF8C00",         # Naranja oscuro
        "Biomasa" => "#8B4513",     # Marrón silla (Saddle Brown)
        "BESS" => "#800080",         # Púrpura
        "Cogeneracion" => "#FF69B4",   # Rosa fuerte (Hot Pink)
        "Solar_CSP" => "#FFD700",    # Amarillo oscuro
        "Geotermica" => "#DC143C",     # Carmesí (Crimson)
        "Biogas" => "#00CED1",       # Turquesa oscuro (Dark Turquoise)
        "PSP" => "#4169E1",         # Azul real (Royal Blue)
        "CAES" => "#006400",         # Verde oscuro (Dark Green)
        "TES" => "#000080"          # Azul marino (Navy)
    )
    
    # Obtener los periodos únicos
    unique_periods = unique(data.period)
    
    # Iterar sobre cada periodo
    for period in unique_periods
        println("Processing period: $period")
        
        # Filtrar datos para el periodo actual
        data_period = filter(row -> row.period == period, data)
        tes_data_period = filter(row -> row.period == period, tes_grouped_data)
        
        # Obtener los días únicos
        unique_days = unique(data_period.day)
        
        # Iterar sobre cada día
        for day in unique_days
            println("Processing day: $day")
            
            # Filtrar datos para el día actual
            data_day = filter(row -> row.day == day, data_period)
            tes_data_day = filter(row -> row.day == day, tes_data_period)
            
            # Agrupar datos por timestamp y gen_energy_source, luego sumar DispatchGen_MW
            grouped_data = combine(groupby(data_day, [:timestamp, :gen_energy_source]), :DispatchGen_MW => sum)
            grouped_data.period = [parse(Int, split(tp, "-")[1]) for tp in grouped_data.timestamp]
            grouped_data.day = [parse(Int, split(tp, "-")[2]) for tp in grouped_data.timestamp]
            grouped_data.hour = [parse(Int, split(tp, "-")[4][1:2]) for tp in grouped_data.timestamp]
            
            # Ensure that the first 24 rows are for the TES technology, followed by the rest of the rows
            if "TES" in unique(grouped_data.gen_energy_source)
                bess_rows = filter(row -> row.gen_energy_source == "TES", grouped_data)
                bess_rows.DispatchGen_MW_sum = bess_rows.DispatchGen_MW_sum .- tes_data_day.ChargeTES_MWt_sum
                other_rows = filter(row -> row.gen_energy_source != "TES", grouped_data)
                grouped_data = vcat(bess_rows, other_rows)
            end
            
            # Ensure that the first 24 rows are for the PSP technology, followed by the rest of the rows
            if "Bomb" in unique(grouped_data.gen_energy_source)
                bess_rows = filter(row -> row.gen_energy_source == "Bomb", grouped_data)
                other_rows = filter(row -> row.gen_energy_source != "Bomb", grouped_data)
                grouped_data = vcat(bess_rows, other_rows)
            end
            
            # Ensure that the first 24 rows are for the BESS technology, followed by the rest of the rows
            bess_rows = filter(row -> row.gen_energy_source == "ESS", grouped_data)
            other_rows = filter(row -> row.gen_energy_source != "ESS", grouped_data)
            grouped_data = vcat(bess_rows, other_rows)
            
            grouped_data2 = copy(grouped_data)
            
            # Update DispatchGen_MW_sum with cumulative sums for each 24-hour period
            for i in 25:nrow(grouped_data)
                if "TES" in unique(grouped_data.gen_energy_source) && "Bomb" in unique(grouped_data.gen_energy_source)
                    if 73 <= i
                        if grouped_data.DispatchGen_MW_sum[i - 24] >= 0
                            grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                        end
                    else
                        grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                    end
                elseif "TES" in unique(grouped_data.gen_energy_source) || "Bomb" in unique(grouped_data.gen_energy_source)
                    if 49 <= i
                        if grouped_data.DispatchGen_MW_sum[i - 24] >= 0
                            grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                        end
                    else
                        grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                    end
                else
                    if 25 <= i
                        if grouped_data.DispatchGen_MW_sum[i - 24] >= 0
                            grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                        end
                    else
                        grouped_data.DispatchGen_MW_sum[i] += grouped_data.DispatchGen_MW_sum[i - 24]
                    end
                end
            end
            
            # Update DispatchGen_MW_sum with cumulative sums for each 24-hour period
            for i in 25:nrow(grouped_data2)
                grouped_data2.DispatchGen_MW_sum[i] += grouped_data2.DispatchGen_MW_sum[i - 24]
            end
            
            line = grouped_data2.DispatchGen_MW_sum[end-23:end]
            
            # Pivotar el DataFrame para tener tecnologías como columnas y horas como filas
            pivot_df = unstack(grouped_data, :hour, :gen_energy_source, :DispatchGen_MW_sum)
            
            # Renombrar columnas si es necesario
            if "ESS" in names(pivot_df)
                rename!(pivot_df, "ESS" => "BESS")
            end
            if "Bomb" in names(pivot_df)
                rename!(pivot_df, "Bomb" => "PSP")
            end
            
            # Sumar las columnas 'Solar-CSP' y 'Solar_CSP' y asignar el resultado a 'Solar-CSP'
            if "Solar-CSP" in names(pivot_df)
                pivot_df = pivot_df[!, Not("Solar-CSP")]
            end
            
            # Crear un gráfico de área apilada
            fig = Figure(size = (1000, 600))
            ax = Axis(fig[1, 1], title="Despacho por tecnología $period-$day, $scenarioo", xlabel="Hora", ylabel="Despacho (GW)")
            for tech in reverse(names(pivot_df)[2:end])
                fill_between!(ax, pivot_df.hour, zeros(length(pivot_df.hour)), pivot_df[!, tech] ./ 1000, label=tech, color=colors[tech])
            end
            
            # Personalizar el gráfico
            ax.xticks = 0:1:23
            Legend(fig[1, 2], ax, "Tecnologías", title="Tecnologías de generación")
            text!("--- : Demanda", position = (0.02, 0.98), space = :relative, align = (:left, :top), fontsize = 12)
            # Plot the line with adjusted indices and as a dashed line, also convert line to GW
            lines!(ax, 0:23, line[1:24] ./ 1000, linestyle=:dash, color=:black, label="Demanda")
            
            # Guardar el gráfico como archivo PNG
            output_dir = joinpath(scenario, "Dispatch_Generation")
            mkpath(output_dir)
            save(joinpath(output_dir, "Dispatch_Generation_$period-$day.png"), fig)
        end
    end
end

println("Processing complete.")
