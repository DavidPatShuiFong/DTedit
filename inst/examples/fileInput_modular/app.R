# DTedit file input example, using blobs
library(shiny)
library(DTedit)
library(blob)

myModuleUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    dteditmodUI(ns('Grocery_List'))
  )
}

myModule <- function(input, output, session) {

  myModule_picture <- reactiveVal()
  myModule_spreadsheet <- reactiveVal()

  my.actionButton.callback <- function(data, row, buttonID) {
    if (substr(buttonID, 1, nchar("picture")) == "picture") {
      # the 'action' button identifier (ID) prefix shows this
      # this is from the 'Picture' column
      if (length(unlist(data[row, "Picture"])) > 0) {
        # not a empty entry!
        outfile <- tempfile(fileext = ".jpg")
        # create temporary filename
        # and write the binary blob to the temporary file
        zz <- file(outfile, "wb") # create temporary file
        writeBin(object = unlist(data[row, "Picture"]), con = zz)
        close(zz)

        # read the picture from the temporary file
        myModule_picture(base64enc::dataURI(file = outfile))

        # cleanup (remove the temporary file)
        file.remove(outfile)
      } else {
        myModule_picture(NULL)
      }
    }
    if (substr(buttonID, 1, nchar("spreadsheet")) == "spreadsheet") {
      if (length(unlist(data[row, "Spreadsheet"])) > 0) {
        outfile <- tempfile(fileext = ".csv")
        # create temporary filename
        zz <- file(outfile, "wb") # create temporary file
        writeBin(object = unlist(data[row, "Spreadsheet"]), con = zz)
        close(zz)

        myModule_spreadsheet(read.csv(outfile))

        # cleanup
        file.remove(outfile)
      } else {
        myModule_spreadsheet(NULL)
      }
    }
    return(NULL)
  }

  Grocery_List_Results <- callModule(
    dteditmod,
    'Grocery_List',
    thedata = data.frame(
      Buy = c('Tea', 'Biscuits', 'Apples'),
      Quantity = c(7, 2, 5),
      Picture = c(as.blob(raw(0)), as.blob(raw(0)), as.blob(raw(0))),
      Spreadsheet = c(as.blob(raw(0)), as.blob(raw(0)), as.blob(raw(0))),
      stringsAsFactors = FALSE
    ),
    view.cols = c("Buy", "Quantity"),
    # note that the 'Picture' and 'Spreadsheet' columns are hidden
    edit.cols = c("Buy", "Quantity", "Picture", "Spreadsheet"),
    edit.label.cols = c(
      "Item to buy", "Quantity",
      "Picture (.jpg)", "Spreadsheet (.csv)"
    ),
    input.choices = list(Picture = ".jpg", Spreadsheet = ".csv"),
    # unfortunately, RStudio's 'browser' doesn't actually respect
    #  file-name/type restrictions. A 'real' browser does respect
    #  the restrictions.
    action.button = list(
      MyActionButton = list(
        columnLabel = "Picture",
        # the column label happens to be the same as a
        # data column label, but it doesn't need to be
        buttonLabel = "Show Picture",
        buttonPrefix = "picture",
        # buttonPrefix will be in the buttonID passed
        # to callback.actionButton
        afterColumn = "Quantity"),
      MyOtherActionButton = list(
        columnLabel = "Spreadsheet",
        buttonLabel = "Show Spreadsheet",
        buttonPrefix = "spreadsheet"
      )
    ),
    callback.actionButton = my.actionButton.callback
  )

  return(
    list(
      thedata = reactive({Grocery_List_Results$thedata}),
      picture = reactive({myModule_picture()}),
      spreadsheet = reactive({myModule_spreadsheet()})
    )
  )
}

server <- function(input, output) {

  output$listPicture <- shiny::renderUI({
    shiny::tags$img(
      src = module_results$picture(),
      width = "100%"
    )
  })

  output$showSpreadsheet <- DT::renderDataTable({
    module_results$spreadsheet()
  })

  module_results <- shiny::callModule(myModule, 'myModule1')

  #### following code for shinytest, not essential for application function ####
  data_list <- list() # exported list for shinytest
  shiny::observeEvent(module_results$thedata(), {
    data_list[[length(data_list) + 1]] <<- module_results$thedata()
  })
  shiny::exportTestValues(data_list = {data_list})
  spreadsheet_list <- list() # exported list for shinytest
  shiny::observeEvent(module_results$spreadsheet(), {
    spreadsheet_list[[length(spreadsheet_list) + 1]] <<- module_results$spreadsheet()
  })
  shiny::exportTestValues(spreadsheet_list = {spreadsheet_list})
  ##############################################################################
}

ui <- fluidPage(
  h3("Grocery List"),
  "Pictures must be in JPEG (.jpg) format. Spreadsheets must be",
  "in comma-separated-value (.csv) format!",
  br(), br(), br(),
  myModuleUI('myModule1'),
  uiOutput("listPicture"),
  DT::dataTableOutput("showSpreadsheet")
)

if (interactive() || isTRUE(getOption("shiny.testmode")))
  return(shinyApp(ui = ui, server = server))
