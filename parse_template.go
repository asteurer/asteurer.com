package main

import (
	"html/template"
	"os"
)

type TemplateData struct {
	Domain      string
	ProjectName string
	AWSRegion   string
	Email       string
}

func main() {
	data := &TemplateData{
		Domain:      os.Getenv("DOMAIN"),
		ProjectName: os.Getenv("PROJECT_NAME"),
		AWSRegion:   os.Getenv("AWS_REGION"),
		Email:       os.Getenv("EMAIL"),
	}

	content, err := os.ReadFile("init_template.yaml")
	if err != nil {
		panic(err)
	}

	tmpl, err := template.New("init_template").Parse(string(content))
	if err != nil {
		panic(err)
	}

	outFile, err := os.Create("init.yaml")
	if err != nil {
		panic(err)
	}

	if err := tmpl.Execute(outFile, data); err != nil {
		panic(err)
	}
}
