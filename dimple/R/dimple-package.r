#' dimple: Data Imputation Made Simple
#'
#' The dimple package offers a convenient pipeline to test and compare various missing data
#' imputation algoritms on simulated data. The central assumption behind dimple is that structurally
#' different datasets (e.g. larger datasets with a large number of correlated variables vs. smaller datasets
#' with non correlated variables) will benefit differently from different missing data imputation algorithms.
#' Dimple takes measurements of your dataset and sets up a sandbox to try a curated list of standard and
#' sophisticated missing data imputation algorithms and compare them assuming custom set missingess patterns.
#' Dimple WILL NOT impute your dataset for you. However, dimple WILL give a comparative analysis of algorithms
#' and offer a report with the best performing algorithms assuming various missing data patterns and publication
#' ready visualizations to help you better understand missing data in your dataset.
#'
#' @author
#' \itemize{
#'  \item Tibor V. Varga \email{tibor.varga@@cpr.ku.dk}
#'  \item David Westergaard \email{david.westergaard@@cpr.ku.dk}
#' }
#'
#' @name dimple
#' @docType package
NULL