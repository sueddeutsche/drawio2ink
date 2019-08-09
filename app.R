pkgs <- c(
    "shiny",
    "xml2",
    "dplyr",
    "purrr",
    "stringr",
    "readr",
    "here"
)

for (p in pkgs) {
    require(p, character.only = TRUE)
}


################
###### UI ######
################

ui <- fluidPage(

    # Application title
    titlePanel("dRink – Parser from draw.io through R to ink"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            h3("1st: Input"),
            fileInput(
                "file1",
                "Choose an .xml file:",
                multiple = FALSE,
                accept = "text/xml",
                buttonLabel = "Browse…",
                placeholder = "No file chosen…"
            ),
            h3("3rd: Download"),
            downloadButton("download_ink", "Download .ink-file")
        ),

        # Show a plot of the generated distribution
        mainPanel(
            h3("2nd: Output preview"),
            verbatimTextOutput("inkText")
            )
        )
    )

################
#### Server ####
################

server <- function(input, output, session) {
    source(here("src", "parse_xml.R"))
    # auf action-button legen mit reactive
    # V8 und shinyjs, um den output zu stylen
    output$inkText <- renderText({
    # if (!is.null(input$goButton)) {
        xmlfile_meta <- input$file1
    #     return(xmlfile)
    # }
        xml_parsed <- parse_xml(file = xmlfile_meta$datapath)
        return(xml_parsed)
        })
    output$download_ink <- downloadHandler(
        filename = function() {
            xmlfile_meta <- input$file1
            paste0(xmlfile_meta$name %>% str_remove("\\.xml"), ".ink")
        },
        content = function(filename) {
            xmlfile_meta <- input$file1
            xml_parsed <- parse_xml(file = xmlfile_meta$datapath)
            # filename = function() {
            #     paste0(xmlfile_meta$name, ".ink")
            # }
            write_file(xml_parsed, filename)
        }
    )
}

# Run the application
shinyApp(ui = ui, server = server)
