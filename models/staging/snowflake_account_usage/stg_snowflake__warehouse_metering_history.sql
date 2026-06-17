{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        start_time,
        end_time,
        warehouse_id,
        warehouse_name,
        credits_used,
        credits_used_compute,
        credits_used_cloud_services,
        credits_attributed_compute_queries
    from {{ source('snowflake_account_usage', 'WAREHOUSE_METERING_HISTORY') }}

    {% if is_incremental() %}
        where start_time > (
            select coalesce(max(start_time), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        start_time,
        end_time,
        warehouse_id,
        warehouse_name,
        credits_used,
        credits_used_compute,
        credits_used_cloud_services,
        credits_attributed_compute_queries,
        current_timestamp() as archived_at
    from source

)

select *
from final
