import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.transforms import *
from awsglue.job import Job
from pyspark.sql import functions as F

# Initialize contexts
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init('consolidated_messages_job', args={})

# Paths / Constants
s3_output_path = "s3://thrive-bucket-96/output/consolidated_messages/"

# Load the data from Glue Catalog
users = glueContext.create_dynamic_frame.from_catalog(database="thrive_project_db", table_name="inputusers")
conversation_start = glueContext.create_dynamic_frame.from_catalog(database="thrive_project_db", table_name="inputconversation_start")
conversation_parts = glueContext.create_dynamic_frame.from_catalog(database="thrive_project_db", table_name="inputconversation_parts")

# Convert to Spark DataFrames
users_df = users.toDF()
conversation_start_df = conversation_start.toDF()
conversation_parts_df = conversation_parts.toDF()

# Build dimension tables
dim_users_df = users_df.select(
    F.col("id").alias("user_id"),
    "email",
    "name",
    "is_customer"
)

dim_conversation_parts_df = conversation_parts_df.select(
    F.col("id").alias("part_id"),
    "conversation_id",
    F.col("part_type"),
    F.col("created_at")
)

# Build consolidated_messages
# 1. Conversation Start messages (open)
conversation_start_messages = (
    conversation_start_df.alias('cs')
    .join(users_df.alias('u'), F.col('cs.conv_dataset_email') == F.col('u.email'), 'inner')
    .filter(F.col('u.is_customer') == 1)
    .select(
        F.col('u.id').alias('user_id'),
        F.col('cs.conv_dataset_email').alias('email'),
        F.col('cs.id').alias('conversation_id'),
        F.col('cs.message').alias('message'),
        F.lit('open').alias('message_type'),
        F.col('cs.created_at')
    )
)

# 2. Conversation Parts messages
conversation_parts_messages = (
    conversation_parts_df.alias('cp')
    .join(conversation_start_df.alias('cs'), F.col('cp.conversation_id') == F.col('cs.id'), 'inner')
    .join(users_df.alias('u'), F.col('cs.conv_dataset_email') == F.col('u.email'), 'inner')
    .filter(F.col('u.is_customer') == 1)
    .select(
        F.col('u.id').alias('user_id'),
        F.col('cp.conv_dataset_email').alias('email'),
        F.col('cp.conversation_id'),
        F.col('cp.message'),
        F.col('cp.part_type').alias('message_type'),
        F.col('cp.created_at')
    )
)

# Union both datasets
consolidated_messages_df = conversation_start_messages.union(conversation_parts_messages)

# Handle conversation starters who are not customers
non_customer_starters = (
    conversation_start_df.alias('cs')
    .join(conversation_parts_df.alias('cp'), F.col('cs.id') == F.col('cp.conversation_id'), 'inner')
    .join(users_df.alias('u'), F.col('cp.conv_dataset_email') == F.col('u.email'), 'inner')
    .filter(F.col('u.is_customer') == 1)
    .select(
        F.col('u.id').alias('user_id'),
        F.col('cs.conv_dataset_email').alias('email'),
        F.col('cs.id').alias('conversation_id'),
        F.col('cs.message'),
        F.lit('open').alias('message_type'),
        F.col('cs.created_at')
    ).subtract(
        consolidated_messages_df.select('user_id', 'email', 'conversation_id', 'message', 'message_type', 'created_at')
    )
)

# Add non_customer_starters into consolidated_messages
consolidated_messages_df = consolidated_messages_df.union(non_customer_starters)

# Add Auto-increment ID by using row_number
from pyspark.sql.window import Window
windowSpec = Window.orderBy("conversation_id", "created_at")
consolidated_messages_df = consolidated_messages_df.withColumn(
    "id", F.row_number().over(windowSpec)
)

# Reorder columns (optional but nice)
consolidated_messages_df = consolidated_messages_df.select(
    "id", "user_id", "email", "conversation_id", "message", "message_type", "created_at"
)

# Write output back to S3
consolidated_messages_df.write.mode('overwrite').parquet(s3_output_path)

job.commit()
