{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        referenced_database,
        referenced_schema,
        referenced_object_name,
        referenced_object_id,
        referenced_object_domain,
        referencing_database,
        referencing_schema,
        referencing_object_name,
        referencing_object_id,
        referencing_object_domain,
        dependency_type
    from {{ source('snowflake_account_usage', 'OBJECT_DEPENDENCIES') }}

),

new_records as (

    select source.*
    from source

    {% if is_incremental() %}
        where not exists (
            select 1
            from {{ this }} as this
            where this.referenced_database = source.referenced_database and
            this.referenced_schema = source.referenced_schema and
            this.referenced_object_name = source.referenced_object_name and
            this.referenced_object_id = source.referenced_object_id and
            this.referenced_object_domain = source.referenced_object_domain and
            this.referencing_database = source.referencing_database and
            this.referencing_schema = source.referencing_schema and
            this.referencing_object_name = source.referencing_object_name and
            this.referencing_object_id = source.referencing_object_id and
            this.referencing_object_domain = source.referencing_object_domain and
            this.dependency_type = source.dependency_type
        )
    {% endif %}

),

final as (

    select
        referenced_database,
        referenced_schema,
        referenced_object_name,
        referenced_object_id,
        referenced_object_domain,
        referencing_database,
        referencing_schema,
        referencing_object_name,
        referencing_object_id,
        referencing_object_domain,
        dependency_type,
        current_timestamp() as archived_at
    from new_records

)

select *
from final
