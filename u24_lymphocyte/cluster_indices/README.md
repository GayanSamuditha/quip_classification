# Survival Curve Pipline


1. We first need to convert pathology images that have infiltrating lymphocytes identified (CNN outputs) into csv files (input of cluster indices).

You need to modify

`gen_csv.sh`

i. `CNNOUTPUT`: output of the CNN, the folder containing subfolders with the name `rates-cancertype-all-auto`.

ii. `CSVFOLDER`: any name for the folder of csv files (this folder will be created automatically)

iii. `OUTFOLDER`: any name for the folder of results of cluster indices (this folder will be created automatically



2. These csvs can be processed by an R script which runs spatial statistics on presense/absence data.
    > `nohup ./run_all.sh input_full.csv 6 > output.log &`

    Be aware that files consume varying amounts of memory and if memory is full, threads will fail.


3. `collateClusterIdx.sh` collects all the statistics into csv files.


4. These were then sent to MD Anderson for surival curve analysis.

