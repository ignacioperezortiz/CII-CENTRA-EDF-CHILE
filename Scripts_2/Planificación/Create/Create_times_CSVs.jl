# script para crear periods.csv, timepoints.csv y timeseries.csv.
using CSV
using DataFrames

# periods.csv
# Función para generar el DataFrame a partir de los años de inicio
function generate_periods(start_years::Vector{Int})
    periods = []
    for i in 1:length(start_years)
        start_year = start_years[i]
        if i < length(start_years)
            end_year = start_years[i + 1] 
        else
            end_year = start_year + 10
        end
        push!(periods, (start_year,start_year,end_year))
    end
    output_df = DataFrame(periods, [:INVESTMENT_PERIOD, :period_start, :period_end])
    println(output_df)
    CSV.write("C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/times/periods2.csv", output_df)
    return 
end

# Lista de años de inicio
start_years = [2020, 2023, 2026, 2029, 2030, 2031, 2033, 2040, 2050]

# Generar el DataFrame
generate_periods(start_years)

# timepoints.csv
function generate_timepoints(start_years::Vector{Int})
    # Definir años y número de días representativos
    años = start_years
    horas = 0:23

    # Crear una lista para almacenar los datos
    rows = []
    mes = 0

    # Asegurarse de que la zona existe en las columnas
    for año in años
        for día in 1:12
            for hora in horas
                if día>=10
                    if hora>=10
                        time = string(año)*"-$día-"*"23-"*string(hora)*":00"
                        timepoint = string(año)*"$día"*"23"*string(hora)
                        timeseries = string(año)*"$día"*"23"
                    else
                        time = string(año)*"-$día-"*"23-"*"0"*string(hora)*":00"
                        timepoint = string(año)*"$día"*"23"*"0"*string(hora)
                        timeseries = string(año)*"$día"*"23"
                    end
                else
                    if hora>=10
                        time = string(año)*"-0$día-"*"23-"*string(hora)*":00"
                        timepoint = string(año)*"0$día"*"23"*string(hora)
                        timeseries = string(año)*"0$día"*"23"
                    else
                        time = string(año)*"-0$día-"*"23-"*"0"*string(hora)*":00"
                        timepoint = string(año)*"0$día"*"23"*"0"*string(hora)
                        timeseries = string(año)*"0$día"*"23"
                    end
                end
                push!(rows, (timepoint, time, timeseries))
            end
        end
    end 
    output_df = DataFrame(rows, [:timepoint_id, :timestamp, :timeseries])
    println(output_df)
    CSV.write("C:/Users/Ignac/Trabajo_Centra/CII-Centra-EDF/SEN/SEN-Files/Electricity Generation/Reference_NDC/times/timepoints2.csv", output_df)
end

generate_timepoints(start_years)

# timeseries.csv
# ??? como se genera el numero de scale??
# ts_num_tps = 24 tp/ts
# ts_duration_of_tp = 1 hr/tp
# ts_duration_hrs = 24 hr/ts 
# ts_scale_to_period = 300 ts/period = 1 ts/24 hr * 24 hr/day * 30 day/yr * 10 yr/period
ts_scale_to_period = 1/24*24*12*3
println(ts_scale_to_period)
# porque me da distinto a lo que dicen ellos...