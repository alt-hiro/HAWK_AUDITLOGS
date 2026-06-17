# HAWK_AUDITLOGS

Snowflake の監査ログを退避するための dbt プロジェクトです。

## 退避対象

このプロジェクトでは Snowflake が提供する `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` を監査ログの退避対象にしています。
ログイン履歴はユーザー、接続元 IP、認証方式、成否、エラー情報などを含むため、アカウントアクセスの監査用途に適しています。

## モデル構成

- `models/audit_logs/snowflake_login_history_archive.sql`
  - `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` を参照します。
  - `materialized='incremental'` と `incremental_strategy='append'` を指定した append-only の差分更新モデルです。
  - 差分判定には `event_timestamp` を使用し、既存退避テーブルの最大 `event_timestamp` より新しい行だけを追加します。
  - dbt のベストプラクティスに沿って、source CTE と renamed CTE に分け、明示的なカラム選択を行っています。
- `models/audit_logs/sources.yml`
  - Snowflake の `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` を dbt source として定義します。
- `models/audit_logs/schema.yml`
  - 退避モデルの説明と基本的な `not_null` テストを定義します。

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
      role: <role_with_imported_privileges_on_snowflake_database>
      database: <archive_database>
      warehouse: <warehouse>
      schema: audit_logs_archive
      threads: 4
      client_session_keep_alive: false
```

`SNOWFLAKE.ACCOUNT_USAGE` を参照するため、実行ロールには Snowflake の `SNOWFLAKE` データベースに対する `IMPORTED PRIVILEGES` が必要です。

## 実行方法

依存関係と接続設定を用意したうえで、次のコマンドを実行します。

```bash
dbt debug
dbt run --select snowflake_login_history_archive
dbt test --select snowflake_login_history_archive
```

初回実行時は対象期間の全ログを退避し、2 回目以降は `event_timestamp` の最大値を高水位として新規ログのみを append します。

## 注意事項

- `ACCOUNT_USAGE` ビューには Snowflake 側の遅延があるため、直近のログがすぐに取得できない場合があります。
- append-only の差分更新のため、同一 `event_timestamp` の遅延到着レコードを厳密に拾う必要がある場合は、ルックバック期間や重複排除用の別モデル追加を検討してください。
- ローカルの `profiles.yml`、dbt の `target/`、`logs/`、`dbt_packages/` は `.gitignore` で除外しています。
