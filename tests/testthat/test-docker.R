test_that("jetty can find and interact with Docker", {
  expect_type(jetty:::docker_installed(), "logical")
  expect_error(jetty:::docker_command("biznatch"), class = "docker_cmd_error")
  expect_type(jetty::docker_info(), "list")
  expect_silent(jetty:::stop_if_not_installed())
})

test_that("jetty executes commands and gets expected results", {
  expect_s3_class(jetty::run({ lm(mpg ~ ., data = mtcars) }), class = "lm")
  expect_s3_class(jetty::run(\(d) lm(mpg ~ ., data = d), args = list(d = mtcars)), class = "lm")
})
