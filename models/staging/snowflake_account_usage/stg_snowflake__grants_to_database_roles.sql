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
        modified_on,
        privilege,
        granted_on,
        name,
        table_catalog,
        table_schema,
        granted_to,
        grantee_name,
        grant_option,
        granted_by,
        deleted_on,
        granted_by_role_type
    from {{ source('snowflake_account_usage', 'GRANTS_TO_DATABASE_ROLES') }}

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
        modified_on,
        privilege,
        granted_on,
        name,
        table_catalog,
        table_schema,
        granted_to,
        grantee_name,
        grant_option,
        granted_by,
        deleted_on,
        granted_by_role_type,
        current_timestamp() as archived_at
    from source

)

select *
from final
