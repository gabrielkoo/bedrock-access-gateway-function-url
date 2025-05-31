#!/bin/bash

export PYTHON_VERSION=3.12
export  SAM_CLI_TELEMETRY=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-embeddings)
      NO_EMBEDDINGS="--no-embeddings"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$AWS_EXECUTION_ENV" == "CloudShell" ]]; then
  echo "You are running in AWS CloudShell, installing Python $PYTHON_VERSION..."
  sudo yum update -y
  sudo yum install -y python$PYTHON_VERSION python$PYTHON_VERSION-pip
  sudo yum clean all
else
  USE_CONTAINER="--use-container"
fi

./prepare_source.sh $NO_EMBEDDINGS

sam build $USE_CONTAINER

if [[ ! -z "$CI" ]]; then
  exit
fi

sam deploy --guided
