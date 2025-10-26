#!/bin/bash

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

NO_EMBEDDINGS=false

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

if [ -d "$REPO_DIR" ]; then
    echo "Repository already cloned, fetching latest changes"
    (cd $REPO_DIR && git fetch)
else
    echo "Cloning aws-samples/bedrock-access-gateway repository"
    git clone --depth 1 https://github.com/aws-samples/bedrock-access-gateway $REPO_DIR
fi

cp -r $REPO_DIR/src/api app/api
cp $REPO_DIR/src/requirements.txt layer/requirements.txt

echo "" > app/requirements.txt

# Apply patches
echo "Applying patches"
(cd $REPO_DIR/src && patch -p1 < ../../../patches/auth.py.patch)
(cd $REPO_DIR/src && patch -p1 < ../../../patches/app.py.patch)
(cd $REPO_DIR/src && patch -p1 < ../../../patches/requirements.txt.patch)
(cd $REPO_DIR/src && patch -p1 < ../../../patches/pydantic-version.patch)

if [ "$NO_EMBEDDINGS" = true ]; then
    echo "Applying no-embeddings patch"
    (cd $REPO_DIR/src && patch -p1 < ../../../patches/no-embeddings.patch)
fi

# Update boto3/botocore to latest versions
for pkg in boto3 botocore; do
    VERSION=$(pip index versions $pkg 2>/dev/null | grep -m 1 "LATEST: " | awk '{print $2}')
    if [ -n "$VERSION" ]; then
        sed -i.bak "s/$pkg==.*/$pkg==$VERSION/g" layer/requirements.txt && rm layer/requirements.txt.bak
    fi
done
