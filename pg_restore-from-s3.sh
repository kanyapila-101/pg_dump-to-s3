#!/usr/bin/env bash

set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import config file
if [ -f "${HOME}/.pg_dump-to-s3.conf" ]; then
    source ${HOME}/.pg_dump-to-s3.conf
else
    source $DIR/.conf
fi

# Usage
__usage="
USAGE:
  $(basename $0) [db target] [s3 object]

EXAMPLE
  $(basename $0) service 2024-09-18-at-08-19-22_TMS-Staging.sql
"

if [[ -z "$@" ]]; then
    echo "$__usage"
    exit 0
fi

# echo " * Restore in progress 1 ${$1}";
# echo " * Restore in progress 2 ${$2}";

# Download backup from s3
aws s3 cp s3://$S3_PATH/$2 /tmp/$2
# aws s3 cp s3://tst-backups-pg-sql/nonprod-pg-sql/2024-09-18-at-08-19-22_TMS-Staging.sql /tmp/2024-09-18-at-08-19-22_TMS-Staging.sql

# Create database if not exists
DB_EXISTS=$(psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$1'")
if [ "$DB_EXISTS" = "1" ]
then
    echo "Database $1 already exists, skipping creation"
    # Restore database
    pg_restore -h $PG_HOST -U $PG_USER -p $PG_PORT -d $1 -Fc --clean --if-exists --no-owner /tmp/$2
else
    echo "Creating database $1"
    createdb -h $PG_HOST -p $PG_PORT -U $PG_USER -T template0 $1
    # Restore database
    pg_restore -h $PG_HOST -U $PG_USER -p $PG_PORT -d $1 -Fc /tmp/$2
fi

# Remove backup file
rm /tmp/$2

echo "$2 restored to database $1"
