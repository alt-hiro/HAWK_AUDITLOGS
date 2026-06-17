# HAWK_AUDITLOGS

Snowflake の `SNOWFLAKE.ACCOUNT_USAGE` にある監査・運用ログを、dbt で長期退避するためのプロジェクトです。

## 退避対象

次の 10 個の Account Usage ビューを退避対象にしています。

1. `QUERY_HISTORY`
2. `ACCESS_HISTORY`
3. `LOGIN_HISTORY`
4. `SESSIONS`
5. `GRANTS_TO_USERS`
6. `GRANTS_TO_ROLES`
7. `GRANTS_TO_DATABASE_ROLES`
8. `OBJECT_DEPENDENCIES`
9. `TAG_REFERENCES`
10. `WAREHOUSE_METERING_HISTORY`

## dbt モデル構成

dbt のベストプラクティスに寄せて、source、staging、mart の層を分けています。

- `models/staging/snowflake_account_usage/sources.yml`
  - `SNOWFLAKE.ACCOUNT_USAGE` の各ビューを dbt source として定義します。
  - 説明文は日本語で記述しています。
- `models/staging/snowflake_account_usage/stg_snowflake__*.sql`
  - source から明示的なカラム選択で取り込みます。
  - `materialized='incremental'` と `incremental_strategy='append'` を使用します。
  - `QUERY_HISTORY`、`ACCESS_HISTORY`、`LOGIN_HISTORY`、`SESSIONS`、各 grants、`WAREHOUSE_METERING_HISTORY` は、それぞれの時刻列を高水位として新規行のみを取り込みます。
  - `OBJECT_DEPENDENCIES` と `TAG_REFERENCES` は差分判定に適した更新時刻がないため、既存の依存関係・タグ関連付けキーと一致しない行だけを append します。
- `models/marts/audit_logs/audit_*_archive.sql`
  - staging 層で退避した新規行を監査ログアーカイブ用の mart として公開します。
  - mart も append incremental とし、`archived_at` を高水位として staging から新規取り込み分だけを追加します。

## 差分更新に使う主な列

| Account Usage ビュー | staging モデル | 差分更新の基準 |
| --- | --- | --- |
| `QUERY_HISTORY` | `stg_snowflake__query_history` | `start_time` |
| `ACCESS_HISTORY` | `stg_snowflake__access_history` | `query_start_time` |
| `LOGIN_HISTORY` | `stg_snowflake__login_history` | `event_timestamp` |
| `SESSIONS` | `stg_snowflake__sessions` | `created_on` |
| `GRANTS_TO_USERS` | `stg_snowflake__grants_to_users` | `created_on` |
| `GRANTS_TO_ROLES` | `stg_snowflake__grants_to_roles` | `modified_on` |
| `GRANTS_TO_DATABASE_ROLES` | `stg_snowflake__grants_to_database_roles` | `created_on` |
| `OBJECT_DEPENDENCIES` | `stg_snowflake__object_dependencies` | 依存関係キーの未取り込み判定 |
| `TAG_REFERENCES` | `stg_snowflake__tag_references` | タグ関連付けキーの未取り込み判定 |
| `WAREHOUSE_METERING_HISTORY` | `stg_snowflake__warehouse_metering_history` | `start_time` |

## セットアップ

`profiles.yml` に Snowflake 接続情報を設定してください。プロファイル名は `dbt_project.yml` の設定に合わせて `hawk_auditlogs` です。

```yaml
hawk_auditlogs:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <account_identifier>
      user: <user>
      password: <password>
      role: <role_with_account_usage_access>
      database: <archive_database>
      warehouse: <warehouse>
      schema: audit_logs
      threads: 4
      client_session_keep_alive: false
```

`SNOWFLAKE.ACCOUNT_USAGE` を参照するには、実行ロールに `SNOWFLAKE` データベースへの `IMPORTED PRIVILEGES` を付与するか、必要な Account Usage ビューを参照できる Snowflake database role を付与してください。

## 実行方法

```bash
dbt debug
dbt run --select staging marts
dbt test --select staging marts
```

初回実行時は対象ビューの保持期間内データを退避し、2 回目以降は各モデルの差分条件に合致する新規行のみを append します。

## 注意事項

- Account Usage ビューには Snowflake 側の遅延があります。ビューによっては反映まで数時間かかります。
- append-only の退避モデルのため、同一タイムスタンプの遅延到着データまで厳密に拾う必要がある場合は、ルックバック期間と重複排除用 mart の追加を検討してください。
- `OBJECT_DEPENDENCIES` と `TAG_REFERENCES` は更新時刻を持たないため、複合キーによる未取り込み判定で append しています。
- ローカルの `profiles.yml`、dbt の `target/`、`logs/`、`dbt_packages/` は `.gitignore` で除外しています。
