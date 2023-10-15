library(hexSticker)
library(magick)

img <- image_read(here::here("man", "figures", "jetty-logo.png"))
res <- img |>
  image_convert("png") |>
  image_fill(color = "none") |>
  image_annotate(text = "jetty",
                 font = "Times",
                 style = "normal",weight = 1000,
                 size = 40,
                 #degrees = 30,
                 location = "+98+130", color="white")

sticker(
  filename = here::here("man", "figures", "logo.png"),
  white_around_sticker = TRUE,
  res,
  package = "",
  s_x = 0.97,
  s_y = 1.04,
  s_width = 2,
  s_height = 14,
  h_fill = "dodgerblue4",
  h_color = "#A9A9A9"
)

# Remove the background at remove.bg
