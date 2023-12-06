import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import io
import json
from urllib.parse import unquote_plus
import time
import os


def update_payload(payload, log=True):
    try:
        data = json.loads(payload)
        if 'password' in data:
            if data['password'] is None:
                # Log if the password is None
                if log:
                    print(f"Found None password in payload: {payload}")
                return payload
            elif not data['password'].startswith('XXXX'):
                original_password = data['password']
                data['password'] = 'XXXX-XXXX-R'
                updated_payload = json.dumps(data)
                if log:
                    print(f"Updated password from '{original_password}' to 'XXXX-XXXX-R' in payload.")
                return updated_payload
        return payload
    except json.JSONDecodeError:
        # Log payload that couldn't be decoded
        if log:
            print(f"Failed to decode JSON payload: {payload}")
        return payload



def process_parquet_file(bucket_name, key, s3_client, dry_run=False, log=True, save_locally=False):
    # Download the file from S3
    response = s3_client.get_object(Bucket=bucket_name, Key=key)
    file_content = response['Body'].read()

    # Read Parquet file into Arrow Table and then convert to Pandas DataFrame
    table = pq.read_table(io.BytesIO(file_content))
    df = table.to_pandas(integer_object_nulls=True)

    # Update the 'payload' column
    if 'payload' in df.columns:
        df['payload'] = df['payload'].apply(lambda p: update_payload(p, log))

    # Cast columns to their original types to preserve schema
    # Example: df['userid'] = df['userid'].astype('int32') 
    # Add similar lines for other columns that need type preservation

    # Convert DataFrame back to PyArrow Table while preserving original schema
    table_updated = pa.Table.from_pandas(df, schema=table.schema, preserve_index=False)

    # Write back to Parquet only if there were changes
    if not table.equals(table_updated):
        output = io.BytesIO()
        pq.write_table(table_updated, output)

        # Save locally if the option is enabled
        if save_locally:
            local_file_name = f"updated_{os.path.basename(key)}"
            with open(local_file_name, 'wb') as local_file:
                local_file.write(output.getvalue())
            if log:
                print(f"Saved updated file locally as {local_file_name}")

        # Upload the modified file back to S3 unless in dry run mode
        if not dry_run:
            s3_client.put_object(Bucket=bucket_name, Key=key, Body=output.getvalue())
            if log:
                print(f"Uploaded modified file to S3: {key}")
        elif log:
            print(f"Dry run: changes detected in {key}, but not uploaded.")
    elif log:
        print(f"No changes detected in {key}, no upload performed.")

# Other funct

def list_files(bucket, prefix, s3_client):
    paginator = s3_client.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for content in page.get('Contents', []):
            key = content['Key']
            if key.endswith('.parquet'):
                if check_and_restore_object(bucket, key, s3_client):
                    yield key
                else:
                    print(f"File {key} restoration in progress. Will check later.")

def check_and_restore_object(bucket, key, s3_client, log=False):
    response = s3_client.head_object(Bucket=bucket, Key=key)

    if log:
        storage_class = response.get('StorageClass')
        print(f"File {key} is in {storage_class} storage class.")

    # Check if the file is in Glacier or Deep Archive
    if response.get('StorageClass') in ['GLACIER', 'DEEP_ARCHIVE']:
        if 'Restore' in response:
            # Check if the restore is in progress or completed
            restore_status = response['Restore']
            if 'ongoing-request="false"' in restore_status:
                if log:
                    print(f"File {key} restore completed.")
                return True  # Restore completed
            else:
                if log:
                    print(f"File {key} restore in progress.")
                return False  # Restore in progress
        else:
            # Initiate restore
            if log:
                print(f"Initiating restore for {key}.")
            s3_client.restore_object(
                Bucket=bucket,
                Key=key,
                RestoreRequest={
                    'Days': 1,  # Number of days to keep it accessible
                    'GlacierJobParameters': {'Tier': 'Standard'}
                }
            )
            if log:
                print(f"Restore initiated for {key}.")
            return False  # Initiated restore, not ready yet
    else:
        if log:
            print(f"File {key} is ready to process.")
        return True  # File is not in Glacier or Deep Archive, ready to process




# Example usage
if __name__ == "__main__":
    s3_client = boto3.client('s3')
    bucket_name = 'bucket'
    folder = 'folder/' # ends with slash!

    # Set dry_run to True for a dry run, False to actually process files
    dry_run = True

    while True:
        all_restored = True
        for key in list_files(bucket_name, folder, s3_client):
            process_parquet_file(bucket_name, key, s3_client, dry_run)
            all_restored = False

        if all_restored:
            print("All files processed.")
            break
        else:
            print("Waiting for files to be restored...")
            time.sleep(3600)  # Wait for some time before checking again