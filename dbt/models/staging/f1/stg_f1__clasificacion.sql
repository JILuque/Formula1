with source as (
    select * from {{ source('f1', 'clasificacion') }}
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
        , quali_constructor_ref
        , quali_constructor_name
        , quali_constructor_nationality
        , quali_constructor_url
        , try_cast(quali_car_number as integer) as quali_car_number
        , quali_position
        , q1
        , q2
        , q3
        , sprint_constructor_ref
        , sprint_constructor_name
        , sprint_constructor_nationality
        , sprint_constructor_url
        , try_cast(sprint_car_number as integer) as sprint_car_number
        , sprint_grid
        , sprint_position
        , sprint_position_text
        , sprint_position_order
        , sprint_points
        , sprint_laps
        , sprint_time_text
        , sprint_time_ms
        , sprint_fastest_lap
        , sprint_fastest_lap_time
        , sprint_status
        , _loaded_at as date_load
    from source
)

select * from renamed