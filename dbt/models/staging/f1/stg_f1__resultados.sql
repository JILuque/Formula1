with source as (
    select * from {{ source('f1', 'resultados') }}
),

renamed as (
    select
          season_year
        , round
        , driver_forename
        , driver_surname
        , driver_dob
        , driver_ref
        , try_cast(driver_number as integer) as driver_number
        , driver_code
        , driver_nationality
        , driver_url
        , constructor_ref
        , constructor_name
        , constructor_nationality
        , constructor_url
        , try_cast(car_number as integer) as car_number
        , grid
        , position
        , position_text
        , position_order
        , points
        , laps
        , race_time_text
        , race_time_ms
        , fastest_lap
        , fastest_lap_rank
        , fastest_lap_time
        , fastest_lap_speed as fastest_lap_speed_kmh
        , status
        , _loaded_at as date_load
    from source
)

select * from renamed