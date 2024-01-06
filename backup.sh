
# nexus url and creds
nexusEndPoint="http://127.0.0.1:8083"
nexusAuth='admin:xxxx'

# crate a unique name for backup folder
backupInstance=backups/bk_`date +"%Y-%m-%d_%H-%M-%S"`

# ID of backup task created in nexus
# In UI -> System -> Tasks, Click on backup task and copy the TaskID from UI or URL
taskID="606ef0c6-28c3-4d1a-8bb7-6945ecb56957";

# Counter for number of retries while waiting for backup job to be done
waitCount=0;

# Run a command inside nexus container
run () {
  docker exec -u root -it nexus-backup-test-nexus-1 bash -c "$@";
}

# Copy a file from nexus container to local
copy () {
  docker cp nexus-backup-test-nexus-1:$1 $2;
}

# Copy a file from local to nexus container
copy2 () {
  docker cp $1 nexus-backup-test-nexus-1:$2;
}

# Run an API call on nexus url
apiCall () {
  # $1 = path
  # $2 = HTTP_METHOD (GET,POST)
  echo "Calling API $1 Method: $2" > /dev/tty;
  res=$(curl -s -X $2 -u "$nexusAuth" "$nexusEndPoint/service/rest/v1/$1");
  echo "API Call Done"> /dev/tty;
  echo $res;
}

# Run the backup task on nexus
runBackupTask () {
  echo "Running backup task: $taskID";
  apiCall "tasks/$taskID/run" POST;
  echo "Running backup task: $taskID Done";
}

# Wait for backup task to complete and return the result
waitForBackupDone () {
  echo "Waiting for backup to complete $waitCount" > /dev/tty;
  res=$(apiCall "tasks/$taskID" GET);
  #echo $res > /dev/tty;
  cState=$(echo "$res" | jq '.currentState');
  #echo $cState > /dev/tty;
  lastRunResult=$(echo "$res" | jq '.lastRunResult');
  echo $lastRunResult > /dev/tty;
  if [ $waitCount -gt 10 ]
  then
    echo "Too many tries";
    return 1;
  fi

  if [ cState = "RUNNING" ]
  then
    sleep 1;
    waitCount +=1;
    waitForBackupDone;
  fi
echo $lastRunResult;
}


# Create a folder for backup artifacts
echo "Init backup instance: "
echo $backupInstance
echo ""
mkdir -p $backupInstance

# 1. Run BackupTask
# 2. Copy Blob
# 3. Copy NodeID
# 4. Store Backup artifacts
# 5. Pack

### 1. Run BackupTask

# Todo: get task id from api (/service/rest/v1/tasks?type=db.backup).
#       and handle currentState and lastRun.
runBackupTask;
echo "Backup task run done"
sleep 3;


#- Run Task by api
#- Wait for task to complete async

### 2. Copy Blob
echo "Backing up blob stores"
copy /nexus-data/blobs/ ./$backupInstance
echo "Backing up blob stores done"

### 3. Copy NodeID
echo "Backing up Node ID"
copy /nexus-data/keystores/node/ ./$backupInstance
echo "Backing up Node ID done"

### 1-2 Wait for backup to complete
echo "Waiting for backup to complete"
wait4bkres=$(waitForBackupDone)
echo "Waiting for backup to complete done. Result:"
echo $wait4bkres;


### 4. Copy Backup Artifacts
echo "Moving database backup to $backupInstance";
cp -r ./bk ./$backupInstance;
sleep 1;

rm -rf ./bk/*;
echo "Moving database backup done.";


### 5. Compact backup package
echo "Compating backup";
tar -czf "$backupInstance.tar.gz" "$backupInstance";
sleep 1;

rm -rf "$backupInstance";
echo "Compating backup done: ";
echo "$backupInstance.tar.gz";
