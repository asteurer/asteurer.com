package handlers

import (
	"context"
	"database/sql"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type Meme struct {
	ID  int    `json:"id"`
	URL string `json:"url"`
}

type Handler struct {
	Config   *HandlerConfig
	DB       *sql.DB
	S3Client *s3.Client
}

type GetMemeResult struct {
	CurrentMeme    Meme `json:"currentMeme"`
	PreviousMemeID int  `json:"previousMemeID"`
	NextMemeID     int  `json:"nextMemeID"`
}

type HandlerConfig struct {
	Context context.Context
	// The region in which the S3 bucket is located
	S3Region string

	// The name of the S3 bucket
	S3Bucket string
}
