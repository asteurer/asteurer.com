package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/h2non/bimg"
)

type Config struct {
	Context     context.Context
	S3Region    string
	S3Bucket    string
	S3Client    *s3.Client
	Bot         *tgbotapi.BotAPI
	DBClientURL string
}

var cfg Config

func main() {
	if err := parseEnvVars(); err != nil {
		log.Fatal(err)
	}

	// Set this to true to log all interactions with telegram servers
	cfg.Bot.Debug = false

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60

	// `updates` is a golang channel which receives telegram updates
	updates := cfg.Bot.GetUpdatesChan(u)

	go receiveUpdates(cfg.Context, updates)

	// Keep the process alive
	select {}
}

func parseEnvVars() error {
	errMsg := func(varName string) string {
		return "ERROR: Could not detect the " + varName + " environment variable"
	}

	// Gather all missing environment variables and print them all in a single error message
	var envVarErr []string

	awsAccessKey := os.Getenv("AWS_ACCESS_KEY")
	if len(awsAccessKey) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_ACCESS_KEY"))
	}

	awsSecretKey := os.Getenv("AWS_SECRET_KEY")
	if len(awsSecretKey) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_SECRET_KEY"))
	}

	// Not required
	awsSessionToken := os.Getenv("AWS_SESSION_TOKEN")

	s3Region := os.Getenv("AWS_S3_REGION")
	if len(s3Region) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_S3_REGION"))
	}

	s3Bucket := os.Getenv("AWS_S3_BUCKET")
	if len(s3Bucket) == 0 {
		envVarErr = append(envVarErr, errMsg("AWS_S3_BUCKET"))
	}

	apiToken := os.Getenv("TG_BOT_TOKEN")
	if len(apiToken) == 0 {
		envVarErr = append(envVarErr, errMsg("TG_BOT_TOKEN"))
	}

	dbClientURL := os.Getenv("DB_CLIENT_URL")
	if len(dbClientURL) == 0 {
		envVarErr = append(envVarErr, errMsg("DB_CLIENT_URL"))
	}

	if len(envVarErr) > 0 {
		return fmt.Errorf("\n" + strings.Join(envVarErr, "\n"))

	}

	ctx := context.Background()

	// Initialize Telegram bot
	bot, err := tgbotapi.NewBotAPI(apiToken)
	if err != nil {
		return err
	}

	// Initialize S3 client
	awsCfg, err := config.LoadDefaultConfig(
		ctx,
		config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(awsAccessKey, awsSecretKey, awsSessionToken),
		),
		config.WithRegion(s3Region),
	)
	if err != nil {
		log.Fatal(err)
	}

	cfg = Config{
		Context:     ctx,
		S3Region:    s3Region,
		S3Bucket:    s3Bucket,
		S3Client:    s3.NewFromConfig(awsCfg),
		Bot:         bot,
		DBClientURL: dbClientURL,
	}

	return nil
}

func receiveUpdates(ctx context.Context, updates tgbotapi.UpdatesChannel) {
	for {
		select {
		// Stop looping if ctx is cancelled
		case <-ctx.Done():
			return
		// Receive update from channel and then handle it
		case update := <-updates:
			handleUpdate(update)
		}
	}
}

func handleUpdate(update tgbotapi.Update) {
	switch {
	// Handle messages
	case update.Message != nil:
		handleMessage(update.Message)
	}
}

// handleMessage
func handleMessage(message *tgbotapi.Message) {
	user := message.From
	if user == nil {
		return
	}

	image := message.Photo
	if image != nil {
		imageData, err := retrieveImage(message)
		if err != nil {
			log.Fatal(err)
		}

		if err := sendImageToS3(imageData); err != nil {
			log.Fatal(err)
		}
	}
}

// retrieveImage retrieves image data from Telegram
func retrieveImage(message *tgbotapi.Message) ([]byte, error) {
	// Select the highest resolution photo
	photo := message.Photo[len(message.Photo)-1]
	fileID := photo.FileID

	// Get file info
	file, err := cfg.Bot.GetFile(tgbotapi.FileConfig{FileID: fileID})
	if err != nil {
		log.Printf("Failed to get file: %v", err)
		return nil, err
	}

	fileURL := file.Link(cfg.Bot.Token)

	resp, err := http.Get(fileURL)
	if err != nil {
		return nil, err
	}

	fileBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ERROR: Bad status\n%s\n%s", resp.Status, string(fileBytes))
	}

	return fileBytes, nil
}

// sendImageToS3 compresses the image, places it in an S3 bucket, and returns the S3 URL to the image
func sendImageToS3(imageBytes []byte) error {
	key := "memes/" + fmt.Sprintf("%d", time.Now().UnixNano()) + ".webp"
	url := "https://s3." + cfg.S3Region + ".amazonaws.com/" + cfg.S3Bucket + "/" + key

	// Compressing image
	imageSpecs := bimg.Options{
		Quality: 50,  // Range of 1 (lowest) and 100 (highest)
		Width:   600, // Pixels
		Type:    bimg.WEBP,
	}

	convertedImg, err := bimg.NewImage(imageBytes).Convert(bimg.WEBP)
	if err != nil {
		return err
	}

	processedImg, err := bimg.NewImage(convertedImg).Process(imageSpecs)
	if err != nil {
		return err
	}

	objData := s3.PutObjectInput{
		Bucket:      aws.String(cfg.S3Bucket),
		Key:         aws.String(key),
		Body:        bytes.NewBuffer(processedImg),
		ContentType: aws.String("image/webp"),
	}

	if _, err = cfg.S3Client.PutObject(cfg.Context, &objData); err != nil {
		return err
	}

	// Sending the URL to the database
	client := &http.Client{}
	req, err := http.NewRequest("PUT", cfg.DBClientURL, bytes.NewBuffer([]byte(url)))
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("BAD STATUS: %d", resp.StatusCode)
	}

	return nil
}

/*
* Some notes about deleteMeme:
* Consider adding a feature that will list all keys in S3, drop the table in postgres, create a new table, then re-fill the table with the keys from S3.
* The idea here is that we would do a re-indexing if I wanted to delete a meme.
 */

// func deleteMeme(id int) error {
// 	urlParts := strings.Split(memeURL, "/")
// 	s3ObjectName := urlParts[len(urlParts)-1]
// 	// Delete the meme from S3
// 	deleteParams := &s3.DeleteObjectInput{Bucket: aws.String(cfg.S3Bucket), Key: aws.String("memes/" + s3ObjectName)}
// 	if _, err := s3Client.DeleteObject(cfg.Context, deleteParams); err != nil {
// 		writeErr(c, http.StatusInternalServerError, err.Error())
// 		return
// 	}
// }
