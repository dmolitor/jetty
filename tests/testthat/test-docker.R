test_that("jetty can find and interact with Docker", {

  skip_if_not(interactive(), "Testing is currently only for local (interactive) development")

  expect_type(jetty:::docker_installed(), "logical")
  expect_error(jetty:::docker_command("fail"), class = "docker_cmd_error")
  expect_type(jetty::docker_info(), "list")
  expect_silent(jetty:::stop_if_not_installed())
})

test_that("jetty executes commands and gets expected results", {

  skip_if_not(interactive(), "Testing is currently only for local (interactive) development")

  # lm test
  expect_s3_class(jetty::run({ lm(mpg ~ ., data = mtcars) }), class = "lm")
  expect_s3_class(jetty::run(\(d) lm(mpg ~ ., data = d), args = list(d = mtcars)), class = "lm")
  expect_error(jetty::run(\(d) lm(mpg ~ ., data = d), args = c(mtcars)))

  # using a package (Matrix)
  expect_equal(
    object = jetty::run({
      library(Matrix)
      set.seed(123)
      rsparsematrix(10, 10, density = 1)
    }),
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
    }),
    expected = jetty::run({
      set.seed(123)
      function(ncol) Matrix::rsparsematrix(10, ncol, 1)
    },
    args = list(ncol = 10))
  )

  # ggplot2 example using a custom image
  plt <- jetty::run(
    func = {
      ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt, color = as.factor(cyl))) +
        ggplot2::geom_point() +
        ggplot2::labs(color = "cyl") +
        ggplot2::theme_minimal()
    },
    image = "djmolitor/mobility-and-pollution"
  )
  expect_s3_class(plt, class = c("gg", "ggplot"))
})
