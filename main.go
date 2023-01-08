package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strconv"

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
			_, message, err := conn.ReadMessage()
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

				exec.Command("bash", "-c", fmt.Sprintf("yt-dlp --force-overwrites --extract-audio --audio-format opus %s -o out.opus", query.URL)).Run()
				exec.Command("bash", "-c", "ffmpeg -y -i out.opus -ac 1 -f wav -b:a 48000 -ar 48000 -c:a pcm_u8 out.pcm").Run()

				f, _ := os.Open("out.pcm")

				packets := make([][]byte, 0)

				for {
					tmp := make([]byte, 1024*16)
					_, err := f.Read(tmp)
					if err != nil {
						log.Println("read stdout failed:", err)
						break
					}

					packets = append(packets, tmp)
				}

				conn.WriteMessage(websocket.TextMessage, []byte(string(strconv.FormatInt(int64(len(packets)), 10))))

				bunchCount := 1

				confCmd := []byte("CONF")

				for packetIndex, packet := range packets {
					println(packetIndex)

					err = conn.WriteMessage(websocket.BinaryMessage, packet)
					if err != nil {
						log.Println("write failed:", err)
						break
					}

					if packetIndex%bunchCount == 0 {
						err = conn.WriteMessage(websocket.TextMessage, confCmd)
						if err != nil {
							log.Println("write failed:", err)
							break
						}

						// println("WAITING FOR ACK")

						_, _, err := conn.ReadMessage()
						if err != nil {
							log.Println("read failed:", err)
							break
						}
					}
				}

				print("Sent packets")
			}
		}
	})

	log.Println("Serving at " + *host)
	http.ListenAndServe(*host, nil)
}
