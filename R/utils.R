bindmount_home <- function() {
  # TODO: figure out correct Windows volume
  home_dir <- path.expand("~")
  arg <- paste0("-v ", home_dir, ":", home_dir, "/")
  arg
}

bindmount_temp <- function(dir) {
  # TODO: figure out correct Windows volume
  arg <- paste0("-v ", dir, ":", dir, "/")
  arg
}

check_args <- function(args) {
  if (is.list(args) && !is.data.frame(args)) return(invisible(args))
  rlang::abort("`args` must be a list")
}

cmd_message <- function(cmd_args) {
  message(
    paste0(
      "Executing command:\n",
      paste0(c("docker", cmd_args), collapse = " ")
    )
  )
}

#' Retrieve system Docker information
#'
#' @param simplify Logical; Whether to simplify the json structure (e.g.
#'   coerce list of lists elements into a data.frame) or return as one big list.
#' @return A list containing Docker system information
#' @export
docker_info <- function(simplify = TRUE) {
  stop_if_not_installed()
  info <- docker_command(c("info", "--format '{{json .}}'"))
  info <- jsonlite::fromJSON(info, simplifyVector = simplify)
  info
}

docker_installed <- function() {
  installed <- Sys.which("docker")
  if (installed == "") installed <- FALSE else installed <- TRUE
  installed
}

handle_error <- function(err) {
  if (inherits(err, "rlang_error")) {
    print(err, backtrace = FALSE)
    stop_quietly()
  }
  if (inherits(err, "error")) stop(err)
  invisible(err)
}

is_windows <- function() {
  if (.Platform$OS.type == "windows") return(TRUE)
  FALSE
}

r_version <- function() {
  paste0(R.version$major, ".", R.version$minor)
}

stop_if_not_installed <- function() {
  is_installed <- docker_installed()
  if (!is_installed) {
    rlang::abort(
      c(
        "Docker is not installed.",
        "i" = "Visit https://docs.docker.com/get-docker/ to get started!"
      ),
      call = parent.frame()
    )
  }
}

stop_quietly <- function() {
  opt <- options(show.error.messages = FALSE)
  on.exit(options(opt), add = TRUE)
  stop()
}
