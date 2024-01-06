# sonatype-nexus-backup-simulator
a docker-compose file plus scripts to test backup solutions on Sonatype Nexus repository.

## Steps:
1. Start Nexus
2. Create backup
3. Restore backup


## 1.Start Nexus

* Start Nexus Docker compose:
```
docker compose up -d;
```
its good to have a `docker logs nexus-backup-test-nexus-1 -f` window to have on eye on logs.

* open 127.0.0.1:8083 on your browser to view admin page of nexus.

* first, youll be guided to change admin password, to get current admin password, run:
```
docker exec nexus-backup-test-nexus-1 cat /nexus-data/admin.password; echo
```

* then visit: `Security -> Realms` and click `Docker Bearer Token Realm` to move it from Avalible realms to Active, then click Save.
* Now visit `Repository->Repositories` and create a new repository as you desire.
* (Port: 8040 is defined in docker compose to be used if you are going to create a docker repo).
* Go to `System -> Tasks -> Create task` and create a new `Admin - Exportdatabases for backup`,
  give it a name, set backup location as `/bk/`, and set Task frequency to `manual`,
  after clicking on `Create task`, a new task will be created, copy the task id, to use for backup.
* upload something on your repository to test backup precedure of blobs.

## 2. Create backup

* open `backup.sh` and set variables like: `nexusAuth=`, `taskID=`.
* Run: `bash backup.sh`
* add come changes or remove repositories to test backup restoration.

## 3. Restore backup

* open `restore-backup.sh` and set variables
* _this script uses `sudo kill -STOP` to pause the pid of nexus inside docker_
* run `bash restore-backup.sh`
* wait for restoration and restart of nexus to complete.
* Test your restored nexus instance.
