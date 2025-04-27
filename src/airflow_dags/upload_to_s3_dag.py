from airflow import DAG
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
import os
import logging

# Constants
S3_BUCKET = 'thrive-bucket-96'
CONN_ID = 'aws_default'  # Airflow MWAA will automatically use this connection

def upload_file_to_s3(**kwargs):
    changed_file_path = kwargs['dag_run'].conf.get('changed_file_path')

    
    if not changed_file_path:
        raise ValueError("No changed file path passed to DAG.")

    filename = os.path.basename(changed_file_path)

    if 'users/' in changed_file_path:
        s3_key = f'input/users/{filename}'
    elif 'conversation_start/' in changed_file_path:
        s3_key = f'input/conversation_start/{filename}'
    elif 'conversation_parts/' in changed_file_path:
        s3_key = f'input/conversation_parts/{filename}'
    else:
        raise ValueError("Unknown subfolder for file: " + changed_file_path)

    try:
        s3 = S3Hook(aws_conn_id=CONN_ID)
        s3.load_file(
            filename=changed_file_path,
            key=s3_key,
            bucket_name=S3_BUCKET,
            replace=True
        )
        logging.info(f"Successfully uploaded {changed_file_path} to s3://{S3_BUCKET}/{s3_key}")
    except Exception as e:
        logging.error(f"Failed to upload {changed_file_path} to S3. Error: {str(e)}")
        raise

default_args = {
    'owner': 'airflow',
    'start_date': days_ago(1),
    'retries': 1,
}

with DAG(
    dag_id='upload_to_s3_dag',  # or 'upload-to-s3-dag', be consistent across project
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    description='Upload new local files to corresponding S3 folders when triggered',
    tags=['s3', 'upload', 'ci-cd']
) as dag:

    upload_task = PythonOperator(
        task_id='upload_file_to_s3',
        python_callable=upload_file_to_s3,
    )
