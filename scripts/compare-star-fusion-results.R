# List of required packages
required_packages <- c("argparser", "data.table", "ggfortify", "ggplot2", "janitor", "openxlsx", "tidyverse", "writexl")

# Function to install missing packages
install_missing_packages <- function(packages) {
  # Set a default CRAN mirror or prompt the user in interactive sessions
  if (is.null(getOption("repos"))) {
    if (interactive()) {
      chooseCRANmirror()
    } else {
      options(repos = c(CRAN = "http://cran.us.r-project.org"))
    }
  }

  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages)) install.packages(new_packages, repos = "http://cran.us.r-project.org")
}

# Install any missing packages
install_missing_packages(required_packages)

# Load the libraries
library(argparser)
library(data.table)
library(ggfortify)
library(ggplot2)
library(janitor)
library(openxlsx)
library(tidyverse)
library(writexl)

# Create a new argument parser
p <- arg_parser("Compare STAR-Fusion results")

# Add named arguments
p <- add_argument(p, "--input_folder", help = "Path to the merged STAR-Fusion results folder")
p <- add_argument(p, "--metadata_folder", help = "Path to the metadata folder")
p <- add_argument(p, "--output_folder", help = "Path to the output folder")
p <- add_argument(p, "--pca_color_by", help = "Metadata column to color PCA plots by")

# Parse command line arguments
argv <- parse_args(p)

# Assign command line arguments to variables
metadata_folder <- argv$metadata_folder
input_folder <- argv$input_folder
output_folder <- argv$output_folder
pca_color_by <- argv$pca_color_by

# Check if all command line arguments are defined
if (is.null(metadata_folder)) {
  stop("The --metadata_folder argument is not defined")
}

if (is.null(input_folder)) {
  stop("The --input_folder argument is not defined")
}

if (is.null(output_folder)) {
  stop("The --output_folder argument is not defined")
}

if (is.null(pca_color_by)) {
  stop("The --pca_color_by argument is not defined")
}

# Create the output folder if it doesn't already exist, including any necessary parent directories
dir.create(output_folder, recursive = TRUE)

# Create a tibble (data frame) of input files by listing all files in the input folder
# that match the pattern "*.preliminary", and get both their full paths and file names
input_files <- tibble(
  full_path = list.files(input_folder, pattern = "*.preliminary", full.names = TRUE),
  file_name = list.files(input_folder, pattern = "*.preliminary", full.names = FALSE)
)

# Ensure the number of full paths matches the number of file names to prevent data mismatch
if (nrow(input_files) != length(input_files$file_name)) {
  stop("Mismatch in the number of files and file names")
}

# Define a function to read TSV files, clean up column names, and add source information
# This function takes a file name and its full path, reads the TSV, cleans column names for consistency,
# and adds columns for file name, full path, and sample name extracted from the file name
read_tsv_and_add_source <- function(file_name, full_path) {
  read_tsv(full_path, show_col_types = FALSE) %>%
    clean_names() %>%
    mutate(
      file_name = file_name,
      full_path = full_path,
      sample = str_extract(file_name, "^[^.]+") # Extracts the sample name before the first dot in the file name
    )
}

# Read all TSV files into a single combined tibble (data frame)
# Using pmap_dfr to apply the function over each row of input_files tibble
combined_data_with_source <- input_files %>%
  pmap_dfr(~ read_tsv_and_add_source(..2, ..1)) # Swapping arguments for the function call

# Filter the combined data to keep only records involving fusions between two MT genes
# Uses regular expression to detect 'MT' at the start of the breakpoint strings
combined_data_with_source_MT <- combined_data_with_source %>%
  filter(str_detect(left_breakpoint, "(?i)^MT") &
    str_detect(right_breakpoint, "(?i)^MT"))

# Aggregate the data by the number of fusion names and samples
# Summarizes junction read counts for each group
# Note: If the data is paired-end, spanning_frag_count can also be included
counts_per_MT_fusion <- combined_data_with_source_MT %>%
  group_by(number_fusion_name, sample) %>%
  summarise(
    fusion_count = sum(junction_read_count),
    .groups = "keep" # Retains the existing groups for further operations
  )

# Transform the fusion counts data from long format to wide format
# This pivots the data so that each sample becomes a column, with fusion counts as values
wide_fusion_counts <- counts_per_MT_fusion %>%
  pivot_wider(names_from = sample, values_from = fusion_count, values_fill = list(fusion_count = 0))

# Transpose the wide format data to have samples as rows and fusion names as columns
# This is helpful for analyses where samples are usually the observations (rows)
transposed_fusion_counts <- t(wide_fusion_counts[-1]) %>%
  as.data.frame() %>%
  setNames(wide_fusion_counts[[1]])

# Convert the transposed data into a data table and add row names as a new column 'Sample'
final_fusion_counts <- data.table(transposed_fusion_counts, keep.rownames = "Sample")

# Read the fragment count data from a CSV file and process it
# This includes cleaning the sample names and rounding the million fragments value for consistency
fragment_counts <- read_csv(file.path(input_folder, "fragment_counts.txt"), show_col_types = FALSE)

fragment_counts_processed <- fragment_counts %>%
  mutate(
    sample = str_extract(file, "^[^_]+"),
    sample = str_remove(sample, "\\.fastq\\.gz$"),
    `million fragments` = round(`million fragments`, 6)
  ) %>%
  select(-file)

# Merge fragment_counts_processed with final_fusion_counts, ensuring fragment_counts_processed columns come first
final_fusion_counts_with_fragments <- left_join(fragment_counts_processed, final_fusion_counts, by = c("sample" = "Sample"))

# Read sample information from SraRunTable.txt
sample_info <- read_csv(file.path(metadata_folder, "SraRunTable.txt"), show_col_types = FALSE)

# Merge sample_info with final_fusion_counts_with_fragments, using 'Run' and 'Sample' as the matching columns
final_fusion_counts_with_metadata <- left_join(sample_info, final_fusion_counts_with_fragments, by = c("Run" = "sample"))

# Count the number of columns in the original final_fusion_counts
num_cols_final_fusion_counts <- ncol(final_fusion_counts)

# Count the number of columns in fragment_counts_processed and sample_info
num_cols_fragment_counts_processed <- ncol(fragment_counts_processed)
num_cols_sample_info <- ncol(sample_info)

# Count the number of columns in the merged dataframe
num_cols_final_fusion_counts_with_metadata <- ncol(final_fusion_counts_with_metadata)

# Calculate the number of columns added
num_cols_added <- num_cols_final_fusion_counts_with_metadata - num_cols_final_fusion_counts

# Define the path for the output Excel file
output_excel_path <- file.path(output_folder, "final_fusion_counts_with_metadata.xlsx")

# Create a new workbook
wb <- createWorkbook()

# Add dataframe as a sheet with desired name
addWorksheet(wb, "raw counts")
writeData(wb, "raw counts", final_fusion_counts_with_metadata, colNames = TRUE, rowNames = TRUE)

# Set the width of each column to 25
num_cols <- ncol(final_fusion_counts_with_metadata) + 1 # +1 if including row names
setColWidths(wb, "raw counts", cols = 1:num_cols, widths = 25)

# Save the workbook
saveWorkbook(wb, output_excel_path, overwrite = TRUE)

# Find the position of the 'million fragments' column
mf_col_position <- which(names(final_fusion_counts_with_metadata) == "million fragments")

# Apply the calculation to columns after 'million fragments'
final_fusion_ffpm <- final_fusion_counts_with_metadata %>%
  mutate(across((mf_col_position + 1):ncol(.), ~ . / `million fragments`))

# Load the existing workbook
wb <- loadWorkbook(output_excel_path)

# Add the new sheet with the calculated data
addWorksheet(wb, "FFPM")
writeData(wb, "FFPM", final_fusion_ffpm, colNames = TRUE, rowNames = TRUE)

# Set the width of each column to 25
num_cols_ffpm <- ncol(final_fusion_ffpm) + 1 # +1 if including row names
setColWidths(wb, "FFPM", cols = 1:num_cols_ffpm, widths = 25)

# Save the workbook
saveWorkbook(wb, output_excel_path, overwrite = TRUE)

# Find the position of the 'million fragments' column in final_fusion_ffpm
mf_col_position_ffpm <- which(names(final_fusion_ffpm) == "million fragments")

# Check if the column was found
if (length(mf_col_position_ffpm) == 0) {
  stop("Column 'million fragments' not found in final_fusion_ffpm.")
}

# Check if the pca_color_by column exists in the data frame
if (!pca_color_by %in% colnames(final_fusion_ffpm)) {
  stop(paste("The column", pca_color_by, "does not exist in the metadata"))
}

# Extract columns for PCA
pca_data <- final_fusion_ffpm[, (mf_col_position_ffpm + 1):ncol(final_fusion_ffpm)]

# Perform PCA
pca_result <- prcomp(pca_data, center = TRUE, scale = FALSE)

# Function to capitalize the first letter
capitalize_first_letter <- function(x) {
  sapply(strsplit(as.character(x), " "), function(words) {
    paste(toupper(substring(words, 1, 1)),
      substring(words, 2),
      sep = "", collapse = " "
    )
  })
}

# Apply the function to the column name
pca_color_by_capitalized <- capitalize_first_letter(pca_color_by)


# Rename the column in the data frame
final_fusion_ffpm_capitalized <- final_fusion_ffpm
names(final_fusion_ffpm_capitalized)[names(final_fusion_ffpm_capitalized) == pca_color_by] <- pca_color_by_capitalized

# Apply the function to the values in the column
final_fusion_ffpm_capitalized[[pca_color_by_capitalized]] <- capitalize_first_letter(final_fusion_ffpm_capitalized[[pca_color_by_capitalized]])

# Generate plots
plot_width <- 17.35 / 2.54
plot_height <- 23.35 / (2.54 * 2)

pdf(
  file = file.path(output_folder, "FFPM-PCA.pdf"),
  width = plot_width,
  height = plot_height
)

autoplot(pca_result,
  data = final_fusion_ffpm_capitalized, colour = pca_color_by_capitalized, label = FALSE, shape = 19, loadings = FALSE,
  loadings.label = FALSE, loadings.label.size = 2
) +
  theme_classic(base_size = 12)

invisible(dev.off())

pdf(
  file = file.path(output_folder, "FFPM-PCA-samples-labelled.pdf"),
  width = plot_width,
  height = plot_height
)

autoplot(pca_result,
  data = final_fusion_ffpm_capitalized, colour = pca_color_by_capitalized, label = TRUE, shape = FALSE, loadings = FALSE,
  loadings.label = FALSE, loadings.label.size = 2
) +
  theme_classic(base_size = 12)

invisible(dev.off())

pdf(
  file = file.path(output_folder, "FFPM-PCA-loadings.pdf"),
  width = plot_width,
  height = plot_height
)

autoplot(pca_result,
  data = final_fusion_ffpm_capitalized, colour = pca_color_by_capitalized, label = FALSE, shape = 19, loadings = TRUE,
  loadings.label = FALSE, loadings.label.size = 2
) +
  theme_classic(base_size = 12)

invisible(dev.off())

pdf(
  file = file.path(output_folder, "FFPM-PCA-loadings-labelled.pdf"),
  width = plot_width,
  height = plot_height
)

autoplot(pca_result,
  data = final_fusion_ffpm_capitalized, colour = pca_color_by_capitalized, label = FALSE, shape = 19, loadings = TRUE,
  loadings.label = TRUE, loadings.label.size = 2
) +
  theme_classic(base_size = 12)

invisible(dev.off())

# Print message
print(paste("The PDF files have been saved in the following directory:", output_folder))
