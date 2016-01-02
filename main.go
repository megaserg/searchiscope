// Copyright 2015 Sergey Serebryakov. All rights reserved.

package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"

	"google.golang.org/appengine"
	"google.golang.org/appengine/urlfetch"
)

type twitterCredentials struct {
	ConsumerKey    string `json:"key"`
	ConsumerSecret string `json:"secret"`
}

const twitterAPIURL string = "https://api.twitter.com"

func makeAuthHandler(creds twitterCredentials) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		authHandler(creds, w, r)
	}
}

func authHandler(creds twitterCredentials, w http.ResponseWriter, r *http.Request) {
	url := twitterAPIURL + "/oauth2/token"

	body := "grant_type=client_credentials"
	bodyReader := bytes.NewBufferString(body)

	req, parseErr := http.NewRequest("POST", url, bodyReader)
	if parseErr != nil {
		http.Error(w, parseErr.Error(), 500)
		return
	}

	credsString := creds.ConsumerKey + ":" + creds.ConsumerSecret

	var buffer bytes.Buffer
	base64Encoder := base64.NewEncoder(base64.StdEncoding, &buffer)
	base64Encoder.Write([]byte(credsString))
	base64Encoder.Close()
	encodedCreds := buffer.String()

	authHeaderValue := "Basic " + encodedCreds

	req.Header.Add("Authorization", authHeaderValue)
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8")

	doRequest(w, r, req)
}

func searchHandler(w http.ResponseWriter, r *http.Request) {
	searchQuery := r.FormValue("query")
	searchGeocode := r.FormValue("coords")

	urlQuery :=
		"q=" + url.QueryEscape(searchQuery) +
			"&" + "geocode=" + searchGeocode +
			"&" + "result_type=" + "recent"

	url := &url.URL{
		Scheme:   "https",
		Host:     "api.twitter.com",
		Path:     "/1.1/search/tweets.json",
		RawQuery: urlQuery,
	}

	log.Print(url.String())

	req, parseErr := http.NewRequest("GET", url.String(), nil)
	if parseErr != nil {
		http.Error(w, parseErr.Error(), 500)
		return
	}

	authToken := r.FormValue("authToken")
	authHeaderValue := "Bearer " + authToken
	req.Header.Add("Authorization", authHeaderValue)

	doRequest(w, r, req)
}

func doRequest(w http.ResponseWriter, r *http.Request, reqToMake *http.Request) {
	ctx := appengine.NewContext(r)
	client := urlfetch.Client(ctx)
	resp, httpErr := client.Do(reqToMake)

	if httpErr != nil {
		http.Error(w, httpErr.Error(), 500)
		return
	}

	respBodyBuffer := new(bytes.Buffer)
	respBodyBuffer.ReadFrom(resp.Body)
	respBody := respBodyBuffer.String()
	fmt.Fprint(w, respBody)
	log.Print(respBody)
	return
}

func readConfig() twitterCredentials {
	configFile, openErr := os.Open("config/twitter_credentials.json")
	if openErr != nil {
		panic(openErr)
	}

	jsonParser := json.NewDecoder(configFile)

	var creds twitterCredentials
	if parseErr := jsonParser.Decode(&creds); parseErr != nil {
		panic(parseErr)
	}
	return creds
}

func init() {
	twitterCredentials := readConfig()
	http.HandleFunc("/auth", makeAuthHandler(twitterCredentials))
	http.HandleFunc("/search", searchHandler)
}
