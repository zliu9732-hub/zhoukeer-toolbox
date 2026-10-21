// Only NEW reviewed templates use this adapter. Existing translations keep their
// original wording and matching order; dynamic game names and paths stay intact.
const renkitThemeHubPatterns = __RENKIT_THEMEHUB_PATTERNS__.map(parts => ({parts,
    regex: new RegExp('^' + parts.map(part => part === null ? '([\\s\\S]*?)' : part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('') + '$')}));
const renkitThemeHubPreviousText = renkitThemeHubText;
renkitThemeHubText = function(value) {
    if (typeof value !== 'string') return value;
    if (Object.prototype.hasOwnProperty.call(renkitThemeHubZh.strings, value)) return renkitThemeHubZh.strings[value];
    for (const pattern of renkitThemeHubPatterns) {
        const match = pattern.regex.exec(value);
        if (!match) continue;
        let index = 0;
        return pattern.parts.map(part => part === null ? match[++index] : (renkitThemeHubZh.strings[part] ?? part)).join('');
    }
    return renkitThemeHubPreviousText(value);
};
