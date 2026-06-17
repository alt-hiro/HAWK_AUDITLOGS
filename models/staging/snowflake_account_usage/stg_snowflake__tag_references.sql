{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        on_schema_change='append_new_columns'
    )
}}

with source as (

    select
        tag_database,
        tag_schema,
        tag_id,
        tag_name,
        tag_value,
        object_database,
        object_schema,
        object_id,
        object_name,
        object_deleted,
        domain,
        column_id,
        column_name,
        apply_method
    from {{ source('snowflake_account_usage', 'TAG_REFERENCES') }}

),

new_records as (

    select source.*
    from source

    {% if is_incremental() %}
        where not exists (
            select 1
            from {{ this }} as this
            where equal_null(this.tag_database, source.tag_database) and
            equal_null(this.tag_schema, source.tag_schema) and
            equal_null(this.tag_id, source.tag_id) and
            equal_null(this.tag_name, source.tag_name) and
            equal_null(this.tag_value, source.tag_value) and
            equal_null(this.object_database, source.object_database) and
            equal_null(this.object_schema, source.object_schema) and
            equal_null(this.object_id, source.object_id) and
            equal_null(this.object_name, source.object_name) and
            equal_null(this.object_deleted, source.object_deleted) and
            equal_null(this.domain, source.domain) and
            equal_null(this.column_id, source.column_id) and
            equal_null(this.column_name, source.column_name) and
            equal_null(this.apply_method, source.apply_method)
        )
    {% endif %}

),

final as (

    select
        tag_database,
        tag_schema,
        tag_id,
        tag_name,
        tag_value,
        object_database,
        object_schema,
        object_id,
        object_name,
        object_deleted,
        domain,
        column_id,
        column_name,
        apply_method,
        current_timestamp() as archived_at
    from new_records

)

select *
from final
