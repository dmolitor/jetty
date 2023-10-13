#' Retrieve system Docker information
#'
#' @param simplify Logical; Whether to simplify the json structure (e.g.
#'   coerce list of lists elements into a data.frame) or return as one big list.
#' @return A list containing Docker system information
#' @export
docker_info <- function(simplify = TRUE) {
  info <- docker_command(c("info", "--format '{{json .}}'"))
  info <- jsonlite::fromJSON(info, simplifyVector = simplify)
  info
}

#' Check if Docker is installed
#'
#' @return `TRUE` or `FALSE`
#' @export
docker_installed <- function() {
  installed <- tryCatch(
    docker_command(c("info", "--format '{{json .}}'")),
    docker_cmd_error = function(err) {
      -1
    },
    error = function(err) {
      rlang::abort(err$message)
    }
  )
  if (installed == -1) installed <- FALSE else installed <- TRUE
  installed
}

#' Run a Docker command
#'
#' @param args A single argument or vector of arguments to pass to [system2()].
#' @examples
#' \dontrun{
#'   docker_command(c("info", "--format '{{json .}}'")
#' }
#' @return The output of the given command as a string.
#' @export
docker_command <- function(args) {
  cmd <- suppressWarnings(system2("docker", args = args, stdout = TRUE))
  status <- attr(cmd, "status")
  if (length(status) > 0 && status > 0) {
    cmd <- paste("docker", paste(args, collapse = " "))
    rlang::abort(
      class = "docker_cmd_error",
      message = c(
        "Docker command exited with non-zero status",
        "i" = paste0("Executed command: ", cmd)
      ),
      data = status
    )
  }
  cmd
}

is_windows <- function() {
  if (.Platform$OS.type == "windows") return(TRUE)
  FALSE
}

r_version <- function() {
  paste0(R.version$major, ".", R.version$minor)
}

# Code snippet of how to deal with specifically `docker_cmd_error`s
# tryCatch(
#   docker_command(c("info", "--format '{{json .}}'", "--biznatch")),
#   docker_cmd_error = function(err) {
#     cat(err$message)
#   },
#   error = function(err) {
#     cat("Caught a non-docker-cmd error!\n")
#   }
# )
