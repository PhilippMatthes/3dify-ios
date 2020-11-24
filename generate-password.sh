#!/bin/bash

< /dev/urandom \
  LANG= \
  tr -dc a-zA-Z0-9 \
  | head -c 32 \
  | pbcopy \
  && pbpaste \
  && echo
