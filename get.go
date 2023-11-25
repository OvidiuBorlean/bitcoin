package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "errors"
    "os"
    "time"
    "strconv"
    "strings"
)

/* Function updateTemplate will get the Bitcoin value through an HTTP Get request and will parse the JSON Output. It will create a html file that would be served by
net/http module to received requests. This function is called in a go routine and it will run in parallel with the main function, hence the BTC values (Realtime and Average) will be updated continously.
*/
func updateTemplate() {

   var array []float64 // Initialize a slice for holding the float64 values of Bitcoin
   var sum float64 // Initialize the "sum" variable to be used in function for calculating average
   sum = 0 // Assign a value of 0
   var avg  float64
   n := 3 // The value for calulating average value. It represent the lenght of the slice that will hold the values
   // Starting a loop
   for {
    file, errs := os.Create("index.html") // Create the "index.html" file
    if errs != nil {
        fmt.Println("Failed to create file:", errs) // Error handling for last operation
        //return
     }
     defer file.Close()  // Release resources used by previous operation

     t := time.Now().UTC() // Get the current time in UTC format
     s1 := t.String() // Transform previous time value into String to be used in outputs
     bitCoinValue := getBTC()  // We are calling the function of getBTC that will return the Bitcoin value. Assigning the value to bitCoinValue variable
     array = append(array, bitCoinValue) // To use for average calculation, will append the value to slice

     // If the lenghts of the slice is equal with the number we want to use for calculating the average (default 360 - 10 minutes) , calculate the Average value
     if len(array) == 3 {
        for i := 0; i < n; i++ {
        // adding the values of array to the variable sum
       sum += (array[i])
      }
       avg = (float64(sum)) / (float64(n))
       fmt.Println("Average value is : ",avg) // Printing the Average value on server side
   }

    strBtcValue := strconv.FormatFloat(bitCoinValue, 'g', 15, 64) // In order to use it in HTML string operation, we need to convert to String
    strAvg := strconv.FormatFloat(avg, 'g', 15, 64) // Also converting the Average value from Float to String

    // Create a template variable that will hold the HTML code of our page. Also added the HTML metadata to refresh the file at 10seconds
    var template = `<html>
    <meta http-equiv="refresh" content="10">
    <head>
        <title>Bitcoin Monitor </title>
    </head>
    <body>
         `
   // As we need to use a single argument to write the String value to  a file, we need to Join all our text and variable values in a single variable.
   all := []string{template,"Local Time: ",s1, "\n", "Bitcoin Realtime Value", strBtcValue, " ", "Average value: ", strAvg, "</body>", "</html>"}
   _, errs = file.WriteString(strings.Join(all,"	"))
   if errs != nil {
      fmt.Println("Failed to write to file:", errs) //print the failed message
      //return
   }
  time.Sleep(10 * time.Second) // Loop delay
  }
}

// Main HTTP Handler. When a request is received by the main function handler it will be served by this function. It will serve the content of the index.html file
func getRoot(w http.ResponseWriter, r *http.Request) {
     fmt.Printf("Request received. \n")
     http.ServeFile(w, r, "index.html")      

}

// Health Endpoint - A request towards this endpoint will return a HTTP 200 Code.
func getHealth(w http.ResponseWriter, r *http.Request) {
     io.WriteString(w, "Ok")
}

// Function used to format data. Accept the input as a slice of bytes and return a string in Json format
func formatJSON(data []byte) string {
    var out bytes.Buffer
    err := json.Indent(&out, data, "", " ")

    if err != nil {
        fmt.Println(err)
    }

    d := out.Bytes()
    return string(d)
}

func getBTC()float64 {

    // Initialize a Go map
    var items map[string]interface{}

    apiUrl := "https://bitpay.com/api/rates/USD" // URL used to Get the values of Bitcoin
    request, error := http.NewRequest("GET", apiUrl, nil)


    if error != nil {
        fmt.Println(error)
    }

    request.Header.Set("Content-Type", "application/json; charset=utf-8") // Setting the Header format to accept JSON

    client := &http.Client{}
    response, error := client.Do(request)

    if error != nil {
        fmt.Println(error)
    }
    defer response.Body.Close()
    responseBody, error := io.ReadAll(response.Body) // Getting the response Body

    if error != nil {
        fmt.Println(error)
    }

    formattedData := formatJSON(responseBody) // Formatting the response

    err := json.Unmarshal([]byte(formattedData), &items) // Unmarshalling the formated response

    if err != nil {
        fmt.Println("Error while decoding the data", err.Error())
    }
     fmt.Println("Bitcoin value is:", items["rate"]) // Writing server side the Bitcoin Realtime value
return items["rate"].(float64) // Function returns the value
}

// Main function that will set the Handlers 
func main() {
  go updateTemplate() // Running the updateTemplate function in a go routing
  fmt.Println("Running Server...")
  http.HandleFunc("/", getRoot)
  http.HandleFunc("/health", getHealth)
  err :=  http.ListenAndServe(":3333", nil)
  if errors.Is(err, http.ErrServerClosed) {
             fmt.Printf("Server closed\n")
     } else if err != nil {
             fmt.Printf("Error starting server: %s\n", err)
             os.Exit(1)
     }
}
