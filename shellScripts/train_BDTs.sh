#!/bin/bash

bgDir=$BDT/processed/bg_medium_V5 #subdirectory for background files, under processDir
subDir=5-16_medium_V5 #subdirectory for weights, under weightsDir
simDir=$BDT/processed/sims_medium

processDir=$BDT/processed
trainMacro=$VEGAS/BDT/VegasBDTClassification.C # to be copied if macro doesn't exist in weights folder
logDir=$BDT/log
plotLog=$logDir/plotLog.txt # on
backupDir=$BDT/backup
weightsDir=$BDT/weights
plotDir=$BDT/plots
plotMacro=$VEGAS/BDT/MakePlots.C

#used in cmd to find appropriate sim files
array=ua # change to V6?
atm=22
wobble=050

runMode=print

zeniths="10 20 30 40"

args=`getopt -o b:qr:t:d:s:a:V: -l atm:,array: -- "$@"` # zeniths:
eval set -- ${args//\'/} # not sure why i have to do this, single quotes are being added around option arguments for some reason 
#echo ${args//\'/}
for i; do
    case "$i" in 
	-q) runMode=qsub
	    shift ;;       
	-r) runMode="$2"
	    shift 2 ;;
	-b) bgDir=$2
	    shift 2 ;;
	-d) subDir=$2
	    shift 2 ;;
	-s) simDir=$2
	    shift 2 ;;
	--array) array=$2
	    shift ; shift ;;
	--atm) atm=$2
	    shift ; shift ;;
	--) shift ; break ;;
    esac
done # loop over command line arguments 

if [ $1 ]; then
    zeniths=""
fi
while [ $1 ]; do
    zeniths="$zeniths $1"
    shift
done

trainDir=$weightsDir/$subDir 

echo "training directory: $trainDir"
echo "zeniths: $zeniths" 

logDirFull=$logDir/train_${subDir}
plotDirFull=$plotDir/${subDir}
for dir in $trainDir $logDirFull $plotDirFull; do
    if [ ! -d $dir ]; then
	echo "Must create directory: $dir"
	test $runMode == print ||  mkdir -p $dir
    fi
done # loop over necessary directories

#if macro doesn't exist in this directory, ask about copying and copy it over
for macro in $trainMacro $plotMacro; do 
    if [ ! -f $trainDir/${macro##*/} ]; then
	echo "Copy of macro $macro does not exist in $trainDir, must copy!"
	test $runMode == print || cp $macro $trainDir/
    fi
done

for z in $zeniths; do
    
    if [ ! -d $bgDir ]; then
	echo "directory: $bgDir with background files does not exist!"
	exit 1
    fi

    simZ=$z
    arrayLow=( 0 320 500 1000 )
    arrayHigh=( 320 560 1120 30000 )
    case $z in 
	10) 
	    simZ=00 ;; 
	20|30) ;;
	40) 
	    arrayLow=( 0 500 1000 )
	    arrayHigh=( 560 1120 30000 ) 
	    ;; 
	60) 
	    arrayLow=( 0 )
	    arrayHigh=( 30000 )
	    ;;
    esac # zenith cases
    numBinsE=${#arrayLow[@]}

    eBin=(0) # the energy bin index 
    while (( eBin < numBinsE )); do 

	eLow=${arrayLow[eBin]}
	eHigh=${arrayHigh[eBin]}

	fileNameBase="TMVAClassification_TestBDT_ELow${eLow}_EHigh${eHigh}_Zenith${z}"
	if [ ! -f $trainDir/${fileNameBase}.weights.xml ]
	then

	    cmd="root -l -b -q 'VegasBDTClassification.C(\"$bgDir\",\"$simDir/Oct2012_${array}_ATM${atm}_vegasv250rc5_7samples_${simZ}deg_${wobble}wobb\",\"${eLow}\",\"${eHigh}\",\"${z}\")'"  
	
	    echo $cmd
	    
	    plotCMD="root -l -b -q 'MakePlots.C(\"$trainDir/TestBDT_ELow${eLow}_EHigh${eHigh}_Zenith${z}.root\")'"

	    logFile=$logDirFull/${fileNameBase}.txt
	    plotLog=$logDirFull/plotLog.txt
	    if [ "$runMode" == "qsub" -o "$runMode" == "bash" ]; then
		if [ -f $logFile ]; then
		    if [ ! -d $backupDir/$subDir ]; then
			mkdir -p $backupDir/$subDir
		    fi
		    mv $logFile $backupDir/$subDir
		fi
	    fi

	    if [ $runMode != print ]; then
	    
		$runMode <<EOF
#PBS -S /bin/bash
#PBS -l nodes=1,mem=2gb
#PBS -j oe
#PBS -o $logFile
#PBS -N $fileNameBase

date
hostname
cd $trainDir
pwd
#cp $trainMacro .

$cmd
completion=\$?

echo "$cmd"

#mv ${trainMacro##*/} $logDirFull/
#cd $plotDirFull
#cp $plotMacro .

echo "$plotCMD" >> $plotLog # command goes into log first here
$plotCMD &>> $plotLog

#mv ${plotMacro##*/} $logDirFull

mv weights/${fileNameBase}.* . #weights/TMVAClassification_${fileNameBase}.*
mv plots/* $plotDirFull
#rmdir plots

if [ \$completion -ne 0 ]; then
mv $logFile $BDT/rejected/
exit 1 # failure 
fi

cp $logFile $BDT/completed/ 
exit 0 # successful exit 

EOF
   
	    fi	    # end if runMode != print
	fi # if this xml file does not exist yet
	eBin=$((eBin+1))
    done # loop over energy bins 
done # for loop over zenith

exit 0 # success
