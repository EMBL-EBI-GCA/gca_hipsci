#!/bin/bash

FROM=/nfs/research2/hipsci/drop/hip-drop/tracked
TO=/hps/nobackup/research/hipsci/tracked
REGEX='.*\.vcf(\.gz)?(\.tbi)?'

find $FROM -regextype posix-awk -regex $REGEX -printf %P\\0 | rsync -ptgo --files-from=- --from0 ${FROM}/ $TO

FROM=/nfs/research2/hipsci/controlled
TO=/hps/nobackup/research/hipsci/controlled
REGEX='.*\.vcf(\.gz)?(\.tbi)?'

find $FROM -regextype posix-awk -regex $REGEX -printf %P\\0 | rsync -ptgo --files-from=- --from0 ${FROM}/ $TO
