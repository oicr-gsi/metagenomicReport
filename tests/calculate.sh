#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

# For json file we do the md5sum
find . -name '*.json' | xargs md5sum
# For text file we do md5sum
find . -name '*.bracken' | xargs md5sum
