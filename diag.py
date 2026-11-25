import ctypes
import urllib.request as u

TOKEN = "MTU3NDQ1MDgwODIyMzY5NTA2MQ.G4vqG-.n8_rOHpNkw5ElhyQMncLJLgVNqhBGSpyuvoXAQ"
HEADERS = {"Authorization": "Bot " + TOKEN, "User-Agent": "DiscordBot (c2,1.0)"}

print("python ok")
print("admin:", bool(ctypes.windll.shell32.IsUserAnAdmin()))

for path in ("/users/@me", "/guilds/1575248309768032257/channels"):
    try:
        response = u.urlopen(
            u.Request("https://discord.com/api/v10" + path, headers=HEADERS),
            timeout=15,
        )
        print(path, "->", response.status, len(response.read()))
    except Exception as error:
        print(path, "-> FAIL", repr(error))
