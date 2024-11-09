package main

import (
	"bytes"
	"context"
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
	Context     context.Context
	S3Region    string
	S3Bucket    string
	S3Client    *s3.Client
	Bot         *tgbotapi.BotAPI
	DBClientURL string
}

type GetMemeResult struct {
	CurrentMeme struct {
		ID  int    `json:"id"`
		URL string `json:"url"`
	} `json:"current_meme"`
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

// parseEnvVars places all environment variable data where it belongs
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

// handleMessage reads a message sent to the Bot.
// If the message is an image, it places it in S3.
// If the message is a /del request, it deletes the image
// from the database and S3
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

		if err := sendImageToS3(imageData); err != nil {
			replyToBot("ERROR: Unable to place image in S3")
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

// deleteMeme deletes the meme with the corresponding ID from S3 and its database entry
func deleteMeme(id int) error {
	// Retrieve S3 URL
	client := &http.Client{}
	url := fmt.Sprintf("%s/%d", cfg.DBClientURL, id)
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
		return fmt.Errorf("BAD STATUS: %d", resp.StatusCode)
	}

	var meme GetMemeResult
	if err := json.Unmarshal(respBytes, &meme); err != nil {
		return err
	}

	// Delete the meme from S3
	urlParts := strings.Split(meme.CurrentMeme.URL, cfg.S3Bucket+"/") // Split the string by 'bucket-name/'
	objData := s3.DeleteObjectInput{
		Bucket: aws.String(cfg.S3Bucket),
		Key:    aws.String(urlParts[1]), // Everything after 'bucket-name/'
	}

	if _, err := cfg.S3Client.DeleteObject(cfg.Context, &objData); err != nil {

		return err
	}

	// Delete the meme URL from the database
	url = fmt.Sprintf("%s/%d", cfg.DBClientURL, id)
	req, err = http.NewRequest("DELETE", url, nil)
	if err != nil {
		return err
	}

	if _, err := client.Do(req); err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("BAD STATUS: %d", resp.StatusCode)
	}

	return nil
}
