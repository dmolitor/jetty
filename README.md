# pod
 Execute R expressions within the context of a Docker container.

## Install
```r
# install.packages("remotes")
remotes::install_github("dmolitor/pod")
```

# Example
```r
library(pod)

mtcars_model <- run(
  func = {
    mtcars <- mtcars |>
      transform(cyl = as.factor(cyl))
    model <- lm(mpg ~ ., data = mtcars)
    model
  },
  image = "r-base:4.2.0"
)
summary(mtcars_model)
```
