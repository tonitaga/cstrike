const fs = require("fs");
const https = require("https");
const os = require("os");
const path = require("path");
const { execFile } = require("child_process");
const { promisify } = require("util");

const execFileAsync = promisify(execFile);

const gameRoot = path.resolve(__dirname, "../../..");
const dataDir = path.join(gameRoot, "addons", "amxmodx", "data", "incom_tts");
const soundDir = path.join(gameRoot, "sound", "incom_tts");
const requestPath = path.join(dataDir, "request.txt");
const statusPath = path.join(dataDir, "status.txt");

const TTS_HOST = "translate.google.com";
const TTS_PATH = "/translate_tts";
const TTS_LANG = "ru-RU";

fs.mkdirSync(dataDir, { recursive: true });
fs.mkdirSync(soundDir, { recursive: true });

let busy = false;

function decodeChat(buf) {
  const utf8 = buf.toString("utf8");
  if (Buffer.from(utf8, "utf8").equals(buf) && !utf8.includes("\uFFFD")) {
    return utf8.replace(/^\uFEFF/, "").trim();
  }

  return new TextDecoder("windows-1251").decode(buf).trim();
}

function writeStatus(value) {
  fs.writeFileSync(statusPath, value);
}

function buildTtsUrl(text) {
  const query = new URLSearchParams({
    ie: "UTF-8",
    tl: TTS_LANG,
    client: "tw-ob",
    q: text,
  });

  return `${TTS_PATH}?${query.toString()}`;
}

function downloadTts(text) {
  const options = {
    hostname: TTS_HOST,
    path: buildTtsUrl(text),
    method: "GET",
    headers: {
      "User-Agent": "Mozilla/5.0",
      Referer: "https://translate.google.com/",
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        res.resume();
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }

      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => resolve(Buffer.concat(chunks)));
    });

    req.on("error", reject);
    req.end();
  });
}

function convertForEngine(input) {
  const tmpIn = path.join(os.tmpdir(), "incom_tts_in.mp3");
  const tmpOut = path.join(os.tmpdir(), "incom_tts_out.wav");
  fs.writeFileSync(tmpIn, input);

  return execFileAsync("ffmpeg", [
    "-y",
    "-hide_banner",
    "-loglevel", "error",
    "-i", tmpIn,
    "-ac", "1",
    "-ar", "8000",
    "-c:a", "pcm_s16le",
    tmpOut,
  ]).then(() => {
    const output = fs.readFileSync(tmpOut);
    fs.unlinkSync(tmpIn);
    fs.unlinkSync(tmpOut);
    return output;
  });
}

function writeSound(buffer) {
  const name = "voice.wav";
  const filePath = path.join(soundDir, name);
  const tmpPath = `${filePath}.tmp`;

  fs.writeFileSync(tmpPath, buffer);
  fs.renameSync(tmpPath, filePath);

  for (const file of fs.readdirSync(soundDir)) {
    if (file !== name && (file.endsWith(".mp3") || file.endsWith(".wav") || file.endsWith(".tmp"))) {
      try {
        fs.unlinkSync(path.join(soundDir, file));
      } catch (err) {}
    }
  }

  console.log(`sound/incom_tts/${name}`);
  return `sound/incom_tts/${name}`;
}

function processRequest() {
  if (busy || !fs.existsSync(requestPath)) {
    return;
  }

  let text = "";
  try {
    const buf = fs.readFileSync(requestPath);
    fs.unlinkSync(requestPath);
    text = decodeChat(buf);
  } catch (err) {
    return;
  }

  if (!text) {
    writeStatus("ERR");
    return;
  }

  busy = true;
  downloadTts(text)
    .then((buffer) => {
      if (!buffer.length) {
        throw new Error("empty audio");
      }

      return convertForEngine(buffer);
    })
    .then((buffer) => {
      writeStatus(`OK ${writeSound(buffer)}`);
    })
    .catch((err) => {
      console.error("[incom_tts]", err.message || err);
      writeStatus("ERR");
    })
    .finally(() => {
      busy = false;
    });
}

setInterval(processRequest, 200);
console.log("[incom_tts] helper started");
