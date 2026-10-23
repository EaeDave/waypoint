.pragma library

// Core labels arrive in upper case for every client; the desktop shows each " · " segment in sentence case.
function sentenceCase(text) {
    return String(text || "").split(" · ").map(part => {
        const lower = part.toLocaleLowerCase();
        return lower.charAt(0).toLocaleUpperCase() + lower.slice(1);
    }).join(" · ");
}
