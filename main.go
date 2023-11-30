package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func helloHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello! From Nitro 🚀")
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // Default port if PORT environment variable is not set
	}

	http.HandleFunc("/hello", helloHandler)

	fmt.Printf("Server is running on port %s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

