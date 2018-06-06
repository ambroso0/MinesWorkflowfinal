#!/bin/bash

# tar -zxvf concessions.tar.gz

VECT="concessions_agregees_2015_one.shp"
vec_RAST=("Hansen_GFC2015_treecover2000_00N_010E.tif" "Hansen_GFC2015_treecover2000_00N_020E.tif" "Hansen_GFC2015_treecover2000_10N_020E.tif" "Hansen_GFC2015_treecover2000_10N_030E.tif" "Hansen_GFC2015_treecover2000_10S_020E.tif")
# vec_OUT=("concessions1.tif" "concessions2.tif" "concessions3.tif" "concessions4.tif" "concessions5.tif"

# Create a counter to dynamically create vect_OUT
cnt=0
# Create an empty rast_sum variable
sum_sum=0
# Create an empty detailed_sum_rast.txt file
echo "" > detailed_rast_sum.txt

for i in "${vec_RAST[@]}"
do
    # increment the counter
    ((cnt+=1))
    
    RAST=$i
    echo "* processing: $RAST"

    # Get extent
    meta=`gdalinfo $RAST | grep 'Lower Left' | sed 's/Lower Left  (//g' |  sed 's/) (/,/g'`
    w=`echo ${meta}| awk -F ',' '{print $1}'`
    s=`echo ${meta}| awk -F ',' '{print $2}'`
    meta=`gdalinfo $RAST | grep 'Upper Right' | sed 's/Upper Right (//g' | sed 's/) (/,/g'`
    e=`echo ${meta}| awk -F ',' '{print $1}'`
    n=`echo ${meta}| awk -F ',' '{print $2}'`
    
    # Get resolution (necessary to use the -tap option to guarantee proper overlay with RAST)
    meta=`gdalinfo $RAST | grep 'Pixel Size' | sed 's/Pixel Size = //g' | sed 's/(//g' | sed 's/)//g' | sed 's/ - /, /g'`
    rez=`echo ${meta}| awk -F ',' '{print $1}'`

    # RASTerize VECT as 1 overlaying perfectly RAST using information just collected
    rm -f concessions$cnt.tif # Remove the file if it already exists
    gdal_rasterize -te $w $s $e $n -tr $rez $rez -tap -burn 1 -init 0 -co COMPRESS=LZW $VECT concessions$cnt.tif
    
    # Combine both rasters
    rm -f masked_$RAST # Remove the file if it already exists
    gdal_calc.py -A $RAST -B concessions$cnt.tif --co COMPRESS=LZW --outfile=masked_$RAST --calc="A*B"
    
    # Calculate pixels sum, multiply by surface (km2) and take percentage into account
    stat=`gdalinfo -stats masked_$RAST | grep 'Size is ' | sed 's/Size is //g' |  sed 's/) (/,/g'`
    xpx=`echo ${stat}| awk -F ',' '{print $1}'`
    ypx=`echo ${stat}| awk -F ',' '{print $2}'`
    cellmean=`gdalinfo -stats masked_$RAST | grep 'STATISTICS_MEAN=' | sed 's/STATISTICS_MEAN=//g' |  sed 's/) (/,/g'`
    rast_sum=`echo $cellmean*$xpx*$ypx*625/100/1000000 | bc`

    # Write the sum of each loop in a detailed file
    echo $rast_sum >> detailed_rast_sum.txt

    # Sum up the result of each loop
    sum_sum=`echo $sum_sum+$rast_sum | bc`
    
done

# write the total sum in a file
echo $sum_sum > rast_sum.txt