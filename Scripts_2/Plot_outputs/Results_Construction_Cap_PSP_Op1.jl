using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/CasoBase/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir colores para cada duración de almacenamiento
colors = Dict(
    8 => "#FFD700",   # Amarillo oscuro
    10 => "#4682B4",  # Azul acero (Steel Blue)
    14 => "#32CD32",  # Verde lima (Lime Green)
    24 => "#800080"   # Púrpura
)

# Definir el orden de las duraciones de almacenamiento para graficar
duration_order = [8, 10, 14, 24]

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

    # Renombrar la columna 'Bomb' a 'PSP'
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

    # Crear tablas pivotadas para Storage_Energy_MWh y GenCapacity_MW, sin sumar valores para duplicados y agrupando por duración de almacenamiento
    pivot_df_energy = unstack(filtered_df, :period, :storage_duration, :Storage_Energy_MWh, combine=sum)
    pivot_df_capacity = unstack(filtered_df, :period, :storage_duration, :GenCapacity_MW, combine=sum)
    period_energy = pivot_df_energy.period
    period_capacity = pivot_df_capacity.period
    pivot_df_energy2 = deepcopy(pivot_df_energy)
    for col in names(pivot_df_energy2)[2:end]
        pivot_df_energy2[2:end, col] = [pivot_df_energy2[i, col] - pivot_df_energy2[i-1, col] for i in 2:nrow(pivot_df_energy2)]
        pivot_df_energy2[1, col] = pivot_df_energy[1, col]  # Mantener el primer valor igual al original
    end
    pivot_df_capacity2 = deepcopy(pivot_df_capacity)
    for col in names(pivot_df_capacity2)[2:end]
        pivot_df_capacity2[2:end, col] = [pivot_df_capacity2[i, col] - pivot_df_capacity2[i-1, col] for i in 2:nrow(pivot_df_capacity2)]
        pivot_df_capacity2[1, col] = pivot_df_capacity[1, col]  # Mantener el primer valor igual al original
    end
    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df_energy2, :period)
    sort!(pivot_df_capacity2, :period)

    # Reordenar las columnas según duration_order
    pivot_df_energy2 = pivot_df_energy2[!, [:"8.0", :"10.0", :"14.0", :"24.0"]]
    pivot_df_capacity2 = pivot_df_capacity2[!, [:"8.0", :"10.0", :"14.0", :"24.0"]]

    rename!(pivot_df_energy2, Dict(Symbol("8.0") => Symbol("8"), Symbol("10.0") => Symbol("10"), Symbol("14.0") => Symbol("14"), Symbol("24.0") => Symbol("24")))
    rename!(pivot_df_capacity2, Dict(Symbol("8.0") => Symbol("8"), Symbol("10.0") => Symbol("10"), Symbol("14.0") => Symbol("14"), Symbol("24.0") => Symbol("24")))
    # Guardar las tablas pivotadas en nuevos archivos CSV
    CSV.write(joinpath(scenario, "bomb_storage_capacity_energy.csv"), pivot_df_energy2)
    CSV.write(joinpath(scenario, "bomb_storage_capacity_mw.csv"), pivot_df_capacity2)

    data_energy = pivot_df_energy2
    data_capacity = pivot_df_capacity2
    # Definir los períodos específicos a mostrar en el eje X
    periods = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
    # Crear la figura y el eje con proporciones ajustadas para Storage_Energy_MWh
    fig_energy = Figure(size=(1000, 600))
    ax_energy = Axis(fig_energy[1, 1], title="Capacidad construida de Almacenamiento PSP (MWh) por Duración (Scenario: $(basename(scenario)))", xlabel="Periodo", ylabel="Capacidad de Almacenamiento (MWh)",
        titlesize=24, xlabelsize=16, ylabelsize=16)

    # Crear el gráfico de barras para Storage_Energy_MWh
    width = 0.4  # Ancho de cada barra
    for i in 1:size(data_energy, 2)
        # Calcular las posiciones de las barras para cada grupo de duración
        x_positions = [findfirst(isequal(p), periods) for p in period_energy]  # Encuentra la posición del año en el vector de periodos
        barplot!(ax_energy, x_positions .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_energy[:, i], label=string(names(pivot_df_energy2)[i]), color=colors[parse(Int, names(pivot_df_energy2)[i])], width=width)
    end

    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_energy = Legend(fig_energy, ax_energy, "Simbología", title="Duración del Almacenamiento (Horas)", fontsize=8)
    fig_energy[1, 2] = legend_energy



    # Asignar las posiciones de los ticks del eje X usando los períodos específicos
    ax_energy.xticks = (1:length(periods), string.(periods))

    # Definir los límites del eje X según los valores de los períodos
    xlims!(ax_energy, 0, length(periods) + 1)

    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_energy.ylabelpadding = 40

    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_energy, 0, nothing)

    display(fig_energy)

    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "bomb_construction_bar_chart_energy.png"), fig_energy)

    # Crear la figura y el eje con proporciones ajustadas para GenCapacity_MW
    fig_capacity = Figure(size=(1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1], title="Capacidad construida (MW) por Duración (Scenario: $(basename(scenario)))", xlabel="Periodo", ylabel="Capacidad de Generación (MW)",
        titlesize=24, xlabelsize=16, ylabelsize=16)

    # Crear el gráfico de barras para GenCapacity_MW
    for i in 1:size(data_capacity, 2)
        # Calcular las posiciones de las barras para cada grupo de duración
        x_positions = [findfirst(isequal(p), periods) for p in period_capacity]  # Encuentra la posición del año en el vector de periodos

        barplot!(ax_capacity, x_positions .+ ((i - length(duration_order) / 2) * width) .+ (width / 2), data_capacity[:, i], label=string(names(pivot_df_capacity2)[i]), color=colors[parse(Int, names(pivot_df_capacity2)[i])], width=width)
    end

    # Añadir leyenda fuera del gráfico, a la derecha y reducir el tamaño de la simbología
    legend_capacity = Legend(fig_capacity, ax_capacity, "Simbología", title="Duración del Almacenamiento (Horas)", fontsize=8)
    fig_capacity[1, 2] = legend_capacity

    # Definir los períodos específicos a mostrar en el eje X
    periods = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

    # Asignar las posiciones de los ticks del eje X usando los períodos específicos
    ax_capacity.xticks = (1:length(periods), string.(periods))

    # Definir los límites del eje X según los valores de los períodos
    xlims!(ax_capacity, 0, length(periods) + 1)

    # Ajustar la posición del título del eje Y para dar más espacio a los ticks del eje Y
    ax_capacity.ylabelpadding = 40

    # Establecer el límite inferior del eje Y siempre en 0
    ylims!(ax_capacity, 0, nothing)

    display(fig_capacity)

    # Guardar la figura en la ruta especificada
    save(joinpath(scenario, "bomb_construction_bar_chart_capacity.png"), fig_capacity)
end

println("Processing complete.")
