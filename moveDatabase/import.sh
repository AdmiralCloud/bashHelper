#!/bin/bash

## Make sure to install pv for monitoring progress -> apt install pv

set -e
source config.txt

if [ -z $oldClusterHost ]
then
  echo "Please enter the hostname for the old cluster"
  read oldClusterHost
fi
if [ -z $oldClusterUser ]
then
  echo "Please enter the username for the old cluster"
  read oldClusterUser
fi
if [ -z $oldClusterPassword ]
then
  echo "Please enter the password for the old cluster"
  read oldClusterPassword
fi

echo "Old Cluster data"
echo "Host: $oldClusterHost"
echo "User: $oldClusterUser"
echo ""

if [ -z $newClusterHost ]
then
  echo "Please enter the hostname for the old cluster"
  read newClusterHost
fi
if [ -z $newClusterUser ]
then
  echo "Please enter the username for the old cluster"
  read newClusterUser
fi
if [ -z $newClusterPassword ]
then
  echo "Please enter the password for the old cluster"
  read newClusterPassword
fi

echo "New Cluster data"
echo "Host: $newClusterHost"
echo "User: $newClusterUser"
echo ""


read -p "Enter database name and tablePrefix [$tablePrefixDefault]: " tablePrefix
tablePrefix=${tablePrefix:-$tablePrefixDefault}

read -p "Start year [2019]: " year
year=${year:-2019}

read -p "Start month [01]: " startMonth
startMonth=${startMonth:-01}


# iterate over month
echo "Use tablePrefix $tablePrefix"
echo "Starting import at $year $startMonth"

for month in $(seq -w $startMonth 12);
do
  #echo $year $month
  table=${tablePrefix}_$year$month
  echo "Export table $table"
  export MYSQL_PWD=$oldClusterPassword
  mysqldump --verbose --single-transaction --set-gtid-purged=OFF --quick -h $oldClusterHost -u$oldClusterUser $tablePrefix $table > $table.sql
  
  echo "Import table $table"
  export MYSQL_PWD=$newClusterPassword
  #mysql -u $newClusterUser -h $newClusterHost $tablePrefix < $table.sql
  pv $table.sql | mysql -h $newClusterHost -u newClusterUser $tablePrefix

  echo "Deleting file"
  rm $table.sql
done
