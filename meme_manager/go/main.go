package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
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
	Context          context.Context
	S3Endpoint       string
	S3Bucket         string
	S3Client         *s3.Client
	Bot              *tgbotapi.BotAPI
	DBClientEndpoint string
}

type GetMemeResult struct {
	CurrentMeme struct {
		ID       int    `json:"id"`
		FileName string `json:"file_name"`
	} `json:"current_meme"`
}

const S3_PREFIX = "memes/"

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

// parseEnvVars places all environment variable data where it belongs
func parseEnvVars() error {
	errMsg := func(varName string) string {
		return "ERROR: Could not detect the " + varName + " environment variable"
	}

	// Gather all missing environment variables and print them all in a single error message
	var envVarErr []string

	accessKey, ok := os.LookupEnv("ACCESS_KEY")
	if !ok {
		envVarErr = append(envVarErr, errMsg("ACCESS_KEY"))
	}

	secretKey, ok := os.LookupEnv("SECRET_KEY")
	if !ok {
		envVarErr = append(envVarErr, errMsg("SECRET_KEY"))
	}

	sessionToken, ok := os.LookupEnv("SESSION_TOKEN") // Not required

	s3Region, ok := os.LookupEnv("S3_REGION") // Not required; allows for a default region
	if !ok {
		s3Region = "us-east-1"
	}

	s3Bucket, ok := os.LookupEnv("S3_BUCKET")
	if !ok {
		envVarErr = append(envVarErr, errMsg("S3_BUCKET"))
	}

	// Must include both protocol and port (e.g. https://localhost:9000)
	s3Endpoint, ok := os.LookupEnv("S3_ENDPOINT")
	if !ok {
		envVarErr = append(envVarErr, errMsg("S3_ENDPOINT"))
	}

	apiToken, ok := os.LookupEnv("TG_BOT_TOKEN")
	if !ok {
		envVarErr = append(envVarErr, errMsg("TG_BOT_TOKEN"))
	}

	dbClientEndpoint, ok := os.LookupEnv("DB_CLIENT_ENDPOINT")
	if !ok {
		envVarErr = append(envVarErr, errMsg("DB_CLIENT_ENDPOINT"))
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
			credentials.NewStaticCredentialsProvider(accessKey, secretKey, sessionToken),
		),
		config.WithRegion(s3Region),
	)
	if err != nil {
		log.Fatal(err)
	}

	cfg = Config{
		Context:    ctx,
		S3Endpoint: s3Endpoint,
		S3Bucket:   s3Bucket,
		S3Client: s3.NewFromConfig(awsCfg, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(s3Endpoint)
			o.UsePathStyle = true // Accommodate for Minio's path-style endpoints (e.g. http://localhost:9000/bucket/object)
			o.HTTPClient = &http.Client{
				Transport: &http.Transport{
					TLSClientConfig: &tls.Config{
						InsecureSkipVerify: true, // Same as using the --insecure flag on the minio client cli
					},
				},
			}
		}),
		Bot:              bot,
		DBClientEndpoint: dbClientEndpoint + "/meme",
	}

	return nil
}

// receiveUpdates checks for new messages sent to the Bot
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

// handleMessage reads a message sent to the Bot. If the message is an image, it places it in S3.
// If the message is a /del request, it deletes the image from the database and S3
func handleMessage(message *tgbotapi.Message) {
	replyToBot := func(text string) {
		msg := tgbotapi.NewMessage(message.Chat.ID, text)
		_, err := cfg.Bot.Send(msg)
		if err != nil {
			log.Println("Failed to send message:", err)
		}
	}

	user := message.From
	if user == nil {
		return
	}

	// Handle sent photo
	image := message.Photo
	if image != nil {
		imageData, err := retrieveImage(message)
		if err != nil {
			replyToBot("ERROR: Unable to retrieve image from telegram")
			log.Println(err)
		}

		if err := processImage(imageData); err != nil {
			replyToBot("ERROR: Failed to process image")
			log.Println(err)
		}

		replyToBot("Image was successfully delivered")
	}

	// Handle delete command
	cmd := message.Command()
	var deleteCmdArgs string
	if cmd == "del" || cmd == "delete" {
		deleteCmdArgs = message.CommandArguments()
	}

	if deleteCmdArgs != "" {
		argArray := strings.Split(deleteCmdArgs, " ")
		for _, idStr := range argArray {
			id, err := strconv.Atoi(idStr)
			if err != nil {
				replyToBot(fmt.Sprintf("ERROR: %q is not an integer", idStr))
				continue
			}

			if err := deleteMeme(id); err != nil {
				replyToBot(fmt.Sprintf("ERROR: %v", err))
				continue
			}

			replyToBot("ID " + idStr + " was successfully deleted")
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

// processImage compresses the image, places it in an S3 bucket, and places the corresponding filename in Postgres
func processImage(imageBytes []byte) error {
	fileName := fmt.Sprintf("%d", time.Now().UnixNano()) + ".webp"

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
		Key:         aws.String(S3_PREFIX + fileName),
		Body:        bytes.NewReader(processedImg),
		ContentType: aws.String("image/webp"),
	}

	if _, err = cfg.S3Client.PutObject(cfg.Context, &objData); err != nil {
		return err
	}

	// Sending the URL to the database
	client := &http.Client{}
	req, err := http.NewRequest("PUT", cfg.DBClientEndpoint, bytes.NewBuffer([]byte(fileName)))
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		respBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return fmt.Errorf("Unable to read response bytes.\n%v", err)
		}

		resp.Body.Close()

		return fmt.Errorf("BAD STATUS (%d): %s", resp.StatusCode, string(respBytes))
	}

	return nil
}

// deleteMeme deletes the meme with the corresponding ID from S3 and its database entry
func deleteMeme(id int) error {
	// Retrieve S3 URL
	client := &http.Client{}
	url := fmt.Sprintf("%s/%d", cfg.DBClientEndpoint, id)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("Unable to read response bytes.\n%v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("BAD STATUS (%d): %s", resp.StatusCode, string(respBytes))
	}

	var meme GetMemeResult
	if err := json.Unmarshal(respBytes, &meme); err != nil {
		return err
	}

	// Delete the meme from S3
	objData := s3.DeleteObjectInput{
		Bucket: aws.String(cfg.S3Bucket),
		Key:    aws.String(S3_PREFIX + meme.CurrentMeme.FileName),
	}

	if _, err := cfg.S3Client.DeleteObject(cfg.Context, &objData); err != nil {

		return err
	}

	// Delete the meme URL from the database
	url = fmt.Sprintf("%s/%d", cfg.DBClientEndpoint, id)
	req, err = http.NewRequest("DELETE", url, nil)
	if err != nil {
		return err
	}

	resp, err = client.Do(req)
	if err != nil {
		return err
	}

	respBytes, err = io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("Unable to read response bytes.\n%v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("BAD STATUS (%d): %s", resp.StatusCode, string(respBytes))
	}

	return nil
}
