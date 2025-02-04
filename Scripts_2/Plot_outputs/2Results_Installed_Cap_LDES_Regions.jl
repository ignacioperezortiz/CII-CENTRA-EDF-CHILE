using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket_sinLDES/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada tecnología
colors = Dict(
    "BESS" => "#800080",  # Púrpura
    "Solar_CSP" => "#FFD700",  # Amarillo oscuro
    "PSP" => "#4169E1",  # Azul real (Royal Blue)
    "CAES" => "#006400",  # Verde oscuro (Dark Green)
    "TES" => "#000080"  # Azul marino (Navy)
)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario*"/outputs"))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Leer el archivo load_zones.csv
    load_zones_file = joinpath(scenario, "inputs", "load_zones.csv")
    load_zones_df = CSV.read(load_zones_file, DataFrame)
    load_zones = load_zones_df.LOAD_ZONE[1:29]  # Considerar solo hasta la fila 29
    
    # Iterar sobre cada región en LOAD_ZONE
    for region in load_zones
        println("Processing region: $region")
        
        # Leer y filtrar el archivo dispatch_gen_annual_summary.csv por región
        dispatch_file = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
        dispatch_df = CSV.read(dispatch_file, DataFrame)
        region_df = filter(row -> occursin(region, row.gen_load_zone), dispatch_df)
        
        # Leer el archivo gen_info.csv para obtener información de duración de almacenamiento
        gen_info_file = joinpath(scenario, "inputs", "gen_info.csv")
        gen_info_df = CSV.read(gen_info_file, DataFrame)
        
        # Reemplazar "." en gen_storage_energy_to_power_ratio con valores de gen_tes_duration si están disponibles
        for row in eachrow(gen_info_df)
            if row.gen_storage_energy_to_power_ratio == "."
                if row.gen_tes_duration != "."
                    row.gen_storage_energy_to_power_ratio = row.gen_tes_duration
                end
            end
        end

        # Convertir la columna gen_storage_energy_to_power_ratio a Float64, reemplazando "." por 17
        gen_info_df.gen_storage_energy_to_power_ratio = [x == "." ? 17.0 : parse(Float64, x) for x in gen_info_df.gen_storage_energy_to_power_ratio]
        
        # Filtrar gen_info_df para incluir solo tecnologías de almacenamiento
        gen_info_df = filter(row -> row.gen_tech in ["ESS", "Solar_CSP", "Bomb", "CAES", "TES"], gen_info_df)
        
        # Inicializar la columna Storage_Energy_MWh con ceros
        region_df.Storage_Energy_MWh = zeros(Float64, nrow(region_df))
        
        # Calcular Storage_Energy_MWh para cada fila
        for row in eachrow(region_df)
            project_info = gen_info_df[gen_info_df.GENERATION_PROJECT .== row.generation_project, :]
            if nrow(project_info) > 0
                storage_energy_ratio = project_info.gen_storage_energy_to_power_ratio[1]
                row.Storage_Energy_MWh = row.GenCapacity_MW * storage_energy_ratio
            end
        end
        
        # Crear la tabla pivotada para MW
        pivot_df_mw = unstack(region_df, :period, :gen_energy_source, :GenCapacity_MW, combine=sum)
        
        # Crear la tabla pivotada para MWh
        pivot_df_mwh = unstack(region_df, :period, :gen_energy_source, :Storage_Energy_MWh, combine=sum)
        
        # Reemplazar los valores 'missing' por 0 en todas las columnas para MW y MWh
        for col in names(pivot_df_mw)
            replace!(pivot_df_mw[!, col], missing => 0)
        end

        # Renombrar la columna 'ESS' a 'BESS'
        if "ESS" in names(pivot_df_mw)
            rename!(pivot_df_mw, "ESS" => "BESS")
        end

        # Renombrar la columna 'ESS' a 'BESS'
        if "Bomb" in names(pivot_df_mw)
            rename!(pivot_df_mw, "Bomb" => "PSP")
        end

        for col in names(pivot_df_mwh)
            replace!(pivot_df_mwh[!, col], missing => 0)
        end
        
        # Renombrar la columna 'ESS' a 'BESS'
        if "ESS" in names(pivot_df_mwh)
            rename!(pivot_df_mwh, "ESS" => "BESS")
        end

        # Renombrar la columna 'ESS' a 'BESS'
        if "Bomb" in names(pivot_df_mwh)
            rename!(pivot_df_mwh, "Bomb" => "PSP")
        end

        # Ordenar las filas por 'period' de menor a mayor para MW y MWh
        sort!(pivot_df_mw, :period)
        sort!(pivot_df_mwh, :period)
        
        # Manejar las columnas 'Solar-CSP' y 'Solar_CSP' para MW y MWh
        if "Solar-CSP" in names(pivot_df_mw) && "Solar_CSP" in names(pivot_df_mw)
            pivot_df_mw.Solar_CSP .+= pivot_df_mw."Solar-CSP"
            select!(pivot_df_mw, Not(:"Solar-CSP"))
        elseif "Solar-CSP" in names(pivot_df_mw) && !("Solar_CSP" in names(pivot_df_mw))
            rename!(pivot_df_mw, "Solar-CSP" => "Solar_CSP")
        end
        
        if "Solar-CSP" in names(pivot_df_mwh) && "Solar_CSP" in names(pivot_df_mwh)
            pivot_df_mwh.Solar_CSP .+= pivot_df_mwh."Solar-CSP"
            select!(pivot_df_mwh, Not(:"Solar-CSP"))
        elseif "Solar-CSP" in names(pivot_df_mwh) && !("Solar_CSP" in names(pivot_df_mwh))
            rename!(pivot_df_mwh, "Solar-CSP" => "Solar_CSP")
        end

        # Lista de columnas a incluir
        include_columns = ["period", "BESS", "Solar_CSP", "Bomb", "CAES", "TES"]
        
        # Identificar los nombres de las columnas del DataFrame y mantener solo las que están en include_columns para MW y MWh
        existing_columns_mw = String[]
        for col in names(pivot_df_mw)
            if col in include_columns
                push!(existing_columns_mw, col)
            end
        end
        storage_df_mw = select(pivot_df_mw, Symbol.(existing_columns_mw))
        
        existing_columns_mwh = String[]
        for col in names(pivot_df_mwh)
            if col in include_columns
                push!(existing_columns_mwh, col)
            end
        end
        storage_df_mwh = select(pivot_df_mwh, Symbol.(existing_columns_mwh))
        
        # Obtener el nombre de la columna 'period' para mantenerla como la primera
        period_column = :period
        
        # Obtener el resto de las columnas y ordenarlas en función del primer valor (de mayor a menor) para MW y MWh
        other_columns_mw = names(storage_df_mw)[2:end]  # Excluyendo 'period'
        sorted_columns_mw = sort(other_columns_mw, by = col -> storage_df_mw[1, Symbol(col)], rev = true)
        
        other_columns_mwh = names(storage_df_mwh)[2:end]  # Excluyendo 'period'
        sorted_columns_mwh = sort(other_columns_mwh, by = col -> storage_df_mwh[1, Symbol(col)], rev = true)
        
        # Reorganizar las columnas, asegurando que 'period' esté al principio para MW y MWh
        ordered_columns_mw = vcat([period_column], sorted_columns_mw)
        ordered_columns_mwh = vcat([period_column], sorted_columns_mwh)
        
        # Reordenar el DataFrame según las nuevas columnas para MW y MWh
        storage_df_mw = storage_df_mw[:, Symbol.(ordered_columns_mw)]
        storage_df_mwh = storage_df_mwh[:, Symbol.(ordered_columns_mwh)]
        
        # Guardar las tablas pivotadas en archivos CSV para MW y MWh
        output_csv_file_mw = joinpath(scenario, "RegionsLDES/"*replace(region, r"\s+" => "")*"_ICap_storage_MW.csv")
        output_csv_file_mwh = joinpath(scenario, "RegionsLDES/"*replace(region, r"\s+" => "")*"_ICap_storage_MWh.csv")
        CSV.write(output_csv_file_mw, storage_df_mw)
        CSV.write(output_csv_file_mwh, storage_df_mwh)
        
        # Crear el nuevo DataFrame con sumas acumulativas para cada columna para MW y MWh
        new_df_mw = DataFrame()
        new_df_mw[!, :period] = storage_df_mw[!, :period]
        for i in 2:ncol(storage_df_mw)  # Empezamos desde la segunda columna
            accumulated_sums = Vector{Float64}(undef, nrow(storage_df_mw))
            for row_idx in 1:nrow(storage_df_mw)
                accumulated_sums[row_idx] = sum(storage_df_mw[row_idx, 2:i])
            end
            new_df_mw[!, Symbol(names(storage_df_mw)[i])] = accumulated_sums
        end
        
        new_df_mwh = DataFrame()
        new_df_mwh[!, :period] = storage_df_mwh[!, :period]
        for i in 2:ncol(storage_df_mwh)  # Empezamos desde la segunda columna
            accumulated_sums = Vector{Float64}(undef, nrow(storage_df_mwh))
            for row_idx in 1:nrow(storage_df_mwh)
                accumulated_sums[row_idx] = sum(storage_df_mwh[row_idx, 2:i])
            end
            new_df_mwh[!, Symbol(names(storage_df_mwh)[i])] = accumulated_sums
        end
        
        # Datos de ejemplo (reemplaza esto con tus datos)
        period_mw = new_df_mw.period
        data_mw = Matrix(new_df_mw[:, 2:end])  # Excluye la columna 'period'
        
        period_mwh = new_df_mwh.period
        data_mwh = Matrix(new_df_mwh[:, 2:end])  # Excluye la columna 'period'
        
        # Crear la figura y el eje con proporciones ajustadas para MW
        fig_mw = Figure(size = (1000, 600))
        ax_mw = Axis(fig_mw[1, 1], title = "Gráfico de Capacidad instalada Acumulada (MW) (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad Generada (MW)",
                     titlesize = 24, xlabelsize = 18, ylabelsize = 18)
        
        # Crear el gráfico de áreas apiladas para MW
        for i in 1:size(data_mw, 2)
            if i == 1
                fill_between!(ax_mw, period_mw, zeros(length(period_mw)), data_mw[:, i], label = names(new_df_mw)[i + 1], color = colors[names(new_df_mw)[i + 1]])
            else
                fill_between!(ax_mw, period_mw, data_mw[:, i - 1], data_mw[:, i], label = names(new_df_mw)[i + 1], color = colors[names(new_df_mw)[i + 1]])
            end
        end
        
        # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
        if size(data_mw, 2) != 0
            legend_mw = Legend(fig_mw, ax_mw, "Simbología", title = "Fuentes de Energía", fontsize = 8)
            fig_mw[1, 2] = legend_mw
        end
        
        # Añadir xticks de 5 en 5
        ax_mw.xticks = 1:5:maximum(period_mw)
        
        # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar
        x_min = minimum(period_mw)
        x_max = maximum(period_mw)
        xlims!(ax_mw, x_min, x_max)
        
        # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
        ax_mw.ylabelpadding = 40
        
        # Establecer el límite inferior del eje Y siempre en 0
        ylims!(ax_mw, 0, nothing)
        
        # Guardar la figura en la ruta especificada
        save(joinpath(scenario, "RegionsLDES/"*replace(region, r"\s+" => "")*"_Storage_Icap_MW.png"), fig_mw)
        
        # Mostrar la figura
        display(fig_mw)
        
        # Crear la figura y el eje con proporciones ajustadas para MWh
        fig_mwh = Figure(size = (1000, 600))
        ax_mwh = Axis(fig_mwh[1, 1], title = "Gráfico de Capacidad instalada Acumulada (MWh) (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad de Almacenamiento (MWh)",
                      titlesize = 24, xlabelsize = 18, ylabelsize = 18)
        
        # Crear el gráfico de áreas apiladas para MWh
        for i in 1:size(data_mwh, 2)
            if i == 1
                fill_between!(ax_mwh, period_mwh, zeros(length(period_mwh)), data_mwh[:, i], label = names(new_df_mwh)[i + 1], color = colors[names(new_df_mwh)[i + 1]])
            else
                fill_between!(ax_mwh, period_mwh, data_mwh[:, i - 1], data_mwh[:, i], label = names(new_df_mwh)[i + 1], color = colors[names(new_df_mwh)[i + 1]])
            end
        end
        
        # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
        if size(data_mwh, 2) != 0 
            legend_mwh = Legend(fig_mwh, ax_mwh, "Simbología", title = "Fuentes de Energía", fontsize = 8)
            fig_mwh[1, 2] = legend_mwh
        end

        # Añadir xticks de 5 en 5
        ax_mwh.xticks = 1:5:maximum(period_mwh)
        
        # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar
        x_min = minimum(period_mwh)
        x_max = maximum(period_mwh)
        xlims!(ax_mwh, x_min, x_max)
        
        # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
        ax_mwh.ylabelpadding = 40
        
        # Establecer el límite inferior del eje Y siempre en 0
        ylims!(ax_mwh, 0, nothing)
        
        # Guardar la figura en la ruta especificada
        save(joinpath(scenario, "RegionsLDES/"*replace(region, r"\s+" => "")*"_area_chart_MWh.png"), fig_mwh)
        
        # Mostrar la figura
        display(fig_mwh)
    end
end

println("Processing complete.")