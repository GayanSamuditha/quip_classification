#!/bin/bash

source ../../conf/variables.sh

mkdir -p ${MODIFIED_HEATMAPS_PATH}

# This script takes input from ${RAW_MARKINGS_PATH}/
# Check out ../download_markings/start.sh on how to prepare the input files

# Input folder to the downloaded markings
# This script will merge the markings
# with the unmodified heatmaps to output
# modified heatmaps.
# This script assumes that under this folder, there are
# two types of files:
#   1. files contain markings
#   2. files have selected lym&necrosis&smoothness weights
# For example:
#   ${RAW_MARKINGS_PATH}/TCGA-NJ-A55O-01Z-00-DX1_rajarsi.gupta__x__mark.txt
#   ${RAW_MARKINGS_PATH}/TCGA-NJ-A55O-01Z-00-DX1_rajarsi.gupta__x__weight.txt
# Checkout ../download_markings/main.sh on how to prepare those input files
MARKING_FOLDER=${RAW_MARKINGS_PATH}

# Path contains the svs slides
# This is just used for getting the height and width
# of the slides
SLIDES=${SVS_INPUT_PATH}

for files in ${MARKING_FOLDER}/*_weight.txt; do
    if [ ! -f ${files} ]; then
        continue;
    fi

    # Get slide id
    SVS=`echo ${files} | awk -F'/' '{print $NF}' | awk -F'__x__' '{print $1}'`
    # Get user name
    USER=`echo ${files} | awk -F'/' '{print $NF}' | awk -F'__x__' '{print $2}' | awk -F'_' '{print $1}'`

    # Get corresponding weight and marking files
    WEIGHT=${files}
    MARK=`echo ${files} | awk '{gsub("weight", "mark"); print $0;}'`

    if [ ! `ls -1 ${SLIDES}/${SVS}*.svs` ]; then
        echo "${SLIDES}/${SVS}.XXXX.svs does not exist. Trying tif..."
        SVS_FILE=`ls -1 ${SLIDES}/${SVS}*.tif | head -n 1`
    else
        SVS_FILE=`ls -1 ${SLIDES}/${SVS}*.svs | head -n 1`
    fi

    if [ -z "$SVS_FILE" ]; then
        echo "Could not find slide."
        continue;
    fi

    WIDTH=` openslide-show-properties ${SVS_FILE} \
          | grep "openslide.level\[0\].width"  | awk '{print substr($2,2,length($2)-2);}'`
    HEIGHT=`openslide-show-properties ${SVS_FILE} \
          | grep "openslide.level\[0\].height" | awk '{print substr($2,2,length($2)-2);}'`
    MPP=`openslide-show-properties ${SVS_FILE} \
          | grep "aperio.MPP" | awk '{print substr($2,2,length($2)-2)}'`

    matlab -nodisplay -singleCompThread -r \
    "get_modified_heatmap('${SVS}', ${WIDTH}, ${HEIGHT}, '${USER}', '${WEIGHT}', '${MARK}', ${MPP}); exit;" \
    </dev/null
done

cp ./modified_heatmaps/* ${MODIFIED_HEATMAPS_PATH}/

exit 0
