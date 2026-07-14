#!/bin/bash

LOG_FILE="logs/toolbox.log"

log(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOG_FILE
}
