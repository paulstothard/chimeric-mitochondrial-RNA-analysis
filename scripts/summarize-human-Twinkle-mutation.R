# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# List of required packages
required_packages <- c(
  "data.table", "ggfortify", "ggplot2", "janitor",
  "openxlsx", "tidyverse", "writexl"
)

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

  # Identify packages that are not already installed
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]

  # Install new packages if any are found
  if (length(new_packages)) {
    install.packages(new_packages, repos = "http://cran.us.r-project.org")
  }
}

# Install any missing packages
install_missing_packages(required_packages)

# Load the necessary libraries
library(data.table)
library(ggfortify)
library(ggplot2)
library(janitor)
library(openxlsx)
library(tidyverse)
library(writexl)

################################################################################
# DATASET-SPECIFIC CONFIGURATION
# Update the following settings for each new dataset.
################################################################################

# Assign command line arguments to variables for input, metadata, and output
# Modify these paths according to your dataset structure
input_folder <- "star-fusion-results/human-Twinkle-mutation" # Path to input data
metadata_folder <- "SRA-metadata/human-Twinkle-mutation" # Path to metadata
output_folder <- "star-fusion-results-summary/human-Twinkle-mutation" # Path for output
pca_color_by <- "Genotype" # Variable for color coding in PCA plot

# Modify this function to perform dataset-specific processing prior to output
# Customize the data processing steps for your specific dataset needs
dataset_specific_processing <- function(df) {
  # Ensure that the input is a data frame
  if (!is.data.frame(df)) {
    stop("Input must be a data frame.")
  }

  # Placeholder for dataset-specific data manipulation
  # Example: df <- df %>% mutate(new_column = existing_column * 2)
  df <- df %>%
    rename(Genotype = genotype)

  df$Genotype <- sub("^(.)", "\\U\\1", df$Genotype, perl = TRUE)

  df <- subset(df, time == "4 months")

  # Return the (possibly modified) data frame
  return(df)
}
################################################################################

# Create the output folder if it doesn't already exist
dir.create(output_folder, recursive = TRUE)

# Create a tibble of input files by listing all files in the input folder
input_files <- tibble(
  full_path = list.files(input_folder, pattern = "*.preliminary", full.names = TRUE),
  file_name = list.files(input_folder, pattern = "*.preliminary", full.names = FALSE)
)

# Check if the input_files tibble is empty
if (nrow(input_files) == 0) {
  stop("No input files found in the specified folder.")
}

# Ensure the number of full paths matches the number of file names
if (nrow(input_files) != length(input_files$file_name)) {
  stop("Mismatch in the number of files and file names")
}

# Define a function to read TSV files, clean up column names, and add source info
read_tsv_and_add_source <- function(file_name, full_path) {
  read_tsv(full_path, show_col_types = FALSE) %>%
    clean_names() %>%
    mutate(
      file_name = file_name,
      full_path = full_path,
      sample = str_extract(file_name, "^[^.]+")
    )
}

# Read all TSV files into a combined tibble
combined_data_with_source <- input_files %>%
  pmap_dfr(~ read_tsv_and_add_source(..2, ..1))

# Filter the combined data for records involving fusions between two MT genes
combined_data_with_source_MT <- combined_data_with_source %>%
  filter(str_detect(left_breakpoint, "(?i)^MT") &
    str_detect(right_breakpoint, "(?i)^MT"))

# Aggregate data by fusion names and samples and summarize junction read counts
counts_per_MT_fusion <- combined_data_with_source_MT %>%
  group_by(number_fusion_name, sample) %>%
  summarise(
    fusion_count = sum(junction_read_count),
    .groups = "keep"
  )

# Transform the fusion counts data from long to wide format
wide_fusion_counts <- counts_per_MT_fusion %>%
  pivot_wider(
    names_from = sample, values_from = fusion_count,
    values_fill = list(fusion_count = 0)
  )

# Transpose the wide format data to have samples as rows
transposed_fusion_counts <- t(wide_fusion_counts[-1]) %>%
  as.data.frame() %>%
  setNames(wide_fusion_counts[[1]])

# Convert transposed data to a data table and add row names as a column
final_fusion_counts <- data.table(transposed_fusion_counts, keep.rownames = "Sample")

# Read and process fragment count data from a CSV file
fragment_counts <- read_csv(file.path(input_folder, "fragment_counts.txt"), show_col_types = FALSE)

fragment_counts_processed <- fragment_counts %>%
  mutate(
    sample = str_extract(file, "^[^_]+"),
    sample = str_remove(sample, "\\.fastq\\.gz$"),
    `million fragments` = round(`million fragments`, 6)
  ) %>%
  select(-file)

# Merge fragment counts with final fusion counts
final_fusion_counts_with_fragments <- left_join(fragment_counts_processed,
  final_fusion_counts,
  by = c("sample" = "Sample")
)

# Read sample information and merge with final fusion counts
sample_info <- read_csv(file.path(metadata_folder, "SraRunTable.txt"), show_col_types = FALSE)
final_fusion_counts_with_fragments_and_SRA <- left_join(sample_info,
  final_fusion_counts_with_fragments,
  by = c("Run" = "sample")
)

# Perform dataset-specific processing
final_fusion_counts_with_metadata <- dataset_specific_processing(final_fusion_counts_with_fragments_and_SRA)

# Checking if 'million fragments' column exists
if ("million fragments" %in% colnames(final_fusion_counts_with_metadata)) {
  # Get the index of the 'million fragments' column
  index_million_fragments <- which(colnames(final_fusion_counts_with_metadata) == "million fragments")

  # Extract the names of all columns after 'million fragments'
  columns_after_million_fragments <- colnames(final_fusion_counts_with_metadata)[(index_million_fragments + 1):ncol(final_fusion_counts_with_metadata)]

  # Check if all these column names start with 'MT-' (case-insensitive)
  all_start_with_MT <- all(grepl("^MT-", columns_after_million_fragments, ignore.case = TRUE))

  if (!all_start_with_MT) {
    stop("'million fragments' column exists but not all subsequent columns start with 'MT-'.")
  }
} else {
  stop("'million fragments' column does not exist.")
}

# Count the number of columns in the merged dataframe
num_cols_final_fusion_counts_with_metadata <- ncol(final_fusion_counts_with_metadata)

# Define the path for the output Excel file
output_excel_path <- file.path(output_folder, "final_fusion_counts_with_metadata.xlsx")

# Create a new workbook and add dataframe as a sheet
wb <- createWorkbook()
addWorksheet(wb, "raw counts")
writeData(wb, "raw counts", final_fusion_counts_with_metadata, colNames = TRUE, rowNames = TRUE)
setColWidths(wb, "raw counts", cols = 1:(num_cols_final_fusion_counts_with_metadata + 1), widths = 25)
saveWorkbook(wb, output_excel_path, overwrite = TRUE)

# Find the position of the 'million fragments' column in metadata
mf_col_position <- which(names(final_fusion_counts_with_metadata) == "million fragments")

# Apply calculation to columns after 'million fragments' for FFPM conversion
final_fusion_ffpm <- final_fusion_counts_with_metadata %>%
  mutate(across((mf_col_position + 1):ncol(.), ~ . / `million fragments`))

# Load the existing Excel workbook for appending data
wb <- loadWorkbook(output_excel_path)

# Add a new sheet with the FFPM calculated data
addWorksheet(wb, "FFPM")
writeData(wb, "FFPM", final_fusion_ffpm, colNames = TRUE, rowNames = TRUE)

# Set column widths to 25 for the FFPM sheet
num_cols_ffpm <- ncol(final_fusion_ffpm) + 1 # Including row names
setColWidths(wb, "FFPM", cols = 1:num_cols_ffpm, widths = 25)

# Save the updated workbook
saveWorkbook(wb, output_excel_path, overwrite = TRUE)

# Find the position of the 'million fragments' column in FFPM data
mf_col_position_ffpm <- which(names(final_fusion_ffpm) == "million fragments")

# Ensure the 'million fragments' column is found in FFPM data
if (length(mf_col_position_ffpm) == 0) {
  stop("Column 'million fragments' not found in final_fusion_ffpm.")
}

# Check for the existence of the pca_color_by column in the data frame
if (!pca_color_by %in% colnames(final_fusion_ffpm)) {
  stop(paste("The column", pca_color_by, "does not exist in the metadata"))
}

# Extract columns for PCA analysis
pca_data <- final_fusion_ffpm[, (mf_col_position_ffpm + 1):ncol(final_fusion_ffpm)]

# Perform PCA on the extracted data
pca_result <- prcomp(pca_data, center = TRUE, scale = FALSE)

# Define plot dimensions
plot_width <- 17.35 / 2.54
plot_height <- 23.35 / (2.54 * 2)

# Functions to generate and save PCA plots
generate_and_save_plot <- function(file_name, label, shape, loadings, loadings_label) {
  # Close any previously open graphics devices
  graphics.off()

  # Construct the full path for the PDF file
  pdf_path <- file.path(output_folder, file_name)

  # Check if the output folder exists and is writable
  if (!dir.exists(output_folder) || !file.access(output_folder, 2) == 0) {
    stop("Output folder does not exist or is not writable")
  }

  # Open a new PDF device
  pdf(file = pdf_path, width = plot_width, height = plot_height)

  # Create the plot and use print() to render it to the file
  plot_to_print <- autoplot(pca_result,
    data = final_fusion_ffpm, colour = pca_color_by,
    label = label, shape = shape, loadings = loadings,
    loadings.label = loadings_label, loadings.label.size = 2
  ) +
    theme_classic(base_size = 12)
  print(plot_to_print)

  # Close the PDF device
  invisible(dev.off())
}

# Generate and save various PCA plots
generate_and_save_plot("FFPM-PCA.pdf", FALSE, 19, FALSE, FALSE)
generate_and_save_plot("FFPM-PCA-samples-labelled.pdf", TRUE, FALSE, FALSE, FALSE)
generate_and_save_plot("FFPM-PCA-loadings.pdf", FALSE, 19, TRUE, FALSE)
generate_and_save_plot("FFPM-PCA-loadings-labelled.pdf", FALSE, 19, TRUE, TRUE)

# Print completion message
print(paste("The PDF files have been saved in the following directory:", output_folder))
