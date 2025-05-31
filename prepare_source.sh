#!/bin/bash

# Display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Prepare source code for bedrock-access-gateway deployment"
    echo ""
    echo "Options:"
    echo "  --help, -h       Display this help message and exit"
    echo "  --no-embeddings  Remove embeddings related code and dependencies"
    echo ""
}

# Function to perform sed operation and remove backup file
sed_edit() {
    local pattern="$1"
    local file="$2"
    sed -i.bak "$pattern" "$file" && rm "${file}.bak"
}

# Initialize variables
NO_EMBEDDINGS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --no-embeddings)
            NO_EMBEDDINGS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

REPO_DIR="build/bedrock-access-gateway"

mkdir -p build

rm -rf app/api
rm -f layer/requirements.txt

# Check if the repository is already cloned
if [ -d "$REPO_DIR" ]; then
    echo "Repository already cloned, fetching latest changes"
    # fetch latest changes
    (
        cd $REPO_DIR
        git fetch
    )
else
    echo "Cloning aws-samples/bedrock-access-gateway repository"
    git clone --depth 1 https://github.com/aws-samples/bedrock-access-gateway $REPO_DIR
fi

cp -r $REPO_DIR/src/api app/api

# Remove "Manum" from requirements.txt, as LWA is used instead.
grep -v "mangum" $REPO_DIR/src/requirements.txt > layer/requirements.txt
grep -v "Mangum" $REPO_DIR/src/api/app.py > app/api/app.py

# Check if --no-embeddings flag is set
if [ "$NO_EMBEDDINGS" = true ]; then
    echo "Deleting embeddings related code and dependencies"

    # Apply patterns to specific files directly

    # For app/api/models/bedrock.py
    sed_edit '/^import numpy/d' "app/api/models/bedrock.py"
    sed_edit '/^import tiktoken/d' "app/api/models/bedrock.py"
    sed_edit '/^ENCODER = /d' "app/api/models/bedrock.py"
    # This removes the final part which consists of embedding related code
    sed_edit '/^class BedrockEmbeddingsModel/,$d' "app/api/models/bedrock.py"

    # For app/api/app.py
    # Remove import of the embeddings model
    sed_edit 's/, embeddings//g' "app/api/app.py"
    # Remove the route for embeddings
    sed_edit '/embeddings.router/d' "app/api/app.py"

    # For layer/requirements.txt
    sed_edit '/^tiktoken/d' "layer/requirements.txt"
    sed_edit '/^numpy/d' "layer/requirements.txt"
fi

# Pydantic need to be >= 2.10.4 in order to fix a installation issue
sed_edit 's/pydantic==.*/pydantic>=2.10.4/g' layer/requirements.txt

# Update boto3/botocore to latest versions
for pkg in boto3 botocore; do
    # pip index versions is no longer experimental from pip 25.1
    VERSION=$(pip index versions $pkg | grep -m 1 "LATEST: " | awk '{print $2}')
    if [ -n "$VERSION" ]; then
        sed_edit "s/$pkg==.*/$pkg==$VERSION/g" layer/requirements.txt
    fi
done
