command_shell_prep <- function(expr, rprof, renv, temp_out, temp_in, dependencies) {
  expr <- rlang::enexpr(expr)
  expr <- rlang::expr_text(expr)
  expr <- paste0(
    "\ntryCatch({",
    if (!is.null(dependencies)) {
      "\ninstall.packages(\"pak\", repos = sprintf(\"https://r-lib.github.io/p/pak/stable/%s/%s/%s\", .Platform$pkgType, R.Version()$os, R.Version()$arch))"
    } else {
      dependencies
    },
    if (!is.null(dependencies)) {
      paste0("\npak::pkg_install(c('", paste0(dependencies, collapse = "', '"), "'))")
    } else {
      dependencies
    },
    if (!is.null(rprof)) paste0("\n", rprof) else rprof,
    if (!is.null(renv)) paste0("\n", renv) else renv,
    "\njetty_output <- ",
    expr,
    "\nif (is.function(jetty_output)) jetty_output <- do.call(jetty_output, args = readRDS(file = \"",
    temp_in,
    "\"))",
    "\nsaveRDS(jetty_output, file=\"",
    temp_out,
    "\") }, error = function(err) { saveRDS(err, file=\"",
    temp_out,
    "\"); return(1) })"
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
#'   to \code{\link{system2}}.
#' @param stdout,stderr where output to ‘stdout’ or ‘stderr’ should be sent.
#'   Possible values are "", to the R console (the default), NULL or FALSE
#'   (discard output), TRUE (capture the output in a character vector) or a
#'   character string naming a file. See \code{\link{system2}} for more details.
#' @param ... Additional arguments to pass directly to \code{\link{system2}}.
#' @return The output of the given command as a string.
#' @examples
#' \dontrun{
#' docker_info <- docker_command(c("info", "--format '{{json .}}'"), stdout = TRUE)
#' }
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
#' \code{callr::r()} in that the user can pass
#' a function (or a code block) to be evaluated. This code will
#' be executed within the context of a Docker container and the result will be
#' returned within the local R session.
#'
#' @section Side effects:
#' 
#' It is important to note that some side effects, e.g. plotting,
#' may be lost since these are being screamed into the void of the Docker
#' container. However, the user has full control over the 'stdterr' and 'stdout'
#' of the R sub-process running in the Docker container, and so side effects such
#' as messages, warnings, and printed output can be directed to the console or
#' captured by the user.
#' 
#' It is also crucial to note that actions on the local file system will not
#' work with jetty sub-processes. For example, reading or writing files to/from
#' the local file system will fail since the R sub-process within the Docker
#' container does not have access to the local file system.
#'
#' @section Error handling:
#'
#' jetty will propagate errors from the Docker process to the main process.
#' That is, if an error is thrown in the Docker process, an error with the same
#' message will be thrown in the main process. However, because of the
#' somewhat isolated nature of the local process and the Docker process,
#' calling functions such as \code{base::traceback()} and \code{rlang::last_trace()} will,
#' unfortunately, not print the callstack of the uncaught error as that has
#' (in its current form) been lost in the Docker void.
#'
#' @param func Function object or code block to be executed in the R session
#'   within the Docker container. It is best to reference package functions using
#'   the \code{::} notation, and only packages installed in the Docker container are
#'   accessible.
#' @param args Arguments to pass to the function. Must be a list.
#' @param image A string in the \code{image:tag} format specifying either a local
#'   Docker image or an image available on DockerHub. Default image is
#'   \code{r-base:{jetty:::r_version()}} where your R version is determined from
#'   your local R session.
#' @param stdout,stderr Where output to ‘stdout’ or ‘stderr’ should be sent.
#'   Possible values are "" (send to the R console; the default), NULL or FALSE
#'   (discard output), TRUE (capture the output in a character vector) or a
#'   character string naming a file. See \code{\link{system2}} for more details.
#' @param install_dependencies A boolean indicating whether jetty should
#'   discover packages used in your code and try to install them in the
#'   Docker container prior to executing the provided function/expression.
#'   In general, things will work better if the Docker image already has all
#'   necessary packages installed.
#' @param r_profile,r_environ Paths specifying where jetty should search for
#'   the .Rprofile and .Renviron files to transfer to the Docker sub-process.
#'   By default jetty will look for files called ".Rprofile" and ".Renviron"
#'   in the current working directory. If either file is found, they will be
#'   transferred to the Docker sub-process and loaded before executing any
#'   R commands.
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
#' 
#' run(
#'   {
#'     mtcars |> 
#'       dplyr::mutate(cyl = as.factor(cyl))
#'     model <- lm(mpg ~ ., data = mtcars)
#'     model
#'   },
#'   install_dependencies = TRUE
#' )
#' 
#' # This will error since the `praise` package is not installed
#' run(function() praise::praise())
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
  r_profile = file.path(getwd(), ".Rprofile"),
  r_environ = file.path(getwd(), ".Renviron"),
  debug = FALSE
) {
  check_args(args)
  # Handle writing of args to serialized temp files
  temp_dir <- tempdir()
  temp_in_local <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  temp_in_docker <- file.path(jetty_temp_dir(), basename(temp_in_local))
  temp_out_local <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  temp_out_docker <- file.path(jetty_temp_dir(), basename(temp_out_local))
  on.exit(if (file.exists(temp_in_local)) file.remove(temp_in_local), add = TRUE)
  on.exit(if (file.exists(temp_out_local)) file.remove(temp_out_local), add = TRUE)
  saveRDS(object = args, file = temp_in_local)
  # Capture the expression to be evaluated
  expr <- rlang::enexpr(func)
  # If requested, write the code to an R file and examine for dependencies
  dependencies <- take_stock(
    expr = expr,
    install_dependencies = install_dependencies,
    temp_dir = temp_dir,
    r_profile = r_profile
  )
  # Generate the bind mounts and loading commands for .Rprofile and .Renviron
  rprof_env_bindmounts <- prof_env_bindmounts(r_profile, r_environ)
  rprof_bindmount <- rprof_env_bindmounts[[1]]
  rprof_load <- rprof_env_bindmounts[[3]]
  renv_bindmount <- rprof_env_bindmounts[[2]]
  renv_load <- rprof_env_bindmounts[[4]]
  # Parse the code into the corresponding docker command
  expr <- command_shell_prep(
    !!expr,
    rprof = rprof_load,
    renv = renv_load,
    temp_out = temp_out_docker,
    temp_in = temp_in_docker,
    dependencies = dependencies
  )
  # Generate additional arguments to pass to `docker run ...`
  temp_dir_mount <- bindmount_temp(temp_dir, jetty_temp_dir())
  cmd_args <- c(
    "run",
    "-t",
    "--rm",
    temp_dir_mount,
    rprof_bindmount,
    renv_bindmount,
    image,
    "Rscript",
    "-e",
    expr
  )
  if (debug) cmd_message(cmd_args)
  out <- docker_command(args = cmd_args, stdout = stdout, stderr = stderr)
  result <- readRDS(temp_out_local)
  handle_error(result)
  result
}
