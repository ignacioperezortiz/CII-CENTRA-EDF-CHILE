using CSV, DataFrames, Dates
include("../global_vars.jl")
function create_corresponding_timeseries(data, start_date::Date, current_period)
    #Se copia la estructura del dataframe original
    new_timeseries = similar(data, 0)

    #Se crea la fila del timeseries correspondientes
    new_timeseries_row = Dict(
        :TIMESERIES => parse(Int, Dates.format(start_date, "yyyymmdd")), 
        :ts_period => current_period, 
        :ts_duration_of_tp => HOURS_OF_EACH_TIMEPOINT,
        :ts_num_tps => Int((DURATION_DAYS_OPERATIONAL_DATA+1)*24/HOURS_OF_EACH_TIMEPOINT),
        :ts_scale_to_period => 1.0
        )

    #Se agrega la fila y se retorna el dataframe correspondiente
    push!(new_timeseries, new_timeseries_row)

    return new_timeseries
end

function expand_week_timepoints(data, start_date::Date, week_index)
    expanded_data = similar(data, 0)
    current_date = start_date
    for day_offset in 0:DURATION_DAYS_OPERATIONAL_DATA  # 7 days in a week

        # Get the current date for this day of the week and the year for check if it passes to next year
        current_year = year(current_date)
        current_date = start_date + Day(day_offset)

        # In the case it passes to the next year, we go back to the beggining of the original period
        if year(current_date) > current_year
            current_date = Date(current_year, month(current_date), day(current_date))
        end
        
        # Clone the day's data and adjust the timestamps
        for hour in 0:23
            # Update the timecode, timestamp, and date
            timecode = parse(Int,Dates.format(current_date, "yyyymmdd") * lpad(hour, 2, '0'))
            timestamp = Dates.format(DateTime(year(current_date), month(current_date), day(current_date), hour), "yyyy-mm-dd-HH:MM")
            date = parse(Int,Dates.format(start_date, "yyyymmdd"))

            # Add additional fields
            new_row = Dict(:timepoint_id => timecode, :timestamp => timestamp, :timeseries => date)
            # Push the new row into the DataFrame
            push!(expanded_data, new_row)
        end
    end
    return expanded_data
end

function generate_week_data(data::DataFrame, start_date::Date, timepoint_column_name)
    # Initialize an empty list to hold weekly data
    weekly_data = similar(data, 0)
    
    current_date = start_date
    # Loop over 7 days (one week)
    for day_offset in 0:DURATION_DAYS_OPERATIONAL_DATA
        # Get the current date for this day of the week and the year for check if it passes to next year
        current_year = year(current_date)
        current_date = start_date + Day(day_offset)

        # In the case it passes to the next year, we go back to the beggining of the original period
        if year(current_date) > current_year
            current_date = Date(current_year, month(current_date), day(current_date))
        end
        #Recover the month of the date to obtain the data to repeat for the day of the week
        month_of_current_date = month(current_date)
        if timepoint_column_name == "timepoint"
            filtered_data = filter(row -> parse(Int,string(row[:timepoint])[5:6]) == month_of_current_date, data)
        elseif timepoint_column_name == "TIMEPOINT"
            filtered_data = filter(row -> parse(Int,string(row[:TIMEPOINT])[5:6]) == month_of_current_date, data)
        end
        # println(filtered_data)
        # Adjust the timestamps for the current day
        current_day_data = filtered_data
        if timepoint_column_name == "timepoint"
            current_day_data.timepoint .= repeat([parse(Int,Dates.format(current_date, "yyyymmdd") * lpad(h, 2, '0')) for h in 0:23], length(unique(filtered_data[:, 1])))
        elseif timepoint_column_name == "TIMEPOINT"
            current_day_data.TIMEPOINT .= repeat([parse(Int,Dates.format(current_date, "yyyymmdd") * lpad(h, 2, '0')) for h in 0:23], length(unique(filtered_data[:, 1])))
        end
        
        # Append the adjusted data for this day to the weekly data
        append!(weekly_data, current_day_data)
    end
    
    return weekly_data
end