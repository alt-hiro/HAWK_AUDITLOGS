{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        event_id,
        event_timestamp,
        event_type,
        user_name,
        client_ip,
        reported_client_type,
        reported_client_version,
        first_authentication_factor,
        second_authentication_factor,
        is_success,
        error_code,
        error_message,
        related_event_id,
        connection,
        client_private_link_id
    from {{ source('snowflake_account_usage', 'LOGIN_HISTORY') }}

    {% if is_incremental() %}
        where event_timestamp > (
            select coalesce(max(event_timestamp), '1900-01-01'::timestamp_ltz)
            from {{ this }}
        )
    {% endif %}

),

renamed as (

    select
        event_id,
        event_timestamp,
        event_type,
        user_name,
        client_ip,
        reported_client_type,
        reported_client_version,
        first_authentication_factor,
        second_authentication_factor,
        is_success,
        error_code,
        error_message,
        related_event_id,
        connection,
        client_private_link_id,
        current_timestamp() as archived_at
    from source

)

select *
from renamed
