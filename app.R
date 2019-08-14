# TODO: Expertenfazit als reactive Option
# TODO: Preview textOutput box unter die Optionen

# define required R packages
pkgs <- c(
    "shiny",
    "shinythemes",
    "here",
    "xml2",
    "dplyr",
    "purrr",
    "stringr",
    "readr",
    "glue"
)

# load packages
for (p in pkgs) {
    require(p, character.only = TRUE)
}


################
###### ui ######
################

ui <- fluidPage(
    theme = shinytheme("flatly"),
    # Application title
    titlePanel("drawio2ink – Parser from draw.io through R to ink"),
    sidebarLayout(
        sidebarPanel(
            p("For detailed information please visit the ", a(href = "https://github.com/sueddeutsche/drawio2ink", "Github repo")),
            # offer some options to configure story elements like the prefixed text for
            # the expert comments or a guiding text after the first reaction
            h3("🛠 Configuration"),
            h4("🗣 Expert Comment"),
            textInput(inputId = "expert_prefix_input",
                      label = "How should the expert be referenced?",
                      value = "Das sagt Expertin Melinda Tamás:",
                      placeholder = "Bsp.: Das sagt Expertin Melinda Tamás:"),
            h5("Preview with example text:"),
            textOutput("expert_prefix_preview"),
            hr(),
            h4("💡 Expert Conclusion"),
            textInput(inputId = "expert_conclusion_input",
                      label = "Text for the expert conclusion?",
                      value = "Das Fazit von Expertin Melinda Tamás:",
                      placeholder = "Bsp.: Das Fazit von Expertin Melinda Tamás:"),
            h5("Preview with example text:"),
            textOutput("expert_conclusion_preview"),
            hr(),
            h4("🌅 Introductory Annotation"),
            checkboxInput(inputId = "annotation_checkbox",
                          label = "Enable a introductory annotation? (Appears after the first reaction of the counterpart)",
                          value = TRUE),
            textAreaInput(inputId = "annotation_text",
                          label = "How do you want to guide the reader into the story after the intro? (Gets the CSS class 'annotation')",
                          value = "",
                          placeholder = "Bsp.: Und, wie reagieren Sie? Klicken Sie einfach auf eine der drei Antwortmöglichkeiten und lesen Sie, was die Expertin dazu sagt – und wie Ihr Gegenüber reagiert.",
                          height = "100px"),
            hr(),
            h4("🔃 Restart Button"),
            textInput(inputId = "restart_text_input",
                      label = "Text for the restart button:",
                      value = "Noch mal",
                      placeholder = "Bsp.: Noch mal"),
            hr(),

            h3("📝 Apply these settings to a file"),
            h4("📂 Input"),
            fileInput(
                "file1",
                "Choose a .xml file:",
                multiple = FALSE,
                accept = "text/xml",
                buttonLabel = "Browse…",
                placeholder = "No file chosen…"
            ),

            h4("💾 Download"),
            downloadButton("download_ink", "Download .ink-file")
        ),

        mainPanel(
            h4("👀 Output preview"),
            verbatimTextOutput("inkText")
            )
        )
    )

################
#### server ####
################

server <- function(input, output, session) {
    source(here("src", "parse_xml.R"))
    # TODO: auf action-button legen mit reactive
    # TODO: V8 und shinyjs, um den output zu stylen

    # variables for the parser and ShinyApp features
        xmlfile_meta <-
            reactive({
                input$file1
                })
        expert_prefix <-
            reactive({
                input$expert_prefix_input
            })
        expert_conclusion <-
            reactive({
                input$expert_conclusion_input
            })
        annotation_checkbox <-
            reactive({
                input$annotation_checkbox
            })
        annotation_text <-
            reactive({
                input$annotation_text
            })
        restart_text <-
            reactive({
                input$restart_text_input
            })
        xml_parsed <-
            reactive({
                if (xmlfile_meta()$datapath %>% is.null()) {
                    return("No file selected")
                } else {
                parse_xml(
                    file = xmlfile_meta()$datapath,
                    expert_prefix = expert_prefix,
                    expert_conclusion = expert_conclusion,
                    annotation_checkbox = annotation_checkbox,
                    annotation_text = annotation_text,
                    restart_text = restart_text
                    )
                }
                })


        output$expert_prefix_preview <-
            renderText({
                glue("<em>{expert_prefix()}</em>Here goes the expert's quote…")
            })
        output$expert_conclusion_preview <-
            renderText({
                glue("<em>{expert_conclusion()}</em>Here goes the expert's conclusion…")
            })
        output$inkText <- renderText({
            xml_parsed()
            })
        output$download_ink <- downloadHandler(
            filename = function() {
                paste0(xmlfile_meta()$name %>% str_remove("\\.xml"), ".ink")
            },
            content = function(filename) {
                write_file(xml_parsed(), filename)
            }
        )
}

# Run the application
shinyApp(ui = ui, server = server)
