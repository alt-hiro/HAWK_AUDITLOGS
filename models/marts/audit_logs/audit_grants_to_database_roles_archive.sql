{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select *
    from {{ ref('stg_snowflake__grants_to_database_roles') }}

    {% if is_incremental() %}
        where archived_at > (
            select coalesce(max(archived_at), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select *
    from source

)

select *
from final
