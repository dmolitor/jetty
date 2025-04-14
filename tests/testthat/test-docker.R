test_that("jetty can find and interact with Docker", {

  skip_on_cran()

  expect_type(jetty:::docker_installed(), "logical")
  expect_error(jetty:::docker_command("fail", stdout = TRUE, stderr = TRUE), class = "docker_cmd_error")
  expect_silent(jetty:::stop_if_not_installed())
})

test_that("jetty executes commands and gets expected results", {

  skip_on_cran()

  # lm test
  expect_s3_class(jetty::run({ lm(mpg ~ ., data = mtcars) }, image = "r-base:latest", r_profile = NULL), class = "lm")
  expect_s3_class(jetty::run(function(d) lm(mpg ~ ., data = d), args = list(d = mtcars), image = "r-base:latest", r_profile = NULL), class = "lm")
  expect_error(jetty::run(function(d) lm(mpg ~ ., data = d), args = c(mtcars), image = "r-base:latest", r_profile = NULL))

  # using a package (Matrix)
  expect_equal(
    object = jetty::run({
      library(Matrix)
      set.seed(123)
      rsparsematrix(10, 10, density = 1)
    }, image = "r-base:latest", r_profile = NULL),
    expected = {
      set.seed(123)
      library(Matrix)
      rsparsematrix(10, 10, density = 1)
    }
  )

  # Using library and :: syntax to reference functions
  expect_equal(
    object = jetty::run({
      library(Matrix)
      set.seed(123)
      rsparsematrix(10, 10, density = 1)
    }, image = "r-base:latest", r_profile = NULL),
    expected = jetty::run({
      set.seed(123)
      function(ncol) Matrix::rsparsematrix(10, ncol, 1)
    },
    args = list(ncol = 10), 
    image = "r-base:latest",
    r_profile = NULL)
  )

  # ggplot2 example
  plt <- jetty::run(
    func = {
      ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt, color = as.factor(cyl))) +
        ggplot2::geom_point() +
        ggplot2::labs(color = "cyl") +
        ggplot2::theme_minimal()
    },
    install_dependencies = TRUE,
    image = "r-base:latest",
    r_profile = NULL
  )
  expect_s3_class(plt, class = c("gg", "ggplot"))
})

test_that("jetty correctly loads existing .Rprofile and .Renviron", {

  if (!interactive()) skip()

  out <- jetty::run(
    func = function() { var(mycars) },
    install_dependencies = TRUE,
    r_profile = here::here("man/scaffolding/.Rprofile"),
    r_environ = here::here("man/scaffolding/.Renviron"),
    image = "r-base:latest"
  )
  expect_equal(out, var(cars))
  expect_equal(
    jetty::run(
      func = function() { Sys.getenv("JETTY_TEST") },
      r_environ = here::here("man/scaffolding/.Renviron"),
      image = "r-base:latest"
    ),
    "123abc456"
  )
  expect_error(
    jetty::run(
      func = function() { var(mycars) },
      r_profile = here::here("man/scaffolding/.Rprofile"),
      r_environ = here::here("man/scaffolding/.Renviron"),
      image = "r-base:latest"
    )
  )
})

test_that("jetty honors R options and System environment variables", {

  if (!interactive()) skip()

  # Set a system environment variable to ignore the .Rprofile
  cur_val <- Sys.getenv("JETTY_IGNORE_RPROFILE")
  Sys.setenv("JETTY_IGNORE_RPROFILE" = TRUE)
  expect_identical(jetty::run(function() var(cars)), var(cars), tolerance = 1e-5)
  Sys.setenv("JETTY_IGNORE_RPROFILE" = cur_val)

  # Set an R option to ignore the .Rprofile
  cur_val <- getOption("jetty.ignore.rprofile")
  options("jetty.ignore.rprofile" = TRUE)
  expect_identical(jetty::run(function() var(cars)), var(cars), tolerance = 1e-5)
  options("jetty.ignore.rprofile" = cur_val)

  skip()
  # Expect an error in this environment because it should fail to
  # execute the existing .Rprofile
  expect_error(jetty::run(function() var(cars), stdout = FALSE))
})
