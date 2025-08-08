#!/bin/bash

cd jameslabel
helm dependency update && helm template . 2>&1
