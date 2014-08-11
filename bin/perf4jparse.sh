#!/bin/bash

# grep $1 $2 | awk '{print $8}' | sort -r
#

grep "time\[" $1 | grep "$2" | cut -d" " -f8 | cut -d'[' -f2 | cut -d']' -f1 | sort -n


