(function () {
    "use strict";
    var openingTime = 900, resultTime = 3000, landingTime = 350;
    var heading = document.getElementsByTagName("h1")[0];
    var intro = document.getElementById("intro");
    var roulette = document.getElementById("roulette");
    var result = document.getElementById("result");
    var resultContent = document.getElementById("result-content");
    var saved = document.getElementById("saved");
    var alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV";
    var mysteryKnife = "knife-mystery.png";
    var request = /^#([0-9a-zA-V,]+);(\d+);(\d+);(\d+);(\d+);([0-9,]+);(\d+)$/.exec(location.hash);

    function show(element) {
        element.className = element.className.replace(/\s*hidden\b/, "");
    }

    function hide(element) {
        element.className += " hidden";
    }

    function text(tag, value) {
        var element = document.createElement(tag);
        element.appendChild(document.createTextNode(value));
        return element;
    }

    function rollingImage(item) {
        return item.knife ? mysteryKnife : item.image;
    }

    function showItem(block, item, reveal) {
        var picture = block.firstChild;
        var resultCard = block.className.indexOf("result-card") !== -1;
        var concealed = item.knife && !resultCard && !reveal;
        block.className = "card " + item.tier + (resultCard ? " result-card" : "")
            + (concealed ? " knife-mystery" : "");
        picture.src = (concealed ? mysteryKnife : item.image) + "?v=13";
        picture.alt = concealed ? "Нож" : item.weapon;
        picture.nextSibling.textContent = concealed ? "Нож" : item.weapon + " · " + item.name;
        block.lastChild.textContent = item.rarity;
    }

    function card(item, large) {
        var block = document.createElement("div");
        block.className = large ? "card result-card" : "card";
        block.appendChild(document.createElement("img"));
        block.appendChild(document.createElement("strong"));
        block.appendChild(document.createElement("span"));
        if (item) {
            showItem(block, item);
        }
        return block;
    }

    function showFallback() {
        hide(intro);
        show(saved);
        saved.firstElementChild.textContent = "Графическая рулетка недоступна";
        saved.lastElementChild.textContent = "Закрой окно и открой /skins. Предмет уже выдан.";
    }

    if (!request || typeof caseCards === "undefined" || typeof caseSkinIds === "undefined") {
        showFallback();
        return;
    }

    var encoded = request[1].split(",");
    var startIndex = Number(request[2]);
    var targetIndex = Number(request[3]);
    var balance = Number(request[4]);
    var spinTime = Number(request[5]);
    var credits = request[6].split(",");
    var allowedCards = caseSkinIds[Number(request[7])];
    var rails = [];
    var preload = {};
    if (!allowedCards || encoded.length > 5 || encoded.length !== credits.length || startIndex < 1
        || targetIndex <= startIndex || spinTime < 1000 || spinTime > 15000) {
        showFallback();
        return;
    }
    if (encoded.length > 1) {
        result.className += " batch-result";
    }
    for (var row = 0; row < encoded.length; row++) {
        if (encoded[row].length < 5 || encoded[row].length > 40
            || targetIndex >= encoded[row].length - 1 || !/^\d+$/.test(credits[row])) {
            showFallback();
            return;
        }
        var roller = document.createElement("div");
        var marker = document.createElement("div");
        var rail = document.createElement("div");
        roller.className = "roller";
        marker.className = "marker";
        rail.className = "rail";
        roller.appendChild(marker);
        roller.appendChild(rail);
        roulette.appendChild(roller);
        var items = [];
        for (var i = 0; i < encoded[row].length; i++) {
            var item = caseCards[allowedCards[alphabet.indexOf(encoded[row].charAt(i))]];
            if (!item) { showFallback(); return; }
            items.push(item);
            var image = rollingImage(item);
            if (!preload[image]) {
                preload[image] = new Image();
                preload[image].src = image + "?v=13";
            }
        }
        rails.push({roller: roller, rail: rail, items: items, first: -1});
        var winner = card(items[targetIndex], true);
        if (Number(credits[row]) > 0) {
            var note = text("div", "Дубликат: +" + Number(credits[row]) + " снежинок");
            note.className = "sale";
            winner.appendChild(note);
        }
        resultContent.appendChild(winner);
    }
    var count = text("div", "Снежинок: " + balance);
    count.className = "balance";
    resultContent.appendChild(count);
    var requestFrame = window.requestAnimationFrame || window.msRequestAnimationFrame;
    var railStyle = document.createElement("div").style;
    var transformProperty = "transform" in railStyle ? "transform"
        : ("msTransform" in railStyle ? "msTransform" : null);

    function animate(duration, draw, done) {
        var started = Date.now();
        function frame() {
            var progress = Math.min(1, (Date.now() - started) / duration);
            draw(progress);
            if (progress < 1) {
                if (requestFrame) {
                    requestFrame.call(window, frame);
                } else {
                    window.setTimeout(frame, 16);
                }
            } else {
                done();
            }
        }
        frame();
    }

    var spinPosition = 0;
    var cardGap = 7;

    function placeRails() {
        for (var i = 0; i < rails.length; i++) {
            var row = rails[i];
            var x = row.from + row.distance * spinPosition;
            // Keep one spare card on each side of the clipped viewport.
            var first = Math.max(0, Math.min(row.items.length - row.poolSize,
                Math.floor(-x / row.step) - 1));
            if (row.first !== first) {
                for (var j = 0; j < row.poolSize; j++) {
                    var index = first + j;
                    var tile = row.rail.children[index % row.poolSize];
                    if (tile.item !== row.items[index]) {
                        tile.item = row.items[index];
                        showItem(tile, tile.item);
                    }
                    tile.style.left = (j * row.step) + "px";
                }
                row.first = first;
            }
            // The strip stays a viewport wide even when far along the sequence.
            x += first * row.step;
            if (transformProperty) {
                row.rail.style[transformProperty] = "translateX(" + x + "px)";
            } else {
                row.rail.style.left = x + "px";
            }
        }
    }

    function sizeRails() {
        if (!roulette.clientHeight) {
            return;
        }

        var count = rails.length;
        var height = roulette.clientHeight;
        var gap = Math.max(0, Math.min(14, Math.floor(height / (count * 12))));
        var usable = height - gap * (count - 1);
        var width = roulette.clientWidth;
        var widthLimit = Math.max(150, Math.floor(width * (count <= 2 ? 0.36 : 0.39)));
        for (var i = 0; i < count; i++) {
            var row = rails[i];
            var start = Math.floor(i * usable / count);
            var laneHeight = Math.floor((i + 1) * usable / count) - start;
            var font = Math.max(10, Math.min(19, Math.floor(laneHeight / 9)));
            var padding = laneHeight < 65 ? 2 : 6;
            var compact = laneHeight < 100;
            var pictureLimit = widthLimit - 2 * padding - (compact ? 104 : 2);
            var imageHeight = Math.max(1, Math.min(
                laneHeight - 2 * padding - (compact ? 5 : 3 * font + 8),
                Math.floor(pictureLimit * 224 / 480)));
            var imageWidth = Math.round(imageHeight * 480 / 224);
            var cardHeight = compact ? laneHeight
                : Math.min(laneHeight, imageHeight + 3 * font + 2 * padding + 8);
            var cardWidth = Math.min(widthLimit,
                Math.max(110, imageWidth + 2 * padding + (compact ? 104 : 2)));
            row.roller.className = compact ? "roller compact" : "roller";
            row.roller.style.top = (start + i * gap) + "px";
            row.roller.style.height = laneHeight + "px";
            row.rail.style.top = Math.floor((laneHeight - cardHeight) / 2) + "px";
            row.step = cardWidth + cardGap;
            row.from = (width - cardWidth) / 2 - startIndex * row.step;
            row.distance = (startIndex - targetIndex) * row.step;
            row.poolSize = Math.min(row.items.length, Math.ceil(width / row.step) + 3);
            row.first = -1;
            while (row.rail.children.length > row.poolSize) {
                row.rail.removeChild(row.rail.lastChild);
            }
            while (row.rail.children.length < row.poolSize) {
                row.rail.appendChild(card(null, false));
            }
            row.rail.style.width = (row.poolSize * row.step) + "px";
            for (var j = 0; j < row.poolSize; j++) {
                var tile = row.rail.children[j];
                var picture = tile.firstChild;
                tile.style.cssText = "width:" + cardWidth + "px;height:" + cardHeight
                    + "px;padding:" + padding + "px";
                picture.style.width = imageWidth + "px";
                picture.style.height = imageHeight + "px";
                picture.nextSibling.style.fontSize = font + "px";
                tile.lastChild.style.fontSize = Math.max(9, font - 2) + "px";
            }
        }
        placeRails();
        if (spinPosition === 1) {
            highlightWinner();
        }
    }

    function highlightWinner() {
        for (var i = 0; i < rails.length; i++) {
            var row = rails[i];
            var winner = row.rail.children[targetIndex % row.poolSize];
            showItem(winner, row.items[targetIndex], true);
            winner.className += " selected";
        }
    }

    function stop() {
        highlightWinner();
        window.setTimeout(function () {
            window.removeEventListener("resize", sizeRails, false);
            hide(roulette);
            hide(heading);
            show(result);
            window.setTimeout(function () {
                hide(result);
                show(heading);
                show(saved);
            }, resultTime);
        }, landingTime);
    }

    function spin() {
        hide(intro);
        show(roulette);
        sizeRails();
        window.addEventListener("resize", sizeRails, false);
        animate(spinTime, function (progress) {
            var left = 1 - progress;
            spinPosition = 0.14 * progress + 0.86 * (1 - left * left * left);
            placeRails();
        }, stop);
    }

    var lid = intro.getElementsByClassName("lid")[0];
    var glow = intro.getElementsByClassName("glow")[0];
    animate(openingTime, function (progress) {
        var lift = progress * progress;
        lid.style.top = (16 - 42 * lift) + "px";
        lid.style.height = (32 - 12 * lift) + "px";
        glow.style.opacity = String(.82 * lift);
    }, spin);
}());
