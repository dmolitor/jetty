bindmount_home <- function() {
  # TODO: figure out correct Windows volume
  if (is_windows()) arg <- ""
  arg <- "-v $(echo $HOME):$(echo $HOME/)"
  arg
}

bindmount_temp <- function(dir) {
  # TODO: figure out correct Windows volume
  if (is_windows()) arg <- ""
  arg <- paste0("-v ", dir, ":", dir, "/")
  arg
}

command_shell_prep <- function(expr, temp_file) {
  expr <- rlang::enexpr(expr)
  expr <- rlang::expr_text(expr)
  cwd <- getwd()
  expr <- paste0(
    "setwd(\"",
    cwd,
    "\")\npod_output <- ",
    expr,
    "\nsaveRDS(pod_output, file=\"",
    temp_file,
    "\")"
  )
  expr <- shQuote(expr)
  expr
}

#' Execute an R expression inside a Docker container
#'
#' This function is somewhat similar to [callr::r()] in that the user can pass
#' a function (or really any expression) to be evaluated. This expression will
#' be executed within the context of a Docker container and the result will be
#' returned within the local R session. While the results will be returned,
#' most side effects, e.g. printing and plotting, will be lost since these are
#' being screamed into the void of the Docker container. However, the local file
#' system and [tempdir()] are mounted to the Docker container, so any side
#' effects that involve writing to the home directory or the temp directory will
#' work as expected!
#'
#' @param func Function object or expression to be executed in the R session
#'   within the Docker container. Package functions should be referenced using
#'   the `::` notation and only packages installed in the Docker container are
#'   accessible.
#' @param image A string in the `image:tag` format specifying either a local
#'   Docker image or an image available on DockerHub. Default image is
#'   `r-base:your-r-version` where your R version is determined from your local
#'   R session.
#' @param debug A logical indicating whether to print out the commands that are
#'   being executed via the shell. This is mostly helpful to see what is
#'   happening when things start to error.
#'
#' @return Value of the evaluated expression.
#' @examples
#' \dontrun{
#' run(
#'   {
#'     mtcars <- mtcars |>
#'       transform(cyl = as.factor(cyl))
#'       model <- lm(mpg ~ ., data = mtcars)
#'       model
#'   }
#' )
#' }
#'
#' @export
run <- function(func, image = paste0("r-base:", r_version()), debug = FALSE) {
  temp_dir <- tempdir()
  temp_file <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  expr <- rlang::enexpr(func)
  expr <- command_shell_prep(!!expr, temp_file = temp_file)
  temp_dir_mount <- bindmount_temp(temp_dir)
  home_dir_mount <- bindmount_home()
  cmd_args <- c("run", "--rm", home_dir_mount, temp_dir_mount, image, "Rscript", "-e", expr)
  if (debug) {
    cat("Command:\n")
    cat(paste0(c("docker", cmd_args), collapse = " "), "\n")
  }
  out <- docker_command(args = cmd_args)
  readRDS(temp_file)
}


# complex_fn <- function(a, b, c) {
#   if (a == 1) print("no!!!")
#   if (b == 1) print("no!!")
#   if (c == 1) print("no!")
#   a + b + c
# }
#
# run(
#   expr = {
#     a <- 4
#     b <- 2
#     c <- 1
#
#     complex_fn <- function(a, b, c) {
#       cat("I'm working!!!\n")
#       if (a == 1) a + 1
#       if (b == 1) b + 1
#       if (c == 1) c + 1
#       a + b + c
#     }
#
#     complex_fn(a = a, b = b, c = c)
#   }
# )
