#!/bin/bash

# Determine if project exports a binary
export BIN_DIR=`nimble dump | grep binDir: | sed -e 's/binDir: //g' | sed -e 's/"*//g'`
export BIN=`nimble dump | grep bin: | sed -e 's/bin: //g' | sed -e 's/"*//g'`

if [[ ! -z "$BIN" ]]
then
  if [[ -z "$BIN_DIR"]]
  then
    BIN_DIR=bin
  fi
  # Install dependencies & build binary
  nimble install -y -d
  nimble build -y
else
  # Install as library
  nimble install -y
fi
