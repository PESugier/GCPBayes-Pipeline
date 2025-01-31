#!/bin/bash

#===============================================================================
#           USAGE:  ./00_Global_run_GCPBayes.sh file_ref_parameter.ini
#
#     DESCRIPTION:  global codes to run the GCPBayes pipeline : this code encapsulate all the different procedures in one running code, 
#                                                               with all the parameters to be specified by the user in a separated .ini file
#
#===============================================================================
#          AUTHOR:  Pierre-Emmanuel Sugier, Yazdan Asgari
#         VERSION:  Pierre-Emmanuel Sugier
#         CREATED:  2021-11-23
#        REVISION:  2022-07-11
# WARNINGS N BUGS:  
#                   .txt or not .txt, that is the question !
#    NOTES N TODO:  
#                   Run HS
#                   Manhattan Plots (global figure)
#                   Figure per group with theta > theta_exploration
#                   Figure for PLACO?
#                   Parameter chr_start chr_end : add in scripts + maybe it is better to consider a list (more flexible)
#                   All strategy based on covariance matrix estimated from a genetic LD matrix from reference, to build IN the codes step 4 (gcpaybes_corr_ref to implement)
#                   
# ================================================================================
#      PARAMETERS:  
#               
#                  ---to specify by user
#     
#                       work_dir                             - working directory (to put files of each step)
#                       output_dir                           - output directory (to put all final outputs)
#                       script_dir                           - directory with all the scripts
#                       
#                       theta_exploration=0.1              - threshold for theta values obtained from DS to run the group with HS
#                       theta_plot=0.5                     - theta value threshold (with DS or HS) to plot the group
#                       gcpaybes_corr_ref="FALSE"          - to perform GCPBayes by using a reference matrix (values: "TRUE" or "FALSE")
#
#                       group_clump_threshold=500          - length threshold used to consider groups (more longer genes are only performed with previous LD clumping if toclump="TRUE")
#                       group_absolute_threshold=1200      - length threshold used to consider groups (analysis will not be performed for more longer genes / If toclump=TRUE", this threshold is evaluated after clumping)
#                       placo_pval_threshold=0.05          - threshold used for decorrelating the Z-scores (in PLACO)
#                       toclump="TRUE"                     - If perform LD Clumping or not (value: TRUE or FALSE)
#                       clump_threshold_r2   =0.8          - LD threshold used for the LD clumping based on r²
#                       clump_threshold_kb=10000           - Maximum distance in based pair used to consider clumping
#                       clump_threshold_p=0.99             - Threshold based on p for ld clumping
#                       
#                       short_data1                          - short name to call dataset 1
#                       short_data2                          - short name to call dataset 2
#
#                       Input_file_trait1                    - input file name for dataset 1
#                       path_inputfile_trait1                - path for dataset 1
#                       Input_file_trait2                    - input file name for dataset 2
#                       path_inputfile_trait2                - path for dataset 2
#                       
#                       chr_start=1                        - first chromosome considered for analysis
#                       chr_end=22                         - last chromosome considered for analysis
#                       
#                       info_threshold=0.9                 - threshold used for minimum imputation quality of SNPs (GWAS QC)
#                       MAF_threshold=0.05                 - threshold used for minimum MAF (GWAS QC)
#
#                       
#                   ---Hard coded inside scripts that are called by the pipeline ---    
#
#                       -> Maximum distance in based pair used to consider clumping (used for example kb=10000)
#                       -> Threshold based on p (used for example p=0.99)
#                         
#                       
# ================================================================================					
#           INPUTS:  
#                   - GWAS data reformatted for each dataset			
#					   An example of the first lines of an input file (reformatted) is:
#                   - reference bfiles for ldclumping
#                   - reference file for annotations
#                   - 
# ================================================================================
#          DIFFERENT STEPS:
#                    
#                    Step 1 : To extract common SNPs between dataset
#                    Step 2 : To run PLACO on each dataset
#                    Step 3 : To perform LD Clumping (locally)
#                    Step 4 : To prepare the GCPBayes inputs in the right format
#                    Step 5 : To get correct list of groups for further analysis according to wanted threshold (length of groups)
#                    Step 6 : To run GCPBayes (DS)
#                    Step 7 : To run GCPBayes (HS) on groups with theta > theta_exploration
#                    Step 8 : To plot figures
#                    
# ================================================================================                   
#          OUTPUTS:  
#                   Results tables for DS
#                   Results tables for HS (to add)
#                   Results for PLACO for each phenotype
#                   Manhattan Plot (to add)
#                   Figures per genes (to add)
#                   Figures for PLACO ?
# ================================================================================                 
#    REQUIREMENTS:  R
# 	 REQUIRED LIBRARIES
# libraries used in the code
# please install the following packages if needed
#     if (!require("BiocManager", quietly = TRUE))
#         install.packages("BiocManager")
#     BiocManager::install(version = "3.15")
#     BiocManager::install("devtools")
#     install.packages('tictoc')
#     BiocManager::install("arm")
#     library(devtools)
#     devtools::install_github("https://github.com/cran/bglm")
#     devtools::install_github("https://github.com/nyiuab/BhGLM.git")
#     devtools::install_github("https://github.com/tbaghfalaki/GCPBayes")
#     BiocManager::install("vroom")
#     BiocManager::install("dplyr")
#     BiocManager::install("data.table")
#     BiocManager::install("tidyr")
#     BiocManager::install("tidyverse")
#     install.packages("optparse")
# ================================================================================

## REQUIRED INFORMATIONS
##########################################################################################################################################

ref_file_parameters="$1"

source $ref_file_parameters



##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##########################################################################################################################################
##       START RUN       ##
###########################

# STEP 1 - To extract common SNPs between dataset
#####################################################

Rscript ${script_dir}/C1_code_find_common_snps_one_pair.R \
											--path1 ${path_inputfile_trait1} \
											--file1 ${Input_file_trait1} \
											--path2 ${path_inputfile_trait2} \
											--file2 ${Input_file_trait2} \
											--pathout ${work_dir} \
											--out1 ${output_step1}_${short_data1}_common_${short_data2} \
											--out2 ${output_step1}_${short_data2}_common_${short_data1} \
											--info ${info_threshold} \
											--maf ${MAF_threshold}

# Step 2 - To run PLACO on each dataset
#####################################################

if  $toclump ; then
  if  -e ${work_dir}/${output_step2}_${short_data1}_${short_data2}.txt  # this step does not run if a corresponding output file already exist
  then
    echo "A corresponding PLACO output is present in the work directory and is going to be used."
  else
    Rscript ${script_dir}/C2_code_run_PLACO_decor_one_pair.R \
        --path ${work_dir} \
        --file1 ${output_step1}_${short_data1}_common_${short_data2} \
        --file2 ${output_step1}_${short_data2}_common_${short_data1} \
        --pathout ${work_dir} \
        --out ${output_step2}_${short_data1}_${short_data2} \
        --pval ${placo_pval_threshold}
  fi
fi

# Step 3 - To perform LD Clumping (locally)
#####################################################

if  $toclump ; then
  Rscript ${script_dir}/C3_code_ldclumping_local.R \
        --path ${work_dir} \
        --file ${output_step2}_${short_data1}_${short_data2} \
        --pathout ${work_dir} \
        --out ${output_step3}_${clump_threshold_r2}_${short_data1}_${short_data2} \
        --ref ${ref_path_b_files} \
        --r2 ${clump_threshold_r2} \
        --kb ${clump_threshold_kb} \
        --p ${clump_threshold_p}
fi

# Step 4 - To prepare the GCPBayes inputs in the right format
#####################################################

Rscript ${script_dir}/D1_code_pipeline_annot_coding_withoutldclumping_extra_info.R \
        --path ${work_dir} \
        --path1 ${path_inputfile_trait1} \
        --path2 ${path_inputfile_trait2} \
        --file1 ${Input_file_trait1} \
        --file2 ${Input_file_trait2} \
        --name1 ${short_data1} \
        --name2 ${short_data2} \
        --annot_gwas_path ${path_gwas_annot} \
        --annot_gwas_file ${file_gwas_annot} \
        --annot_path ${path_annot} \
        --annot_file ${file_annot} \
        --info ${info_threshold} \
        --maf ${MAF_threshold} \
        --out ${output_step4wc}

if $toclump ; then
  Rscript ${script_dir}/D2_code_pipeline_annot_coding_ldclumping_extra_info.R \
        --path ${work_dir} \
        --path1 ${path_inputfile_trait1} \
        --path2 ${path_inputfile_trait2} \
        --file1 ${Input_file_trait1} \
        --file2 ${Input_file_trait2} \
        --name1 ${short_data1} \
        --name2 ${short_data2} \
        --annot_gwas_path ${path_gwas_annot} \
        --annot_gwas_file ${file_gwas_annot} \
        --annot_path ${path_annot} \
        --annot_file ${file_annot} \
        --ldclumpout ${output_step3}_${clump_threshold_r2}_${short_data1}_${short_data2} \
        --info ${info_threshold} \
        --maf ${MAF_threshold} \
        --out ${output_step4c}
fi

# Step 5 - To get correct list of groups for further analysis according to wanted threshold (length of groups)
#####################################################

Rscript ${script_dir}/D3_code_separate_groups_length_threshold.R \
        --path ${work_dir} \
        --file_noclump ${output_step4wc} \
        --file_clump ${output_step4c} \
        --out_noclump ${output_step5wc} \
        --out_clump ${output_step5c} \
        --t_SNP_number ${group_clump_threshold}
        

# Step 6 - To run GCPBayes (DS)
#####################################################

# A - To run GCPBayes (DS) on groups without ld clumping (length <= group_clump_threshold)
Rscript ${script_dir}/E1_code_gcpbayes_less_extra_info.R \
        --path ${work_dir} \
        --file ${output_step5wc} \
        --t_SNP_number ${group_absolute_threshold} \
        --t_theta ${theta_exploration} \
        --pathout ${output_dir} \
        --out ${output_step6wc}
# WARNINGS : theta_exploration is used (not theta_plot)

# B - To run GCPBayes (DS) on groups after ld clumping (group_clump_threshold < length <= group_absolute_threshold)
if $toclump ; then
Rscript ${script_dir}/E1_code_gcpbayes_less_extra_info.R \
        --path ${work_dir} \
        --file ${output_step5c} \
        --t_SNP_number ${group_absolute_threshold} \
        --t_theta ${theta_exploration} \
        --pathout ${output_dir} \
        --out ${output_step6c}
# WARNINGS : theta_exploration is used (not theta_plot)
fi

# Step 7 - To run GCPBayes (HS) on groups with theta > theta_exploration
#####################################################

# Step 8 - To plot figures
#####################################################





































