package handlers

import (
	"bytes"
	"database/sql"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
	"github.com/h2non/bimg"
)

func writeErr(c *gin.Context, statusCode int, msg string) {
	if len(msg) == 0 {
		c.Status(statusCode)
	} else {
		c.JSON(statusCode, gin.H{"error": msg})
	}
}

// getMeme returns the current, previous, and next meme URLs. If no meme_id is provided in the request URL,
// the first meme is used as the current meme, the last is used as the prev meme, and the second is used as the next meme.
func GetMeme(cfg *HandlerConfig, db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		tx, err := db.Begin()
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer tx.Rollback()

		// If the URL doesn't contain a meme_id, set the meme_id to 0; otherwise parse the meme_id
		var currentMeme Meme
		idStr, ok := c.Params.Get("meme_id")
		if !ok {
			currentMeme.ID = 0
		} else {
			currentMeme.ID, err = strconv.Atoi(idStr)
			if err != nil {
				writeErr(c, http.StatusBadRequest, "The 'meme_id' parameter must be an integer")
				return
			}
		}

		if currentMeme.ID > 0 {
			row := tx.QueryRowContext(cfg.Context, "SELECT url FROM memes WHERE ID = $1", currentMeme.ID)
			if err := row.Scan(&currentMeme.URL); err != nil {
				if err == sql.ErrNoRows {
					writeErr(c, http.StatusNotFound, fmt.Sprintf("Meme with ID %d does not exist", currentMeme.ID))
				} else {
					writeErr(c, http.StatusInternalServerError, err.Error())
				}
				return
			}
		} else { // If there isn't a current meme, find the most-recent meme (largest ID number), return the URL, and set as the currentMemeID
			row := tx.QueryRowContext(cfg.Context, "SELECT id, url FROM memes ORDER BY id DESC LIMIT 1")
			if err := row.Scan(&currentMeme.ID, &currentMeme.URL); err != nil {
				if err == sql.ErrNoRows {
					writeErr(c, http.StatusNoContent, "There are no memes in the database")
				} else {
					writeErr(c, http.StatusInternalServerError, err.Error())
				}
				return
			}
		}

		var prevMemeID int
		// The previous meme URL will traverse the table rows in ascending order (oldest to newest, or smallest ID to largest ID)
		prevQueryString :=
			`SELECT id FROM memes WHERE id = COALESCE(
    		(SELECT id FROM memes WHERE id > $1 ORDER BY id ASC LIMIT 1),
    		(SELECT id FROM memes ORDER BY id ASC LIMIT 1)
		)`

		row := tx.QueryRowContext(cfg.Context, prevQueryString, currentMeme.ID)
		if err := row.Scan(&prevMemeID); err != nil {
			if err == sql.ErrNoRows {
				writeErr(c, http.StatusNoContent, "There are no memes in the database")
			} else {
				writeErr(c, http.StatusInternalServerError, err.Error())
			}
			return
		}

		var nextMemeID int
		// The next meme URL will traverse the table rows in descending order (newest to oldest, or largest ID to smallest ID)
		nextQueryString :=
			`SELECT id FROM memes WHERE id = COALESCE(
			(SELECT id FROM memes WHERE id < $1 ORDER BY id DESC LIMIT 1),
			(SELECT id FROM memes ORDER BY id DESC LIMIT 1)
		)`

		row = tx.QueryRowContext(cfg.Context, nextQueryString, currentMeme.ID)
		if err := row.Scan(&nextMemeID); err != nil {
			if err == sql.ErrNoRows {
				writeErr(c, http.StatusNoContent, "There are no memes in the database")
			} else {
				writeErr(c, http.StatusInternalServerError, err.Error())
			}
			return
		}

		if err := tx.Commit(); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		c.JSON(http.StatusOK, GetMemeResult{PreviousMemeID: prevMemeID, CurrentMeme: currentMeme, NextMemeID: nextMemeID})
	}
}

// putMeme places an image in an S3 bucket and inserts the corresponding S3 URL into the database
func PutMeme(cfg *HandlerConfig, db *sql.DB, s3Client *s3.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		contentType := c.Request.Header.Get("content-type")
		if len(contentType) == 0 {
			writeErr(c, http.StatusBadRequest, "ERROR: You must include the 'content-type' header with your request")
			return
		} else if !strings.Contains(contentType, "image/") {
			writeErr(c, http.StatusBadRequest, "ERROR: The 'content-type' provided must be an image")
			return
		}

		imgBytes, err := io.ReadAll(c.Request.Body)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer c.Request.Body.Close()

		// A file extension is not included in the key because the ContentType is set in the objData variable,
		// and it's assumed that the file extension is not necessary to render the image in the browser.
		key := "memes/" + fmt.Sprintf("%d", time.Now().UnixNano()) + ".webp"

		url := "https://s3." + cfg.S3Region + ".amazonaws.com/" + cfg.S3Bucket + "/" + key

		// Commence image compression
		imageSpecs := bimg.Options{
			Quality: 70,  // Range of 1 (lowest) and 100 (highest)
			Width:   800, // Pixels
			Type:    bimg.WEBP,
		}

		convertedImg, err := bimg.NewImage(imgBytes).Convert(bimg.WEBP)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		processedImg, err := bimg.NewImage(convertedImg).Process(imageSpecs)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		objData := s3.PutObjectInput{
			Bucket:      aws.String(cfg.S3Bucket),
			Key:         aws.String(key),
			Body:        bytes.NewBuffer(processedImg),
			ContentType: aws.String("image/webp"),
		}

		if _, err = s3Client.PutObject(cfg.Context, &objData); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		tx, err := db.Begin()
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer tx.Rollback()

		if _, err := tx.ExecContext(cfg.Context, "INSERT INTO memes (url) VALUES($1)", url); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		if err := tx.Commit(); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		c.Status(http.StatusOK)
	}
}

func DeleteMeme(cfg *HandlerConfig, db *sql.DB, s3Client *s3.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		idStr, ok := c.Params.Get("meme_id")
		if !ok {
			writeErr(c, http.StatusBadRequest, "ERROR: You must include a 'meme_id' parameter in the request URL")
			return
		}

		memeID, err := strconv.Atoi(idStr)
		if err != nil {
			writeErr(c, http.StatusBadRequest, "ERROR: The 'meme_id' parameter must be an integer")
			return
		}

		tx, err := db.Begin()
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer tx.Rollback()

		var memeURL string
		row := tx.QueryRowContext(cfg.Context, "SELECT url FROM memes WHERE id = $1", memeID)
		if err := row.Scan(&memeURL); err != nil {
			if err == sql.ErrNoRows {
				writeErr(c, http.StatusNotFound, fmt.Sprintf("ERROR: Meme with ID %d does not exist", memeID))
				return
			} else {
				writeErr(c, http.StatusInternalServerError, err.Error())
				return
			}
		}

		urlParts := strings.Split(memeURL, "/")
		s3ObjectName := urlParts[len(urlParts)-1]

		// Delete the meme database entry
		if _, err := tx.ExecContext(cfg.Context, "DELETE FROM memes WHERE id = $1", memeID); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		// Delete the meme from S3
		deleteParams := &s3.DeleteObjectInput{Bucket: aws.String(cfg.S3Bucket), Key: aws.String("memes/" + s3ObjectName)}
		if _, err := s3Client.DeleteObject(cfg.Context, deleteParams); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		if err := tx.Commit(); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
	}
}
