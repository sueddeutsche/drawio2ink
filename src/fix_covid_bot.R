library(tidyverse)

fix_covid_bot <- function(df) {

# Targets: Add _ENDE; replace class with group1 to group4
  df %>%
    mutate(class = str_extract(value, "(?<=Gruppe )[0-9]+(?=\\)\\.)"),
           value = ifelse(grepl("\\(Gruppe .+\\)\\.", value),
                          str_replace(value, "(?<=CLASS\\: ).+", paste0("group", class)),
                          value)) -> cells_df

  return(cells_df)

}

get_end_ids <- function(df) {
  df %>%
    filter(is.na(target)) %>%
    pull(id) -> end_ids

  return(end_ids)
}

replace_end_ids <- function(id) {
  id <- gsub("\\(\\?\\!\\[0\\-9\\]\\)", "", id)
  return(
    paste0(id, "_ENDE")
  )
}
