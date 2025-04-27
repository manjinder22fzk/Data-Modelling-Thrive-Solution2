# 🛠️ Thrive Conversations Data Pipeline (S3 ➔ MWAA ➔ Glue ➔ S3)

 ## 🚀 Solution 2 Overview

This is an additional solution that I have provided, designed with a more Data Engineering-focused and production-grade approach.  
The goal here was to replicate how real-world data pipelines are built and deployed in industry environments.

In this solution:

- I created a **CI/CD pipeline** using **GitHub Actions**.
- Developed a **Bash pipeline script** that:
  - Creates a virtual environment
  - Installs required Python libraries
  - Pushes the latest code changes automatically to the GitHub repository
- Upon pushing, **GitHub Actions** trigger a workflow that:
  - Initiates an **Apache Airflow (Amazon MWAA)** DAG
  - The Airflow DAG uploads the input files into an **S3 bucket**.
- An **AWS Glue Crawler** then:
  - Crawls the input directory
  - Creates tables inside the **AWS Glue Database**.
- A **AWS Glue ETL job** processes the data and:
  - Consolidates it according to the required logic
  - Dumps the final output back into the **S3 output directory** in **Parquet format**.
- Another **Glue Crawler** scans the output directory and:
  - Creates the final output table inside the **AWS Glue Database**.

You can find all related **screenshots**, **output files**, and the **Spark ETL script** inside this repository.

This solution reflects how modern data platforms automate and scale data ingestion, transformation, and storage efficiently.

## 📚 Project Overview

This project builds an AWS Data Pipeline that:

- Uploads raw user conversation files into an S3 input bucket.
- Triggers an MWAA (Managed Airflow) DAG through GitHub Actions.
- Uses AWS Glue Crawlers to create input tables.
- Runs a Glue ETL Job to transform and create a `consolidated_messages` fact table.
- Saves the final consolidated data back into an S3 output directory.
- Creates an output Glue table from the final consolidated data.

The architecture automates raw-to-analytics transformation without using Redshift, keeping everything serverless and cost-effective.

## ⚙️ Tech Stack

| Component         | Technology          |
| :---------------- | :------------------- |
| Orchestration     | AWS MWAA (Apache Airflow) |
| Storage           | Amazon S3            |
| ETL Jobs          | AWS Glue (Serverless Spark) |
| Metadata Catalog  | AWS Glue Crawlers    |
| CI/CD             | GitHub Actions       |
| Programming       | Python (Airflow DAG, Glue Job) |
| Infrastructure    | IAM Roles, Policies  |

## 🏗️ Project Structure

thrive-data-pipeline/ ├── raw_uploads/ │ ├── users/ │ ├── conversation_start/ │ └── conversation_parts/ ├── src/ │ └── airflow_dags/ │ └── upload_to_s3_dag.py ├── pipelines.sh ├── .github/ │ └── workflows/ │ └── cicd.yml ├── output/ ├── README.md


## 🚀 Pipeline Execution Flow

When new data or code is pushed to the `master` branch on GitHub:

- GitHub Actions automatically triggers:
  - Uploads `raw_uploads/` files to the `input/` folder inside the S3 bucket `thrive-bucket-96`.
  - Uploads updated Airflow DAGs (`upload_to_s3_dag.py`) to the MWAA S3 DAGs location.
  - Triggers the Airflow DAG `upload_to_s3_dag`.
- The Airflow DAG:
  - Uploads any new or changed local files into specific folders in S3 using `S3Hook`.
- AWS Glue Crawler (`thrive_input_crawler`):
  - Scans the `input/` directory in S3.
  - Creates and updates Glue tables for `users`, `conversation_start`, and `conversation_parts`.
- AWS Glue ETL Job (`thrive_transform_glue_job`):
  - Reads the source tables.
  - Creates a consolidated fact table called `consolidated_messages`.
  - Writes the transformed data into the S3 `output/` directory (`s3://thrive-bucket-96/output/consolidated_messages/`).
- AWS Glue Output Crawler (`thrive_output_crawler`):
  - Scans the `output/` directory.
  - Creates a Glue Catalog Table for the consolidated messages.

## 📄 Consolidated Messages Logic

The `consolidated_messages` table is created by combining:

- Data from `conversation_start` and `conversation_parts`.
- Mapped with `users` information.
- Only `is_customer = 1` users are included.
- Ordered by `conversation_id` and `created_at` timestamp.
- The output is partitioned and saved back into S3 in Parquet format.

## 🛠️ Important AWS Services Configurations

- **S3 Bucket:** `thrive-bucket-96`
- **MWAA Environment:** Hosting the Airflow DAGs.
- **IAM Role:** A custom IAM role created to allow Glue and MWAA access to S3 and metadata actions.
- **GitHub Secrets:**
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `MWAA_ENV_NAME`
  - `MWAA_WEB_SERVER_HOSTNAME`
- **Glue Crawlers:**
  - `thrive_input_crawler` (for input tables)
  - `thrive_output_crawler` (for consolidated output)
- **Glue Jobs:**
  - `thrive_transform_glue_job` (builds the consolidated messages)

## ✅ How to Trigger End-to-End Pipeline

1. Add/modify files under `raw_uploads/` (users, conversation_start, conversation_parts).
2. Run `pipelines.sh` to:
   - Create virtual environment.
   - Install dependencies.
   - Push code and data to GitHub.
3. GitHub Actions will:
   - Sync data to S3.
   - Upload DAGs.
   - Trigger MWAA Airflow DAG.
4. Airflow DAG will:
   - Upload new data into S3 input folders.
5. Glue Crawler (`thrive_input_crawler`) will:
   - Crawl input and update Glue catalog tables.
6. Glue Job (`thrive_transform_glue_job`) will:
   - Process and generate consolidated messages.
   - Save final table to `s3://thrive-bucket-96/output/consolidated_messages/`.
7. Glue Crawler (`thrive_output_crawler`) will:
   - Create the final `consolidated_messages` table from output.

## 📋 Final Data Output

- **Location:** `s3://thrive-bucket-96/output/consolidated_messages/`
- **Format:** Parquet
- **Access:** Query-ready through AWS Glue Catalog or Athena.

## 📚 Assumptions

- All users, conversations, and parts are valid and properly formatted.
- `created_at` fields are UNIX timestamp integers.
- Only `is_customer = 1` users are included for consolidated messages.

## 📢 Potential Future Improvements

- Add Data Quality Validation Glue Jobs.
- Add alerts for failed DAGs or Glue Jobs.
- Partition the consolidated output by `month` or `year`.
- Integrate Redshift Spectrum or Lake Formation for fine-grained access.
- Build Looker/Tableau dashboards directly on the consolidated S3 output.

---

# 🎯 Project Complete — Thrive Data Engineering Pipeline Fully Automated 🚀

## AWS Screenshots

![image](https://github.com/user-attachments/assets/f3daa4a6-2ed7-4f99-b295-495de37e1950)

![image](https://github.com/user-attachments/assets/d62bb92d-5736-4eac-bb90-cb5f6c0ac64a)

![image](https://github.com/user-attachments/assets/bf8fbcc4-8e74-41a5-92f0-3edb40ecf288)


![image](https://github.com/user-attachments/assets/abb181e2-95dd-47e3-a01f-28cf23158baf)





