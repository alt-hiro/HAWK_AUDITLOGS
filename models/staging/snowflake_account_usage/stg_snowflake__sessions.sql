{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        session_id,
        created_on,
        user_name,
        authentication_method,
        login_event_id,
        client_application_version,
        client_application_id,
        client_environment,
        client_build_id,
        client_version,
        access_time,
        is_open,
        closed_reason
    from {{ source('snowflake_account_usage', 'SESSIONS') }}

    {% if is_incremental() %}
        where created_on > (
            select coalesce(max(created_on), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

final as (

    select
        session_id,
        created_on,
        user_name,
        authentication_method,
        login_event_id,
        client_application_version,
        client_application_id,
        client_environment,
        client_build_id,
        client_version,
        access_time,
        is_open,
        closed_reason,
        current_timestamp() as archived_at
    from source

)

select *
from final
