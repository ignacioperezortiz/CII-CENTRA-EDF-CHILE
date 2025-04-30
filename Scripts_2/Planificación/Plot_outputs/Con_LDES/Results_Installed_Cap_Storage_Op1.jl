using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir tecnologías de almacenamiento
storage_techs = ["ESS", "Solar_CSP", "Bomb", "CAES", "TES"]

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
    filename1 = joinpath(scenario, "outputs", "dispatch_gen_annual_summary.csv")
    filename2 = joinpath(scenario, "inputs", "gen_info.csv")
    
    # Leer los datos CSV en DataFrames, asegurando que las columnas se lean como cadenas de texto
    df1 = CSV.read(filename1, DataFrame; types=Dict(:gen_tech => String, :generation_project => String))
    df2 = CSV.read(filename2, DataFrame; types=Dict(:gen_tech => String, :GENERATION_PROJECT => String, :gen_storage_energy_to_power_ratio => String, :gen_tes_duration => String))
    df3 = df2

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
    
    # Filtrar df2 para incluir solo tecnologías de almacenamiento
    df2 = filter(row -> row.gen_tech in storage_techs, df2)
    
    # Añadir la fila de df3 que contiene la columna GENERATION_PROJECT con valor de CSP_Cerro_Dominador
    csp_cerro_dominador_row = df3[df3.GENERATION_PROJECT .== "CSP_Cerro_Dominador", :]
    append!(df2, csp_cerro_dominador_row)
    
    # Filtrar df1 para incluir solo tecnologías de almacenamiento
    filtered_df = filter(row -> row.gen_tech in storage_techs || row.generation_project == "CSP_Cerro_Dominador", df1)

    # Transformar gen_tech a "Solar_CSP" para filas con generation_project igual a "CSP_Cerro_Dominador"
    filtered_df[filtered_df.generation_project .== "CSP_Cerro_Dominador", :gen_tech] .= "Solar_CSP"
    
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
    
    # Crear la tabla pivotada usando el argumento combine para manejar duplicados
    pivot_df_energy = unstack(filtered_df, :period, :gen_tech, :Storage_Energy_MWh, combine=sum)
    pivot_df_capacity = unstack(filtered_df, :period, :gen_tech, :GenCapacity_MW, combine=sum)
    
    # Guardar el DataFrame resultante en un nuevo archivo CSV
    CSV.write(joinpath(scenario, "filtered_storage_data.csv"), pivot_df_energy)
    
    # Reemplazar los valores 'missing' por 0 en todas las columnas
    for col in names(pivot_df_energy)
        replace!(pivot_df_energy[!, col], missing => 0)
    end

    # Renombrar la columna 'ESS' a 'BESS'
    if "ESS" in names(pivot_df_energy)
        rename!(pivot_df_energy, "ESS" => "BESS")
    end

    # Renombrar la columna 'ESS' a 'BESS'
    if "Bomb" in names(pivot_df_energy)
        rename!(pivot_df_energy, "Bomb" => "PSP")
    end
    
    for col in names(pivot_df_capacity)
        replace!(pivot_df_capacity[!, col], missing => 0)
    end

    # Renombrar la columna 'ESS' a 'BESS'
    if "ESS" in names(pivot_df_capacity)
        rename!(pivot_df_capacity, "ESS" => "BESS")
    end

    # Renombrar la columna 'ESS' a 'BESS'
    if "Bomb" in names(pivot_df_capacity)
        rename!(pivot_df_capacity, "Bomb" => "PSP")
    end
    
    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df_energy, :period)
    sort!(pivot_df_capacity, :period)
    
    # Guardar las tablas pivotadas en nuevos archivos CSV
    CSV.write(joinpath(scenario, "storage_capacity_energy.csv"), pivot_df_energy)
    CSV.write(joinpath(scenario, "storage_capacity_mw.csv"), pivot_df_capacity)

    # println(pivot_df_energy)
    # println(pivot_df_capacity)
    
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
    # println(new_df_energy)
    
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
    # println(new_df_capacity)
    
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
            fill_between!(ax_energy, period_energy, zeros(length(period_energy)), data_energy[:, i], label = names(new_df_energy)[i + 1], color = colors[names(new_df_energy)[i + 1]])
        else
            fill_between!(ax_energy, period_energy, data_energy[:, i - 1], data_energy[:, i], label = names(new_df_energy)[i + 1], color = colors[names(new_df_energy)[i + 1]])
        end
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_energy = Legend(fig_energy, ax_energy, "Simbología", title = "Tecnologías de Almacenamiento", fontsize = 8)
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
    save(joinpath(scenario, "stacked_area_chart_storage_energy.png"), fig_energy)
    
    # Mostrar la figura
    display(fig_energy)
    
    # Crear la figura y el eje con proporciones ajustadas para GenCapacity_MW
    fig_capacity = Figure(size = (1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1], title = "Gráfico de Capacidad de Almacenamiento Acumulada (MW) (Scenario: $(basename(scenario)))", xlabel = "Periodo", ylabel = "Capacidad de Almacenamiento (MW)",
                       titlesize = 24, xlabelsize = 18, ylabelsize = 18)
    
    # Crear el gráfico de áreas apiladas para GenCapacity_MW
    for i in 1:size(data_capacity, 2)
        if i == 1
            fill_between!(ax_capacity, period_capacity, zeros(length(period_capacity)), data_capacity[:, i], label = names(new_df_capacity)[i + 1], color = colors[names(new_df_capacity)[i + 1]])
        else
            fill_between!(ax_capacity, period_capacity, data_capacity[:, i - 1], data_capacity[:, i], label = names(new_df_capacity)[i + 1], color = colors[names(new_df_capacity)[i + 1]])
        end
    end
    
    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_capacity = Legend(fig_capacity, ax_capacity, "Simbología", title = "Tecnologías de Almacenamiento", fontsize = 8)
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
    save(joinpath(scenario, "stacked_area_chart_storage_capacity.png"), fig_capacity)
    
    # Mostrar la figura
    display(fig_capacity)
end

println("Processing complete.")