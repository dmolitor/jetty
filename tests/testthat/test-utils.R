test_that("utility functions work as expected", {
  testthat::skip_on_cran()
  expect_message(
    cmd_message(c("run", "-i", "-t", "--rm", "r-base:latest")),
    regexp = "Executing command:\ndocker run -i -t --rm r-base:latest"
  )
  expect_equal(jetty_temp_dir(), "/jetty/tmp/")
  expect_true(docker_installed())
  expect_null(stop_if_not_installed())
})
