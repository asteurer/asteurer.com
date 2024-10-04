package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	"asteurer.com/api/pkg/handlers"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

type Creds struct {
	PostgresURL     string
	AWSAccessKey    string
	AWSSecretKey    string
	AWSSessionToken string

	// This is used for gin.BasicAuth
	Auth gin.Accounts
}

func main() {
	cfg, creds, err := parseEnvVars()
	if err != nil {
		log.Fatal(err)
	}

	db, err := sql.Open("postgres", creds.PostgresURL)
	if err != nil {
		log.Fatal("ERROR: Unable to connect to postgres\n" + err.Error())
	}

	// Initialize S3 client
	awsCfg, err := config.LoadDefaultConfig(
		cfg.Context,
		config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(creds.AWSAccessKey, creds.AWSSecretKey, creds.AWSSessionToken),
		),
		config.WithRegion(cfg.S3Region),
	)
	if err != nil {
		log.Fatal(err)
	}
	s3Client := s3.NewFromConfig(awsCfg)

	r := gin.Default()
	r.GET("/", handlers.GetMeme(cfg, db))
	r.GET("/:meme_id", handlers.GetMeme(cfg, db))
	r.PUT("/", gin.BasicAuth(creds.Auth), handlers.PutMeme(cfg, db, s3Client))
	r.DELETE("/:meme_id", gin.BasicAuth(creds.Auth), handlers.DeleteMeme(cfg, db, s3Client))
	r.Run(":8080")
}

func parseEnvVars() (*handlers.HandlerConfig, *Creds, error) {
	errMsg := func(varName string) string {
		return "ERROR: Could not detect the " + varName + " environment variable"
	}

	// Gather all missing environment variables and print them all in a single error message
	var envVarErr []string

	pgHost := os.Getenv("POSTGRES_HOST")
	if len(pgHost) == 0 {
		envVarErr = append(envVarErr, errMsg("POSTGRES_HOST"))
	}

	pgPort := os.Getenv("POSTGRES_PORT")
	if len(pgHost) == 0 {
		envVarErr = append(envVarErr, errMsg("POSTGRES_HOST"))
	}

	pgDB := os.Getenv("POSTGRES_DATABASE")
	if len(pgHost) == 0 {
		envVarErr = append(envVarErr, errMsg("POSTGRES_HOST"))
	}

	pgUser := os.Getenv("POSTGRES_USER")
	if len(pgUser) == 0 {
		envVarErr = append(envVarErr, errMsg("POSTGRES_USER"))
	}

	pgPasswd := os.Getenv("POSTGRES_PASSWORD")
	if len(pgPasswd) == 0 {
		envVarErr = append(envVarErr, errMsg("POSTGRES_PASSWORD"))
	}

	awsAccessKey := os.Getenv("AWS_ACCESS_KEY")
	if len(awsAccessKey) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_ACCESS_KEY"))
	}

	awsSecretKey := os.Getenv("AWS_SECRET_KEY")
	if len(awsSecretKey) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_SECRET_KEY"))
	}

	s3Region := os.Getenv("AWS_S3_REGION")
	if len(s3Region) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_S3_REGION"))
	}

	s3Bucket := os.Getenv("AWS_S3_BUCKET")
	if len(s3Bucket) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_S3_BUCKET"))
	}

	authUser := os.Getenv("AUTH_USER")
	if len(authUser) == 0 {
		envVarErr = append(envVarErr, errMsg("AUTH_USER"))
	}

	authPswd := os.Getenv("AUTH_PASSWORD")
	if len(authPswd) == 0 {
		envVarErr = append(envVarErr, errMsg("AUTH_PASSWORD"))
	}

	if len(envVarErr) > 0 {
		return nil, nil, fmt.Errorf("\n" + strings.Join(envVarErr, "\n"))

	} else {
		cfg := &handlers.HandlerConfig{
			Context:  context.TODO(),
			S3Region: s3Region,
			S3Bucket: s3Bucket,
		}

		pgURL := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", pgUser, pgPasswd, pgHost, pgPort, pgDB)

		creds := &Creds{
			PostgresURL:  pgURL,
			AWSAccessKey: awsAccessKey,
			AWSSecretKey: awsSecretKey,
			// This is optional, so no checks are done
			AWSSessionToken: os.Getenv("AWS_SESSION_TOKEN"),
			Auth:            gin.Accounts{authUser: authPswd},
		}

		return cfg, creds, nil
	}
}
