# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# List of required packages
required_packages <- c("data.table", "ggfortify", "ggplot2", "janitor", "openxlsx", "tidyverse", "writexl")

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
