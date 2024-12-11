#!/bin/bash

# Default values
differential="false"
# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -d)
      differential="$2"
      shift 2
      ;;
    -dir)
      if [[ -n "$2" ]]; then
        target_dir="$2"
        if [[ -d "$target_dir" ]]; then
          absolute_dir=$(realpath "$target_dir")
          cd "$absolute_dir" || { echo "Failed to change directory to $absolute_dir"; exit 1; }
          echo "Changed directory to: $absolute_dir"
        else
          echo "Directory $target_dir does not exist!"
          exit 1
        fi
        shift # Move past the directory value
      else
        echo "Error: Missing argument for -dir flag!"
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Source the .env file
if [ -f ".env" ]; then
  source ".env"
else
  echo "Error: .env file not found!"
  exit 1
fi

# Variables
export container_name=${DB_CONTAINER_NAME}
export server="localhost"
export username="SA"
export password=${SA_PASSWORD}
export backup_dir=${BAK_DIR_INSIDE_CONTAINER}

# Check if DB_HOST exists and has a value
if [[ -n "${DB_HOST}" ]]; then
  server="${DB_HOST}"
fi
# Print the server variable (for debugging purposes, optional)
echo "Server is set to: ${server}"

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
# Check if BACK_DIR_INSIDE_HOST is empty
if [[ -z "$BACK_DIR_INSIDE_HOST" ]]; then
    echo "Error: BACK_DIR_INSIDE_HOST is empty. Exiting."
    exit 1
fi
# Normalize the path by removing trailing slashes
BACK_DIR_INSIDE_HOST=$(realpath -m "$BACK_DIR_INSIDE_HOST")
# System directories to block
BLOCKED_DIRS=("/" "/etc" "/usr" "/bin" "/boot" "/dev" "/var" "/root" "/sys" "/mnt" "/proc")
# Check if BACK_DIR_INSIDE_HOST matches any blocked directory exactly
for DIR in "${BLOCKED_DIRS[@]}"; do
    if [[ "$BACK_DIR_INSIDE_HOST" == "$DIR" ]]; then
        echo "Error: BACK_DIR_INSIDE_HOST is a restricted system directory ($DIR). Exiting."
        exit 1
    fi
done
echo "BACK_DIR_INSIDE_HOST is valid: $BACK_DIR_INSIDE_HOST"
/usr/bin/mv ${BACK_DIR_INSIDE_HOST}/* /home/backupuser/backups/${PROJECT_NAME}/
chown -R backupuser:backupuser /home/backupuser/backups/
echo "Backup process completed."
