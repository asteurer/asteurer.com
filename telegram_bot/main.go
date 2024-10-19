package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

var bot *tgbotapi.BotAPI

func main() {
	apiToken := os.Getenv("TG_BOT_TOKEN")
	if len(apiToken) == 0 {
		log.Panic("ERROR: Could not detect the TG_BOT_TOKEN environment variable")
	}

	var err error
	bot, err = tgbotapi.NewBotAPI(apiToken)
	if err != nil {
		// Abort if something is wrong
		log.Panic(err)
	}

	// Set this to true to log all interactions with telegram servers
	bot.Debug = false

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60

	// Create a new cancellable background context. Calling `cancel()` leads to the cancellation of the context
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)

	// `updates` is a golang channel which receives telegram updates
	updates := bot.GetUpdatesChan(u)

	// Pass cancellable context to goroutine
	go receiveUpdates(ctx, updates)

	// Tell the user the bot is online
	log.Println("Start listening for updates. Press enter to stop")

	// Wait for a newline symbol, then cancel handling updates
	bufio.NewReader(os.Stdin).ReadBytes('\n')
	cancel()

}

func receiveUpdates(ctx context.Context, updates tgbotapi.UpdatesChannel) {
	for {
		select {
		// stop looping if ctx is cancelled
		case <-ctx.Done():
			return
		// receive update from channel and then handle it
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

func handleMessage(message *tgbotapi.Message) {
	user := message.From
	if user == nil {
		return
	}

	image := message.Photo
	if image == nil {
		return
	} else {
		imageData, err := handlePhoto(message)
		if err != nil {
			log.Panic(err)
		}

		if err := os.WriteFile("/home/andyboi/Repositories/Personal/asteurer.com/test.jpg", imageData, 0777); err != nil {
			log.Panic(err)
		}
	}
}

func handlePhoto(message *tgbotapi.Message) ([]byte, error) {
	// Select the highest resolution photo
	photo := message.Photo[len(message.Photo)-1]
	fileID := photo.FileID

	// Get file info
	file, err := bot.GetFile(tgbotapi.FileConfig{FileID: fileID})
	if err != nil {
		log.Printf("Failed to get file: %v", err)
		return nil, err
	}

	fileURL := file.Link(bot.Token)

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
		return nil, fmt.Errorf("ERROR: Bad status\n%s", resp.Status)
	}

	return fileBytes, nil
}
