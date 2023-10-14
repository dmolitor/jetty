command_shell_prep <- function(expr, temp_file) {
  expr <- rlang::enexpr(expr)
  expr <- rlang::expr_text(expr)
  cwd <- getwd()
  expr <- paste0(
    "\nsetwd(\"",
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

#' Run a Docker command
#'
#' Execute a function or expression within the context of a Docker container
#' and return the results to the local R session.
#'
#' @param args A single argument or vector of arguments to pass
#'   to \code{\link[=system2]{system2()}}
#' @examples
#' \dontrun{
#' docker_info <- docker_command(c("info", "--format '{{json .}}'")
#' }
#' @return The output of the given command as a string.
#' @export
docker_command <- function(args) {
  stop_if_not_installed()
  cmd <- suppressWarnings(system2("docker", args = args, stdout = TRUE))
  status <- attr(cmd, "status")
  if (length(status) > 0 && status > 0) {
    cmd <- paste("docker", paste(args, collapse = " "))
    rlang::abort(
      class = "docker_cmd_error",
      message = c(
        "Docker command exited with non-zero status",
        "i" = paste0("Status: ", status)
      ),
      data = status
    )
  }
  cmd
}

#' Execute an R expression inside a Docker container
#'
#' This function is somewhat similar in spirit to
#' \code{\link[callr:r]{callr::r()}} in that the user can pass
#' a function (or an expression) to be evaluated. This expression will
#' be executed within the context of a Docker container and the result will be
#' returned within the local R session.
#'
#' It is important to note that most side effects, e.g. printing and plotting,
#' will be lost since these are being screamed into the void of the Docker
#' container. However, the local file system `path.expand("~")` and
#' \code{\link[=tempdir]{tempdir()}} are mounted to the Docker container, so
#' any side effects that involve writing to the local file system or the
#' temp directory will work as expected.
#'
#' @param func Function object or expression to be executed in the R session
#'   within the Docker container. Package functions should be referenced using
#'   the `::` notation and only packages installed in the Docker container are
#'   accessible.
#' @param image A string in the `image:tag` format specifying either a local
#'   Docker image or an image available on DockerHub. Default image is
#'   `r-base:your.r.version` where your R version is determined from your local
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
    message(paste0("Executing command:\n", paste0(c("docker", cmd_args), collapse = " ")))
  }
  out <- docker_command(args = cmd_args)
  readRDS(temp_file)
}
