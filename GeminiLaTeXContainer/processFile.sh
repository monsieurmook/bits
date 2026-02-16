cat $1 | docker run -i -v $(pwd)/outputs:/mnt/user-data/outputs debuerrotype-gemini:latest
