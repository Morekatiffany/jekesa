#!/bin/bash

if ! [ -d $confindrDir ]; then
  echo "creating confindr work directory"
  mkdir -p $confindrDir
fi
confindrDB=$DATABASES_DIR/confindr_db
 
for read1 in $trimmedReads/*_R1_*.fq.gz
do
  if [ -s $read1 ];then
  fq=$(echo $read1 | awk -F "_R1" '{print $1 "_R2"}')
  fqfile=$(basename $fq)
  read2=$(find $trimmedReads -name "${fqfile}*val_2.fq.gz")
  #outdir for each name
  name=$(basename $read1 | awk -F '_S' '{print $1}')

  ln -s $read1 $confindrDir/${name}_R1.fastq.gz
  ln -s $read2 $confindrDir/${name}_R2.fastq.gz
  fq1=$confindrDir/${name}_R1.fastq.gz
  fq2=$confindrDir/${name}_R2.fastq.gz

  mkdir -p $confindrDir/${name}
  echo "$confindrDir/${name}"

  confindr.py -t $threads -i ${confindrDir}/ -o ${confindrDir}/${name} -d $confindrDB
  rm $fq1 $fq2
 fi
done
# check contamination in previously assembled genomes
if [ -d "$spadesDir/previousContigs" ]; then
 
 for contFile in $spadesDir/previousContigs/*_assembly.fasta
      do
        id=$(basename -s _assembly.fasta $contFile)
        conf_out=$confindrDir/$id
        if ! [ -d $conf_out ]; then
          mkdir -p $conf_out
        fi
	
	ln -s $contFile $conf_out 
	confindr.py --fasta -t $threads -i $conf_out -o $conf_out -d $confindrDB
 done
fi

# Save confindr results in one .csv file
cat ${confindrDir}/*/*_report.csv > ${confindrDir}/confindr_merged.csv
echo "Sample,Genera_present,ContaminationPresent" > ${confindrDir}/${projectName}-confindr-final.csv
grep -v "^Sample,Genus,NumContamSNVs" ${confindrDir}/confindr_merged.csv | \
sed 's/_.*1,/,/g' | cut -d "," -f1,2,4,5 | \
awk -F ',' '{print $1,$2,$3" ("$4"%)"}' OFS="," >> ${confindrDir}/${projectName}-confindr-final.csv

# Convert confindr results to .xlsx file
Rscript $SCRIPTS_DIR/csv2xlsx.R $confindrDir/${projectName}-confindr-final.csv \
$reportsDir/04.confindr.xlsx >> $project/tmp/04.confindr.csv2xlsx.log 2>&1
