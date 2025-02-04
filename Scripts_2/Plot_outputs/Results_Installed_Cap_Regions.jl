using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada tecnología
colors = Dict(
    "Solar_FV" => "#FFD700",  # Amarillo oscuro
    "Hidroelectrica" => "#4682B4",  # Azul acero (Steel Blue)
    "Eolica" => "#32CD32",  # Verde lima (Lime Green)
    "Carbon" => "#696969",  # Gris oscuro
    "Diesel" => "#A9A9A9",  # Gris claro
    "GNL" => "#FF8C00",  # Naranja oscuro
    "Biomasa" => "#8B4513",  # Marrón silla (Saddle Brown)
    "BESS" => "#800080",  # Púrpura
    "Cogeneracion" => "#FF69B4",  # Rosa fuerte (Hot Pink)
    "Solar_CSP" => "#FFD700",  # Amarillo oscuro
    "Geotermica" => "#DC143C",  # Carmesí (Crimson)
    "Biogas" => "#00CED1",  # Turquesa oscuro (Dark Turquoise)
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
        
        # Crear la tabla pivotada, manejando duplicados sumando los valores
        pivot_df = unstack(region_df, :period, :gen_energy_source, :GenCapacity_MW, combine=sum)
        
        # Reemplazar los valores 'missing' por 0 en todas las columnas
        for col in names(pivot_df)
            replace!(pivot_df[!, col], missing => 0)
        end
        
        # Renombrar la columna 'ESS' a 'BESS'
        if "ESS" in names(pivot_df)
            rename!(pivot_df, "ESS" => "BESS")
        end

        # Renombrar la columna 'ESS' a 'BESS'
        if "Bomb" in names(pivot_df)
            rename!(pivot_df, "Bomb" => "PSP")
        end

        # Ordenar las filas por 'period' de menor a mayor
        sort!(pivot_df, :period)

        # Manejar las columnas 'Solar-CSP' y 'Solar_CSP'
        if "Solar-CSP" in names(pivot_df) && "Solar_CSP" in names(pivot_df)
            pivot_df.Solar_CSP .+= pivot_df."Solar-CSP"
            select!(pivot_df, Not(:"Solar-CSP"))
        elseif "Solar-CSP" in names(pivot_df) && !("Solar_CSP" in names(pivot_df))
            rename!(pivot_df, "Solar-CSP" => "Solar_CSP")
        end
        
        # Guardar la tabla pivotada en un archivo CSV
        output_csv_file = joinpath(scenario, "Regions/"*replace(region, r"\s+" => "")*"_ICap_storage.csv")
        CSV.write(output_csv_file, pivot_df)
        
        # Crear el nuevo DataFrame con sumas acumulativas para cada columna
        new_df = DataFrame()
        new_df[!, :period] = pivot_df[!, :period]
        for i in 2:ncol(pivot_df)  # Empezamos desde la segunda columna
            accumulated_sums = Vector{Float64}(undef, nrow(pivot_df))
            for row_idx in 1:nrow(pivot_df)
                accumulated_sums[row_idx] = sum(pivot_df[row_idx, 2:i])
            end
            new_df[!, Symbol(names(pivot_df)[i])] = accumulated_sums
        end
        
        # Datos de ejemplo (reemplaza esto con tus datos)
        period = new_df.period
        data = Matrix(new_df[:, 2:end])  # Excluye la columna 'period'
        
        # Crear la figura y el eje con proporciones ajustadas
        fig = Figure(size = (1000, 600))
        ax = Axis(fig[1, 1], title = "Gráfico de Capacidad instalada Acumulada (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad Generada (MW)",
                  titlesize = 24, xlabelsize = 18, ylabelsize = 18)
        
        # Crear el gráfico de áreas apiladas
        for i in 1:size(data, 2)
            if i == 1
                fill_between!(ax, period, zeros(length(period)), data[:, i], label = names(new_df)[i + 1], color = colors[names(new_df)[i + 1]])
            else
                fill_between!(ax, period, data[:, i - 1], data[:, i], label = names(new_df)[i + 1], color = colors[names(new_df)[i + 1]])
            end
        end
        
        # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
        legend = Legend(fig, ax, "Simbología", title = "Fuentes de Energía", fontsize = 8)
        fig[1, 2] = legend
        
        # Añadir xticks de 5 en 5
        ax.xticks = 1:5:maximum(period)
        
        # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar
        x_min = minimum(period)
        x_max = maximum(period)
        xlims!(ax, x_min, x_max)
        
        # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
        ax.ylabelpadding = 40
        
        # Establecer el límite inferior del eje Y siempre en 0
        ylims!(ax, 0, nothing)
        
        # Guardar la figura en la ruta especificada
        save(joinpath(scenario, "Regions/"*replace(region, r"\s+" => "")*"_Storage_Icap_stacked_area_chart.png"), fig)
        
        # Mostrar la figura
        # display(fig)
    end
end

println("Processing complete.")