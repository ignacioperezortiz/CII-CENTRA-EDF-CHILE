# script para crear periods.csv, timepoints.csv y timeseries.csv.
using CSV
using DataFrames

# Se verifica si existe el directorio donde guardar los inputs, sino se crea
if !isdir("test_inputs")
    mkpath("test_inputs")
end

# Se definen los parametros base para la ejecucion del script

ts_duration_of_tp = 1
ts_num_tps = 24
last_period_duration = 10 #years
base_year_duration = 365.25
start_years = [2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]
months = 1:12

#Se crean las horas dependiendo de la duracion en horas de cada timepoint
if 24 % ts_duration_of_tp != 0
    println("El valor de ts_duration_of_tp debe ser un divisor de 24")
    return 0
end
hours = 0:ts_duration_of_tp:23
#El array de dias se debe poner a mano dependiendo de la combinacion de ts_duration_of_tp y ts_num_tps
days = [23]
#En caso que la cantidad de dias en el array sea mayor a la cantidad de dias calculados por ts_duration_of_tp y ts_num_tps, se detiene la ejecucion
if length(days) > (ts_duration_of_tp*ts_num_tps)/24
    println("La cantidad de días en el array dias debe ser consistente con ts_duration_of_tp*ts_num_tps")
    return 0
end

#Se genera un diccionario con los array base para la generacion de los archivos
base_arrays_dict = Dict(
    "base_year_duration" => base_year_duration,
    "start_years" => start_years,
    "last_period_duration" => last_period_duration,
    "months" => months,
    "ts_duration_of_tp" => ts_duration_of_tp,
    "ts_num_tps" => ts_num_tps,
    "days" => days,
    "hours" => hours,
)



# periods.csv
# Función para generar el DataFrame a partir de los años de inicio

function generate_periods(base_arrays_dict::Dict)
    #La funcion vcat permite generar un array al unir desde el segundo elemento con la ultima fecha que le suma last_period_duration a la ultima fecha del array
    periods = DataFrame(INVESTMENT_PERIOD = base_arrays_dict["start_years"], period_start = base_arrays_dict["start_years"], period_end = vcat(base_arrays_dict["start_years"][2:end], base_arrays_dict["start_years"][end] + base_arrays_dict["last_period_duration"]))
    CSV.write("test_inputs/periods2.csv", periods)
end

# Lista de años de inicio

# Generar el DataFrame
generate_periods(base_arrays_dict)

# timepoints.csv
function generate_timepoints(base_arrays_dict::Dict)
    # Crear una lista para almacenar los datos
    n_rows = length(base_arrays_dict["start_years"]) * length(base_arrays_dict["months"]) * length(base_arrays_dict["hours"])
    rows = Vector{Tuple{String, String, String}}(undef, n_rows)

    # Asegurarse de que la zona existe en las columnas
    idx = 1
    for year in base_arrays_dict["start_years"]
        for month in base_arrays_dict["months"]
            month_str = month < 10 ? "0$month" : string(month)
            for day in base_arrays_dict["days"]
                day_str = day < 10 ? "0$day" : string(day)
                for hour in base_arrays_dict["hours"]
                    hour_str = hour < 10 ? "0$hour" : string(hour)
                    time = "$year-$month_str-$day_str-$hour_str:00"
                    timepoint = "$year$month_str$day_str$hour_str"
                    timeseries = "$year$month_str$day_str"
                    rows[idx] = (timepoint, time, timeseries)
                    idx += 1
                end
            end
        end
    end 
    output_df = DataFrame(rows, [:timepoint_id, :timestamp, :timeseries])
    CSV.write("test_inputs/timepoints2.csv", output_df)
end

generate_timepoints(base_arrays_dict)

# timeseries.csv
function generate_timeseries(base_arrays_dict::Dict)


    ts_duration_of_tp = string(base_arrays_dict["ts_duration_of_tp"])
    ts_num_tps = string(base_arrays_dict["ts_num_tps"])
    start_years = base_arrays_dict["start_years"]
    end_years = vcat(start_years[2:end], start_years[end] + last_period_duration)

    n_rows = length(start_years) * length(base_arrays_dict["months"])
    rows = Vector{Tuple{String, String, String, String, String}}(undef, n_rows)
    
    row_idx = 1
    year_idx = 1
    for year in start_years
        current_year_difference = end_years[year_idx] - start_years[year_idx]
        year_idx += 1
        for month in base_arrays_dict["months"]
            month_str = month < 10 ? "0$month" : string(month)
            for day in base_arrays_dict["days"]
                day_str = day < 10 ? "0$day" : string(day)
                timeseries = "$year$month_str$day_str"
                ts_period = string(year)
                ts_scale_to_period = string(current_year_difference*base_arrays_dict["base_year_duration"]/(length(base_arrays_dict["months"])))

                rows[row_idx] = (timeseries, ts_period, ts_duration_of_tp, ts_num_tps, ts_scale_to_period)
                row_idx += 1
            end
        end
    end

    output_df = DataFrame(rows, [:TIMESERIES, :ts_period, :ts_duration_of_tp, :ts_num_tps, :ts_scale_to_period])
    CSV.write("test_inputs/timeseries2.csv", output_df)

end

generate_timeseries(base_arrays_dict)

println("Archivos generados con éxito")
return 0