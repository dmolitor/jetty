library(ggplot2)

ggplot(mtcars, aes(x = mpg, y = hp, color = factor(cyl))) +
  geom_point() +
  theme_minimal() +
  labs(color = "cyl")

ggsave(here::here("man/scaffolding/mtcars_plot.png"))

lm_mtcars <- lm(mpg ~ hp, data = mtcars)
saveRDS(lm_mtcars, here::here("man/scaffolding/mtcars_lm.Rds"))