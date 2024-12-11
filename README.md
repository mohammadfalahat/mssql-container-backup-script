1.	define .env file next to compose.yml
2.	add script next to compose.yml
3.	add crontab schedule

## 1. .env:
```
PROJECT_NAME=project
DB_CONTAINER_NAME=database-container-name
DB_HOST="localhost,1433"
SA_PASSWORD=SomeStrongPassword!
BAK_DIR_INSIDE_CONTAINER=/var/opt/mssql/backup
BACK_DIR_INSIDE_HOST=./mssql/backup
```

## 2. Script:

Get it here: [Download](https://raw.githubusercontent.com/mohammadfalahat/mssql-container-backup-script/refs/heads/main/backup.sh)

test it works:
```
chmod +x backup.sh
./backup.sh
```

## 3. /etc/crontab

```
# to take full backup:
30 17 * * * root /bin/bash /etc/projects/docker_project/backup.sh

# to take differential backup:
0,30 * * * * root /bin/bash /etc/projects/docker_project/backup.sh -d true
```
