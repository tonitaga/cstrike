(function () {
    "use strict";
    var openingTime = 900, resultTime = 3000, landingTime = 350;
    var intro = document.getElementById("intro");
    var roulette = document.getElementById("roulette");
    var roller = document.getElementById("roller");
    var rail = document.getElementById("rail");
    var result = document.getElementById("result");
    var saved = document.getElementById("saved");
    var request = /^#([0-9,]+);([0-9]+);([0-9]+);([0-9]+);([0-9]+);([0-9]+);([0-9]+)$/.exec(location.hash);

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

    function card(item, large) {
        var block = document.createElement("div");
        var picture = document.createElement("img");
        block.className = "card " + item.tier + (large ? " result-card" : "");
        picture.src = item.image;
        picture.alt = item.weapon;
        block.appendChild(picture);
        block.appendChild(text("strong", item.weapon + " · " + item.name));
        block.appendChild(text("span", item.rarity));
        return block;
    }

    function showFallback() {
        hide(intro);
        show(saved);
        saved.firstElementChild.textContent = "Графическая рулетка недоступна";
        saved.lastElementChild.textContent = "Закрой окно и открой /wintercollection. Предмет уже выдан.";
    }

    if (!request || typeof caseCards === "undefined") {
        showFallback();
        return;
    }

    var ids = request[1].split(",");
    var startIndex = Number(request[2]);
    var targetIndex = Number(request[3]);
    var rewardId = Number(request[4]);
    var balance = Number(request[5]);
    var spinTime = Number(request[6]);
    var credit = Number(request[7]);
    var target = null;
    if (ids.length < 5 || ids.length > 40 || startIndex < 1 || targetIndex <= startIndex
        || targetIndex >= ids.length - 1 || Number(ids[targetIndex]) !== rewardId
        || !caseCards[rewardId] || spinTime < 1000 || spinTime > 15000) {
        showFallback();
        return;
    }
    for (var i = 0; i < ids.length; i++) {
        var item = caseCards[Number(ids[i])];
        if (!item) { showFallback(); return; }
        var element = card(item, false);
        rail.appendChild(element);
        if (i === targetIndex) { target = element; }
    }
    result.appendChild(card(caseCards[rewardId], true));
    var count = text("div", "Снежинок: " + balance);
    count.className = "balance";
    result.appendChild(count);
    if (credit > 0) {
        var sale = "Дубликат продан: +" + credit + " снежинок";
        var note = text("div", sale);
        note.className = "sale";
        result.appendChild(note);
        saved.firstElementChild.textContent = sale;
        saved.lastElementChild.textContent = "Баланс: " + balance + " снежинок.";
    }
    function animate(duration, draw, done) {
        var started = Date.now();
        function frame() {
            var progress = Math.min(1, (Date.now() - started) / duration);
            draw(progress);
            if (progress < 1) {
                window.setTimeout(frame, 16);
            } else {
                done();
            }
        }
        frame();
    }

    function offsetFor(cardElement) {
        return roller.clientWidth / 2 - cardElement.offsetLeft - cardElement.offsetWidth / 2;
    }

    function center(cardElement) {
        rail.style.left = offsetFor(cardElement) + "px";
    }

    function stop() {
        center(target);
        target.className += " selected";
        window.setTimeout(function () {
            hide(roulette);
            show(result);
            window.setTimeout(function () {
                hide(result);
                show(saved);
            }, resultTime);
        }, landingTime);
    }

    function spin() {
        hide(intro);
        show(roulette);
        var from = offsetFor(rail.children[startIndex]);
        animate(spinTime, function (progress) {
            var left = 1 - progress;
            var eased = 0.14 * progress + 0.86 * (1 - left * left * left);
            rail.style.left = (from + (offsetFor(target) - from) * eased) + "px";
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
