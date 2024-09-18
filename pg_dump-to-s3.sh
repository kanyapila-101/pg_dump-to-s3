#!/usr/bin/env bash

#                     _                             _                  _____ 
#  _ __   __ _     __| |_   _ _ __ ___  _ __       | |_ ___        ___|___ / 
# | '_ \ / _` |   / _` | | | | '_ ` _ \| '_ \ _____| __/ _ \ _____/ __| |_ \ 
# | |_) | (_| |  | (_| | |_| | | | | | | |_) |_____| || (_) |_____\__ \___) |
# | .__/ \__, |___\__,_|\__,_|_| |_| |_| .__/       \__\___/      |___/____/ 
# |_|    |___/_____|                   |_|                                   
#
# Project at https://github.com/gabfl/pg_dump-to-s3
#
echo " * Backup in progress.,.${HOME}";
set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo " * Backup in progress.,.${DIR}";

# Import config file
if [ -f "${HOME}/.pg_dump-to-s3.conf" ]; then
    source ${HOME}/.pg_dump-to-s3.conf
else
    source $DIR/.conf
fi

# Vars
NOW=$(date +"%Y-%m-%d-at-%H-%M-%S")
echo " * Backup in progress.,.${NOW}";

# DELETETION_TIMESTAMP=`[ "$(uname)" = Linux ] && date +%s --date="-$DELETE_AFTER"` # Maximum date (will delete all files older than this date)

# Split databases
IFS=',' read -ra DBS <<< "$PG_DATABASES"

# Delete old files
echo " * Backup in progress.,.";

# Loop thru databases
for db in "${DBS[@]}"; do
    FILENAME="$NOW"_"$db"


    echo "   -> backing up $db..."

    # Dump database
    pg_dump -Fc -h $PG_HOST -U $PG_USER -W $PG_PASS -p $PG_PORT $db --no-owner > /tmp/"$FILENAME".sql

    # Copy to S3
    aws s3 cp /tmp/"$FILENAME".sql s3://$S3_PATH/"$FILENAME".sql --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$FILENAME".sql

    # Log
    echo "      ...database $db has been backed up"
done

# Delere old files
echo " * Deleting old backups...";

# Loop thru files
aws s3 ls s3://$S3_PATH/ | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $DELETETION_TIMESTAMP ]]
    then
        # Get file name
        FILENAME=`echo $line|awk {'print $4'}`
        if [[ $FILENAME != "" ]]
          then
            echo "   -> Deleting $FILENAME"
            aws s3 rm s3://$S3_PATH/$FILENAME
        fi
    fi
done;

echo ""
echo "...done!";
echo ""
