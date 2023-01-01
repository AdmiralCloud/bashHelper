#aws sqs list-queues --profile DEV --queue-name-prefix local_test_backupDeletion

while read p; do
  echo "$p"
  aws sqs delete-queue --profile DEV --queue-url $p
done <queues.txt