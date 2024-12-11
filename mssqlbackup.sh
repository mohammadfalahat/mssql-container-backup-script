#!/bin/bash

# Default values
differential="false"

# Function to print timestamped error messages
log_error() {
  echo "$(date "+%b %d %H:%M:%S") Error: $1" >&2
}

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
          cd "$absolute_dir" || { log_error "Failed to change directory to $absolute_dir"; exit 1; }
          echo "Changed directory to: $absolute_dir"
        else
          log_error "Directory $target_dir does not exist!"
          exit 1
        fi
        shift # Move past the directory value
      else
        log_error "Missing argument for -dir flag!"
        exit 1
      fi
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Source the .env file
if [ -f ".env" ]; then
  source ".env"
else
  log_error ".env file not found!"
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
if [[ $? -ne 0 ]]; then
  log_error "Failed to fetch the list of databases."
  exit 1
fi

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
    if [[ $? -ne 0 ]]; then
      log_error "Backup for database ${database} failed."
      exit 1
    fi
    echo "Backup for ${database} created: ${backup_file}"
done

# MOVE BACKUP FILES TO BACKUPUSER 
if [ ! -d "/home/backupuser/backups/${PROJECT_NAME}/" ]; then
  mkdir -p /home/backupuser/backups/${PROJECT_NAME}/ || { log_error "Failed to create backup directory."; exit 1; }
fi

# Check if BACK_DIR_INSIDE_HOST is empty
if [[ -z "$BACK_DIR_INSIDE_HOST" ]]; then
    log_error "BACK_DIR_INSIDE_HOST is empty. Exiting."
    exit 1
fi

# Normalize the path by removing trailing slashes
BACK_DIR_INSIDE_HOST=$(realpath -m "$BACK_DIR_INSIDE_HOST")
if [[ $? -ne 0 ]]; then
  log_error "Invalid path for BACK_DIR_INSIDE_HOST: $BACK_DIR_INSIDE_HOST"
  exit 1
fi

# System directories to block
BLOCKED_DIRS=("/" "/etc" "/usr" "/bin" "/boot" "/dev" "/var" "/root" "/sys" "/mnt" "/proc")
for DIR in "${BLOCKED_DIRS[@]}"; do
    if [[ "$BACK_DIR_INSIDE_HOST" == "$DIR" ]]; then
        log_error "BACK_DIR_INSIDE_HOST is a restricted system directory ($DIR). Exiting."
        exit 1
    fi
done
echo "BACK_DIR_INSIDE_HOST is valid: $BACK_DIR_INSIDE_HOST"

# Move backup files
/usr/bin/mv ${BACK_DIR_INSIDE_HOST}/* /home/backupuser/backups/${PROJECT_NAME}/ || { log_error "Failed to move backup files."; exit 1; }
chown -R backupuser:backupuser /home/backupuser/backups/ || { log_error "Failed to set permissions for backup files."; exit 1; }
echo "Backup process completed successfully."
