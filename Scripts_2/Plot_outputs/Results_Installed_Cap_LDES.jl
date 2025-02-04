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
    
    # Definir rutas de archivos para el escenario actual
    filename = joinpath(scenario, "outputs", "dispatch_annual_summary.csv")
    
    # Leer los datos CSV en un DataFrame
    df = CSV.read(filename, DataFrame)
    
    # Crear la tabla pivotada
    pivot_df = unstack(df, :period, :gen_energy_source, :GenCapacity_MW)
    
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
    
    # Sumar las columnas 'Solar-CSP' y 'Solar_CSP' y asignar el resultado a 'Solar-CSP'
    if "Solar-CSP" in names(pivot_df) && "Solar_CSP" in names(pivot_df)
        pivot_df.Solar_CSP .+= pivot_df."Solar-CSP"
        select!(pivot_df, Not(:"Solar-CSP"))
    end
    
    # Crear una copia de pivot_df sin las columnas especificadas
    storage_df = select(pivot_df, Not([:Solar_FV, :Hidroelectrica, :Eolica, :Carbon, :Diesel, :GNL, :Biomasa, :Cogeneracion, :Geotermica, :Biogas]))
    
    # Obtener el nombre de la columna 'period' para mantenerla como la primera
    period_column = :period
    
    # Obtener el resto de las columnas y ordenarlas en función del primer valor (de mayor a menor)
    other_columns = names(storage_df)[2:end]  # Excluyendo 'period'
    sorted_columns = sort(other_columns, by = col -> storage_df[1, Symbol(col)], rev = true)
    
    # Reorganizar las columnas, asegurando que 'period' esté al principio
    ordered_columns = vcat([period_column], sorted_columns)
    
    # Reordenar el DataFrame según las nuevas columnas
    storage_df = storage_df[:, Symbol.(ordered_columns)]
    
    # Mostrar el DataFrame resultante
    # println(storage_df)
    
    CSV.write(joinpath(scenario, "ICap_storage.csv"), storage_df)
    
    # Crear el nuevo DataFrame con la misma estructura
    new_df = DataFrame()
    
    # Copiar la primera columna (period)
    new_df[!, :period] = storage_df[!, :period]
    
    # Crear las sumas acumulativas para las columnas
    for i in 2:ncol(storage_df)  # Empezamos desde la segunda columna
        # Inicializar una columna vacía para acumular los valores
        accumulated_sums = Vector{Float64}(undef, nrow(storage_df))
        
        # Calcular la suma acumulada de las columnas 1 a i para cada fila
        for row_idx in 1:nrow(storage_df)
            accumulated_sums[row_idx] = sum(storage_df[row_idx, 2:i])
        end
        
        # Asignar la columna acumulada al nuevo DataFrame
        new_df[!, Symbol(names(storage_df)[i])] = accumulated_sums
    end
    
    # Mostrar el DataFrame resultante
    # println(new_df)
    
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
    save(joinpath(scenario, "Storage_Icap_stacked_area_chart.png"), fig)
    
    # Mostrar la figura
    # display(fig)
end

println("Processing complete.")