1.	create .env file next to compose.yml  (for example: `/etc/projects/docker_project1/.env`)
2.	install `mssqlbackup`
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

## 2. install `mssqlbackup`:

```
sudo wget https://raw.githubusercontent.com/mohammadfalahat/mssql-container-backup-script/refs/heads/main/mssqlbackup.sh
sudo chmod +x mssqlbackup.sh
sudo mv mssqlbackup.sh /usr/bin/mssqlbackup
```

## 3. add crontab schedule
add cronjob with `crontab -e` or `sudo vi /etc/crontab`
```
# to take full backup:
30 17 * * * root /usr/bin/mssqlbackup -dir /etc/projects/docker_project1            >> /var/log/mssqlbackup.log 2>&1; echo " CRON[$$] finished" >> /var/log/mssqlbackup.log
35 17 * * * root /usr/bin/mssqlbackup -dir /etc/projects/docker_project2            >> /var/log/mssqlbackup.log 2>&1; echo " CRON[$$] finished" >> /var/log/mssqlbackup.log

# to take differential backup add [-d true] flag:
0,30 * * * * root /usr/bin/mssqlbackup -dir /etc/projects/docker_project1 -d true  >> /var/log/mssqlbackup.log 2>&1; echo " CRON[$$] finished" >> /var/log/mssqlbackup.log
0,30 * * * * root /usr/bin/mssqlbackup -dir /etc/projects/docker_project2 -d true  >> /var/log/mssqlbackup.log 2>&1; echo " CRON[$$] finished" >> /var/log/mssqlbackup.log
```
