#!/bin/bash
PATH=$PATH:$LAMBDA_TASK_ROOT/bin \
    PYTHONPATH=$LAMBDA_TASK_ROOT:$PYTHONPATH:/opt/python \
    exec python3 api/app.py
