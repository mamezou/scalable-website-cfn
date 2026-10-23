#!/bin/bash

# Config
S3_BUCKET_NAME="cfn-wordpress-multitemplate"
S3_BASE_PATH="wordpress"
AWS_REGION="ap-northeast-1"
TEMPLATE_DIR="./templates"
# 使う AWS プロファイルは環境変数 AWS_PROFILE で指定する (未設定なら既定の資格情報)
AWS_PROFILE="${AWS_PROFILE:-}"

# Determine if a profile is specified
if [ -n "$AWS_PROFILE" ]; then
  PROFILE_OPTION="--profile $AWS_PROFILE"
else
  PROFILE_OPTION=""
fi

# Function to check if S3 bucket exists, and create it if not
check_and_create_bucket() {
  echo "Checking if S3 bucket '${S3_BUCKET_NAME}' exists..."
  aws s3api head-bucket --bucket "${S3_BUCKET_NAME}" $PROFILE_OPTION > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo "S3 bucket '${S3_BUCKET_NAME}' does not exist. Creating..."
    aws s3 mb "s3://${S3_BUCKET_NAME}" --region "${AWS_REGION}" $PROFILE_OPTION

    if [ $? -ne 0 ]; then
      echo "Error: Failed to create S3 bucket '${S3_BUCKET_NAME}'."
      exit 1
    fi

    echo "S3 bucket '${S3_BUCKET_NAME}' created successfully."
  else
    echo "S3 bucket '${S3_BUCKET_NAME}' already exists."
  fi
}

# Function to upload to S3 and register in Parameter Store
upload_and_register() {
  local file_name=$1
  local s3_key="${S3_BASE_PATH}/${file_name}"
  local s3_url="https://${S3_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com/${s3_key}"
  local parameter_name="${file_name%.*}-url"

  # Replace backslashes with forward slashes (Windows compatibility)
  parameter_name=$(echo "${parameter_name}" | sed "s/'//g")

  echo "Uploading ${file_name} to S3..."
  aws s3 cp "${TEMPLATE_DIR}/${file_name}" "s3://${S3_BUCKET_NAME}/${s3_key}" --region "${AWS_REGION}" $PROFILE_OPTION

  if [ $? -ne 0 ]; then
    echo "Error: Failed to upload ${file_name} to S3."
    return
  fi

  # Debug log for parameter name and S3 URL
  echo "S3 URL: '${s3_url}'"
  echo "Generated Parameter Name: ${parameter_name}"

  echo "Registering ${parameter_name} in Parameter Store..."
  aws ssm put-parameter \
    --name "${parameter_name}" \
    --type String \
    --value "${s3_url}" \
    --overwrite \
    --region "${AWS_REGION}" $PROFILE_OPTION

  if [ $? -ne 0 ]; then
    echo "Error: Failed to register ${parameter_name} in Parameter Store."
    return
  fi

  echo "Uploaded and registered: ${file_name} -> ${parameter_name}"
}

# Main process
if [ ! -d "${TEMPLATE_DIR}" ]; then
  echo "Error: Template directory '${TEMPLATE_DIR}' does not exist."
  exit 1
fi

# Check and create the S3 bucket if necessary
check_and_create_bucket

# Process templates in the directory
for file in $(ls "${TEMPLATE_DIR}"); do
  if [[ $file == *.yml || $file == *.yaml ]]; then
    upload_and_register "$file"
  else
    echo "Skipping non-template file: $file"
  fi
done

echo "All templates have been uploaded and registered in Parameter Store."