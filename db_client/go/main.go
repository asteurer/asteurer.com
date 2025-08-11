package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	"asteurer.com/db-client/pkg/handlers"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

func main() {
	pgURL, err := getPostgresURL()
	if err != nil {
		log.Fatal(err)
	}

	db, err := sql.Open("postgres", pgURL)
	if err != nil {
		log.Fatal("ERROR: Unable to connect to postgres\n" + err.Error())
	}

	ctx := context.Background()

	gin.SetMode(gin.ReleaseMode)

	r := gin.Default()
	r.GET("/all_memes", handlers.GetAllMemes(ctx, db))
	r.GET("/latest_meme", handlers.GetMeme(ctx, db))
	r.GET("/meme/:meme_id", handlers.GetMeme(ctx, db))
	r.PUT("/meme", handlers.PutMeme(ctx, db))
	r.DELETE("/meme/:meme_id", handlers.DeleteMeme(ctx, db))
	r.POST("/meme", handlers.UpdateMeme(ctx, db))
	r.Run(":8080")
}

// getPostgresURL parses environment variables and returns a connection string
func getPostgresURL() (string, error) {
	errMsg := func(varName string) string {
		return "ERROR: Could not detect the " + varName + " environment variable"
	}

	// Gather all missing environment variables and print them all in a single error message
	var envVarErr []string

	pgHost, ok := os.LookupEnv("POSTGRES_HOST")
	if !ok {
		envVarErr = append(envVarErr, errMsg("POSTGRES_HOST"))
	}

	pgPort, ok := os.LookupEnv("POSTGRES_PORT")
	if !ok {
		envVarErr = append(envVarErr, errMsg("POSTGRES_PORT"))
	}

	pgDB, ok := os.LookupEnv("POSTGRES_DATABASE")
	if !ok {
		envVarErr = append(envVarErr, errMsg("POSTGRES_DATABASE"))
	}

	pgUser, ok := os.LookupEnv("POSTGRES_USER")
	if !ok {
		envVarErr = append(envVarErr, errMsg("POSTGRES_USER"))
	}

	pgPasswd, ok := os.LookupEnv("POSTGRES_PASSWORD")
	if !ok {
		envVarErr = append(envVarErr, errMsg("POSTGRES_PASSWORD"))
	}

	if len(envVarErr) > 0 {
		return "", fmt.Errorf("\n" + strings.Join(envVarErr, "\n"))
	}

	return fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", pgUser, pgPasswd, pgHost, pgPort, pgDB), nil
}
