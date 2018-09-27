#!/usr/bin/env bash
# SPARK_CONF_DIR=executor $SPARK_HOME/sbin/start-master.sh
# SPARK_CONF_DIR=executor $SPARK_HOME/sbin/stop-master.sh spark://127.0.0.1:5737 5
SPARK_MASTER_HOST=0.0.0.0
SPARK_MASTER_PORT=5737
SPARK_MASTER_WEBUI_PORT=5770
SPARK_WORKER_CORES=16
SPARK_WORKER_DIR=executor/work
SPARK_LOCAL_DIRS=executor/local
SPARK_LOG_DIR=executor/logs
