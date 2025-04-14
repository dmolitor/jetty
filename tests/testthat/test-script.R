test_that("Basic script execution functionality works correctly", {
  
  if (!interactive()) skip()
  
  out <- run_script(
    file = here::here("man", "scaffolding", "test_script_simple.R"),
    stdout = FALSE,
    install_dependencies = TRUE,
    r_profile = here::here("man", "scaffolding", ".Rprofile"),
    r_environ = here::here("man", "scaffolding", ".Renviron")
  )
  expect_equal(out, "123abc456")
  expect_true(file.exists(here::here("man", "scaffolding", "mtcars.csv")))
  expect_true(file.exists(here::here("man", "scaffolding", "mycars.csv")))

  for (file in here::here("man", "scaffolding", c("mtcars.csv", "mycars.csv"))) {
    if (file.exists(file)) file.remove(file)
  }
})

test_that("jetty handles the `run_script` context as expected", {
  
  if (!interactive()) skip()
  
  expect_error(
    object = run_script(
      file = here::here("man", "scaffolding", "test_script_advanced.R"),
      stdout = FALSE,
      install_dependencies = TRUE,
      r_profile = NULL
    )
  )
  out <- run_script(
    file = here::here("man", "scaffolding", "test_script_advanced.R"),
    context = here::here(),
    stdout = FALSE,
    install_dependencies = TRUE,
    r_profile = NULL
  )
  expect_identical(
    confint(readRDS(here::here("man", "scaffolding", "mtcars_lm.Rds"))),
    confint(lm(mpg ~ hp, data = mtcars)),
    tolerance = 1e-5
  )
  expect_true(file.exists(here::here("man", "scaffolding", "mtcars_plot.png")))
  expect_true(file.exists(here::here("man", "scaffolding", "mtcars_lm.Rds")))

  for (file in here::here("man", "scaffolding", c("mtcars_plot.png", "mtcars_lm.Rds"))) {
    if (file.exists(file)) file.remove(file)
  }
})

test_that("`run_script` errors when installed packages are missing", {
  
  if (!interactive()) skip()
  
  expect_error(
    run_script(
      file = here::here("man", "scaffolding", "test_script_simple.R"),
      stdout = FALSE,
      r_profile = here::here("man", "scaffolding", ".Rprofile"),
      r_environ = here::here("man", "scaffolding", ".Renviron")
    )
  )
})
