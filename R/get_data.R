#' @title Extraction of metadata from dataframes
#'
#' @description
#' \code{\link{get_data}} extracts descriptive metadata from the dataframe including information on missing data
#'
#' @details
#' This function uses the original dataframe and extracts descriptive metadata including dimensions,
#' missingness fractions overall and by variable, number of missing values overall and by variable,
#' missing data patterns, missing data correlations and missing data visualizations
#'
#' @param X Original dataframe with samples in rows and variables as columns. Can also use the resulting object from the \code{\link{clean}} function
#' @param matrixplot_sort Boolean with default TRUE. If TRUE, the matrix plot will be sorted by missing/non-missing status. If FALSE, the original order of rows will be retained
#' @param plot_transform Boolean with default TRUE. If TRUE, the matrix plot will plot all variables scaled (mean = 0, SD = 1). If FALSE, the matrix plot will show the variables on their original scale
#'
#' @name get_data
#'
#' @return
#' \item{Complete_cases}{Number of complete cases (samples with no missing data in any columns)}
#' \item{Rows}{Total number of rows (samples) in the dataframe}
#' \item{Columns}{Total number of columns (variables) in the dataframe}
#' \item{Corr_matrix}{Correlation matrix of all variables. The correlation matrix contains Pearson correlation coefficients based on pairwise correlations between variable pairs}
#' \item{Fraction_missingness}{Total fraction of missingness expressed as a number between 0 and 1, where 1 means 100\% of data is missing and 0 means there are no missing values}
#' \item{Fraction_missingness_per_variable}{Fraction of missingness per variable. A (named) numeric vector of length the number of columns. Each variable missingness values are expressed as numbers between 0 and 1, where 1 means 100\% of data is missing and 0 means there are no missing values}
#' \item{Total_NA}{Total number of missing values in the dataframe}
#' \item{NA_per_variable}{Number of missing values per variables in the dataframe. A (named) numeric vector of length the number of columns}
#' \item{MD_Pattern}{Missing data pattern calculated using mice::md_pattern (see \code{\link[mice]{md.pattern}} in the mice package)}
#' \item{NA_Correlations}{Correlation matrix of variables vs. variables converted to boolean based on missingness status (yes/no). Point-biserial correlation coefficients based on variable pairs is obtained using complete observations in the respective variable pairs. Higher correlation coefficients can indicate MAR missingness pattern}
#' \item{NA_Correlation_plot}{Plot based on NA_Correlations}
#' \item{min_PDM_thresholds}{Small dataframe offering clues on how to set min_PDM thresholds in the next steps of the pipeline. The first column represents min_PDM thresholds, while the second column represents percentages that would be retained by setting min_PDM to the respective values. These values are the percentages of the total rows with any number of missing data (excluding complete observations), so a value of e.g. 80\% would mean that 80\% of rows with missing data with the most common patterns are represented in the simulation step}
#' \item{Vars_above_half}{Character vector of variables names with missingness higher than 50\%}
#' \item{Matrix_plot}{Matrix plot where missing values are colored gray and available values are colored based on value range}
#' \item{Cluster_plot}{Cluster plot of co-missingness. Variables demonstrating shared missingness patterns will branch at closer to the bottom of the plot, while no patterns will be represented by branches high in the plot}
#'
#' @examples
#' cleaned <- clean(clindata_miss, missingness_coding = -9)
#' metadata <- get_data(cleaned)
#' metadata <- get_data(cleaned, matrixplot_sort = FALSE)
#'
#' @export


### FUNCTION
get_data <- function(X, matrixplot_sort = T, plot_transform = T) {

  vars_non_num <- names(X)[!sapply(X, is.numeric)]
  if (length(vars_non_num) != 0)
    stop(paste("Warning! Variable(s) ", (paste(vars_non_num, collapse = ", ")),
               " is/are not numeric. Convert this/these variables to numeric using missCompare::clean() and repeat the missCompare::get_data() function until no warnings are shown.",
               sep = ""))

  comp <- sum(stats::complete.cases(X))
  rows <- nrow(X)
  cols <- ncol(X)
  mat <- stats::cor(X, use = "pairwise.complete.obs", method = "pearson")
  missfrac_per_df <- sum(is.na(X))/(nrow(X) * ncol(X))
  missfrac_per_var <- colMeans(is.na(X))
  na_per_df <- sum(is.na(X))
  na_per_var <- sapply(X, function(x) sum(length(which(is.na(x)))))
  mdpat <- mice::md.pattern(X, plot = F)
  data_names <- colnames(X)
  mdpat <- mdpat[, data_names]

  # checking min_PDM thresholds
  mdpat_count <- mdpat[-c(1, nrow(mdpat)), ]
  min_PDM <- c(5,10,20,50,100,200,500,1000)
  min_PDM_obs <- c()
  for (i in 1:length(min_PDM)) {
    index <- as.numeric(rownames(mdpat_count)) > min_PDM[i]
    mdpat_count_simple <- mdpat_count[index, ]
    min_PDM_obs[i] <- round(sum(100 * as.numeric(rownames(mdpat_count_simple)))/sum(as.numeric(rownames(mdpat_count))))
  }

  min_PDM_df <- cbind(min_PDM, min_PDM_obs)
  row.names(min_PDM_df) <- c(1:8)
  colnames(min_PDM_df) <- c("min_PDM_threshold", "perc_obs_retained")

  # NA correlation
  na_cor <- matrix(nrow = cols, ncol = cols)
  colnames(na_cor) <- colnames(X)
  row.names(na_cor) <- paste0(colnames(X), "_is.na")
  for (i in 1:cols) {
    for (j in 1:cols) {
      na_cor[i,j] <- ltm::biserial.cor(X[,j], is.na(X)[,i], use="complete.obs")
    }
  }

  melted_cormat <- data.table::melt(na_cor)
  p_cor <- ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) +
    geom_tile() + labs(x= "", y= "") + theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    ggtitle("Variable - Variable NA Correlation Matrix") +
    theme(plot.title = element_text(hjust = 0.5)) + guides(fill=guide_legend(title="Point-biserial correlation coefficient"))

  if (plot_transform == T)
    X_update <- as.data.frame(scale(X)) else X_update <- X

  nm1 <- names(X_update)[colSums(is.na(X_update)) > 0]
  mydescend <- function(x) {
    dplyr::desc(is.na(x))
  }
  arr_X <- X_update %>% dplyr::arrange_at(dplyr::vars(nm1), funs(mydescend))

  vars_above_half <- colnames(X_update)[missfrac_per_var >= 0.5]
  if (length(vars_above_half) != 0)
    message(paste("Warning! Missingness exceeds 50% for variable(s) ", (paste(vars_above_half,
                                                                              collapse = ", ")), ". Although the pipeline will function with variables with high missingness, consider excluding these variables using missCompare::clean() and repeating function until no warnings are shown.",
                  sep = ""))

  # matrix plot
  df_miss_id <- cbind(c(1:rows), arr_X)
  colnames(df_miss_id) <- c("Observations", colnames(arr_X))
  df_melt <- data.table::melt(df_miss_id, id = c("Observations"))
  matrixplot_sorted <- ggplot(df_melt, aes(x = variable, y = Observations)) + geom_tile(aes(fill = value)) +
    scale_fill_gradient(low = "white", high = "blue") + theme(panel.background = element_blank()) +
    ggtitle("Matrix plot of missing data") + theme(plot.title = element_text(hjust = 0.5))

  df_miss_id <- cbind(c(1:rows), X_update)
  colnames(df_miss_id) <- c("Observations", colnames(X_update))
  df_melt <- data.table::melt(df_miss_id, id = c("Observations"))
  matrixplot_unsorted <- ggplot(df_melt, aes(x = variable, y = Observations)) + geom_tile(aes(fill = value)) +
    scale_fill_gradient(low = "white", high = "blue") + theme(panel.background = element_blank()) +
    ggtitle("Matrix plot of missing data") + theme(plot.title = element_text(hjust = 0.5))

  if (matrixplot_sort == F)
    matrix_plot <- matrixplot_unsorted else matrix_plot <- matrixplot_sorted

  # cluster plot
  any_miss <- X_update[, which(!colSums(is.na(X_update)) == 0)]

  yesno <- any_miss %>% is.na
  d <- stats::dist(t(yesno), method = "binary")
  hc <- stats::hclust(d, method = "ward.D")
  hcdata <- ggdendro::dendro_data(hc)
  cluster_plot <- ggdendro::ggdendrogram(hcdata, theme_dendro = FALSE) + ggtitle("Cluster plot of missing data") +
    theme(plot.title = element_text(hjust = 0.5)) + labs(x = "variable", y = "Height")

  # output
  list(Complete_cases = comp, Rows = rows, Columns = cols, Corr_matrix = mat, Fraction_missingness = missfrac_per_df,
       Fraction_missingness_per_variable = missfrac_per_var, Total_NA = na_per_df,
       NA_per_variable = na_per_var, MD_Pattern = mdpat, NA_Correlations = na_cor, NA_Correlation_plot = p_cor,
       min_PDM_thresholds = min_PDM_df, Vars_above_half = vars_above_half,
       Matrix_plot = matrix_plot, Cluster_plot = cluster_plot)
}

