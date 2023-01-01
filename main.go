package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"

	"github.com/gorilla/websocket"
	jsoniter "github.com/json-iterator/go"
)

var upgrader = websocket.Upgrader{}

type query struct {
	URL string `json:"url"`
}

func validateURL(str string) bool {
	_, err := url.Parse(str)
	return err == nil
}

func main() {
	host := flag.String("host", os.Getenv("HOST"), "Host")
	flag.Parse()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Println("Connection made")

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Print("upgrade failed: ", err)
			return
		}

		defer conn.Close()

		// Continuously read and write message
		for {
			mt, message, err := conn.ReadMessage()
			if err != nil {
				log.Println("read failed:", err)
				break
			}

			var query query
			err = jsoniter.Unmarshal(message, &query)
			if err != nil {
				log.Println("read failed:", err)
				break
			}

			println("Query", query.URL)

			if validateURL(query.URL) {
				log.Println("Query for " + query.URL)
				command := fmt.Sprintf("yt-dlp %s -o - | ffmpeg -i pipe: -c:a dfpwm -b:a 48k -f wav pipe:", query.URL)

				println(command)

				cmd := exec.Command("bash", "-c", command)
				stdout, err := cmd.StdoutPipe()
				cmd.Stderr = cmd.Stdout
				if err != nil {
					log.Println("stdout failed:", err)
					break
				}
				if err = cmd.Start(); err != nil {
					log.Println("start failed:", err)
					break
				}

				for {
					tmp := make([]byte, 65536)
					_, err := stdout.Read(tmp)
					if err != nil {
						log.Println("read stdout failed:", err)
						break
					}

					err = conn.WriteMessage(mt, tmp)
					if err != nil {
						log.Println("write failed:", err)
						break
					}
				}
			}
		}
	})

	log.Println("Serving at " + *host)
	http.ListenAndServe(*host, nil)
}
