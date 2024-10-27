package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type Meme struct {
	ID  int    `json:"id"`
	URL string `json:"url"`
}

type GetMemeResult struct {
	CurrentMeme    Meme `json:"current_meme"`
	PreviousMemeID int  `json:"previous_meme_id"`
	NextMemeID     int  `json:"next_meme_id"`
}

func writeErr(c *gin.Context, statusCode int, msg string) {
	if len(msg) == 0 {
		c.Status(statusCode)
	} else {
		c.JSON(statusCode, gin.H{"error": msg})
	}
}

// GetMeme returns the current, previous, and next meme URLs. If no meme_id is provided in the request URL,
// the first meme is used as the current meme, the last is used as the prev meme, and the second is used as the next meme.
func GetMeme(ctx context.Context, db *sql.DB) gin.HandlerFunc {
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
			row := tx.QueryRowContext(ctx, "SELECT url FROM memes WHERE ID = $1", currentMeme.ID)
			if err := row.Scan(&currentMeme.URL); err != nil {
				if err == sql.ErrNoRows {
					writeErr(c, http.StatusNotFound, fmt.Sprintf("Meme with ID %d does not exist", currentMeme.ID))
				} else {
					writeErr(c, http.StatusInternalServerError, err.Error())
				}
				return
			}
		} else { // If there isn't a current meme, find the most-recent meme (largest ID number), return the URL, and set as the currentMemeID
			row := tx.QueryRowContext(ctx, "SELECT id, url FROM memes ORDER BY id DESC LIMIT 1")
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

		row := tx.QueryRowContext(ctx, prevQueryString, currentMeme.ID)
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

		row = tx.QueryRowContext(ctx, nextQueryString, currentMeme.ID)
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

// GetAllMemes lists all memes in the database
func GetAllMemes(ctx context.Context, db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.QueryContext(ctx, "SELECT * FROM memes")
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		var memes []Meme
		for rows.Next() {
			var meme Meme
			if err := rows.Scan(&meme.ID, &meme.URL); err != nil {
				writeErr(c, http.StatusInternalServerError, err.Error())
				return
			}

			memes = append(memes, meme)
		}

		if len(memes) == 0 {
			writeErr(c, http.StatusNoContent, "There are no memes in the database")
		}

		c.JSON(http.StatusOK, memes)
	}
}

// PutMeme inserts a URL into the database and returns the ID of the new entry
func PutMeme(ctx context.Context, db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		url, err := io.ReadAll(c.Request.Body)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer c.Request.Body.Close()

		var id int
		if err := db.QueryRowContext(ctx, "INSERT INTO memes (url) VALUES($1) RETURNING id", string(url)).Scan(&id); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		response := struct {
			ID int `json:"id"`
		}{ID: id}

		c.JSON(http.StatusOK, response)
	}
}

// DeleteMeme deletes a specified meme from the database
func DeleteMeme(ctx context.Context, db *sql.DB) gin.HandlerFunc {
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

		if _, err := db.ExecContext(ctx, "DELETE FROM memes WHERE id = $1", memeID); err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		c.Status(http.StatusOK)
	}
}

func UpdateMeme(ctx context.Context, db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reqBytes, err := io.ReadAll(c.Request.Body)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}
		defer c.Request.Body.Close()

		var meme Meme
		if err := json.Unmarshal(reqBytes, &meme); err != nil {
			writeErr(c, http.StatusBadRequest, "ERROR: Unable to parse JSON\n"+err.Error())
			return
		}

		// Make sure that the request payload has the necessary data
		var errString []string
		if meme.ID <= 0 {
			errString = append(errString, "ERROR: JSON missing 'id'")
		}
		if len(meme.URL) == 0 {
			errString = append(errString, "ERROR: JSON missing 'url'")
		}
		if len(errString) != 0 {
			writeErr(c, http.StatusBadRequest, strings.Join(errString, "\n"))
			return
		}

		result, err := db.ExecContext(ctx, "UPDATE memes SET url = $1 WHERE id = $2", meme.URL, meme.ID)
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		rowsAffected, err := result.RowsAffected()
		if err != nil {
			writeErr(c, http.StatusInternalServerError, err.Error())
			return
		}

		if rowsAffected == 0 {
			writeErr(c, http.StatusBadRequest, fmt.Sprintf("ERROR: The requested ID %d doesn't exist", meme.ID))
			return
		}

		c.Status(http.StatusOK)
	}
}
