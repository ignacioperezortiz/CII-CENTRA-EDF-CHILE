using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/Estudio_oficial/Estudio_Oficial/Nuevos_GNLMarket/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada duración de almacenamiento
colors = Dict(
    8 => "#FFD700",  # Amarillo oscuro
    10 => "#4682B4",  # Azul acero (Steel Blue)
    14 => "#32CD32",  # Verde lima (Lime Green)
    24 => "#800080"  # Púrpura
)

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")
    
    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(joinpath(scenario, "outputs")))
        println("Skipping empty scenario: $scenario")
        continue
    end
    
    # Definir rutas de archivos para el escenario actual
    filename1 = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
    filename2 = joinpath(scenario, "inputs", "gen_info.csv")
    
    # Leer los datos CSV en DataFrames, asegurando que las columnas se lean como cadenas de texto
    df1 = CSV.read(filename1, DataFrame; types=Dict(:gen_tech => String, :generation_project => String))
    df2 = CSV.read(filename2, DataFrame; types=Dict(:gen_tech => String, :GENERATION_PROJECT => String, :gen_storage_energy_to_power_ratio => String))
    
    # Reemplazar "." en gen_storage_energy_to_power_ratio con valores de gen_tes_duration si están disponibles
    for row in eachrow(df2)
        if row.gen_storage_energy_to_power_ratio == "."
            if row.gen_tes_duration != "."
                row.gen_storage_energy_to_power_ratio = row.gen_tes_duration
            end
        end
    end

    # Convertir la columna gen_storage_energy_to_power_ratio a Float64, reemplazando "." por 17
    df2.gen_storage_energy_to_power_ratio = [x == "." ? 17.0 : parse(Float64, x) for x in df2.gen_storage_energy_to_power_ratio]
    
    # Filtrar df2 para incluir solo tecnologías Bomb
    df2 = filter(row -> row.gen_tech == "Bomb", df2)
    
    # Filtrar df1 para incluir solo tecnologías Bomb
    filtered_df = filter(row -> row.gen_tech == "Bomb", df1)

    # Renombrar la columna 'ESS' a 'BESS'
    if "Bomb" in names(filtered_df)
        rename!(filtered_df, "Bomb" => "PSP")
    end
    
    # Inicializar la columna Storage_Energy_MWh con ceros
    filtered_df.Storage_Energy_MWh = zeros(Float64, nrow(filtered_df))
    
    # Calcular Storage_Energy_MWh para cada fila
    for row in eachrow(filtered_df)
        project_info = df2[df2.GENERATION_PROJECT .== row.generation_project, :]
        if nrow(project_info) > 0
            storage_energy_ratio = project_info.gen_storage_energy_to_power_ratio[1]
            row.Storage_Energy_MWh = row.GenCapacity_MW * storage_energy_ratio
        end
    end
    
    # Clasificar tecnologías Bomb por duración de almacenamiento (8, 10, 14, 24 horas)
    filtered_df.storage_duration = [df2[df2.GENERATION_PROJECT .== row.generation_project, :gen_storage_energy_to_power_ratio][1] for row in eachrow(filtered_df)]
    
    # Guardar el DataFrame resultante en un nuevo archivo CSV
    CSV.write(joinpath(scenario, "filtered_bomb_data.csv"), filtered_df)
    
    # Crear tablas pivotadas para Storage_Energy_MWh y GenCapacity_MW, sumando valores para duplicados y agrupando por duración de almacenamiento
    pivot_df_energy = unstack(filtered_df, :period, :storage_duration, :Storage_Energy_MWh, combine=sum)
    pivot_df_capacity = unstack(filtered_df, :period, :storage_duration, :GenCapacity_MW, combine=sum)
    
    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df_energy, :period)
    sort!(pivot_df_capacity, :period)
    
    # Renombrar las columnas eliminando ".0" y convirtiéndolas a enteros
    rename!(pivot_df_energy, Dict(Symbol("10.0") => Symbol("10"), Symbol("14.0") => Symbol("14"), Symbol("24.0") => Symbol("24"), Symbol("8.0") => Symbol("8")))
    rename!(pivot_df_capacity, Dict(Symbol("10.0") => Symbol("10"), Symbol("14.0") => Symbol("14"), Symbol("24.0") => Symbol("24"), Symbol("8.0") => Symbol("8")))
    
    # Guardar las tablas pivotadas en nuevos archivos CSV
    CSV.write(joinpath(scenario, "bomb_storage_capacity_energy.csv"), pivot_df_energy)
    CSV.write(joinpath(scenario, "bomb_storage_capacity_mw.csv"), pivot_df_capacity)
    
    # Crear el nuevo DataFrame con la misma estructura para Storage_Energy_MWh
    new_df_energy = DataFrame()
    
    # Copiar la primera columna (period)
    new_df_energy[!, :period] = pivot_df_energy[!, :period]
    
    # Crear las sumas acumulativas para las columnas
    for i in 2:ncol(pivot_df_energy)  # Empezamos desde la segunda columna
        # Inicializar una columna vacía para acumular los valores
        accumulated_sums = Vector{Float64}(undef, nrow(pivot_df_energy))
        
        # Calcular la suma acumulada de las columnas 1 a i para cada fila
        for row_idx in 1:nrow(pivot_df_energy)
            accumulated_sums[row_idx] = sum(pivot_df_energy[row_idx, 2:i])
        end
        
        # Asignar la columna acumulada al nuevo DataFrame
        new_df_energy[!, Symbol(names(pivot_df_energy)[i])] = accumulated_sums
    end
    
    # Mostrar el DataFrame resultante
    println(new_df_energy)
    
    # Crear el nuevo DataFrame con la misma estructura para GenCapacity_MW
    new_df_capacity = DataFrame()
    
    # Copiar la primera columna (period)
    new_df_capacity[!, :period] = pivot_df_capacity[!, :period]
    
    # Crear las sumas acumulativas para las columnas
    for i in 2:ncol(pivot_df_capacity)  # Empezamos desde la segunda columna
        # Inicializar una columna vacía para acumular los valores
        accumulated_sums = Vector{Float64}(undef, nrow(pivot_df_capacity))
        
        # Calcular la suma acumulada de las columnas 1 a i para cada fila
        for row_idx in 1:nrow(pivot_df_capacity)
            accumulated_sums[row_idx] = sum(pivot_df_capacity[row_idx, 2:i])
        end
        
        # Asignar la columna acumulada al nuevo DataFrame
        new_df_capacity[!, Symbol(names(pivot_df_capacity)[i])] = accumulated_sums
    end
    
    # Mostrar el DataFrame resultante
    println(new_df_capacity)
    
    # Datos de ejemplo (reemplaza esto con tus datos)
    period_energy = new_df_energy.period
    data_energy = Matrix(new_df_energy[:, 2:end])  # Excluye la columna 'period'
    
    period_capacity = new_df_capacity.period
    data_capacity = Matrix(new_df_capacity[:, 2:end])  # Excluye la columna 'period'
    
    # Crear la figura y el eje con proporciones ajustadas para Storage_Energy_MWh
    fig_energy = Figure(size = (1000, 600))
    ax_energy = Axis(fig_energy[1, 1], title = "Gráfico de Capacidad de Almacenamiento Acumulada (MWh) (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad de Almacenamiento (MWh)",
                     titlesize = 24, xlabelsize = 18, ylabelsize = 18)
    
    # Crear el gráfico de áreas apiladas para Storage_Energy_MWh
    for i in 1:size(data_energy, 2)
        if i == 1
            fill_between!(ax_energy, period_energy, zeros(length(period_energy)), data_energy[:, i], label = string(names(new_df_energy)[i + 1]), color = colors[parse(Int, names(new_df_energy)[i + 1])])
        else
            fill_between!(ax_energy, period_energy, data_energy[:, i - 1], data_energy[:, i], label = string(names(new_df_energy)[i + 1]), color = colors[parse(Int, names(new_df_energy)[i + 1])])
        end
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_energy = Legend(fig_energy, ax_energy, "Simbología", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_energy[1, 2] = legend_energy
    
    # Añadir xticks de 5 en 5
    ax_energy.xticks = 1:5:maximum(period_energy)
    
    # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar
    x_min = minimum(period_energy)
    x_max = maximum(period_energy)
    xlims!(ax_energy, x_min, x_max)
    
    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_energy.ylabelpadding = 40
    
    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_energy, 0, nothing)
    
    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "bomb_stacked_area_chart_storage_energy.png"), fig_energy)
    
    # Mostrar la figura
    display(fig_energy)

    # Crear la figura y el eje con proporciones ajustadas para GenCapacity_MW
    fig_capacity = Figure(size = (1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1], title = "Gráfico de Capacidad Instalada Acumulada (MW) (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad Instalada (MW)",
                        titlesize = 24, xlabelsize = 18, ylabelsize = 18)
    
    # Crear el gráfico de áreas apiladas para GenCapacity_MW
    for i in 1:size(data_capacity, 2)
        if i == 1
            fill_between!(ax_capacity, period_capacity, zeros(length(period_capacity)), data_capacity[:, i], label = string(names(new_df_capacity)[i + 1]), color = colors[parse(Int, names(new_df_capacity)[i + 1])])
        else
            fill_between!(ax_capacity, period_capacity, data_capacity[:, i - 1], data_capacity[:, i], label = string(names(new_df_capacity)[i + 1]), color = colors[parse(Int, names(new_df_capacity)[i + 1])])
        end
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_capacity = Legend(fig_capacity, ax_capacity, "Simbología", title = "Duración del Almacenamiento (Horas)", fontsize = 8)
    fig_capacity[1, 2] = legend_capacity
    
    # Añadir xticks de 5 en 5
    ax_capacity.xticks = 1:5:maximum(period_capacity)
    
    # Definir los límites del eje x como el valor mínimo y máximo de los periodos a graficar
    x_min = minimum(period_capacity)
    x_max = maximum(period_capacity)
    xlims!(ax_capacity, x_min, x_max)
    
    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_capacity.ylabelpadding = 40
    
    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_capacity, 0, nothing)
    
    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "bomb_stacked_area_chart_installed_capacity.png"), fig_capacity)
    
    # Mostrar la figura
    display(fig_capacity)
end

println("Processing complete.")