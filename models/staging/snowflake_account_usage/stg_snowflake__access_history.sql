{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        query_id,
        query_start_time,
        user_name,
        direct_objects_accessed,
        base_objects_accessed,
        objects_modified,
        object_modified_by_ddl,
        policies_referenced,
        parent_query_id,
        root_query_id,
        event_source,
        additional_properties
    from {{ source('snowflake_account_usage', 'ACCESS_HISTORY') }}

    {% if is_incremental() %}
        where query_start_time > (
            select coalesce(max(query_start_time), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        query_id,
        query_start_time,
        user_name,
        direct_objects_accessed,
        base_objects_accessed,
        objects_modified,
        object_modified_by_ddl,
        policies_referenced,
        parent_query_id,
        root_query_id,
        event_source,
        additional_properties,
        current_timestamp() as archived_at
    from source

)

select *
from final
