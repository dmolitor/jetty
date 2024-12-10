command_shell_prep <- function(expr, temp_out, temp_in, dependencies) {
  expr <- rlang::enexpr(expr)
  expr <- rlang::expr_text(expr)
  cwd <- getwd()
  expr <- paste0(
    "\ntryCatch({ ",
    if (!is.null(dependencies)) {
      "install.packages(\"pak\", repos = sprintf(\"https://r-lib.github.io/p/pak/stable/%s/%s/%s\", .Platform$pkgType, R.Version()$os, R.Version()$arch))"
    } else {
      dependencies
    },
    if (!is.null(dependencies)) {
      paste0("\npak::pkg_install(c('", paste0(dependencies, collapse = "', '"), "'))")
    } else {
      dependencies
    },
    "\nsetwd(\"",
    cwd,
    "\")",
    "\njetty_output <- ",
    expr,
    "\nif (is.function(jetty_output)) jetty_output <- do.call(jetty_output, args = readRDS(file = \"",
    temp_in,
    "\"))",
    "\nsaveRDS(jetty_output, file=\"",
    temp_out,
    "\") }, error = function(err) { saveRDS(err, file=\"",
    temp_out,
    "\"); return(0) })"
  )
  expr <- shQuote(expr)
  expr
}

#' Run a Docker command
#'
#' Execute a function or code block within the context of a Docker container
#' and return the results to the local R session.
#'
#' @param args A single argument or vector of arguments to pass
#'   to [system2].
#' @param stdout,stderr where output to ‘stdout’ or ‘stderr’ should be sent.
#'   Possible values are "", to the R console (the default), NULL or FALSE
#'   (discard output), TRUE (capture the output in a character vector) or a
#'   character string naming a file. See [system2] for more details.
#' @param ... Additional arguments to pass directly to [system2].
#' @examples
#' \dontrun{
#' docker_info <- docker_command(c("info", "--format '{{json .}}'"), stdout = TRUE)
#' }
#' @return The output of the given command as a string.
#' @export
docker_command <- function(args, stdout = "", stderr = "", ...) {
  stop_if_not_installed()
  cmd <- suppressWarnings(system2("docker", args = args, stdout = stdout, stderr = stderr, ...))
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
#' a function (or a code block) to be evaluated. This code will
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
#' @section Error handling:
#'
#' \link{jetty} will propagate errors from the Docker process to the main process.
#' That is, if an error is thrown in the Docker process, an error with the same
#' message will be thrown in the main process. However, because of the
#' somewhat isolated nature of the local process and the Docker process,
#' calling functions such as \code{\link[=traceback]{traceback()}} and
#' \code{\link[rlang:last_trace]{rlang::last_trace()}} will, unfortunately,
#' not print the callstack of the uncaught error as that has (in its current
#' form) been lost in the Docker void.
#'
#' @param func Function object or code block to be executed in the R session
#'   within the Docker container. Package functions should be referenced using
#'   the `::` notation, and only packages installed in the Docker container are
#'   accessible.
#' @param args Arguments to pass to the function. Must be a list.
#' @param image A string in the `image:tag` format specifying either a local
#'   Docker image or an image available on DockerHub. Default image is
#'   `r-base:your.r.version` where your R version is determined from your local
#'   R session.
#' @param stdout,stderr where output to ‘stdout’ or ‘stderr’ should be sent.
#'   Possible values are "", to the R console (the default), NULL or FALSE
#'   (discard output), TRUE (capture the output in a character vector) or a
#'   character string naming a file. See [system2] for more details.
#' @param install_dependencies A boolean indicating whether jetty should
#'   discover packages used in your code and try to install them in the
#'   Docker container prior to executing the provided function/expression.
#'   In general, things will work better if the Docker image already has all
#'   necessary packages installed.
#' @param debug A boolean indicating whether to print out the commands that are
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
#'     model <- lm(mpg ~ ., data = mtcars)
#'     model
#'   }
#' )
#' }
#' 
#' \dontrun{
#' run(
#'   {
#'     mtcars |> 
#'       dplyr::mutate(cyl = as.factor(cyl))
#'     model <- lm(mpg ~ ., data = mtcars)
#'     model
#'   },
#'   install_dependencies = TRUE
#' )
#' }
#'
#' @export
run <- function(
  func,
  args = list(),
  image = paste0("r-base:", r_version()),
  stdout = "",
  stderr = "",
  install_dependencies = FALSE,
  debug = FALSE
) {
  check_args(args)
  temp_dir <- tempdir()
  temp_out <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  temp_in <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  saveRDS(object = args, file = temp_in)
  on.exit(if (file.exists(temp_in)) file.remove(temp_in), add = TRUE)
  on.exit(if (file.exists(temp_out)) file.remove(temp_out), add = TRUE)
  expr <- rlang::enexpr(func)
  if (install_dependencies) {
    temp_R <- file.path(temp_dir, "jetty.R")
    writeLines(rlang::expr_text(expr), temp_R)
    on.exit(if (file.exists(temp_R)) file.remove(temp_R), add = TRUE)
    dependencies <- renv::dependencies(temp_R, quiet = TRUE)$Package
  } else {
    dependencies <- NULL
  }
  expr <- command_shell_prep(
    !!expr,
    temp_out = temp_out,
    temp_in = temp_in,
    dependencies = dependencies
  )
  temp_dir_mount <- bindmount_temp(temp_dir)
  home_dir_mount <- bindmount_home()
  cmd_args <- c(
    "run",
    "-t",
    "--rm",
    home_dir_mount,
    temp_dir_mount,
    image,
    "Rscript",
    "-e",
    expr
  )
  if (debug) cmd_message(cmd_args)
  out <- docker_command(args = cmd_args, stdout = stdout, stderr = stderr)
  result <- readRDS(temp_out)
  handle_error(result)
  result
}
