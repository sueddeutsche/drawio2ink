# TODO: support for chart-images (in square format) (/ datawrapper-iframes)
rm(list = ls())

parse_xml <-
  function(file, expert_prefix, annotation_checkbox, annotation_text, restart_text, expert_conclusion) {
    doc_xml <-
      read_xml(file, encoding = "utf8", options = "")
    expert_prefix <-
      glue("<em>{expert_prefix()}</em>")
    annotation <-
      glue("{annotation_text()} # CLASS: annotation")

    doc_mxcells <-
    doc_xml %>%
    xml_child() %>%
    xml_child() %>%
    xml_children() %>%
    xml_find_all(., "mxCell")


  # pre-construct df with the needed xml attributes as column names
  cells_df <-
    tribble(
      ~id,
      ~style,
      # ~parent,
      ~source,
      ~target,
      # ~edge,
      # ~vertex,
      ~value
      )

  # add a row for each xml element
  cells_df <-
    doc_mxcells %>%
    map(xml_attrs) %>%
    map_df(~add_row(.data = cells_df,
                    id = .["id"],
                    style = .["style"],
                    source = .["source"],
                    target = .["target"],
                    value = .["value"]))


  # remove these two rows that have no use
  cells_df %>%
    filter(!id %in% c(0, 1)) -> cells_df


  # the following lines aren't that useful, because sometimes,
  # after manual changes in the draw.io flow chart, the order of the style elements
  # differs. So it could be an arrow, even if there was no 'edgeStyle' as first element
  # # extract the first element in the style attribute
  # # to identify the type of xml element
  # cells_df %>%
  #   mutate(
  #       style_extracted = str_extract(style, "^[^;]+(?=;)")
  #   ) -> cells_df
  # # what different types of xml elements are in the xml?
  # cells_df %>% pull(style_extracted) %>% unique()

  # create two columns for the different types of elements and textboxes we have
  cells_df %>%
    mutate(
      type = case_when(
        str_detect(style, "orthogonalLoop") ~ "arrow",
        str_detect(style, "endArrow")       ~ "arrow",
        str_detect(style, "rounded=1")      ~ "textbox",
        str_detect(style, "rounded=0")      ~ "textbox",
        str_detect(style, "ellipse")        ~ "textbox",
        str_detect(style, "shape=hexagon")  ~ "textbox",
        str_detect(style, "text")           ~ "textbox",
        TRUE                                ~ "other"
        ),
      textbox_type = case_when(
        type == "textbox" & str_detect(style, "rounded=1")     ~ "option",
        type == "textbox" & str_detect(style, "rounded=0")     ~ "reaction",
        type == "textbox" & str_detect(style, "ellipse")       ~ "expert",
        # 'shape=hexagon' is a necessary style to identify the initial reaction
        type == "textbox" & str_detect(style, "shape=hexagon") ~ "reaction",
        type == "textbox" & str_detect(style, "text")          ~ "other_text",
        TRUE                                                   ~ "none"
        )
    ) -> cells_df

  # cells_df %>% pull(type) %>% table
  # cells_df %>% pull(textbox_type) %>% table


  # check  for disconnected arrows w/ message output
  cells_df %>%
    filter(type == "arrow") %>%
    filter(
      is.na(source) |  is.na(target)
    ) %>%
    select(id, source, target) -> disconnected_arrows

  disconnected_arrows_msg <-
    function() {
      print(paste0("There are ", nrow(disconnected_arrows), " arrows without a proper beginning and ending:"))
      df <- tibble()
      for (i in seq_along(disconnected_arrows$id)) {
        df <- bind_rows(df, cells_df %>%
                filter(id == if_else(
                  is.na(disconnected_arrows$source[i]),
                  disconnected_arrows$target[i],
                  disconnected_arrows$source[i])) %>%
                  mutate(
                    connected_at = if_else(
                      is.na(disconnected_arrows$source[i]),
                      "target",
                      "source")
                  ) %>%
                select(id, value, textbox_type, connected_at)
              )
      }
      print(df)
      print(df$value)
      }

  if (nrow(disconnected_arrows) > 0) {
    disconnected_arrows_msg()
    stop("There are disconnected arrows. Please visit your draw.io and fix them.")
  }


  # names for stitches in ink are not allowed to have a "-" in them
  cells_df %>%
    mutate_at(
      c("id", "source", "target"),
      str_replace_all,
      pattern = "-",
      replacement = "_"
      ) -> cells_df

  # remove this characters that are only relevant for humans
  cells_df %>%
    mutate(
      value = str_replace(value, "\\(ENDE\\)", ""),
      value = str_replace(value, "\\(Ende\\)", "")
      ) -> cells_df

  #TODO: this does not work at the moment, but I don't want to lose the idea
  # replace the weird ids with comprehensible ones;
  # names for stitches in ink are not allowed to have a "-"(minus) in them
  # cells_df %>%
  #   mutate(
  #     id = case_when(
  #       type == "arrow" ~ str_replace(id, "[:alnum:]+-", paste0(type, "_")),
  #       type == "textbox" ~ str_replace(id, "[:alnum:]+-", paste0(textbox_type, "_")),
  #       TRUE ~ id
  #       )
  #     ) -> cells_df

  # for (i in seq_along(cells_df$source)) {
  #   print(i)
  #   if (!is.na(cells_df$source[i])) {
  #     print(i)
  #   cells_df$source[i] <- na.omit(str_extract(cells_df$id, paste0(".+", str_extract(cells_df$source[i], ".{2}$"), "$")))
  #   } else {
  #     next
  #   }
  # }
  #
  # for (i in seq_along(cells_df$target)) {
  #   if (!is.na(cells_df$target[i])) {
  #     cells_df$target[i] <- na.omit(str_extract(cells_df$id, paste0(".+", str_extract(cells_df$target[i], "[0-9]+$"), "$")))
  #   } else {
  #     next
  #   }
  # }


  # get the target ids for the storytext from the arrows
  for (i in seq_along(cells_df$id)) {
    if (cells_df$type[i] == "textbox" & sum(na.omit(cells_df$source == cells_df$id[i])) > 1) {
      # print(paste0("Zeile ", i, " hat mehr als eine source"))
      cells_df$target[i] <- unlist(na.omit(cells_df$target[cells_df$source == cells_df$id[i]])) %>% na.omit() %>% list()

      } else if(cells_df$type[i] == "textbox" & sum(na.omit(cells_df$source == cells_df$id[i])) == 1) {
        # print(paste0("Zeile ", i, " hat genau eine source"))
        # print(paste0("Vorher: ", cells_df$target[[i]]))
        cells_df$target[[i]] <- cells_df$target[cells_df$type == "arrow" & cells_df$source == cells_df$id[i]] %>% na.omit()
        # print(paste0("Nachher: ", cells_df$target[[i]]))
      } else {
        next
      }
    }


  # get id of the initial reaction for the top of the ink file
  start_id <-
    cells_df %>%
    filter(str_detect(style, "shape=hexagon")) %>%
    pull(id)


  # we don't need most of the columns and no arrow rows for the rest
  cells_df %>%
    filter(type != "arrow", textbox_type != "other_text") %>%
    select(id, source, target, value, type, textbox_type) -> cells_df


  # single target values have been converted to a list, we want them unlisted
  cells_df$target <-
    map_if(cells_df$target, is_list, unlist)

  # remove all quotation marks and add the correct ones only for the dialogue;
  #  also remove html-tags
  cells_df %>%
    mutate(
      value = str_remove_all(value, '“|”|"'),
      value = str_remove_all(value, "<{1}[:lower:]+>{1}|<{1}\\/[a-z]+>{1}"),
      value = str_remove(value, "FAZIT:"),
      value = str_replace_all(value, "&nbsp;", " "),
      value = str_replace_all(value, "([,.?!])(?=[:alpha:])", "\\1 "),
      value = str_trim(value),
      value = case_when(
        textbox_type == "reaction" ~ paste0("„", value, "“"),
        textbox_type == "option" ~ paste0("„", value, "“"),
        TRUE ~ value
      ),
      value = str_replace_all(value, "CO2", "CO₂")
    ) -> cells_df

  # we want to append the appropriate css-class for the different textbox types
  cells_df %>%
    mutate(
      value = case_when(
        textbox_type == "option"   ~ paste0(value, " # CLASS: self"),
        textbox_type == "reaction" ~ paste0(value, " # CLASS: opposite"),
        textbox_type == "expert"   ~ paste0(value, " # CLASS: expert"),
        TRUE ~ value
      )
    ) -> cells_df

  # this is necessary to have a separate df with the ids of only the reactions
  cells_df_reactions <- cells_df %>% filter(textbox_type == "reaction")


  ##### Writing the ink file ####

  # initialize ink story with a divert arrow to the first stitch
  ink <- paste0("-> ", start_id, "\n")
  #TODO: remove space at the end, if ready for publication:

  # loop through row, then targets per row,
  # because each reaction has several options and those have divert targets
  for (i in 1:nrow(cells_df_reactions)) {
    print(paste0("Processing row ", i))
    # append stitch name and reaction text:
    ink <- paste0(
      ink, "\n", "\n",
      "= ", cells_df_reactions$id[i],
      "\n",
      cells_df_reactions$value[i], "\n",
      if (annotation_checkbox() == TRUE) {
        if (cells_df_reactions$id[i] == start_id) {
          paste0("\n\t", annotation, "\n")
        }
      }
      )

    for (j in seq_along(cells_df_reactions$target[[i]])) {
      print(paste0("Processing target ", j, " of row ", i))

        if (any(is.na(cells_df$value[cells_df$id == cells_df_reactions$target[[i]][j]]))) {
          # append end stitches:
          print(paste0("Creating END arrow for row ", i, ", target ", j))
          ink <- paste0(
            ink,
            # add expert conclusion before end divert arrow
            #TODO: remove space at the end, if ready for publication:
            "\n\t\t <em>", expert_conclusion(), "</em>", cells_df$value[cells_df$target ==  cells_df_reactions$id[[i]] & cells_df$textbox_type == "expert"] %>% na.omit(), "\n",
            "\n\t\t * [", restart_text(),"] # RESTART\n\t\t -> ", start_id, "\n"#,
            # "\t\t-> END"
          )
        } else {
          # append option text and divert targets of options:
          if (cells_df_reactions$textbox_type[[i]] == "none") {
            print(paste0("Not a textbox, skipping… "))
            next
          } else {
            ink <- paste0(
              ink, "\n", # append to ink file

              # option text: ####
              "\t* ", cells_df$value[cells_df$id == cells_df_reactions$target[[i]][j]], "\n",

              # expert text: ####
              if (!cells_df$textbox_type[cells_df$target == cells_df_reactions$target[[i]][j]] %>% na.omit %>% is_empty() && cells_df$textbox_type[cells_df$target %in% cells_df_reactions$target[[i]][j]] %>% na.omit %>% unlist == "expert") {
              paste0("\t\t", expert_prefix, cells_df$value[cells_df$target == cells_df_reactions$target[[i]][j]] %>% na.omit(), "\n")
              },
              "\t\t-> ", cells_df$target[cells_df$id == cells_df_reactions$target[[i]][j]]
            )
          }
        }
    }

  }
  return(ink)
}

# parse_xml("data/input/flightshaming_pro.xml")

# write_file(ink, "data/parsed/story.ink")
# it's possible to automatically compile the json version of the ink file for
# web deployment of the story. however, it's complicated to run on linux and
# different for every OS.
# check out https://github.com/inkle/ink#using-inklecate-on-the-command-line
# for more info.
# system("~/Downloads/inklecate_mac/inklecate data/parsed/story.ink")


