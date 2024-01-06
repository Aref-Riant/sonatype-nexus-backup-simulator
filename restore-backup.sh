## Refrence:| https://help.sonatype.com/repomanager3/planning-your-implementation/backup-and-restore/restore-exported-databases


# nexus url and creds
nexusEndPoint="http://127.0.0.1:8083"
nexusAuth='admin:xxxx'

# name of created backup file
backupinstance="backups/bk_2024-01-06_07-13-54.tar.gz"
backupname=$(echo $backupinstance | cut -d '/' -f 2 | cut -d '.' -f 1)

# Gets pid of nexus process on host machine
nexuspid=$(ps -eopid,cmd | grep nexus | grep -v  grep | grep -v docker | cut -d ' ' -f 2)


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

##########


## Create a fresh temp folder to extract artifacts
rm -rf .tmpbk;
mkdir -p .tmpbk;
tar xzvf $backupinstance -C .tmpbk;



## 1. Freeze Nexus
apiCall "read-only/freeze" POST;
sleep 2;

## Send SIGKILL signal to nexus to pause the process
## so it doesn't recrate the removed directories
sudo kill -STOP $nexuspid;
sleep 2;

## 2. Remove db files
run "rm -rf /nexus-data/db/{component,config,security}";

## 3. Copy .bk files
copy2 .tmpbk/backups/$backupname/bk/. /nexus-data/restore-from-backup/;

## 4. Restore blobsotres
## rm -rf /nexus-data/blobs/*
copy2 .tmpbk/backups/$backupname/blobs/. /nexus-data/blobs/;

## Restore node ID
copy2 .tmpbk/backups/$backupname/node/. /nexus-data/keystores/node/;

## set nexus user as owner
run "chown -R nexus:nexus /nexus-data/"

## 5. ReStart Nexus
##apiCall "read-only/release" POST;

docker stop nexus-backup-test-nexus-1;
sleep 3;
docker start nexus-backup-test-nexus-1;


## 6. ls dir $data_dir/nexus3/db
sleep 10;
run "ls /nexus-data/db/config/";

rm -rf .tmpbk;
