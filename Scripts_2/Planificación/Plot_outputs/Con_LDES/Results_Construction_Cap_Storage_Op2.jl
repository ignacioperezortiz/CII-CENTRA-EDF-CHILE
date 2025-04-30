using CSV
using DataFrames
using CairoMakie
using PrettyTables
using FilePathsBase

# Definir la carpeta base que contiene las carpetas de los escenarios
base_dir = "C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Estudio_Oficial/Sensibilidades/OK/Corridos/BESS_Construccion_Masiva2/"

# Obtener la lista de carpetas de escenarios
scenarios = readdir(base_dir, join=true) |> filter(isdir)

# Definir tecnologías de almacenamiento
storage_techs = ["ESS", "Solar_CSP", "Bomb", "CAES", "TES"]

# Definir colores para cada tecnología
colors = Dict(
    "BESS" => "#800080",    # Púrpura
    "Solar_CSP" => "#FFD700",  # Amarillo oscuro
    "PSP" => "#4169E1",    # Azul real (Royal Blue)
    "CAES" => "#006400",  # Verde oscuro (Dark Green)
    "TES" => "#000080"    # Azul marino (Navy)
)

# Definir los períodos específicos
periods = [2024, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

# Iterar sobre cada carpeta de escenario y procesar los archivos
for scenario in scenarios
    println("Processing scenario: $scenario")

    # Verificar si el directorio del escenario está vacío
    if isempty(readdir(scenario * "/outputs"))
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
    pivot_df_energy = combine(groupby(filtered_df, [:period, :gen_tech]), :Storage_Energy_MWh => sum => :Storage_Energy_MWh)
    pivot_df_capacity = combine(groupby(filtered_df, [:period, :gen_tech]), :GenCapacity_MW => sum => :GenCapacity_MW)

    # Convertir a GWh y GW
    pivot_df_energy.Storage_Energy_MWh ./= 1000
    pivot_df_capacity.GenCapacity_MW ./= 1000

    # Guardar el DataFrame resultante en un nuevo archivo CSV
    CSV.write(joinpath(scenario, "filtered_storage_data.csv"), pivot_df_energy)

    # Reemplazar los valores 'missing' por 0 en todas las columnas
    replace!(pivot_df_energy[!, :Storage_Energy_MWh], missing => 0)
    replace!(pivot_df_capacity[!, :GenCapacity_MW], missing => 0)

    # Renombrar las columna 'ESS' a 'BESS' y 'Bomb' a 'PSP'
    replace!(pivot_df_energy[!, :gen_tech], "ESS" => "BESS")
    replace!(pivot_df_energy[!, :gen_tech], "Bomb" => "PSP")
    replace!(pivot_df_capacity[!, :gen_tech], "ESS" => "BESS")
    replace!(pivot_df_capacity[!, :gen_tech], "Bomb" => "PSP")

    # Ordenar las filas por 'period' de menor a mayor
    sort!(pivot_df_energy, :period)
    sort!(pivot_df_capacity, :period)

    # Función para calcular el incremento anual
    function calculate_annual_increase(df::DataFrame, value_column::Symbol)
        result_df = DataFrame(period = Int64[], gen_tech = String[], increase = Float64[])
        unique_periods = unique(df.period)
        for i in 2:length(unique_periods)
            current_period = unique_periods[i]
            previous_period = unique_periods[i-1]
            current_data = df[df.period .== current_period, :]
            previous_data = df[df.period .== previous_period, :]
            for tech in unique(df.gen_tech)
                current_value = 0.0
                previous_value = 0.0
                row_current = findfirst(current_data.gen_tech .== tech)
                if row_current !== nothing
                    current_value = current_data[row_current, value_column]
                end
                row_previous = findfirst(previous_data.gen_tech .== tech)
                if row_previous !== nothing
                    previous_value = previous_data[row_previous, value_column]
                end
                increase = current_value - previous_value
                if increase > 0
                    push!(result_df, (current_period, tech, increase))
                end
            end
        end
        return result_df
    end

    # Calcular el incremento anual para energía y capacidad
    increase_df_energy = calculate_annual_increase(pivot_df_energy, :Storage_Energy_MWh)
    increase_df_capacity = calculate_annual_increase(pivot_df_capacity, :GenCapacity_MW)

    # Filtrar los DataFrames para los períodos deseados
    increase_df_energy = filter(row -> row.period in periods, increase_df_energy)
    increase_df_capacity = filter(row -> row.period in periods, increase_df_capacity)

    # Crear las figuras para las gráficas apiladas
    fig_energy = Figure(size=(1000, 600))
    ax_energy = Axis(fig_energy[1, 1],
        title="Incremento Anual en Capacidad de Almacenamiento (GWh) (Escenario: $(basename(scenario)))",
        xlabel="Periodo",
        ylabel="Incremento en Capacidad de Almacenamiento (GWh)",
        xticks=(1:length(periods), string.(periods)),
        # Establecer límites del eje y
        limits=(nothing, nothing, nothing, 30),
        titlesize=24,
        xlabelsize=16,
        ylabelsize=16)

    fig_capacity = Figure(size=(1000, 600))
    ax_capacity = Axis(fig_capacity[1, 1],
        title="Incremento Anual en Capacidad Instalada (GW) (Escenario: $(basename(scenario)))",
        xlabel="Periodo",
        ylabel="Incremento en Capacidad Instalada (GW)",
        xticks=(1:length(periods), string.(periods)),
        # Establecer límites del eje y
        limits=(nothing, nothing, nothing, 8),
        titlesize=24,
        xlabelsize=16,
        ylabelsize=16)

    # Mapear períodos a valores numéricos para graficar
    period_mapping_energy = Dict(period => i for (i, period) in enumerate(periods))
    period_mapping_capacity = Dict(period => i for (i, period) in enumerate(periods))

    # Get unique technologies
    unique_techs_energy = unique(increase_df_energy.gen_tech)
    unique_techs_capacity = unique(increase_df_capacity.gen_tech)

    # Create a dictionary mapping techs to integer positions for stacking
    tech_position_mapping_energy = Dict(tech => i for (i, tech) in enumerate(unique_techs_energy))
    tech_position_mapping_capacity = Dict(tech => i for (i, tech) in enumerate(unique_techs_capacity))

    # Add a new column with the integer position of the technology
    increase_df_energy[:, :tech_position] = [tech_position_mapping_energy[tech] for tech in increase_df_energy.gen_tech]
    increase_df_capacity[:, :tech_position] = [tech_position_mapping_capacity[tech] for tech in increase_df_capacity.gen_tech]

    # Graficar la gráfica de barras apiladas para energía
    barplot_energy = barplot!(ax_energy,
        [period_mapping_energy[period] for period in increase_df_energy.period],
        increase_df_energy.increase,
        stack=increase_df_energy.tech_position, # Use the integer positions for stacking
        color=[colors[tech] for tech in increase_df_energy.gen_tech],
        width=0.5,
        label=[string(tech) for tech in unique_techs_energy])

    # Graficar la gráfica de barras apiladas para capacidad
    barplot_capacity = barplot!(ax_capacity,
        [period_mapping_capacity[period] for period in increase_df_capacity.period],
        increase_df_capacity.increase,
        stack=increase_df_capacity.tech_position, # Use the integer positions for stacking
        color=[colors[tech] for tech in increase_df_capacity.gen_tech],
        width=0.5,
        label=[string(tech) for tech in unique_techs_capacity])

    # Crear la leyenda con colores correctos
    Legend(fig_energy[1, 2],
        [PolyElement(color=colors[tech]) for tech in unique_techs_energy],
        string.("Tecnología: ", unique_techs_energy);
        labelcolor=:black,
        labelsize=12,
        titlecolor=:black,
        titlefont=10)

    Legend(fig_capacity[1, 2],
        [PolyElement(color=colors[tech]) for tech in unique_techs_capacity],
        string.("Tecnología: ", unique_techs_capacity);
        labelcolor=:black,
        labelsize=12,
        titlecolor=:black,
        titlefont=10)

    # Guardar las figuras
    save(joinpath(scenario, "storage_annual_bar_chart_energy_increase.png"), fig_energy)
    save(joinpath(scenario, "storage_annual_bar_chart_capacity_increase.png"), fig_capacity)

    # Mostrar las figuras
    display(fig_energy)
    display(fig_capacity)
end

println("Processing complete.")
