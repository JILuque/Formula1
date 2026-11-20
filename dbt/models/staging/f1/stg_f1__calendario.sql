with source as (
    select * from {{ source('f1', 'calendario') }}
),

renamed as (
    select
          season_year
        , round
        , race_name
        , race_date
        , try_to_time(race_time) as race_time
        , race_url
        , fp1_date
        , try_to_time(fp1_time) as fp1_time
        , fp2_date
        , try_to_time(fp2_time) as fp2_time
        , fp3_date
        , try_to_time(fp3_time) as fp3_time
        , quali_date
        , try_to_time(quali_time) as quali_time
        , sprint_date
        , try_to_time(sprint_time) as sprint_time
        , circuit_ref
        , circuit_name
        , circuit_location
        , circuit_country
        , circuit_lat
        , circuit_lng
        , circuit_alt as circuit_altitude_m
        , circuit_url
        , _loaded_at as date_load
    from source
)

select * from renamed