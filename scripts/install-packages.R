packages <- c("argparser", "data.table", "ggfortify", "ggplot2", "janitor", "openxlsx", "tidyverse", "writexl")

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
  }
}