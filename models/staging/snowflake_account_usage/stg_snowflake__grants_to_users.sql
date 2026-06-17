{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        created_on,
        deleted_on,
        role,
        granted_to,
        grantee_name,
        granted_by
    from {{ source('snowflake_account_usage', 'GRANTS_TO_USERS') }}

    {% if is_incremental() %}
        where created_on > (
            select coalesce(max(created_on), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        created_on,
        deleted_on,
        role,
        granted_to,
        grantee_name,
        granted_by,
        current_timestamp() as archived_at
    from source

)

select *
from final
