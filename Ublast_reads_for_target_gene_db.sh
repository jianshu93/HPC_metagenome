#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Function: this script calculate the coverage of target functional gene(s) in different samples appling ublast.

   Usage: ./Ublast_reads_for_target_genes.sh target_gene_dir reads_dir max_jobs

   [target_genes_dir]: Path to target genes, all the genes should be cat into one fasta file (it dosen't matter Nucleic or Protein sequence).
   Note: The fa file should be named the same as the folder's name.

   [reads_dir]: Folder path to the clean reads must be in FastQ format, and filenames must follow the format: <name>_<sis>.fastq, where <name> is the sample name, and <sis> is 1 or 2 indicating which sister read the file contains. Use only '1' as <sis> if you only want to use single reads to generate a fast calculation.

   [max_jobs]	(optional) Maximum number of jobs to run in parallel. By default: 5.

   Please be cautious that the parameters of ublast (~/bin_scripts/run_ublast.slurm) can be modified according to your own purposes!
   " >&2 ;
   exit 1 ;
fi ;
if [[ "$3" == "" ]] ; then
    MAX=5 ;
else
    let MAX=$3+0 ;
fi ;

target_genes=$(readlink -f $1) ;
target_gene_name=$(basename $target_genes)
reads_dir=$(readlink -f $2)
pac=$(dirname $(readlink -f $0)) ;
cwd=$(pwd) ;

## generate index and the length of target_genes
sed -i 's/ /_/g' $target_genes/${target_gene_name}.fa
### length
if [ ! -f "$target_genes/${target_gene_name}_length" ] ; then
  sed 's/ /_/g' $target_genes/${target_gene_name}.fa | awk '/^>/&&NR>1{print "";}{ printf "%s",/^>/ ? $0" ":$0 }' | awk '{print $1"\t"length($2)}' | sed -e 's/^>//' | sort -k1,1 > $target_genes/${target_gene_name}_length ;
else
  ### index for ublast (optional)
  ## PATH/TO/usearch -makeudb_ublast $target_genes -output $target_genes/${target_gene_name}.udb
  k=0 ;
  for i in $reads_dir/*.fastq ; do
    EXTRA="" ;
    EXTRA_MSG="" ;
    if [[ $k -ge $MAX ]] ; then
       let prek=$k-$MAX ;
       echo "There remained $prek fastq file"
       EXTRA="-W depend=afterany:${jids[$prek]}" ;
       EXTRA_MSG=" (waiting for ${jids[$prek]})" ;
    else
      b=$(basename $i) ;
      b_n=$(basename $i .fastq)
      # Launch job
      jids[$k]=$(sbatch --export="READ_DIR=$reads_dir,SAMPLE=$b,TARGET=$target_genes/${target_gene_name}.fa" -J "ublast-$b_n" -o "out-$b_n.log" $pac/run_ublast.slurm | grep .) ;
      echo "$b: ${jids[$k]}$EXTRA_MSG" ;
    fi ;
    let k=$k+1 ;
  done ;
fi
