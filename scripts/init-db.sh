#!/bin/bash
# 数据库初始化脚本（如果migrations目录挂载失败时的备用方案）

set -e

echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres -U $POSTGRES_USER -d $POSTGRES_DB -c '\q' 2>/dev/null; do
  >&2 echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is ready - running migrations..."

# 运行迁移文件
for file in /migrations/*.sql; do
  if [ -f "$file" ]; then
    echo "Running migration: $file"
    PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres -U $POSTGRES_USER -d $POSTGRES_DB -f "$file"
  fi
done

echo "Database initialization complete!"

