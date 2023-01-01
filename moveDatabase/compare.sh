#!/bin/bash

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
echo "Starting compare at $year $startMonth"
echo ""
echo ""

for month in $(seq -w $startMonth 12);
do
  table=${tablePrefix}_$year$month

  echo "Comparing:   $table"
  oldCnt=$(export MYSQL_PWD=$oldClusterPassword; mysql -h $oldClusterHost --user=$oldClusterUser --database=$tablePrefix -s --execute="select count(id) as cnt from $table limit 1;"|cut -f1)
  echo "Old Cluster: $oldCnt"
  newCnt=$(export MYSQL_PWD=$newClusterPassword; mysql -h $newClusterHost --user=$newClusterUser --database=$tablePrefix -s --execute="select count(id) as cnt from $table limit 1;"|cut -f1)
  echo "New Cluster: $newCnt"
  diff=$((oldCnt-newCnt))
  echo "Difference:  ${diff}"
  echo ""
done