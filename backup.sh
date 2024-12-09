#!/bin/bash
# Source the .env file
if [ -f "$(dirname "$0")/.env" ]; then
  source "$(dirname "$0")/.env"
else
  echo "Error: .env file not found!"
  exit 1
fi
# Default values
differential="false"
# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -d)
      differential="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done
# Variables
export container_name=${DB_CONTAINER_NAME}
export server="localhost"
export username="SA"
export password=${SA_PASSWORD}
export backup_dir=${BAK_DIR_INSIDE_CONTAINER}
# Databases to exclude
exclude_databases=("master" "tempdb" "model" "msdb")
# Get the list of databases
databases=$(docker exec $container_name /opt/mssql-tools/bin/sqlcmd -S "${server}" -U "${username}" -P "${password}" -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4" | grep -v "name" | grep -v "^-*$")
# Loop through the databases and create backups
for database in $databases; do
    # Check if the database should be excluded
    if [[ " ${exclude_databases[@]} " =~ " ${database} " || "$database" == model_* ]]; then
        echo "Skipping backup for excluded database: ${database}"
        continue
    fi
    echo "Creating backup for ${database}..."
    # Use sqlcmd to create backup
    if [ "$differential" = "true" ]; then
      backup_file="${backup_dir}/${database}_backup_$(date +%Y%m%d_%H%M%S)-d.bak"
      echo "Taking differential backup..."
      docker exec $container_name /opt/mssql-tools/bin/sqlcmd -S "${server}" -U "${username}" -P "${password}" -Q "BACKUP DATABASE [${database}] TO DISK='${backup_file}' WITH DIFFERENTIAL"
    else
      backup_file="${backup_dir}/${database}_backup_$(date +%Y%m%d_%H%M%S)-f.bak"
      echo "Taking full backup..."
      docker exec $container_name /opt/mssql-tools/bin/sqlcmd -S "${server}" -U "${username}" -P "${password}" -Q "BACKUP DATABASE [${database}] TO DISK='${backup_file}'"
    fi

    echo "Backup for ${database} created: ${backup_file}"
done
### MOVE BACKUP FILES TO BACKUPUSER 
if [ ! -d "/home/backupuser/backups/${PROJECT_NAME}/" ]; then
  mkdir /home/backupuser/backups/${PROJECT_NAME}/
fi
mv ${BACK_DIR_INSIDE_HOST}/* /home/backupuser/backups/${PROJECT_NAME}/
chown -R backupuser:backupuser /home/backupuser/backups/
echo "Backup process completed."
