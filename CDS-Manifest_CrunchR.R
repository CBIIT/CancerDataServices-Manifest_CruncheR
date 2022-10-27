#!/usr/bin/env Rscript

#Cancer Data Services - Manifest CruncheR

#This script will download data from a bucket, or data from a directory, and concatenate it for verification and indexing manifest creation.

##################
#
# USAGE
#
##################

#Run the following command in a terminal where R is installed for help.

#Rscript --vanilla CDS-Manifest_CruncheR.R --help


##################
#
# Env. Setup
#
##################

#List of needed packages
list_of_packages=c("dplyr","readr","stringi","readxl","optparse","tools")

#Based on the packages that are present, install ones that are required.
new.packages <- list_of_packages[!(list_of_packages %in% installed.packages()[,"Package"])]
suppressMessages(if(length(new.packages)) install.packages(new.packages))

#Load libraries.
suppressMessages(library(dplyr,verbose = F))
suppressMessages(library(readr,verbose = F))
suppressMessages(library(stringi,verbose = F))
suppressMessages(library(readxl,verbose = F))
suppressMessages(library(optparse,verbose = F))
suppressMessages(library(tools,verbose = F))

#remove objects that are no longer used.
rm(list_of_packages)
rm(new.packages)


##################
#
# Arg parse
#
##################

#Option list for arg parse
option_list = list(
  make_option(c("-b", "--bucket"), type="character", default=NULL, 
              help="The base AWS bucket location of the files, e.g. s3://bucket.location.is.here/", metavar="character"),
  make_option(c("-g", "--grep"), type="character", default=NULL, 
              help="The term/pattern that will filter the submission files from the rest of the files in the bucket. To test your grep term, please try the following command in command line interface: aws s3 ls --recursive s3://bucket.location.is.here/ | grep 'grep_term'.", metavar="character"),
  make_option(c("-d", "--directory"), type="character", default=NULL, 
              help="If all the files are already downloaded from a bucket into a directory, selecting this option will bypass the bucket portion of the script and concatenate the submission templates that are available in the directory.", metavar="character"),
  make_option(c("-t", "--template"), type="character", default=NULL, 
              help="dataset template file, CDS_submission_metadata_template-v1.3.xlsx", metavar="character")
)

#create list of options and values for file input
opt_parser = OptionParser(option_list=option_list, description = "\nManifest_CruncheR\n v.1.3.1\n\nPlease supply the following script with the AWS bucket location and grep term or a directory with the submission templates, and the CDS template file.")
opt = parse_args(opt_parser)

#If no template is presented, return --help, stop and print the following message.
if (is.null(opt$template)){
  print_help(opt_parser)
  cat("Please supply the template file (-t), CDS_submission_metadata_template-v1.3.xlsx.\n\n")
  suppressMessages(stop(call.=FALSE))
}

#If no options are presented, return --help, stop and print the following message.
if (is.null(opt$directory)){
  if (is.null(opt$bucket)|is.null(opt$grep)){
    print_help(opt_parser)
    cat("Please either supply both the bucket path for the AWS files (-b) and the grep term (-g), or a directory (-d) with the submission files present.\n\n")
    suppressMessages(stop(call.=FALSE))
  }
}

#Data file pathway
base_bucket=opt$bucket

#Grep term
grep_term=opt$grep

#Directory path if files are already downloaded
new_dir=opt$directory

#Template file pathway
template_path=file_path_as_absolute(opt$template)

#set working directory based on where the script is run.
wd=getwd()

#A start message for the user that the validation is underway.
cat("The data files are being gathered and concatenated.\n")


#############################
#
# Obtain metadata submission files
#
#############################

#If a directory with submission files was presented, skip over this step to pull submission files from a bucket.
if (is.null(new_dir)){
  
  #based on the bucket location and grep term, obtain a list of the entire bucket.
  metadata_files=system(command = paste("aws s3 ls --recursive ", base_bucket, " | grep ",grep_term,sep = ""),intern = TRUE)
  
  #remove double white space until there is only a single white space between fields is left.
  while (any(grepl(pattern = "  ",x = metadata_files))==TRUE){
    metadata_files=stri_replace_all_fixed(str = metadata_files,pattern = "  ",replacement = " ")
  }
  
  #Based on the single white space field, pull out the file name and directory path.
  for (bucket_file in 1:length(metadata_files)){
    metadata_files[bucket_file]=stri_split_fixed(str = metadata_files[bucket_file],pattern = " ",n = 4)[[1]][4]
    metadata_files[bucket_file]=paste(base_bucket,metadata_files[bucket_file],sep = "")
  }
  
  #Obtain a list of directories in the working directory path
  dirs=list.dirs(wd)
  
  #Create a new directory name for the files that are about to be downloaded.
  new_dir=stri_split_fixed(str = base_bucket,pattern = "/")[[1]][3]
  
  new_dir=paste(new_dir,
                "_",
                stri_replace_all_fixed(
                  str = Sys.Date(),
                  pattern = "-",
                  replacement = "_"),
                sep="")
  
  #Check to see if the directory already exists, helps prevent too many directories or rewriting over directories that already exists.
  suppressMessages(if (!any(dirs %in% new_dir)){
    system(command = paste("mkdir ",wd,"/",new_dir,sep = ""))
  })
  
  #Runs the download command for aws into the output directory.
  for (bucket_file_download in metadata_files){
    system(command = paste("aws s3 cp ",bucket_file_download," ",wd,"/",new_dir,"/.",sep = ""),intern = TRUE)
  }
  
}

#Read in blank metadata from template
df_meta_temp=suppressMessages(read_xlsx(path =template_path,sheet = "Metadata", col_types = "text"))

#Setup collection data fram from template.
df_all=df_meta_temp

#Set file path for metadata files.
metadata_file_dir=paste(wd,new_dir,"",sep = "/")

#List files in file path
file_list=list.files(path = metadata_file_dir)

#Determine the extension for each file and then determine the correct read input.
for (file in file_list){
  ext=tolower(stri_reverse(stri_split_fixed(str = stri_reverse(file),pattern = ".",n=2)[[1]][1]))
  file_path=paste(metadata_file_dir,file,sep = "")
  #Read in metadata page/file to check against the expected/required properties. 
  #Logic has been setup to accept the original XLSX as well as a TSV or CSV format.
  if (ext == "tsv"){
    df=suppressMessages(read_tsv(file = file_path, guess_max = 1000000, col_types = cols(.default = col_character())))
  }else if (ext == "csv"){
    df=suppressMessages(read_csv(file = file_path, guess_max = 1000000, col_types = cols(.default = col_character())))
  }else if (ext == "xlsx"){
    df=suppressMessages(read_xlsx(path = file_path,sheet = "Metadata", guess_max = 1000000, col_types = "text"))
  }else{
    stop("\n\nERROR: Please submit a data file that is in either xlsx, tsv or csv format.\n\n")
  }
  
  #Bind the newly read data frame to the running total data frame.
  df_all=bind_rows(df_all,df)
}

#remove duplicate rows.
df_all=unique(df_all)

#create output file name               
output_file=paste("MetaMerge",
                  stri_replace_all_fixed(
                    str = Sys.Date(),
                    pattern = "-",
                    replacement = ""),
                  sep="")                 

#write out the combined metadata sheet as a file in tsv format.
write_tsv(x = df_all,file = paste(wd,"/",output_file,".tsv",sep = ""),na="")

cat(paste("\n\nProcess Complete.\n\nThe output file can be found here: ",wd,"/\n\n",sep = "")) 
